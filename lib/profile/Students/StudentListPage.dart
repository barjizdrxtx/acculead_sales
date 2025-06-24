// lib/pages/Students/StudentListPage.dart
import 'dart:convert';
import 'package:acculead_sales/profile/Students/StudentDetailsPage.dart';
import 'package:acculead_sales/profile/Students/AddNewStudent.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utls/url.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({Key? key}) : super(key: key);

  @override
  _StudentListPageState createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _students = [];
  String _searchText = '';

  // filters
  String? _selectedDuration;
  String? _selectedCourseName;
  bool? _filterJoined;
  bool? _filterCompleted;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/students');
      final resp = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['success'] == true && body['result'] is List) {
          _students = List<Map<String, dynamic>>.from(body['result']);
        } else {
          _error = 'Unexpected server response';
        }
      } else {
        final body = jsonDecode(resp.body);
        _error = body['message'] ?? 'Failed to load students';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isNotEmpty) {
      await FlutterPhoneDirectCaller.callNumber(phone);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    final native = Uri.parse('whatsapp://send?phone=+91$phone');
    final web = Uri.parse('https://api.whatsapp.com/send?phone=+91$phone');
    if (!await launchUrl(native, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Map && v['\$date'] != null) return DateTime.tryParse(v['\$date']);
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String _fmtDate(dynamic v) {
    final dt = _parseDate(v);
    return dt != null ? DateFormat('dd MMM, yyyy').format(dt) : '—';
  }

  String _fmtPhone(dynamic v) {
    if (v is Map && v['\$numberLong'] != null)
      return v['\$numberLong'].toString();
    return v?.toString() ?? '';
  }

  List<String> get _durationOptions => _students
      .map((s) => s['duration']?.toString().trim() ?? '')
      .where((d) => d.isNotEmpty)
      .toSet()
      .toList();

  List<String> get _courseOptions => _students
      .map((s) => s['course']?.toString().trim() ?? '')
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();

  List<Map<String, dynamic>> get _filteredBase {
    var list = _students;
    if (_searchText.isNotEmpty) {
      list = list.where((s) {
        final name = (s['fullName'] ?? '').toString().toLowerCase();
        return name.contains(_searchText.toLowerCase());
      }).toList();
    }
    return list;
  }

  /// Compute installments and expected due-to-date
  List<Map<String, dynamic>> _getInstallments(Map<String, dynamic> s) {
    final total = (s['courseFee'] as num?)?.toDouble() ?? 0.0;
    final durStr = s['duration']?.toString().trim() ?? '1';
    final months =
        int.tryParse(RegExp(r'\d+').firstMatch(durStr)?.group(0) ?? '1') ?? 1;
    final joinedDt = _parseDate(s['joiningDate']) ?? DateTime.now();
    final payments = <double>[];
    if (s['followUps'] is List) {
      for (var fu in s['followUps'] as List) {
        if (fu is Map<String, dynamic>)
          payments.add((fu['feePaid'] as num?)?.toDouble() ?? 0.0);
      }
    }
    double remaining = total;
    int remMonths = months;
    final today = DateTime.now();
    double expectedToDate = 0.0;
    final schedule = <Map<String, dynamic>>[];

    for (int i = 0; i < months; i++) {
      final date = DateTime(joinedDt.year, joinedDt.month + i, joinedDt.day);
      double amt = i < payments.length ? payments[i] : (remaining / remMonths);
      schedule.add({'date': date, 'amount': amt});
      if (!date.isAfter(today)) expectedToDate += amt;
      remaining -= amt;
      remMonths--;
    }

    return [
      {'schedule': schedule, 'expectedToDate': expectedToDate},
    ];
  }

  void _showInstallments(Map<String, dynamic> s) {
    final data = _getInstallments(s).first;
    final schedule = data['schedule'] as List<Map<String, dynamic>>;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment Schedule',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...schedule.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  DateFormat('dd MMM yyyy').format(e['date'] as DateTime),
                ),
                trailing: Text('₹${(e['amount'] as double).toInt()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          DropdownButton<String>(
            hint: const Text('Duration'),
            value: _selectedDuration,
            items: _durationOptions
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDuration = v),
          ),
          DropdownButton<String>(
            hint: const Text('Course'),
            value: _selectedCourseName,
            items: _courseOptions
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCourseName = v),
          ),
          FilterChip(
            label: const Text('Joined'),
            selected: _filterJoined == true,
            onSelected: (sel) =>
                setState(() => _filterJoined = sel ? true : null),
          ),
          if (_filterJoined == null || _filterJoined == true)
            FilterChip(
              label: const Text('Not Joined'),
              selected: _filterJoined == false,
              onSelected: (sel) =>
                  setState(() => _filterJoined = sel ? false : null),
            ),
          FilterChip(
            label: const Text('Completed'),
            selected: _filterCompleted == true,
            onSelected: (sel) =>
                setState(() => _filterCompleted = sel ? true : null),
          ),
          if (_filterCompleted == null || _filterCompleted == true)
            FilterChip(
              label: const Text('Not Completed'),
              selected: _filterCompleted == false,
              onSelected: (sel) =>
                  setState(() => _filterCompleted = sel ? false : null),
            ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear filters',
            onPressed: () => setState(() {
              _selectedDuration = null;
              _selectedCourseName = null;
              _filterJoined = null;
              _filterCompleted = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String? type) {
    var list = _filteredBase;
    if (type != null)
      list = list.where((s) => s['courseType'] == type).toList();
    if (_selectedDuration != null)
      list = list.where((s) => s['duration'] == _selectedDuration).toList();
    if (_selectedCourseName != null)
      list = list.where((s) => s['course'] == _selectedCourseName).toList();
    if (_filterJoined != null)
      list = list
          .where((s) => (s['isJoined'] == true) == _filterJoined)
          .toList();
    if (_filterCompleted != null)
      list = list
          .where((s) => (s['isCompleted'] == true) == _filterCompleted)
          .toList();

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    if (list.isEmpty) return const Center(child: Text('No students found'));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildStudentTile(list[i], i + 1),
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> s, int idx) {
    final id = (s['_id'] is Map && s['_id']['\$oid'] != null)
        ? s['_id']['\$oid']
        : s['_id'];
    final name = s['fullName']?.toString() ?? '—';
    final phone = _fmtPhone(s['phone']);
    final joined = _fmtDate(s['joiningDate']);
    final course = s['course']?.toString() ?? '—';
    final duration = s['duration']?.toString().trim() ?? '—';
    final type = s['courseType']?.toString() ?? '—';
    final joinedFlag = s['isJoined'] == true;
    final completeFlag = s['isCompleted'] == true;
    final total = (s['courseFee'] as num?)?.toDouble() ?? 0.0;

    // compute actual paid
    double totalPaid = 0.0;
    if (s['followUps'] is List) {
      for (var fu in s['followUps'] as List) {
        if (fu is Map<String, dynamic>)
          totalPaid += (fu['feePaid'] as num?)?.toDouble() ?? 0.0;
      }
    }
    final due = total - totalPaid;
    final data = _getInstallments(s).first;
    final expectedToDate = data['expectedToDate'] as double;
    final overdue = (expectedToDate - totalPaid).clamp(0.0, double.infinity);
    final progress = total > 0 ? (totalPaid / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      color: const Color(0xFFF6F6F6),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentDetailsPage(studentId: id)),
        ).then((_) => _fetchStudents()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: index, avatar, name, call/whatsapp
              Row(
                children: [
                  Text(
                    '$idx.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: secondaryColor,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _makePhoneCall(phone),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => _openWhatsApp(phone),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Chips: type, joined/completed
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(type.toUpperCase())),
                  if (joinedFlag)
                    Chip(
                      label: const Text('Joined'),
                      backgroundColor: Colors.green.shade100,
                    ),
                  if (completeFlag)
                    Chip(
                      label: const Text('Completed'),
                      backgroundColor: Colors.blue.shade100,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Course, Duration, Joining Date
              Row(
                children: [
                  const Icon(Icons.book, size: 16, color: Colors.teal),
                  const SizedBox(width: 4),
                  Expanded(child: Text(course)),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(duration),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text('Joined: $joined'),
                ],
              ),
              const Divider(height: 20),
              // Payment summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paid: ₹${totalPaid.toInt()}'),
                      Text('Total: ₹${total.toInt()}'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Due: ₹${due.toInt()}'),
                      if (overdue > 0)
                        Text(
                          'Overdue: ₹${overdue.toInt()}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'View schedule',
                    onPressed: () => _showInstallments(s),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Students List'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: secondaryColor,
            labelColor: secondaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Online'),
              Tab(text: 'Offline'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchStudents,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search students...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _searchText = v),
              ),
            ),
            _buildFilters(),
            Expanded(
              child: TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _fetchStudents,
                    child: _buildList(null),
                  ),
                  RefreshIndicator(
                    onRefresh: _fetchStudents,
                    child: _buildList('online'),
                  ),
                  RefreshIndicator(
                    onRefresh: _fetchStudents,
                    child: _buildList('offline'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: secondaryColor,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddNewStudent()),
          ).then((_) => _fetchStudents()),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
