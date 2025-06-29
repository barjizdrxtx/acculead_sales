import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar.dart';
import 'package:acculead_sales/home/followUp/FollowUpFormPage.dart';
import 'package:acculead_sales/home/followUp/UpdateFollowUp.dart';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utls/url.dart';

class MainFollowUpsPage extends StatefulWidget {
  @override
  _MainFollowUpsPageState createState() => _MainFollowUpsPageState();
}

class _MainFollowUpsPageState extends State<MainFollowUpsPage> {
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
        return Colors.grey;
      case 'in progress':
        return Colors.blue;
      case 'closed':
        return Colors.grey.shade600;
      case 'lost':
        return Colors.red;
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

    todayLeads = allLeads.where((lead) {
      final fus = lead['followUps'];
      if (fus is! List || fus.isEmpty) return false;

      final dates = fus
          .map((fu) {
            final raw = fu['followUpDate']?.toString();
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
      isLoading = false;
    });
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final times = <String>[];
    final todayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));

    for (var fu in (lead['followUps'] as List)) {
      final raw = fu['followUpDate']?.toString();
      final dt = raw == null
          ? null
          : DateTime.tryParse(
              raw,
            )?.toUtc().add(const Duration(hours: 5, minutes: 30));
      if (dt != null && DateFormat('yyyy-MM-dd').format(dt) == todayStr) {
        times.add(DateFormat('hh:mm a').format(dt));
      }
    }

    Future<void> call(String phone) async {
      if (phone.isNotEmpty) await FlutterPhoneDirectCaller.callNumber(phone);
    }

    Future<void> whatsapp(String phone) async {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final ph = digits.length > 10 ? '+$digits' : '+91$digits';
      final native = Uri.parse('whatsapp://send?phone=$ph');
      if (!await launchUrl(native, mode: LaunchMode.externalApplication)) {
        final web = Uri.parse('https://api.whatsapp.com/send?phone=$ph');
        if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp')),
          );
        }
      }
    }

    final name = lead['fullName'] ?? 'No Name';
    final phone = lead['phoneNumber'] ?? '-';
    final status = lead['status'] ?? '-';
    final id = lead['_id']?.toString() ?? '';
    final history = (lead['followUps'] as List).cast<Map<String, dynamic>>();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailPage(id: id)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.blue),
                  onPressed: () => call(phone),
                ),
                IconButton(
                  icon: Image.asset(
                    'assets/whatsapp.png',
                    width: 24,
                    height: 24,
                  ),
                  onPressed: () => whatsapp(phone),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (history.isNotEmpty) ...[
              const Text(
                'History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Divider(),
              ...history.map((fu) {
                final raw = fu['followUpDate'] ?? fu['createdAt'];
                final dt = raw != null
                    ? DateTime.tryParse(
                        raw.toString(),
                      )?.toUtc().add(const Duration(hours: 5, minutes: 30))
                    : null;
                final txt = dt != null
                    ? DateFormat('dd MMM, yyyy – hh:mm a').format(dt)
                    : '-';
                final note = fu['note'] ?? '-';
                final st = fu['status'] ?? '-';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: _getAvatarColor(st),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              txt,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$st • $note',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowUpFormPage(leadId: id),
                    ),
                  );
                },
                icon: const Icon(Icons.add_task, size: 22, color: Colors.white),
                label: const Text(
                  'Add Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Today's Follow-Up"),
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : todayLeads.isEmpty
          ? Center(
              child: Text(
                'No follow-ups today.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchTodayFollowups,
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: todayLeads.length,
                itemBuilder: (_, i) => _buildLeadCard(todayLeads[i]),
                separatorBuilder: (_, __) => Divider(
                  color: Colors.grey.shade300,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                ),
              ),
            ),
    );
  }
}
