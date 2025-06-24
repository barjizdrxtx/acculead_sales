// lib/pages/lead_page.dart

import 'dart:convert';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:acculead_sales/home/lead/LeadFormPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../../utls/url.dart';

class LeadPage extends StatefulWidget {
  const LeadPage({Key? key}) : super(key: key);

  @override
  _LeadPageState createState() => _LeadPageState();
}

class _LeadPageState extends State<LeadPage> with TickerProviderStateMixin {
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
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        allLeads = result['success'] == true ? result['result'] as List : [];
      } else {
        allLeads = [];
      }
    } catch (_) {
      allLeads = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  String formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    return date != null ? DateFormat('dd-MM-yyyy').format(date) : '';
  }

  Future<void> _openAddLeadForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeadFormPage()),
    );
    await _fetchLeads();
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isNotEmpty) {
      await FlutterPhoneDirectCaller.callNumber(phoneNumber);
    }
  }

  List<dynamic> get _filteredLeads => allLeads.where((lead) {
    if (activeStatus != 'All' && lead['status'] != activeStatus) return false;
    final q = searchQuery.toLowerCase();
    final name = (lead['fullName'] ?? '').toString().toLowerCase();
    final phone = (lead['phoneNumber'] ?? '').toString().toLowerCase();
    if (!name.contains(q) && !phone.contains(q)) return false;
    if (selectedDateRange != null) {
      final d = DateTime.tryParse(lead['enquiryDate'] ?? '');
      if (d == null ||
          d.isBefore(selectedDateRange!.start) ||
          d.isAfter(selectedDateRange!.end))
        return false;
    }
    return true;
  }).toList();

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDateRange = picked);
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = _filteredLeads;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_assigneeName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black54,
        elevation: 0,
        bottom: TabBar(
          controller: _statusController,
          isScrollable: true,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.black54,
          tabs: statusTabLabels.map((e) => Tab(text: e.capitalize())).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final lead = leads[i];
                        final fullName = (lead['fullName'] ?? '').toString();
                        final phoneNumber = (lead['phoneNumber'] ?? '')
                            .toString();
                        final date = formatDate(lead['enquiryDate'] ?? '');
                        final status = (lead['status'] ?? '').toString();
                        final initial = fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : '?';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getAvatarColor(status),
                            child: Text(
                              initial,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(fullName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(phoneNumber),
                              const SizedBox(height: 4),
                              Text(date),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAvatarColor(status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.capitalize(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () =>
                                _makePhoneCall(lead['phoneNumber'] ?? ''),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeadDetailPage(id: lead['_id']),
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
