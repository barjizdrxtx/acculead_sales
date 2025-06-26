// lib/main.dart

import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acculead_sales/auth/login.dart';
import 'package:acculead_sales/components/bottomnavbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(AccessToken.accessToken);

  runApp(
    MaterialApp(
      title: 'Acculead Sales',
      debugShowCheckedModeBanner: false,
      home: token?.isNotEmpty == true ? const BottomNavBar() : LoginPage(),
    ),
  );
}
