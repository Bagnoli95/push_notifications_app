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
      id: json['id'],
      title: json['title'],
      message: json['message'],
      isRead: json['is_read'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class NotificationService extends ChangeNotifier {
  static const String baseUrl = 'http://your-server-ip:8000'; // Cambiar por tu IP

  List<InternalNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InternalNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        _errorMessage = 'No authentication token';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(Uri.parse('$baseUrl/internal-notifications'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _notifications = (data['notifications'] as List).map((json) => InternalNotification.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to fetch notifications';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token');

      if (token == null) {
        return false;
      }

      final response = await http.put(Uri.parse('$baseUrl/internal-notifications/$notificationId/read'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});

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
        }
        return true;
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }

    return false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
