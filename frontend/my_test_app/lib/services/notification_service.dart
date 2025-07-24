import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InternalNotification {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  InternalNotification({required this.id, required this.title, required this.message, required this.isRead, this.createdAt});

  factory InternalNotification.fromJson(Map<String, dynamic> json) {
    return InternalNotification(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is InternalNotification && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class NotificationService extends ChangeNotifier {
  static const String baseUrl = 'http://192.168.100.151:8000'; // Cambiar por tu IP

  List<InternalNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetch;

  List<InternalNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool showLoading = false}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        _errorMessage = 'No authentication token';
        if (showLoading) {
          _isLoading = false;
          notifyListeners();
        }
        return;
      }

      print('🔄 Fetching internal notifications...');

      final response = await http.get(
        Uri.parse('$baseUrl/internal-notifications'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['notifications'] != null) {
          List<InternalNotification> newNotifications = (data['notifications'] as List)
              .map((json) {
                try {
                  return InternalNotification.fromJson(json);
                } catch (e) {
                  print('Error parsing notification: $e');
                  return null;
                }
              })
              .where((notification) => notification != null)
              .cast<InternalNotification>()
              .toList();

          // Verificar si hay nuevas notificaciones
          bool hasNewNotifications = _hasNewNotifications(newNotifications);

          _notifications = newNotifications;
          _lastFetch = DateTime.now();

          if (hasNewNotifications) {
            print('🔔 New notifications detected! Total: ${_notifications.length}, Unread: $unreadCount');
          }

          print('📊 Notifications updated: ${_notifications.length} total, $unreadCount unread');
        } else {
          _notifications = [];
        }

        _errorMessage = null;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Authentication expired';
        print('❌ Auth token expired, need to re-login');
      } else {
        _errorMessage = 'Failed to fetch notifications: ${response.statusCode}';
        print('❌ Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Network error fetching notifications: $e');
    }

    if (showLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  bool _hasNewNotifications(List<InternalNotification> newNotifications) {
    if (_notifications.isEmpty && newNotifications.isNotEmpty) {
      return true;
    }

    if (newNotifications.length != _notifications.length) {
      return true;
    }

    // Check if any notification has different read status
    for (var newNotif in newNotifications) {
      var existingNotif = _notifications.firstWhere(
        (n) => n.id == newNotif.id,
        orElse: () => InternalNotification(id: -1, title: '', message: '', isRead: true),
      );

      if (existingNotif.id == -1 || existingNotif.isRead != newNotif.isRead) {
        return true;
      }
    }

    return false;
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        print('❌ Cannot mark as read: No auth token');
        return false;
      }

      print('✅ Marking notification $notificationId as read...');

      final response = await http.put(
        Uri.parse('$baseUrl/internal-notifications/$notificationId/read'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Actualizar localmente
        int index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = InternalNotification(
            id: _notifications[index].id,
            title: _notifications[index].title,
            message: _notifications[index].message,
            isRead: true,
            createdAt: _notifications[index].createdAt,
          );
          notifyListeners();
          print('✅ Notification $notificationId marked as read locally');
        }
        return true;
      } else {
        print('❌ Failed to mark notification as read: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Método para forzar refresh manual
  Future<void> refreshNotifications() async {
    print('🔄 Manual refresh requested...');
    await fetchNotifications(showLoading: true);
  }

  // Método para verificar si necesita actualizar
  bool shouldRefresh() {
    if (_lastFetch == null) return true;

    final now = DateTime.now();
    final difference = now.difference(_lastFetch!);

    // Refresh si han pasado más de 30 segundos
    return difference.inSeconds > 30;
  }
}
