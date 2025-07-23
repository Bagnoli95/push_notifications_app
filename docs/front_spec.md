# 📱 Push Notifications App - Frontend Specification

## 📋 Información General

**Framework:** Flutter 3.0+  
**Plataforma:** Android (APK)  
**Lenguaje:** Dart  
**Arquitectura:** Provider Pattern (State Management)  
**Autenticación:** JWT + Biometric Authentication  

---

## 🏗️ Arquitectura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada de la aplicación
├── services/                    # Servicios de negocio
│   ├── auth_service.dart       # Manejo de autenticación
│   └── notification_service.dart # Manejo de notificaciones internas
├── screens/                    # Pantallas de la aplicación
│   ├── login_screen.dart       # Pantalla de login/registro
│   ├── home_screen.dart        # Pantalla principal
│   └── notification_detail_screen.dart # Detalle de notificaciones
└── widgets/                    # Componentes reutilizables
    └── notification_bell.dart  # Campanita de notificaciones
```

---

## 📦 Dependencias Principales

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP requests
  http: ^1.1.0
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.10
  
  # Local notifications
  flutter_local_notifications: ^16.3.2
  
  # Biometric authentication
  local_auth: ^2.1.7
  
  # Storage
  shared_preferences: ^2.2.2
  
  # State management
  provider: ^6.1.1
  
  # Device info
  device_info_plus: ^9.1.1
```

---

## 🔐 Sistema de Autenticación

### Flujo de Autenticación
1. **Login tradicional** con username/password
2. **Autenticación biométrica** (huella dactilar)
3. **Registro automático de device** post-login
4. **Persistencia de sesión** con SharedPreferences

### AuthService Capabilities
```dart
class AuthService extends ChangeNotifier {
  // Estado de autenticación
  bool isAuthenticated
  bool isLoading
  String? token
  int? userId
  String? username
  String? errorMessage
  
  // Métodos principales
  Future<bool> login(String username, String password)
  Future<bool> register(String username, String email, String password)
  Future<bool> authenticateWithBiometrics()
  Future<void> logout()
  Future<void> checkAuthStatus()
}
```

### Características de Seguridad
- **JWT Token Storage** en SharedPreferences
- **Validación automática** de tokens en startup
- **Biometric fallback** para re-autenticación
- **Auto-logout** cuando token expira

---

## 📱 Pantallas y Navegación

### 1. 🔑 **Login Screen** (`/login`)

#### Funcionalidades
- **Modo Login/Register** con toggle
- **Validación de campos** en tiempo real
- **Autenticación biométrica** como alternativa
- **Manejo de errores** con UI feedback

#### UI Components
```dart
// Campos del formulario
TextFormField username
TextFormField email (solo en registro)
TextFormField password (con show/hide)

// Botones de acción
ElevatedButton login/register
OutlinedButton biometric_auth
TextButton toggle_mode
```

#### Validaciones
- **Username**: Requerido, no vacío
- **Email**: Formato válido, requerido en registro
- **Password**: Mínimo 6 caracteres en registro

### 2. 🏠 **Home Screen** (`/home`)

#### Funcionalidades
- **Dashboard principal** con información del usuario
- **Estado del sistema** (autenticación, dispositivos, notificaciones)
- **Campanita de notificaciones** en AppBar
- **Menú de usuario** con logout

#### UI Components
```dart
AppBar(
  title: "Push Notifications App",
  actions: [
    NotificationBell(),      // Campanita con contador
    PopupMenuButton()        // Menú de usuario
  ]
)

// Cards informativos
StatusCard authentication_status
StatusCard device_registration
StatusCard push_notifications
StatusCard internal_notifications
InfoCard how_it_works
```

#### Features
- **Gradient background** para mejor UX
- **Cards con elevación** para información
- **Indicadores de estado** en tiempo real
- **Navegación fluida** entre secciones

### 3. 📄 **Notification Detail Screen** (`/notification-detail`)

#### Funcionalidades
- **Vista detallada** de notificaciones push/internas
- **Diferenciación visual** entre tipos de notificación
- **Información del usuario** receptor
- **Metadata adicional** si está disponible

#### UI Components
```dart
// Header card
Card notification_header {
  Icon type_indicator
  Text notification_type
  Text title
}

// Content card
Card message_content {
  Container formatted_message
}

// Additional data (opcional)
Card additional_data {
  KeyValue metadata_pairs
}

// User info
Card user_info {
  CircleAvatar user_avatar
  UserDetails username_and_id
}
```

---

## 🔔 Sistema de Notificaciones

### Push Notifications (FCM)
```dart
// Configuración en main.dart
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler)
FirebaseMessaging.onMessage.listen(_showNotification)
FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap)
```

#### Flujo de Push Notifications
1. **Firebase setup** en app startup
2. **Permission request** para notificaciones
3. **Token registration** automático post-login
4. **Notificación nativa** del sistema Android
5. **Navigation handling** al tocar notificación
6. **Biometric auth** si usuario no está logueado

### Internal Notifications
```dart
class NotificationService extends ChangeNotifier {
  List<InternalNotification> notifications
  bool isLoading
  int unreadCount
  
  Future<void> fetchNotifications()
  Future<bool> markAsRead(int notificationId)
}
```

#### Campanita de Notificaciones
- **Badge con contador** de no leídas
- **Menu dropdown** con vista previa
- **Scroll infinito** en dialog modal
- **Mark as read** automático al tocar
- **Navigation** a pantalla de detalle

---

## 🎨 UI/UX Design

### Color Scheme
```dart
ThemeData(
  primarySwatch: Colors.blue,
  useMaterial3: true,
)

// Colores principales
primary_color: Colors.blue
success_color: Colors.green  
warning_color: Colors.orange
error_color: Colors.red
```

