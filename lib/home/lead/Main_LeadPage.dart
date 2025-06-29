// lib/pages/main_lead_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:acculead_sales/home/lead/LeadFormPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utls/url.dart';

class Main_LeadPage extends StatefulWidget {
  const Main_LeadPage({Key? key}) : super(key: key);

  @override
  _Main_LeadPageState createState() => _Main_LeadPageState();
}

class _Main_LeadPageState extends State<Main_LeadPage>
    with TickerProviderStateMixin {
  List<dynamic> allLeads = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTimeRange? selectedDateRange;
  late String _assigneeId;
  String _assigneeName = 'My Leads';
  String activeStatus = 'All';

  late TabController _statusController;
  final List<String> statusTabLabels = [
    'All',
    'new',
    'hot',
    'not connected',
    'in progress',
    'closed',
    'lost',
  ];

  @override
  void initState() {
    super.initState();
    _statusController =
        TabController(length: statusTabLabels.length, vsync: this)
          ..addListener(() {
            if (!_statusController.indexIsChanging) {
              setState(
                () => activeStatus = statusTabLabels[_statusController.index],
              );
            }
          });
    _loadAssignee();
  }

  Future<void> _loadAssignee() async {
    final prefs = await SharedPreferences.getInstance();
    _assigneeId = prefs.getString('userId') ?? '';
    _assigneeName = prefs.getString('userName') ?? 'My Leads';
    setState(() {});
    await _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/lead?assignedTo=${Uri.encodeComponent(_assigneeId)}',
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body);
        allLeads = jsonBody['success'] == true
            ? (jsonBody['result'] as List)
            : [];
      } else {
        allLeads = [];
      }
    } catch (_) {
      allLeads = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _effectiveStatus(Map<String, dynamic> lead) {
    final followUps = lead['followUps'] as List<dynamic>? ?? [];
    if (followUps.isNotEmpty) {
      return followUps.last['status']?.toString().toLowerCase().trim() ?? 'new';
    }
    return (lead['status']?.toString().toLowerCase().trim() ?? 'new');
  }

  List<dynamic> get _filteredLeads {
    return allLeads.where((lead) {
      final statusVal = _effectiveStatus(lead);
      if (activeStatus != 'All' && statusVal != activeStatus) {
        return false;
      }
      final q = searchQuery.toLowerCase();
      final name = (lead['fullName'] ?? '').toString().toLowerCase();
      final phone = (lead['phoneNumber'] ?? '').toString().toLowerCase();
      if (!name.contains(q) && !phone.contains(q)) return false;
      if (selectedDateRange != null) {
        final d = DateTime.tryParse(lead['enquiryDate'] ?? '');
        if (d == null ||
            d.isBefore(selectedDateRange!.start) ||
            d.isAfter(selectedDateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Map<String, int> get _statusCounts {
    final counts = {for (var s in statusTabLabels) s: 0};
    for (var lead in allLeads) {
      final statusVal = _effectiveStatus(lead);
      if (counts.containsKey(statusVal))
        counts[statusVal] = counts[statusVal]! + 1;
      counts['All'] = counts['All']! + 1;
    }
    return counts;
  }

  Future<void> _openAddLeadForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );
    await _fetchLeads();
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isNotEmpty) await FlutterPhoneDirectCaller.callNumber(phone);
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final phoneWithCountry = digits.length > 10 ? '+$digits' : '+91$digits';
    final native = Uri.parse('whatsapp://send?phone=$phoneWithCountry');
    final web = Uri.parse(
      'https://api.whatsapp.com/send?phone=$phoneWithCountry',
    );
    if (!await launchUrl(native, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
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

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = _filteredLeads;
    final counts = _statusCounts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _assigneeName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 0,
        bottom: TabBar(
          controller: _statusController,
          isScrollable: true,
          indicatorColor: _getAvatarColor(activeStatus),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: statusTabLabels.map((label) {
            final cap = label.capitalize();
            final count = counts[label] ?? 0;
            return Tab(text: '$cap ($count)');
          }).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2022),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => selectedDateRange = picked);
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                searchQuery = '';
                selectedDateRange = null;
                activeStatus = 'All';
                _statusController.index = 0;
              });
              _fetchLeads();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name or phone',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : leads.isEmpty
                ? const Center(child: Text('No leads found'))
                : RefreshIndicator(
                    onRefresh: _fetchLeads,
                    child: ListView.separated(
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (_, i) {
                        final lead = leads[i];
                        final fullName = (lead['fullName'] ?? '').toString();
                        final phoneNumber = (lead['phoneNumber'] ?? '')
                            .toString();
                        final rawId = lead['_id'];
                        final leadId =
                            rawId is Map && rawId.containsKey('\$oid')
                            ? rawId['\$oid']
                            : rawId.toString();
                        final statusVal = _effectiveStatus(lead);
                        final initial = fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : '?';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAvatarColor(statusVal),
                            child: Text(
                              initial,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            fullName.isNotEmpty ? fullName : 'No Name',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text(phoneNumber),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAvatarColor(statusVal),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusVal.capitalize(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _makePhoneCall(phoneNumber),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Image.asset(
                                  'assets/whatsapp.png',
                                  width: 24,
                                  height: 24,
                                ),
                                onPressed: () => _openWhatsApp(phoneNumber),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeadDetailPage(id: leadId),
                            ),
                          ).then((_) => _fetchLeads()),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddLeadForm,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
