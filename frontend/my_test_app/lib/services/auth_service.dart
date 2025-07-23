import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

class AuthService extends ChangeNotifier {
  static const String baseUrl = 'http://your-server-ip:8000'; // Cambiar por tu IP

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  int? _userId;
  String? _username;
  String? _errorMessage;

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  int? get userId => _userId;
  String? get username => _username;
  String? get errorMessage => _errorMessage;

  AuthService() {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token');
      _userId = prefs.getInt('user_id');
      _username = prefs.getString('username');

      if (_token != null) {
        // Verificar si el token es válido
        final response = await http.get(Uri.parse('$baseUrl/internal-notifications'), headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'});

        if (response.statusCode == 200) {
          _isAuthenticated = true;
        } else {
          await _clearAuthData();
        }
      }
    } catch (e) {
      print('Error checking auth status: $e');
      await _clearAuthData();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(Uri.parse('$baseUrl/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': username, 'password': password}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _token = data['access_token'];
        _userId = data['user_id'];
        _username = data['username'];
        _isAuthenticated = true;

        // Guardar en SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _token!);
        await prefs.setInt('user_id', _userId!);
        await prefs.setString('username', _username!);

        // Registrar device después del login exitoso
        await _registerDevice();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final error = jsonDecode(response.body);
        _errorMessage = error['detail'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(Uri.parse('$baseUrl/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'username': username, 'email': email, 'password': password}));

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final error = jsonDecode(response.body);
        _errorMessage = error['detail'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _registerDevice() async {
    try {
      // Obtener FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      // Obtener device ID
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      String deviceId = androidInfo.id;

      if (fcmToken != null) {
        final response = await http.post(
          Uri.parse('$baseUrl/register-device'),
          headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
          body: jsonEncode({'fcm_token': fcmToken, 'device_id': deviceId}),
        );

        if (response.statusCode == 200) {
          print('Device registered successfully');
        } else {
          print('Failed to register device: ${response.body}');
        }
      }
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }

      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );

      return didAuthenticate;
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _clearAuthData();
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> _clearAuthData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('username');

    _token = null;
    _userId = null;
    _username = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