### Design Patterns
- **Material Design 3** como base
- **Cards con elevación** para contenido
- **Gradients sutiles** en backgrounds
- **Iconografía consistente** en toda la app
- **Animation smooth** en transiciones

### Responsive Design
- **SafeArea** para diferentes dispositivos
- **Flexible layouts** con Column/Row
- **Scroll views** para contenido largo
- **Adaptive sizing** para diferentes pantallas

---

## 🛠️ Servicios y Utilidades

### HTTP Service Configuration
```dart
// Base URL configuration
static const String baseUrl = 'http://your-server-ip:8000';

// Headers standard
headers: {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
}
```

### Local Storage (SharedPreferences)
```dart
// Datos persistidos
'access_token': String
'user_id': int  
'username': String
```

### Device Information
```dart
// Info del dispositivo para FCM
DeviceInfoPlugin deviceInfo
AndroidDeviceInfo androidInfo
String deviceId = androidInfo.id
String? fcmToken = await FirebaseMessaging.instance.getToken()
```

---

## 🔄 State Management (Provider)

### Providers Setup
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthService()),
    ChangeNotifierProvider(create: (_) => NotificationService()),
  ],
  child: MaterialApp(...)
)
```

### State Consumption
```dart
// Reactive UI updates
Consumer<AuthService>(
  builder: (context, authService, child) {
    if (authService.isLoading) return CircularProgressIndicator();
    return authService.isAuthenticated ? HomeScreen() : LoginScreen();
  },
)
```

---

## 🚀 Build y Deployment

### Configuración de Build
```yaml
# pubspec.yaml
version: 1.0.0+1

flutter:
  uses-material-design: true
```

### Android Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Firebase Setup Requerido
1. **google-services.json** en `android/app/`
2. **Firebase project** configurado
3. **Cloud Messaging** habilitado
4. **SHA-1 certificate** registrado

### Commands de Build
```bash
# Debug build
flutter run

# Release APK
flutter build apk --release

# Install APK
flutter install --release
```

---

## 🧪 Testing y Debug

### Debug Features
- **Hot reload** para desarrollo rápido
- **Console logs** para debugging
- **Error handling** con try-catch
- **Network logs** para API calls

### Test Users
```dart
// Usuario de prueba
username: "admin"
password: "admin123"
```

### Common Debug Scenarios
```dart
// Verificar estado de autenticación
print('Auth status: ${authService.isAuthenticated}');
print('Token: ${authService.token}');

// Debug FCM token
String? fcmToken = await FirebaseMessaging.instance.getToken();
print('FCM Token: $fcmToken');

// Debug notificaciones
print('Unread notifications: ${notificationService.unreadCount}');
```

---

## ⚡ Performance Optimizations

### Memory Management
- **Dispose controllers** en StatefulWidgets
- **Lazy loading** de notificaciones
- **Image caching** automático de Flutter

### Network Optimization
- **HTTP client reuse** para múltiples requests
- **Error retry logic** en servicios
- **Timeout configuration** para requests

### UI Performance
- **const constructors** donde sea posible
- **ListView.builder** para listas largas
- **Avoid rebuilds** innecesarios con Consumer

---

## 🔧 Configuración de Desarrollo

### Environment Setup
```bash
# Flutter version
flutter --version
# Debe ser 3.0+

# Check doctor
flutter doctor

# Get dependencies
flutter pub get
```

### IDE Recommendations
- **Android Studio** con Flutter plugin
- **VS Code** con Dart/Flutter extensions
- **Emulator** Android API 21+ para testing

### Required Files
```
android/app/google-services.json    # Firebase config
android/app/src/main/AndroidManifest.xml    # Permissions
```

---

## 🐛 Troubleshooting

### Common Issues

#### FCM Token Issues
```dart
// Force refresh token
await FirebaseMessaging.instance.deleteToken();
String? newToken = await FirebaseMessaging.instance.getToken();
```

#### Biometric Authentication Issues  
```dart
// Check biometric availability
final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
final bool isDeviceSupported = await _localAuth.isDeviceSupported();
```

#### Navigation Issues
```dart
// Use named routes for better navigation
Navigator.pushNamed(context, '/notification-detail', arguments: data);
```

#### Network Issues
```dart
// Add timeout to HTTP requests
final response = await http.post(
  uri,
  headers: headers,
  body: body,
).timeout(Duration(seconds: 30));
```

---

## 📈 Future Enhancements

### Potential Features
- **Dark mode** support
- **Offline mode** con local database
- **Push notification scheduling**
- **User preferences** screen
- **Notification categories** y filtering
- **Multi-language** support (i18n)

### Technical Improvements
- **State management upgrade** (Riverpod/Bloc)
- **Unit testing** implementation
- **Integration testing** para flows críticos
- **CI/CD pipeline** para deployment automático

---

## 📞 Development Support

### Key Files to Monitor
- `main.dart` - App initialization y Firebase setup
- `auth_service.dart` - Authentication logic
- `notification_service.dart` - Internal notifications
- `AndroidManifest.xml` - Permissions y configuration

### Debug Commands
```bash
# See logs
flutter logs

# Clean build
flutter clean && flutter pub get

# Build verbose
flutter build apk --verbose
```

---

## 📋 Checklist de Deployment

### Pre-Release
- [ ] Cambiar `baseUrl` en services a IP de producción
- [ ] Verificar `google-services.json` de producción
- [ ] Testing completo en dispositivo físico
- [ ] Verificar permisos de Android
- [ ] Test de notificaciones push
- [ ] Test de autenticación biométrica

### Release Build
- [ ] `flutter build apk --release`
- [ ] Test APK en múltiples dispositivos
- [ ] Verificar size del APK (<50MB recomendado)
- [ ] Documentación actualizada

---

*Última actualización: Julio 2025*