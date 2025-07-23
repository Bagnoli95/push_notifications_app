import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_bell.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationService>(context, listen: false).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Push Notifications App'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          NotificationBell(),
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return PopupMenuButton<String>(
                icon: Icon(Icons.account_circle),
                onSelected: (value) {
                  if (value == 'logout') {
                    _showLogoutDialog();
                  }
                },
                itemBuilder:
                    (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'user',
                        enabled: false,
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.grey),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(authService.username ?? 'User', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('ID: ${authService.userId}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Logout')])),
                    ],
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Theme.of(context).primaryColor.withOpacity(0.1), Colors.white])),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_active, size: 100, color: Theme.of(context).primaryColor),
                SizedBox(height: 24),

                Text(
                  'Welcome to Push Notifications App!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    return Text('Hello, ${authService.username}!', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[700]), textAlign: TextAlign.center);
                  },
                ),
                SizedBox(height: 32),

                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Theme.of(context).primaryColor),
                        SizedBox(height: 16),
                        Text('App Status', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        _buildStatusItem(icon: Icons.login, title: 'Authentication', status: 'Active', color: Colors.green),
                        SizedBox(height: 8),
                        _buildStatusItem(icon: Icons.phone_android, title: 'Device Registration', status: 'Registered', color: Colors.green),
                        SizedBox(height: 8),
                        _buildStatusItem(icon: Icons.notifications, title: 'Push Notifications', status: 'Ready', color: Colors.green),
                        SizedBox(height: 8),
                        Consumer<NotificationService>(
                          builder: (context, notificationService, child) {
                            return _buildStatusItem(
                              icon: Icons.campaign,
                              title: 'Internal Notifications',
                              status: '${notificationService.unreadCount} unread',
                              color: notificationService.unreadCount > 0 ? Colors.orange : Colors.green,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),

                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.help_outline, size: 48, color: Theme.of(context).primaryColor),
                        SizedBox(height: 16),
                        Text('How it works', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text(
                          '• Push notifications appear as system notifications\n'
                          '• Tap them to see details (login required if logged out)\n'
                          '• Internal notifications appear in the bell icon\n'
                          '• Use biometric authentication for quick login',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem({required IconData icon, required String title, required String status, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(child: Text(title, style: TextStyle(fontSize: 14))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
          child: Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                Provider.of<AuthService>(context, listen: false).logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        );
      },
    );
  }
}
