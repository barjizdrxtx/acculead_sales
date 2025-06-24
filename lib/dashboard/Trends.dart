import 'package:acculead_sales/dashboard/StatusDistributon.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

Widget buildMetricsForLeads(List<Map<String, dynamic>> leads) {
  int total = leads.length;
  int nNew = 0, nProg = 0, nClosed = 0, nLost = 0, nThisMonth = 0;

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  List<Map<String, dynamic>> followUpsToday = [];

  for (var lead in leads) {
    final status = (lead['status'] ?? '') as String;
    switch (status) {
      case 'new':
        nNew++;
        break;
      case 'in progress':
        nProg++;
        break;
      case 'closed':
        nClosed++;
        break;
      case 'lost':
        nLost++;
        break;
      default:
        break;
    }

    final dtStr = lead['enquiryDate']?.toString() ?? '';
    final dt = DateTime.tryParse(dtStr);
    if (dt != null &&
        dt.isAfter(monthStart.subtract(const Duration(seconds: 1)))) {
      nThisMonth++;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final followUpDate = lead['followUpDate']?.toString() ?? '';
    if (followUpDate.startsWith(todayStr)) {
      followUpsToday.add(lead);
    }
  }

  final totDouble = total > 0 ? total.toDouble() : 1.0;
  final statusPercentages = [
    nNew / totDouble,
    nProg / totDouble,
    nClosed / totDouble,
    nLost / totDouble,
  ];
  final statusLabels = ['new', 'in progress', 'closed', 'lost'];
  final statusColors = [
    Colors.green,
    Colors.orange,
    Colors.redAccent,
    Colors.grey,
  ];

  final double conversionRate = total > 0 ? (nClosed / total) * 100 : 0.0;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Smaller stat cards in a 3-column grid
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStatCard(
            "Total",
            total.toString(),
            Icons.list,
            Colors.blueAccent,
          ),
          _buildStatCard("New", nNew.toString(), Icons.fiber_new, Colors.green),
          _buildStatCard(
            "In Prog",
            nProg.toString(),
            Icons.autorenew,
            Colors.orange,
          ),
          _buildStatCard(
            "Closed",
            nClosed.toString(),
            Icons.check_circle,
            Colors.redAccent,
          ),
          _buildStatCard(
            "Lost",
            nLost.toString(),
            Icons.remove_circle,
            Colors.grey,
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              "Conversion",
              "${conversionRate.toStringAsFixed(1)}%",
              Icons.show_chart,
              secondaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              "This Month",
              nThisMonth.toString(),
              Icons.calendar_today,
              Colors.teal,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        "Status Distribution",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.grey[800],
        ),
      ),
      const SizedBox(height: 8),
      StatusDistributon(statusPercentages, statusLabels, statusColors, [
        nNew,
        nProg,
        nClosed,
        nLost,
      ]),
      const SizedBox(height: 24),
    ],
  );
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.3),
          radius: 20,
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: color.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMetricCard(
  String title,
  String value,
  IconData icon,
  Color color,
) {
  return Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
