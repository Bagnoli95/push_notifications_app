import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/pending_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_detail_screen.dart';
import 'dart:convert';

// Handler para notificaciones en background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Handling a background message: ${message.messageId}');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Configurar handler para mensajes en background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Configurar notificaciones locales
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Manejar tap en notificación
      if (response.payload != null) {
        try {
          Map<String, dynamic> payloadData = jsonDecode(response.payload!);
          navigatorKey.currentState?.pushNamed(
            '/notification-detail',
            arguments: payloadData,
          );
        } catch (e) {
          print('Error parsing notification payload: $e');
        }
      }
    },
  );

  runApp(MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'Push Notifications App',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: AuthWrapper(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/home': (context) => HomeScreen(),
          '/notification-detail': (context) => NotificationDetailScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Streams subscriptions para poder cancelarlas en dispose
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _setupFirebaseMessaging();
  }

  @override
  void dispose() {
    // Cancelar subscriptions para evitar memory leaks
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    super.dispose();
  }

  void _checkAuthStatus() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.checkAuthStatus();

    // Verificar si hay notificación pendiente después de verificar auth
    if (mounted && authService.isAuthenticated) {
      _checkForPendingNotifications();
    }
  }

  void _checkForPendingNotifications() async {
    if (!mounted) return;

    try {
      Map<String, dynamic>? pendingNotification = await PendingNotificationService.getPendingNotification();

      if (pendingNotification != null && mounted) {
        print('📬 Found pending notification on startup: ${pendingNotification['title']}');

        // Delay para asegurar que la UI esté lista
        await Future.delayed(const Duration(milliseconds: 1000));

        if (mounted) {
          _goToNotificationDetail(pendingNotification);
        }
      }
    } catch (e) {
      print('❌ Error checking pending notifications: $e');
    }
  }

  void _setupFirebaseMessaging() async {
    if (!mounted) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Handle foreground messages - Usar subscription para poder cancelar
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!mounted) return;

      print('🔔 Got a message whilst in the foreground!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      if (message.notification != null) {
        _showNotification(message);
      }
    });

    // Handle notification tap when app is in background but not terminated
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (!mounted) return;

      print('🔔 A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message);
    });

    // Handle notification tap when app is terminated
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && mounted) {
      print('🔔 Got initial message on app launch!');
      // Delay handling to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleNotificationTap(initialMessage);
        }
      });
    }
  }

  void _showNotification(RemoteMessage message) async {
    if (!mounted) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: jsonEncode({
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? 'No content',
        'data': message.data,
        'type': 'push_notification',
        'isInternal': false,
      }),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // ✅ VERIFICAR mounted ANTES de usar context
    if (!mounted) {
      print('⚠️ Widget unmounted, cannot handle notification tap');
      return;
    }

    print('🔔 Notification tapped!');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');

    // ✅ USAR try-catch para manejo de errores
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Crear datos de notificación
      Map<String, dynamic> notificationData = {
        'title': message.notification?.title ?? 'Push Notification',
        'body': message.notification?.body ?? 'No content available',
        'data': message.data ?? {},
        'isInternal': false,
      };

      print('📦 Notification data prepared: $notificationData');

      if (authService.isAuthenticated) {
        // Usuario logueado: ir directamente al detalle
        print('✅ User authenticated - Going to detail');
        _goToNotificationDetail(notificationData);
      } else {
        // Usuario NO logueado: guardar y redirigir a login
        print('❌ User not authenticated - Saving for later');
        PendingNotificationService.savePendingNotification(notificationData);

        // ✅ VERIFICAR mounted antes de navegar
        if (mounted) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  void _goToNotificationDetail(Map<String, dynamic> notificationData) {
    // ✅ VERIFICAR mounted antes de navegar
    if (!mounted) {
      print('⚠️ Widget unmounted, cannot navigate to detail');
      return;
    }

    print('🚀 Navigating to detail with: $notificationData');

    try {
      navigatorKey.currentState?.pushNamed('/notification-detail', arguments: notificationData);
    } catch (e) {
      print('❌ Error navigating to notification detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (authService.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        return authService.isAuthenticated ? HomeScreen() : LoginScreen();
      },
    );
  }
}
