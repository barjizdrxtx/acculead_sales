// lib/home/notifications/MainNotificationPage.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../components/CustomAppBar.dart';
import '../../utls/url.dart';

class MainNotificationPage extends StatefulWidget {
  const MainNotificationPage({Key? key}) : super(key: key);

  @override
  _MainNotificationPageState createState() => _MainNotificationPageState();
}

class _MainNotificationPageState extends State<MainNotificationPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _fetchNotifications();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchNotifications(showLoader: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    if (token.isEmpty || userId.isEmpty) {
      if (showLoader) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
      return;
    }

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/user/${Uri.encodeComponent(userId)}',
    );

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['result'] is List) {
          setState(() {
            _notifications = (body['result'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          setState(() => _notifications = []);
        }
      } else {
        setState(() => _notifications = []);
      }
    } catch (_) {
      setState(() => _notifications = []);
    } finally {
      if (showLoader) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notifId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    if (token.isEmpty) return;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/markRead/${Uri.encodeComponent(notifId)}',
    );

    try {
      final res = await http.patch(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        // Refresh list to update read status
        await _fetchNotifications(showLoader: false);
      }
    } catch (_) {
      // ignore errors silently
    }
  }

  Future<void> _markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';
    if (token.isEmpty || userId.isEmpty) return;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/markAllRead/${Uri.encodeComponent(userId)}',
    );

    try {
      final res = await http.patch(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        await _fetchNotifications(showLoader: false);
      }
    } catch (_) {}
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
      appBar: CustomAppBar(
        title: "Notifications",
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
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
              onRefresh: () => _fetchNotifications(showLoader: false),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final notif = _notifications[i];
                  final id = notif['_id']?.toString() ?? '';
                  final title = notif['title']?.toString() ?? '';
                  final message = notif['message']?.toString() ?? '';
                  final isRead = notif['read'] == true;
                  final time = _formatDate(notif['createdAt']?.toString());

                  return ListTile(
                    tileColor: isRead
                        ? Colors.white
                        : Colors.blue.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.grey.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.notifications,
                        size: 20,
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isRead ? Colors.black54 : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? Colors.black45 : Colors.black54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read, size: 18),
                            tooltip: 'Mark as read',
                            onPressed: () => _markAsRead(id),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (!isRead) _markAsRead(id);
                      // add further tap handling here
                    },
                  );
                },
              ),
            ),
    );
  }
}
