// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acculead_sales/auth/login.dart';
import 'package:acculead_sales/components/bottomnavbar.dart';
import 'package:acculead_sales/utls/url.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(AccessToken.accessToken);
  runApp(MyApp(initialToken: token));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  const MyApp({Key? key, this.initialToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Main',
      debugShowCheckedModeBanner: false,
      home: SplashScreen(initialToken: initialToken),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final String? initialToken;
  const SplashScreen({Key? key, this.initialToken}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate right away
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToNextScreen());
  }

  void _goToNextScreen() {
    final next = (widget.initialToken?.isNotEmpty ?? false)
        ? const BottomNavBar()
        : LoginPage();

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    // Simple blank splash (could show logo/loading if you like)
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
