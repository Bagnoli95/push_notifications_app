import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:push_notifications_app/services/pending_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _rememberCredentials = true;
  bool _isLoading = false;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedCredentials();
  }

  void _initializeAnimations() {
    try {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ));

      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ));

      _scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ));

      _animationController?.forward();
    } catch (e) {
      print('Error initializing animations: $e');
      // Continue without animations if there's an error
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String savedUsername = prefs.getString('saved_username') ?? 'testuser123';
      String savedPassword = prefs.getString('saved_password') ?? 'password123';
      bool rememberMe = prefs.getBool('remember_credentials') ?? true;

      if (mounted) {
        setState(() {
          _usernameController.text = savedUsername;
          _passwordController.text = savedPassword;
          _rememberCredentials = rememberMe;
        });
      }
    } catch (e) {
      print('Error loading credentials: $e');
      // Use default test credentials if loading fails
      if (mounted) {
        setState(() {
          _usernameController.text = 'testuser123';
          _passwordController.text = 'password123';
        });
      }
    }
  }

  void _saveCredentials() async {
    try {
      if (_rememberCredentials && _isLoginMode) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_username', _usernameController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('remember_credentials', true);
      }
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  void _toggleMode() {
    if (mounted) {
      setState(() {
        _isLoginMode = !_isLoginMode;
        if (!_isLoginMode) {
          _emailController.clear();
        }
      });

      try {
        Provider.of<AuthService>(context, listen: false).clearError();
      } catch (e) {
        print('Error clearing auth error: $e');
      }
    }
  }

  void _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      bool success = false;

      if (_isLoginMode) {
        authService.setOnLoginSuccess(() async {
          await _checkPendingNotifications();
        });

        success = await authService.login(_usernameController.text.trim(), _passwordController.text);

        if (success) {
          _saveCredentials();

          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      } else {
        success = await authService.register(_usernameController.text.trim(), _emailController.text.trim(), _passwordController.text);

        if (success) {
          _showSuccessDialog();
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print('Error during submit: $e');
      if (mounted) {
        _showErrorSnackBar('An error occurred. Please try again.');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPendingNotifications() async {
    try {
      Map<String, dynamic>? pendingNotification = await PendingNotificationService.getPendingNotification();

      if (pendingNotification != null && mounted) {
        print('🎯 Processing pending notification after login');

        // Delay para asegurar que la navegación termine
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          Navigator.of(context).pushNamed('/notification-detail', arguments: pendingNotification);
        }
      }
    } catch (e) {
      print('❌ Error processing pending notification: $e');
    }
  }

  void _authenticateWithBiometrics() async {
    if (!mounted) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Authenticating with biometrics...'),
                ],
              ),
            ),
          ),
        ),
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      bool authenticated = await authService.authenticateWithBiometrics();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (authenticated) {
        await authService.checkAuthStatus();
        if (authService.isAuthenticated && mounted) {
          // Verificar notificación pendiente
          await _checkPendingNotifications();
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          _showBiometricInfoDialog();
        }
      } else {
        _showErrorSnackBar('Biometric authentication failed or not available');
      }
    } catch (e) {
      print('Error during biometric auth: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        _showErrorSnackBar('Biometric authentication error');
      }
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: const Text('Registration successful! Please login with your new account.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
                _toggleMode();
              }
            },
            child: const Text('Login Now'),
          ),
        ],
      ),
    );
  }

  void _showBiometricInfoDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Biometric Login'),
          ],
        ),
        content: const Text(
          'Biometric authentication was successful, but no saved session was found. Please login with your username and password first.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _fillTestCredentials() {
    if (mounted) {
      setState(() {
        _usernameController.text = 'testuser123';
        _passwordController.text = 'password123';
        if (!_isLoginMode) {
          _emailController.text = 'test@example.com';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.6),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_animationController != null && _fadeAnimation != null && _slideAnimation != null && _scaleAnimation != null) {
      return AnimatedBuilder(
        animation: _animationController!,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation!,
            child: SlideTransition(
              position: _slideAnimation!,
              child: ScaleTransition(
                scale: _scaleAnimation!,
                child: _buildMainContent(),
              ),
            ),
          );
        },
      );
    } else {
      // Fallback without animations
      return _buildMainContent();
    }
  }

  Widget _buildMainContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 20,
            shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildErrorDisplay(),
                  _buildLoginForm(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  if (_isLoginMode) ...[
                    const SizedBox(height: 24),
                    _buildBiometricButton(),
                  ],
                  const SizedBox(height: 24),
                  _buildToggleModeButton(),
                  if (_isLoginMode) ...[
                    const SizedBox(height: 16),
                    _buildTestCredentialsButton(),
                    _buildDebugBiometricButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_active,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isLoginMode ? 'Welcome Back!' : 'Create Account',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginMode ? 'Sign in to continue to your account' : 'Create a new account to get started',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorDisplay() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final errorMessage = authService.errorMessage;
        if (errorMessage != null && errorMessage.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200] ?? Colors.red),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your username';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          if (!_isLoginMode) ...[
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (!_isLoginMode && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          if (_isLoginMode) ...[
            const SizedBox(height: 16),
            _buildRememberMeCheckbox(),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                ),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  }
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300] ?? Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300] ?? Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberCredentials,
          onChanged: (value) {
            if (mounted) {
              setState(() {
                _rememberCredentials = value ?? false;
              });
            }
          },
          activeColor: Theme.of(context).primaryColor,
        ),
        Text(
          'Remember my credentials',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isServiceLoading = authService.isLoading;
        final isLoading = _isLoading || isServiceLoading;

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
            child: isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...'),
                    ],
                  )
                : Text(
                    _isLoginMode ? 'Login' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBiometricButton() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300] ?? Colors.blue),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.blue[50] ?? Colors.blue.withOpacity(0.1),
            Colors.blue[25] ?? Colors.blue.withOpacity(0.05),
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: _authenticateWithBiometrics,
          icon: const Icon(Icons.fingerprint, size: 24),
          label: const Text(
            'Login with Biometrics',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue[700],
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleModeButton() {
    return TextButton(
      onPressed: _toggleMode,
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.grey[600]),
          children: [
            TextSpan(
              text: _isLoginMode ? "Don't have an account? " : "Already have an account? ",
            ),
            TextSpan(
              text: _isLoginMode ? 'Sign up' : 'Sign in',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCredentialsButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200] ?? Colors.orange),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Development Mode',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Test credentials: testuser123 / password123',
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: _fillTestCredentials,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange[700],
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('Fill', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugBiometricButton() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200] ?? Colors.purple),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.purple[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Debug Biometric',
                style: TextStyle(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              _debugBiometricCredentials();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Check Saved Credentials'),
          ),
        ],
      ),
    );
  }

  void _debugBiometricCredentials() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      String? savedUsername = prefs.getString('saved_username');
      String? savedPassword = prefs.getString('saved_password');
      bool biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      bool rememberCredentials = prefs.getBool('remember_credentials') ?? false;

      String debugInfo = '''
Debug Info:
- Saved Username: ${savedUsername ?? 'NOT FOUND'}
- Saved Password: ${savedPassword != null ? 'PRESENT (${savedPassword.length} chars)' : 'NOT FOUND'}
- Biometric Enabled: $biometricEnabled
- Remember Credentials: $rememberCredentials

Keys in SharedPreferences:
${prefs.getKeys().join(', ')}
    ''';

      print('🐛 BIOMETRIC DEBUG:');
      print(debugInfo);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Biometric Debug'),
          content: SingleChildScrollView(
            child: Text(debugInfo),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            if (savedUsername == null || savedPassword == null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Force save test credentials
                  await prefs.setString('saved_username', 'testuser123');
                  await prefs.setString('saved_password', 'password123');
                  await prefs.setBool('biometric_enabled', true);
                  await prefs.setBool('remember_credentials', true);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test credentials force-saved!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Force Save Test Creds'),
              ),
          ],
        ),
      );
    } catch (e) {
      print('Error in debug: $e');
    }
  }
}
