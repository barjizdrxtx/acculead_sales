// lib/pages/all_attendance_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceRecord {
  final String userId;
  final String userName;
  final int month;
  final int year;
  final Map<int, String> attendanceStatus;

  AttendanceRecord({
    required this.userId,
    required this.userName,
    required this.month,
    required this.year,
    required this.attendanceStatus,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) {
    final user = m['userId'] as Map<String, dynamic>;
    final rawMap = (m['attendanceStatus'] as Map<String, dynamic>)
        .map<int, String>(
          (key, value) => MapEntry(int.parse(key), value as String),
        );
    return AttendanceRecord(
      userId: user['_id'] as String,
      userName: user['fullName'] as String,
      month: m['month'] as int,
      year: m['year'] as int,
      attendanceStatus: rawMap,
    );
  }

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  int get presentCount =>
      attendanceStatus.values.where((s) => s == 'present').length;
  int get halfDayCount =>
      attendanceStatus.values.where((s) => s == 'half-day').length;
  int get absentCount =>
      attendanceStatus.values.where((s) => s == 'absent').length;
}

class AllAttendancePage extends StatefulWidget {
  const AllAttendancePage({Key? key}) : super(key: key);

  @override
  State<AllAttendancePage> createState() => _AllAttendancePageState();
}

class _AllAttendancePageState extends State<AllAttendancePage> {
  bool _isLoading = false;
  String? _error;
  List<AttendanceRecord> _records = [];
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchAllAttendance();
  }

  Future<void> _fetchAllAttendance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final resp = await http.get(
        Uri.parse('https://api.acculeadinternational.com/attendance/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch all (${resp.statusCode})');
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      final list = body['result'] as List<dynamic>?;

      if (list == null) {
        setState(() => _records = []);
      } else {
        _records =
            list
                .map((e) => AttendanceRecord.fromMap(e as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.userName.compareTo(b.userName));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusIcon(String? status) {
    switch (status) {
      case 'present':
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case 'half-day':
        return const Icon(Icons.remove_circle, color: Colors.amber, size: 18);
      case 'absent':
        return const Icon(Icons.cancel, color: Colors.red, size: 18);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    // group by user
    final grouped = <String, List<AttendanceRecord>>{};
    for (var rec in _records) {
      if (_searchTerm.isNotEmpty &&
          !rec.userName.toLowerCase().contains(_searchTerm.toLowerCase())) {
        continue;
      }
      grouped.putIfAbsent(rec.userName, () => []).add(rec);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Users Attendance'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllAttendance,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search user...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
                onChanged: (v) => setState(() => _searchTerm = v),
              ),
              const SizedBox(height: 12),
              // content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : grouped.isEmpty
                    ? const Center(child: Text('No records found.'))
                    : ListView(
                        children: grouped.entries.map((entry) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ExpansionTile(
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: entry.value.map((rec) {
                                final monthLabel = DateFormat.yMMMM().format(
                                  DateTime(rec.year, rec.month),
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        monthLabel,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'P:${rec.presentCount}   H:${rec.halfDayCount}   A:${rec.absentCount}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      // days row
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: List.generate(
                                            rec.daysInMonth,
                                            (i) {
                                              final day = i + 1;
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                    ),
                                                child: _buildStatusIcon(
                                                  rec.attendanceStatus[day],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const Divider(),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
