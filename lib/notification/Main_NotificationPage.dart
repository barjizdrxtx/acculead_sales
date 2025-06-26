// lib/home/notifications/MainNotificationPage.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
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
  late IO.Socket _socket;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialNotifications();
    _initSocket();
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _loadInitialNotifications() async {
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
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true && body['result'] is List) {
          _notifications = (body['result'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _notifications = [];
        }
      } else {
        _notifications = [];
      }
    } catch (_) {
      _notifications = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) return;

    _socket = IO.io(
      '${ApiConstants.socketUrl}/notifications', // connect to notifications namespace
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .disableMultiplex()
          .setPath('/socket.io') // explicit handshake path
          .setQuery({'userId': userId})
          .build(),
    );

    _socket.connect();

    _socket.onConnect((_) {
      debugPrint('🟢 Socket connected: ${_socket.id}');
    });

    _socket.on('newNotification', (data) {
      final notif = data is String ? jsonDecode(data) : data;
      setState(() {
        _notifications.insert(0, Map<String, dynamic>.from(notif));
      });
    });

    _socket.onDisconnect((_) {
      debugPrint('🔴 Socket disconnected');
    });

    _socket.onError((err) {
      debugPrint('⚠️ Socket error: $err');
    });
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
        _loadInitialNotifications();
      }
    } catch (_) {}
  }

  Future<void> _markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    if (token.isEmpty) return;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/markRead/${Uri.encodeComponent(id)}',
    );
    try {
      final res = await http.patch(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['_id'] == id);
          if (idx != -1) _notifications[idx]['read'] = true;
        });
      }
    } catch (_) {}
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    return dt == null ? '' : DateFormat('dd MMM, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Notifications',
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
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadInitialNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  final isRead = n['read'] == true;
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
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications,
                        size: 20,
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                    ),
                    title: Text(
                      n['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isRead ? Colors.black54 : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      n['message'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? Colors.black45 : Colors.black54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDate(n['createdAt']?.toString()),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.mark_email_read, size: 18),
                            onPressed: () => _markAsRead(n['_id'].toString()),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (!isRead) {
                        _markAsRead(n['_id'].toString());
                      }
                    },
                  );
                },
              ),
            ),
    );
  }
}
