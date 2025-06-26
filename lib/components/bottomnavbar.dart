// lib/components/bottomnavbar.dart

import 'dart:convert';
import 'package:acculead_sales/notification/Main_NotificationPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:acculead_sales/dashboard/Main_DashboardPage.dart';
import 'package:acculead_sales/home/followUp/Main_FollowUpsPage.dart';
import 'package:acculead_sales/home/lead/Main_LeadPage.dart';
import 'package:acculead_sales/profile/Main_Profile.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:acculead_sales/utls/url.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  int _newLeadsCount = 0;
  int _newNotificationsCount = 0;

  static final List<Widget> _pages = [
    MainDashboardPage(),
    MainNotificationPage(),
    MainFollowUpsPage(),
    Main_LeadPage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkNewLeads();
    _checkNewNotifications();
  }

  Future<void> _checkNewLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';
    if (token.isEmpty || userId.isEmpty) return;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/lead?assignedTo=${Uri.encodeComponent(userId)}',
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body);
        final leads = jsonBody['success'] == true
            ? (jsonBody['result'] as List)
            : [];
        final count = leads.where((lead) => lead['status'] == 'new').length;
        if (count != _newLeadsCount) {
          setState(() => _newLeadsCount = count);
        }
      }
    } catch (_) {}
  }

  Future<void> _checkNewNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';
    if (token.isEmpty || userId.isEmpty) return;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/notifications/notRead/${Uri.encodeComponent(userId)}',
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true && body['result'] is List) {
          final allNotifs = (body['result'] as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final unreadCount = allNotifs.where((n) {
            final raw = n['read'];
            bool isRead;

            if (raw is bool) {
              isRead = raw;
            } else if (raw is int) {
              isRead = raw != 0;
            } else {
              // e.g. "true" or "false"
              isRead = raw.toString().toLowerCase() == 'true';
            }

            return !isRead; // only count those not read
          }).length;

          if (unreadCount != _newNotificationsCount) {
            setState(() => _newNotificationsCount = unreadCount);
          }
        }
      } else {
        debugPrint('Notifications API returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    // refresh badges whenever switching tabs
    _checkNewLeads();
    _checkNewNotifications();
  }

  BottomNavigationBarItem _buildLeadsItem() {
    Widget buildIcon(IconData iconData) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(iconData),
          if (_newLeadsCount > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$_newLeadsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return BottomNavigationBarItem(
      icon: buildIcon(Icons.store_outlined),
      activeIcon: buildIcon(Icons.store),
      label: 'Leads',
    );
  }

  BottomNavigationBarItem _buildNotificationsItem() {
    Widget buildIcon(IconData iconData) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(iconData),
          if (_newNotificationsCount > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$_newNotificationsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return BottomNavigationBarItem(
      icon: buildIcon(Icons.notifications_none),
      activeIcon: buildIcon(Icons.notifications),
      label: 'Notifications',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          _buildNotificationsItem(),
          const BottomNavigationBarItem(
            icon: Icon(Icons.follow_the_signs_outlined),
            activeIcon: Icon(Icons.follow_the_signs),
            label: 'Follow Up',
          ),
          _buildLeadsItem(),
        ],
      ),
    );
  }
}
