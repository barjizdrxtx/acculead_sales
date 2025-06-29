// lib/pages/dashboard_page.dart

import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar.dart';
import 'package:acculead_sales/dashboard/Trends.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acculead_sales/dashboard/StatusDistributon.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:acculead_sales/utls/url.dart';

class MainDashboardPage extends StatefulWidget {
  final String pageTitle;
  const MainDashboardPage({Key? key, this.pageTitle = 'Dashboard'})
    : super(key: key);

  @override
  _MainDashboardPageState createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> leadsData = [];
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
    await _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    if (token.isEmpty) {
      setState(() {
        leadsData = [];
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
        leadsData = (body['result'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        leadsData = [];
      }
    } catch (_) {
      leadsData = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(title: widget.pageTitle),
      body: isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchLeads,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    buildMetricsForLeads(leadsData),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: List.generate(2, (_) {
              return Expanded(
                child: Container(
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              4,
              (_) => Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
