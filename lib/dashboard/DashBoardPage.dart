// lib/pages/dashboard_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acculead_sales/dashboard/Trends.dart';
import 'package:acculead_sales/utls/colors.dart';
import '../utls/url.dart';

class DashboardPage extends StatefulWidget {
  final String pageTitle;

  const DashboardPage({Key? key, this.pageTitle = 'Dashboard'})
    : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> leads = [];
  late String _assigneeId;

  @override
  void initState() {
    super.initState();
    _loadAssigneeAndLeads();
  }

  Future<void> _loadAssigneeAndLeads() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _assigneeId = prefs.getString('userId') ?? '';
    await _loadLeads();
  }

  Future<void> _loadLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    if (token.isEmpty) {
      setState(() {
        leads = [];
        isLoading = false;
      });
      return;
    }

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
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        leads = List<Map<String, dynamic>>.from(body['result']);
      } else {
        leads = [];
      }
    } catch (_) {
      leads = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pageTitle,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeads,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: buildMetricsForLeads(leads),
              ),
            ),
    );
  }
}
