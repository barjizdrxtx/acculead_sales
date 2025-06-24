import 'package:acculead_sales/dashboard/StatusDistributon.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

Widget buildMetricsForLeads(List<Map<String, dynamic>> leads) {
  int total = leads.length;
  int nNew = 0,
      nHot = 0,
      nNotConnected = 0,
      nProg = 0,
      nClosed = 0,
      nLost = 0,
      nThisMonth = 0;

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final todayStr = DateFormat('yyyy-MM-dd').format(now);

  List<Map<String, dynamic>> followUpsToday = [];

  for (var lead in leads) {
    final status = (lead['status'] ?? '').toString().toLowerCase();
    switch (status) {
      case 'new':
        nNew++;
        break;
      case 'hot':
        nHot++;
        break;
      case 'not connected':
        nNotConnected++;
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

    final followUpDate = lead['followUpDate']?.toString() ?? '';
    if (followUpDate.startsWith(todayStr)) {
      followUpsToday.add(lead);
    }
  }

  final totDouble = total > 0 ? total.toDouble() : 1.0;

  final statusPercentages = [
    nNew / totDouble,
    nHot / totDouble,
    nNotConnected / totDouble,
    nProg / totDouble,
    nClosed / totDouble,
    nLost / totDouble,
  ];
  final statusLabels = [
    'new',
    'hot',
    'not connected',
    'in progress',
    'closed',
    'lost',
  ];
  final statusColors = [
    Colors.green,
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.redAccent,
    Colors.grey,
  ];
  final statusCounts = [nNew, nHot, nNotConnected, nProg, nClosed, nLost];

  final double conversionRate = total > 0 ? (nClosed / total) * 100 : 0.0;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stat cards in a responsive grid with smaller height
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.8, // makes each card shorter
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
            _buildStatCard(
              "New",
              nNew.toString(),
              Icons.fiber_new,
              Colors.green,
            ),
            _buildStatCard(
              "Hot",
              nHot.toString(),
              Icons.whatshot,
              Colors.orange,
            ),
            _buildStatCard(
              "Not Connected",
              nNotConnected.toString(),
              Icons.call_missed,
              Colors.blue,
            ),
            _buildStatCard(
              "In Progress",
              nProg.toString(),
              Icons.autorenew,
              Colors.purple,
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
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Status Distribution",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 8),
        StatusDistributon(
          statusPercentages,
          statusLabels,
          statusColors,
          statusCounts,
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.3),
          radius: 16,
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center, // vertically center text
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: color.withOpacity(0.85),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
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
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // vertically center
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.85),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
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
