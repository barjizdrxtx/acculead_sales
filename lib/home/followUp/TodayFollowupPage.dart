// lib/pages/today_followup_page.dart

import 'dart:convert';
import 'package:acculead_sales/home/followUp/UpdateFollowUp.dart';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utls/url.dart';

class TodayFollowupPage extends StatefulWidget {
  @override
  _TodayFollowupPageState createState() => _TodayFollowupPageState();
}

class _TodayFollowupPageState extends State<TodayFollowupPage> {
  List<Map<String, dynamic>> todayLeads = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTodayFollowups();
  }

  Future<void> fetchTodayFollowups() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';
    if (token.isEmpty || userId.isEmpty) {
      setState(() {
        todayLeads = [];
        isLoading = false;
      });
      return;
    }

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/lead?assignedTo=$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final result = jsonDecode(response.body);
    if (response.statusCode != 200 || result['success'] != true) {
      setState(() {
        todayLeads = [];
        isLoading = false;
      });
      return;
    }

    final allLeads = (result['result'] as List).cast<Map<String, dynamic>>();
    final todayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));

    final matches = allLeads.where((lead) {
      final fus = lead['followUps'];
      if (fus is! List || fus.isEmpty) return false;

      final dates = fus
          .map((fu) {
            final raw = fu['date']?.toString();
            if (raw == null) return null;
            return DateTime.tryParse(
              raw,
            )?.toUtc().add(const Duration(hours: 5, minutes: 30));
          })
          .whereType<DateTime>()
          .toList();

      if (dates.isEmpty) return false;
      final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
      return DateFormat('yyyy-MM-dd').format(latest) == todayStr;
    }).toList();

    setState(() {
      todayLeads = matches;
      isLoading = false;
    });
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final todayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));

    final times = <String>[];
    for (var fu in (lead['followUps'] as List)) {
      final raw = fu['date']?.toString();
      final parsed = raw == null
          ? null
          : DateTime.tryParse(
              raw,
            )?.toUtc().add(const Duration(hours: 5, minutes: 30));
      if (parsed != null &&
          DateFormat('yyyy-MM-dd').format(parsed) == todayStr) {
        times.add(DateFormat('hh:mm a').format(parsed));
      }
    }

    final name = lead['fullName'] ?? 'No Name';
    final phone = lead['phoneNumber'] ?? '-';
    final status = lead['status'] ?? '-';
    final id = lead['_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailPage(id: id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.smartphone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.phone, size: 20, color: Colors.teal),
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final updated = await showAddFollowUpSheet(context, id);
                    if (updated == true) {
                      await fetchTodayFollowups();
                    }
                  },
                  icon: const Icon(Icons.add_task),
                  label: const Text('Add Follow-Up'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = DateFormat(
      'dd MMM, yyyy',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        title: const Text("Today's Follow-Ups"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(
              displayDate,
              style: const TextStyle(color: Colors.teal, fontSize: 16),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : todayLeads.isEmpty
                ? Center(
                    child: Text(
                      'No follow-ups today.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchTodayFollowups,
                    child: ListView.builder(
                      itemCount: todayLeads.length,
                      itemBuilder: (_, i) => _buildLeadCard(todayLeads[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
