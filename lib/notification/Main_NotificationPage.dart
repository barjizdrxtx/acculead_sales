// lib/home/notifications/MainNotificationPage.dart

import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../utls/url.dart';

class MainNotificationPage extends StatefulWidget {
  const MainNotificationPage({Key? key}) : super(key: key);

  @override
  _MainNotificationPageState createState() => _MainNotificationPageState();
}

class _MainNotificationPageState extends State<MainNotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    if (token.isEmpty || userId.isEmpty) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      return;
    }

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/user/${Uri.encodeComponent(userId)}',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['result'] != null) {
          final List<dynamic> data = body['result'];
          final notifications = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          setState(() {
            _notifications = notifications;
          });
        } else {
          setState(() {
            _notifications = [];
          });
        }
      } else {
        setState(() {
          _notifications = [];
        });
      }
    } catch (e) {
      setState(() {
        _notifications = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    return dt == null ? '' : DateFormat('dd MMM, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: "Notification"),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final notif = _notifications[i];
                  final title = notif['title']?.toString() ?? '';
                  final message = notif['message']?.toString() ?? '';
                  final time = _formatDate(notif['createdAt']?.toString());

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      message,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () {
                      // Notification tap handling (optional)
                    },
                  );
                },
              ),
            ),
    );
  }
}
