// lib/pages/Students/MonthlyDuePage.dart
import 'dart:convert';
import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MonthlyDuePage extends StatefulWidget {
  const MonthlyDuePage({Key? key}) : super(key: key);

  @override
  _MonthlyDuePageState createState() => _MonthlyDuePageState();
}

class _MonthlyDuePageState extends State<MonthlyDuePage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _students = [];
  String _searchTerm = '';
  String _courseTypeFilter = 'All'; // All, Online, Offline

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/students');
      final resp = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['success'] == true && body['result'] is List) {
          _students = List<Map<String, dynamic>>.from(body['result']);
        } else {
          _error = 'Unexpected server response';
        }
      } else {
        final body = jsonDecode(resp.body);
        _error = body['message'] ?? 'Failed to load students';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Map && v.containsKey(r'$date')) {
      final dateStr = v[r'$date'].toString();
      return DateTime.tryParse(dateStr);
    }
    if (v is String) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  List<double> _buildSchedule(Map<String, dynamic> s) {
    final total = (s['courseFee'] as num?)?.toDouble() ?? 0.0;
    final durStr = s['duration']?.toString().trim() ?? '1';
    final months =
        int.tryParse(RegExp(r'\d+').firstMatch(durStr)?.group(0) ?? '1') ?? 1;
    double remaining = total;
    int remMonths = months;
    final schedule = <double>[];
    for (int i = 0; i < months; i++) {
      double part = remaining / remMonths;
      schedule.add(part);
      remaining -= part;
      remMonths--;
    }
    return schedule;
  }

  double _getMonthlyInstallment(Map<String, dynamic> s) {
    final now = DateTime.now();
    final schedule = _buildSchedule(s);
    final joined = _parseDate(s['joiningDate']) ?? now;
    final monthsSinceJoin =
        (now.year - joined.year) * 12 + (now.month - joined.month);
    if (monthsSinceJoin < 0 || monthsSinceJoin >= schedule.length) return 0.0;
    return schedule[monthsSinceJoin];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    // Build list of due entries
    final dueList = <Map<String, dynamic>>[];
    double totalDue = 0.0;

    for (var s in _students) {
      if (s['isJoined'] != true) continue;
      if (_courseTypeFilter != 'All' &&
          (s['courseType']?.toString().toLowerCase() ?? '') !=
              _courseTypeFilter.toLowerCase())
        continue;

      final schedule = _buildSchedule(s);
      final joined = _parseDate(s['joiningDate']) ?? now;
      final monthsSinceJoin =
          (now.year - joined.year) * 12 + (now.month - joined.month);
      if (monthsSinceJoin < 0) continue;

      final expectedToDate = schedule
          .take((monthsSinceJoin + 1).clamp(0, schedule.length))
          .fold(0.0, (sum, amt) => sum + amt);

      double paidTotal = 0.0;
      if (s['followUps'] is List) {
        for (var fu in s['followUps'] as List) {
          if (fu is Map<String, dynamic>) {
            paidTotal += (fu['feePaid'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      final due = expectedToDate - paidTotal;
      final monthlyDue = _getMonthlyInstallment(s);

      if (due > 0) {
        totalDue += due;
        dueList.add({
          'fullName': s['fullName']?.toString() ?? '—',
          'phone': s['phone']?.toString() ?? '—',
          'course': s['course']?.toString() ?? '—',
          'duration': s['duration']?.toString() ?? '—',
          'due': due,
          'monthly': monthlyDue,
        });
      }
    }

    final filtered = _searchTerm.isEmpty
        ? dueList
        : dueList
              .where(
                (e) => e['fullName']!.toLowerCase().contains(
                  _searchTerm.toLowerCase(),
                ),
              )
              .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Dues for ${DateFormat('MMMM yyyy').format(now)}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchTerm = v),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    underline: const SizedBox(),
                    value: _courseTypeFilter,
                    items: ['All', 'Online', 'Offline']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _courseTypeFilter = v!),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Due This Month',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '₹${totalDue.toInt()}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No dues to collect'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final entry = filtered[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry['fullName'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.call, size: 20),
                                  onPressed: () async {
                                    final url = 'tel:${entry['phone']}';
                                    if (await canLaunch(url)) await launch(url);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                Chip(label: Text(entry['course'])),
                                Chip(label: Text(entry['duration'])),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Due So Far',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      '₹${entry['due'].toInt()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
