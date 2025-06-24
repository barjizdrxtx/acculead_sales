// lib/main.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
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
  bool _permissionDenied = false;
  List<String> leadNumbers = [];

  @override
  void initState() {
    super.initState();
    _syncCallLogsAndNavigate();
  }

  Future<void> _syncCallLogsAndNavigate() async {
    await _fetchLeadNumbers();

    final status = await Permission.phone.request();
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      await Future.delayed(const Duration(seconds: 2));
      _goToNextScreen();
      return;
    }

    final callLogs = await CallLog.get();
    final filtered = callLogs.where((log) {
      final number = log.number?.replaceAll(' ', '').trim();
      if (number == null) return false;
      return leadNumbers.any((leadNum) {
        final cleanLead = leadNum.replaceAll(' ', '').trim();
        return number.contains(cleanLead) || cleanLead.contains(number);
      });
    }).toList();

    for (var log in filtered) {
      await _uploadSingleLog(log);
    }

    _goToNextScreen();
  }

  Future<void> _fetchLeadNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';
    final uri = Uri.parse('${ApiConstants.baseUrl}/lead?assignedTo=$userId');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['result'] as List<dynamic>;
        leadNumbers = data
            .map(
              (e) =>
                  e['phoneNumber']?.toString().replaceAll(' ', '').trim() ?? '',
            )
            .where((num) => num.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _uploadSingleLog(CallLogEntry log) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    final payload = {
      'phoneNumber': log.number ?? '',
      'name': log.name ?? 'Unsaved',
      'type': _getCallLabel(log.callType).toLowerCase(),
      'timestamp': DateTime.fromMillisecondsSinceEpoch(
        log.timestamp ?? 0,
      ).toIso8601String(),
      'duration': log.duration ?? 0,
      'userId': userId,
    };

    final url = Uri.parse('${ApiConstants.baseUrl}/calllogs');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      // ignore errors
    }
  }

  String _getCallLabel(CallType? type) {
    switch (type) {
      case CallType.missed:
        return 'missed';
      case CallType.incoming:
        return 'incoming';
      case CallType.outgoing:
        return 'outgoing';
      default:
        return 'unknown';
    }
  }

  void _goToNextScreen() {
    final next =
        (widget.initialToken != null && widget.initialToken!.isNotEmpty)
        ? BottomNavBar()
        : LoginPage();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _permissionDenied
          ? const Center(
              child: Text(
                'Phone permission denied.\nPlease enable it in settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo/title skeleton
                  Container(
                    width: 120,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Menu placeholders
                  Row(
                    children: List.generate(
                      3,
                      (_) => Expanded(
                        child: Container(
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Card placeholders
                  Expanded(
                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
