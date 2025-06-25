// lib/pages/today_followup_page.dart

import 'dart:convert';
import 'package:acculead_sales/home/followUp/UpdateFollowUp.dart';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
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

  
  Color _getAvatarColor(String status) {
    switch (status) {
      case 'new':
        return Colors.green;
      case 'hot':
        return Colors.orange;
      case 'not connected':
        return Colors.blue;
      case 'in progress':
        return Colors.purple;
      case 'closed':
        return Colors.red;
      case 'lost':
        return Colors.grey;
      default:
        return Colors.grey.shade400;
    }
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

    Future<void> _makePhoneCall(String phone) async {
      if (phone.isNotEmpty) {
        await FlutterPhoneDirectCaller.callNumber(phone);
      }
    }

    Future<void> _openWhatsApp(String phone) async {
      // Strip out any non-digits
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      // If it's already more than 10 digits, assume it includes country code
      final phoneWithCountry = digits.length > 10 ? '+$digits' : '+91$digits';

      final native = Uri.parse('whatsapp://send?phone=$phoneWithCountry');
      final web = Uri.parse(
        'https://api.whatsapp.com/send?phone=$phoneWithCountry',
      );

      try {
        // Try the native URI first, fall back to web
        if (!await launchUrl(native, mode: LaunchMode.externalApplication)) {
          if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch WhatsApp';
          }
        }
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call, color: Colors.blue),
                      onPressed: () => _makePhoneCall(phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: Image.asset(
                        'assets/whatsapp.png',
                        width: 24,
                        height: 24,
                      ),
                      onPressed: () => _openWhatsApp(phone),
                    ),
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
                    elevation: 0,
                    backgroundColor: Colors.blue,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Today's Follow-Ups",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
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
