// lib/pages/lead_detail_page.dart

import 'dart:convert';
import 'package:acculead_sales/home/followUp/FollowUpFormPage.dart';
import 'package:acculead_sales/home/lead/LeadFormPage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../utls/colors.dart';
import '../../utls/url.dart';

class LeadDetailPage extends StatefulWidget {
  final String id;
  const LeadDetailPage({Key? key, required this.id}) : super(key: key);

  @override
  _LeadDetailPageState createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  Map<String, dynamic>? lead;
  bool isLoading = false;
  bool isUpdatingStatus = false;
  double progress = 0.0;
  String status = '';
  String currentRole = '';

  final Map<String, String> statusDisplayMap = {
    'new': 'new',
    'hot': 'hot',
    'not connected': 'not connected',
    'in progress': 'in progress',
    'closed': 'closed',
    'lost': 'lost',
  };

  @override
  void initState() {
    super.initState();
    _loadRoleAndFetch();
  }

  Future<void> _loadRoleAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    currentRole = prefs.getString('role')?.toLowerCase() ?? '';
    await fetchLead();
  }

  Future<void> fetchLead() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final url = Uri.parse('${ApiConstants.baseUrl}/lead/${widget.id}');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['result'];
      setState(() {
        lead = data;
        status = (data['status'] ?? '').toString().toLowerCase().trim();
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> updateStatus(String newStatus) async {
    setState(() {
      isUpdatingStatus = true;
      progress = 0.0;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final url = Uri.parse('${ApiConstants.baseUrl}/lead/${widget.id}/status');
    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': newStatus}),
    );
    if (response.statusCode == 200) {
      await fetchLead();
      setState(() {
        status = newStatus;
        progress = 1.0;
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      isUpdatingStatus = false;
      progress = 0.0;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return '-';
    }
  }

  Widget _buildLabel(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusTextColor(String s) {
    switch (s) {
      case 'new':
        return Colors.green.shade700;
      case 'in progress':
        return Colors.orange.shade700;
      case 'closed':
      case 'lost':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _statusBgColor(String s) {
    switch (s) {
      case 'new':
        return Colors.green.shade100;
      case 'in progress':
        return Colors.orange.shade100;
      case 'closed':
      case 'lost':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    // safely get name and initial
    final rawName = lead?['fullName']?.toString().trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : 'Unnamed';
    final initial = rawName.isNotEmpty ? rawName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Lead Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lead == null
          ? const Center(child: Text('No data found'))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: secondaryColor,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBgColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusDisplayMap[status] ?? 'N/A',
                      style: TextStyle(
                        color: _statusTextColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status.isNotEmpty ? status : null,
                    items: statusDisplayMap.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: isUpdatingStatus
                        ? null
                        : (v) =>
                              v != null && v != status ? updateStatus(v) : null,
                  ),
                  if (isUpdatingStatus) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 6),
                    const Text(
                      'Updating status...',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ],
                  const Divider(height: 30),
                  _buildLabel('Phone', lead!['phoneNumber']),
                  _buildLabel('Email', lead!['email']),
                  _buildLabel('Gender', lead!['gender']),
                  _buildLabel('Place', lead!['place']),
                  _buildLabel('District', lead!['district']),
                  _buildLabel('Course', lead!['course']),
                  _buildLabel(
                    'Enquiry Date',
                    _formatDate(lead!['enquiryDate']),
                  ),
                  _buildLabel('Updated At', _formatDate(lead!['updatedAt'])),
                  _buildLabel('Source', lead!['source']),
                  _buildLabel('Assigned To', lead!['assignedTo']),
                  const SizedBox(height: 20),
                  if (lead!['followUps'] != null &&
                      (lead!['followUps'] as List).isNotEmpty) ...[
                    const Divider(height: 30),
                    const Text(
                      'Follow-Up History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...((lead!['followUps'] as List)
                        .map((fuRaw) {
                          final fu = Map<String, dynamic>.from(fuRaw);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.note, color: secondaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date: ${_formatDate(fu['date']?.toString())}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(fu['note']?.toString() ?? '-'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList()
                        .cast<Widget>()),
                  ],
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'addFollowUp',
            backgroundColor: Colors.green,
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowUpFormPage(leadId: widget.id),
                ),
              );
              if (added == true) fetchLead();
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'editLead',
            backgroundColor: Colors.blue,
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => LeadFormPage(leadId: widget.id),
                ),
              );
              if (updated == true) fetchLead();
            },
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
