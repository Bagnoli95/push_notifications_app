import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class NotificationDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    // Variables por defecto
    String title = 'Notification';
    String body = 'No content available';
    Map<String, dynamic>? data;
    bool isInternal = false;

    // Debug info
    print('🔍 NotificationDetailScreen arguments: $arguments');
    print('🔍 Arguments type: ${arguments.runtimeType}');

    // Procesar argumentos
    if (arguments is Map<String, dynamic>) {
      title = arguments['title']?.toString() ?? 'Notification';
      body = arguments['body']?.toString() ?? 'No content available';
      data = arguments['data'] as Map<String, dynamic>?;
      isInternal = arguments['isInternal'] == true;
    } else if (arguments is String) {
      // Fallback para strings
      body = arguments;
    }

    print('🔍 Final parsed - Title: "$title", Body: "$body"');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug Card (puedes quitar esto después de que funcione)
            Card(
              color: Colors.yellow[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🐛 DEBUG INFO', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Arguments: $arguments'),
                    Text('Title: "$title"'),
                    Text('Body: "$body"'),
                    Text('Is Internal: $isInternal'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      isInternal ? Icons.campaign : Icons.notifications_active,
                      size: 40,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isInternal ? 'Internal Notification' : 'Push Notification',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        body,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (data != null && data.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Data',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...data.entries
                          .map((entry) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('${entry.key}: ${entry.value}'),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Back button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
