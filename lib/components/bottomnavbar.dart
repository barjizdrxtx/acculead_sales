// lib/components/bottomnavbar.dart

import 'package:acculead_sales/dashboard/DashBoardPage.dart';
import 'package:acculead_sales/home/followUp/TodayFollowupPage.dart';
import 'package:acculead_sales/home/followUp/FollowUpFormPage.dart';
import 'package:flutter/material.dart';
import 'package:acculead_sales/home/lead/LeadPage.dart';
import 'package:acculead_sales/profile/Profile.dart';
import 'package:acculead_sales/utls/colors.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    DashboardPage(),
    TodayFollowupPage(),
    LeadPage(),
    ProfilePage(),
  ];

  static final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.follow_the_signs_outlined),
      activeIcon: Icon(Icons.follow_the_signs),
      label: 'Follow Up',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'Leads',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _navItems,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
