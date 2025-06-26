// lib/pages/dashboard_page.dart

import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acculead_sales/dashboard/Trends.dart';
import 'package:acculead_sales/utls/colors.dart';
import '../utls/url.dart';

class MainDashboardPage extends StatefulWidget {
  final String pageTitle;

  const MainDashboardPage({Key? key, this.pageTitle = 'Dashboard'})
    : super(key: key);

  @override
  _MainDashboardPageState createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
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
      backgroundColor: Colors.white,

      appBar: CustomAppBar(title: "Dashboard"),
      body: isLoading
          // Skeleton loading UI
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // metrics skeleton row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (_) {
                      return Expanded(
                        child: Container(
                          height: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // list skeleton
                  Expanded(
                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 12,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 12,
                                    width:
                                        MediaQuery.of(context).size.width * 0.5,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          // Actual content
          : RefreshIndicator(
              onRefresh: _loadLeads,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: buildMetricsForLeads(leads),
              ),
            ),
    );
  }
}
