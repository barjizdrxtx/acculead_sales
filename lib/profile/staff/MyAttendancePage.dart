import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAttendancePage extends StatefulWidget {
  const MyAttendancePage({Key? key}) : super(key: key);

  @override
  _MyAttendancePageState createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  late DateTime _today;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  bool _loading = false;
  String? _error;
  Timer? _timer;
  int _workedMinutes = 0;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadPrefsAndData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefsAndData() async {
    setState(() => _loading = true);
    await _loadTodayData();
    if (_checkInTime != null && _checkOutTime == null) {
      _workedMinutes = DateTime.now().difference(_checkInTime!).inMinutes;
      _startTimer();
    }
    setState(() => _loading = false);
  }

  Future<void> _loadTodayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final now = DateTime.now();
      final resp = await http.get(
        Uri.parse(
          'https://api.acculeadinternational.com/attendance/$userId/${now.month}/${now.year}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final body = json.decode(resp.body);
      final rec = body['result'] as Map<String, dynamic>?;

      if (rec != null) {
        final details = rec['attendanceDetails'] as Map<String, dynamic>? ?? {};
        final todayKey = now.day.toString();
        if (details.containsKey(todayKey)) {
          final todayRec = details[todayKey];
          if (todayRec['checkInTime'] != null) {
            _checkInTime = DateTime.parse(todayRec['checkInTime']);
            _isCheckedIn = true;
          }
          if (todayRec['checkOutTime'] != null) {
            _checkOutTime = DateTime.parse(todayRec['checkOutTime']);
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _workedMinutes++;
      });
    });
  }

  Future<void> _doAction(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final userId = prefs.getString('userId') ?? '';
    final now = DateTime.now();

    setState(() => _loading = true);

    try {
      final resp = await http.post(
        Uri.parse(
          'https://api.acculeadinternational.com/attendance/$userId/mark',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': type}),
      );

      if (resp.statusCode == 200) {
        setState(() {
          if (type == 'present') {
            _checkInTime = now;
            _checkOutTime = null;
            _workedMinutes = 0;
            _isCheckedIn = true;
            _startTimer();
          } else if (type == 'checkout') {
            _checkOutTime = now;
            _timer?.cancel();
          }
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  bool _isNowBetween9And6() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 9);
    final end = DateTime(now.year, now.month, now.day, 18);
    return now.isAfter(start) && now.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'My Attendance',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildHistoryCard(),
              const SizedBox(height: 20),
              _buildCheckInOutCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    final inStr = _checkInTime != null
        ? DateFormat.jm().format(_checkInTime!)
        : '--';
    final outStr = _checkOutTime != null
        ? DateFormat.jm().format(_checkOutTime!)
        : '--';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.lightBlueAccent],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Attendance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Check-in: $inStr',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                'Check-out: $outStr',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOutCard() {
    final used = min(_workedMinutes, 480).toDouble();
    final remaining = max(0, 480 - _workedMinutes).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          const Text(
            'Working Duration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sections: [
                  PieChartSectionData(
                    value: used,
                    color: Colors.green,
                    radius: 55,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: remaining,
                    color: Colors.grey[300],
                    radius: 55,
                    showTitle: false,
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 45,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isAllowedTime = _isNowBetween9And6();

    if (!_isCheckedIn && isAllowedTime) {
      return _buildCircleButton(
        Icons.login,
        'Check In',
        Colors.green,
        () => _doAction('present'),
      );
    } else if (_isCheckedIn && _checkOutTime == null) {
      return _buildCircleButton(
        Icons.logout,
        'Check Out',
        Colors.red,
        () => _doAction('checkout'),
      );
    } else {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 40),
            SizedBox(height: 6),
            Text(
              'Present',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCircleButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
