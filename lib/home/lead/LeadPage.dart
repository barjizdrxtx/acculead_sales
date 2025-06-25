import 'dart:convert';
import 'dart:io';
import 'package:acculead_sales/home/lead/DetailPage.dart';
import 'package:acculead_sales/home/lead/LeadFormPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // Tab controller for status
    _statusController =
        TabController(length: statusTabLabels.length, vsync: this)
          ..addListener(() {
            if (!_statusController.indexIsChanging) {
              setState(
                () => activeStatus = statusTabLabels[_statusController.index],
              );
            }
          });

    // Initialize notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    _localNotifications.initialize(initSettings);

    // Request permissions if needed
    _requestNotificationPermissions();

    _loadAssignee();
  }

  Future<void> _requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ runtime notification permission
      final status = await Permission.notification.request();
      debugPrint('Android notification permission: $status');
    } else if (Platform.isIOS) {
      final iosPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final settings = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('iOS notification settings: $settings');
      }
    }
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

        // NEW: check for any lead with isAlert == true
        final alertLead = allLeads.firstWhere((lead) {
          // some documents nest ObjectId in {"$oid": "..."}
          final idField = lead['_id'];
          // no matter how _id is formatted, just check the boolean:
          return lead['isAlert'] == true;
        }, orElse: () => null);
        if (alertLead != null) {
          final name = alertLead['fullName'] ?? 'a lead';
          _showLocalNotification(
            '🚨 Lead Alert',
            'Attention: "$name" is marked urgent.',
          );
        }
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
    final dt = DateTime.tryParse(dateStr);
    return dt != null ? DateFormat('dd-MM-yyyy').format(dt) : '';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'lead_channel',
      'Lead Notifications',
      channelDescription: 'Notifications for lead actions',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformDetails = NotificationDetails(android: androidDetails);
    await _localNotifications.show(0, title, body, platformDetails);
  }

  List<dynamic> get _filteredLeads => allLeads.where((lead) {
    if (activeStatus != 'All' && lead['status'] != activeStatus) {
      return false;
    }
    final q = searchQuery.toLowerCase();
    final name = (lead['fullName'] ?? '').toString().toLowerCase();
    final phone = (lead['phoneNumber'] ?? '').toString().toLowerCase();
    if (!name.contains(q) && !phone.contains(q)) {
      return false;
    }
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
        title: Text(_assigneeName, style: const TextStyle(color: Colors.black)),
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
                      separatorBuilder: (_, __) => const Divider(height: 10),
                      itemBuilder: (_, i) {
                        final lead = leads[i];
                        final fullName = (lead['fullName'] ?? '').toString();
                        final phoneNumber = (lead['phoneNumber'] ?? '')
                            .toString();
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
                          title: Text(
                            fullName.trim().isNotEmpty ? fullName : 'No Name',
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
                              const SizedBox(height: 10),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Call
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.call,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _makePhoneCall(phoneNumber),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // WhatsApp
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
                                  onPressed: () => _openWhatsApp(phoneNumber),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
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
