import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

class AuthService extends ChangeNotifier {
  static const String baseUrl = 'http://192.168.100.151:8000'; // Cambiar por tu IP

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

  void Function()? _onLoginSuccess;

  void setOnLoginSuccess(void Function()? callback) {
    _onLoginSuccess = callback;
  }

  AuthService() {
    _initializeService();
  }

  void _initializeService() {
    try {
      checkAuthStatus();
    } catch (e) {
      print('Error initializing AuthService: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> Function()? _postLoginCallback;

  void setPostLoginCallback(Future<void> Function()? callback) {
    _postLoginCallback = callback;
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('access_token');
      _userId = prefs.getInt('user_id');
      _username = prefs.getString('username');

      if (_token != null && _token!.isNotEmpty) {
        // Verificar si el token es válido
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/internal-notifications'),
            headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            _isAuthenticated = true;
            print('Token validation successful');
          } else {
            print('Token validation failed: ${response.statusCode}');
            await _clearAuthData();
          }
        } catch (e) {
          print('Network error during token validation: $e');
          // Don't clear auth data on network error, just set as not authenticated
          _isAuthenticated = false;
        }
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      print('Error checking auth status: $e');
      await _clearAuthData();
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'Username and password are required';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['access_token'] != null && data['user_id'] != null && data['username'] != null) {
            _token = data['access_token'];
            _userId = data['user_id'];
            _username = data['username'];
            _isAuthenticated = true;

            // Guardar en SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('access_token', _token!);
            await prefs.setInt('user_id', _userId!);
            await prefs.setString('username', _username!);

            print('Login successful for user: $_username (ID: $_userId)');

            // Registrar device después del login exitoso
            await _registerDevice();

            // ✨ AGREGAR ESTAS LÍNEAS:
            if (_onLoginSuccess != null) {
              _onLoginSuccess!();
              _onLoginSuccess = null;
            }

            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _errorMessage = 'Invalid response from server';
            _isLoading = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          _errorMessage = 'Error processing server response';
          print('Error parsing login response: $e');
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          _errorMessage = error['detail'] ?? 'Login failed';
        } catch (e) {
          _errorMessage = 'Login failed with status: ${response.statusCode}';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: Please check your connection';
      print('Login network error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    if (username.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      _errorMessage = 'All fields are required';
      notifyListeners();
      return false;
    }

    if (!email.contains('@')) {
      _errorMessage = 'Please enter a valid email address';
      notifyListeners();
      return false;
    }

    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username.trim(), 'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        try {
          final error = jsonDecode(response.body);
          _errorMessage = error['detail'] ?? 'Registration failed';
        } catch (e) {
          _errorMessage = 'Registration failed with status: ${response.statusCode}';
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: Please check your connection';
      print('Registration network error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _registerDevice() async {
    try {
      // Check if we have a valid token
      if (_token == null || _token!.isEmpty) {
        print('Cannot register device: No auth token');
        return;
      }

      print('Starting device registration...');

      // Obtener FCM token con manejo de errores
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        print('FCM Token obtained: ${fcmToken?.substring(0, 20)}...');
      } catch (e) {
        print('Error getting FCM token: $e');
        // Continue without FCM token - app can still work
        return;
      }

      // Obtener device ID con manejo de errores
      String? deviceId;
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        print('Device ID obtained: $deviceId');
      } catch (e) {
        print('Error getting device info: $e');
        deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (fcmToken != null && fcmToken.isNotEmpty && deviceId != null) {
        try {
          final response = await http
              .post(
                Uri.parse('$baseUrl/register-device'),
                headers: {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'},
                body: jsonEncode({'fcm_token': fcmToken, 'device_id': deviceId}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            print('Device registered successfully');
          } else {
            print('Failed to register device: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          print('Network error during device registration: $e');
        }
      } else {
        print('Cannot register device: Missing FCM token or device ID');
      }
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      print('Starting biometric authentication...');

      // Check if biometrics are available
      bool canCheckBiometrics = false;
      bool isDeviceSupported = false;

      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
        isDeviceSupported = await _localAuth.isDeviceSupported();
        print('Biometrics available: $canCheckBiometrics, Device supported: $isDeviceSupported');
      } catch (e) {
        print('Error checking biometric availability: $e');
        return false;
      }

      if (!canCheckBiometrics || !isDeviceSupported) {
        print('Biometrics not available or device not supported');
        return false;
      }

      // Check available biometric types
      List<BiometricType> availableBiometrics = [];
      try {
        availableBiometrics = await _localAuth.getAvailableBiometrics();
        print('Available biometrics: $availableBiometrics');
      } catch (e) {
        print('Error getting available biometrics: $e');
        return false;
      }

      if (availableBiometrics.isEmpty) {
        print('No biometric methods available');
        return false;
      }

      // Perform biometric authentication
      bool didAuthenticate = false;
      try {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to access the app',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        print('Biometric authentication result: $didAuthenticate');
      } catch (e) {
        print('Error during biometric authentication: $e');
        return false;
      }

      return didAuthenticate;
    } catch (e) {
      print('Unexpected error during biometric authentication: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _clearAuthData();
      _isAuthenticated = false;
      _token = null;
      _userId = null;
      _username = null;
      _errorMessage = null;
      notifyListeners();
      print('User logged out successfully');
    } catch (e) {
      print('Error during logout: $e');
      // Force reset even if there's an error
      _isAuthenticated = false;
      _token = null;
      _userId = null;
      _username = null;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _clearAuthData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      await prefs.remove('username');
      print('Auth data cleared from SharedPreferences');
    } catch (e) {
      print('Error clearing auth data: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Helper method to validate if user is properly authenticated
  bool isValidSession() {
    return _isAuthenticated && _token != null && _token!.isNotEmpty && _userId != null && _username != null && _username!.isNotEmpty;
  }

  // Helper method to get auth headers
  Map<String, String> getAuthHeaders() {
    if (_token != null && _token!.isNotEmpty) {
      return {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };
    }
    return {'Content-Type': 'application/json'};
  }

  // Method to refresh token if needed (can be implemented later)
  Future<bool> refreshTokenIfNeeded() async {
    // Placeholder for token refresh logic
    // This would be useful for longer sessions
    return isValidSession();
  }
}
