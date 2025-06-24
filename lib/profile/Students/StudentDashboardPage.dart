// lib/pages/Students/StudentDashboardPage.dart

import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../utls/colors.dart';
import '../../utls/url.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({Key? key}) : super(key: key);

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _students = [];

  double _totalCollected = 0;
  double _totalToCollect = 0;

  double get _profit => _totalCollected;
  double get _remaining => _totalToCollect - _totalCollected;

  Map<String, int> _courseCount = {};
  Map<String, double> _courseRevenue = {};
  Map<String, double> _monthlyRevenue = {};
  Map<String, double> _potentialRevenue = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/students'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = List<Map<String, dynamic>>.from(body['result']);
        _processData(list);
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _processData(List<Map<String, dynamic>> data) {
    _students = data;
    _totalCollected = 0;
    _totalToCollect = 0;
    _courseCount.clear();
    _courseRevenue.clear();
    _monthlyRevenue.clear();
    _potentialRevenue.clear();

    for (var student in _students) {
      // Parse course fee
      final feeRaw = student['courseFee'];
      final fee = feeRaw is num
          ? feeRaw.toDouble()
          : double.tryParse(feeRaw.toString()) ?? 0;
      _totalToCollect += fee;

      // Track potential revenue per course
      final course = (student['course'] ?? 'Unknown').toString();
      _potentialRevenue[course] = (_potentialRevenue[course] ?? 0) + fee;

      // Count students per course
      _courseCount[course] = (_courseCount[course] ?? 0) + 1;

      // Process follow-ups (actual collected)
      final followUps = List<Map<String, dynamic>>.from(
        student['followUps'] ?? [],
      );
      for (var f in followUps) {
        final paidRaw = f['feePaid'] ?? 0;
        final paid = paidRaw is num
            ? paidRaw.toDouble()
            : double.tryParse(paidRaw.toString()) ?? 0;
        _totalCollected += paid;
        _courseRevenue[course] = (_courseRevenue[course] ?? 0) + paid;

        // Monthly grouping
        final dateStr = f['date'] ?? '';
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = DateFormat('MMM yy').format(date);
          _monthlyRevenue[key] = (_monthlyRevenue[key] ?? 0) + paid;
        }
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Overview of student metrics and revenue',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value, {
    Color? color,
    IconData? icon,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Icon(icon, color: color ?? primaryColor, size: 28),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    final sections = _courseRevenue.entries.map((e) {
      final idx = _courseRevenue.keys.toList().indexOf(e.key);
      final color = Colors.primaries[idx % Colors.primaries.length];
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '${e.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: Text(
          e.key,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        badgePositionPercentageOffset: .98,
      );
    }).toList();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue by Course',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 6,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Potential Revenue by Course',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _potentialRevenue.entries.map((e) {
                final idx = _potentialRevenue.keys.toList().indexOf(e.key);
                final color = Colors.primaries[idx % Colors.primaries.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key}: ₹${e.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        title: const Text('Student Sales Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatTile(
                        'Total Students',
                        _students.length.toString(),
                        icon: Icons.group,
                      ),
                      _buildStatTile(
                        'Total To Collect',
                        _totalToCollect.toStringAsFixed(2),
                        color: Colors.red,
                        icon: Icons.money,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildStatTile(
                        'Collected',
                        _profit.toStringAsFixed(2),
                        color: Colors.green,
                        icon: Icons.trending_up,
                      ),
                      _buildStatTile(
                        'Remaining To Collect',
                        _remaining.toStringAsFixed(2),
                        color: Colors.orange,
                        icon: Icons.collections,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPieChart(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
