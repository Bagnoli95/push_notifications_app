import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
    // Limpiar errores al cambiar de modo
    Provider.of<AuthService>(context, listen: false).clearError();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success;

    if (_isLoginMode) {
      success = await authService.login(_usernameController.text.trim(), _passwordController.text);
    } else {
      success = await authService.register(_usernameController.text.trim(), _emailController.text.trim(), _passwordController.text);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: Colors.green));
        _toggleMode();
        return;
      }
    }

    if (success && _isLoginMode) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _authenticateWithBiometrics() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    bool authenticated = await authService.authenticateWithBiometrics();

    if (authenticated) {
      // Si la autenticación biométrica es exitosa, verificar si hay token guardado
      await authService.checkAuthStatus();
      if (authService.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometric authentication failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, size: 64, color: Theme.of(context).primaryColor),
                    SizedBox(height: 24),
                    Text(
                      _isLoginMode ? 'Welcome Back!' : 'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                    SizedBox(height: 24),

                    Consumer<AuthService>(
                      builder: (context, authService, child) {
                        if (authService.errorMessage != null) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                            child: Row(
                              children: [Icon(Icons.error, color: Colors.red), SizedBox(width: 8), Expanded(child: Text(authService.errorMessage!, style: TextStyle(color: Colors.red[700])))],
                            ),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          if (!_isLoginMode) ...[
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
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
                            SizedBox(height: 16),
                          ],

                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            obscureText: _obscurePassword,
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
                          SizedBox(height: 24),

                          Consumer<AuthService>(
                            builder: (context, authService, child) {
                              return SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: authService.isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: authService.isLoading ? CircularProgressIndicator() : Text(_isLoginMode ? 'Login' : 'Register', style: TextStyle(fontSize: 16)),
                                ),
                              );
                            },
                          ),

                          SizedBox(height: 16),

                          if (_isLoginMode) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _authenticateWithBiometrics,
                                icon: Icon(Icons.fingerprint),
                                label: Text('Login with Biometrics'),
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            SizedBox(height: 16),
                          ],

                          TextButton(onPressed: _toggleMode, child: Text(_isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
