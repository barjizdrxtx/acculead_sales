// lib/pages/student_form_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../utls/colors.dart';
import '../../utls/url.dart';

class EditStudentDetails extends StatefulWidget {
  final String studentId;
  const EditStudentDetails({Key? key, required this.studentId})
    : super(key: key);

  @override
  _EditStudentDetailsState createState() => _EditStudentDetailsState();
}

class _EditStudentDetailsState extends State<EditStudentDetails> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _studentIdController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _courseTypeController = TextEditingController();
  final _courseFeeController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();
  final _followUpNoteController = TextEditingController();
  final _feePaidController = TextEditingController();
  final _feeDueController = TextEditingController();
  final _reportNoteController = TextEditingController();

  String? _gender;
  String? _course;
  String? _duration;
  DateTime? _joiningDate;
  DateTime? _dateOfBirth;
  DateTime? _followUpDate;
  DateTime? _reportDate;
  bool _isJoined = false;
  bool _isCompleted = false;

  bool _loadingData = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _existingFollowUps = [];
  List<Map<String, dynamic>> _existingReports = [];

  final List<String> _courses = [
    'UI UX',
    'Digital Marketing',
    'Graphic Design',
    'Web Development',
  ];
  final List<String> _durations = [
    '1 month',
    '2 months',
    '3 months',
    '4 months',
    '6 months',
    '8 months',
    '10 months',
    '1 year',
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _loadingData = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/students/${widget.studentId}',
    );
    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      dynamic raw = decoded;
      if (decoded is Map && decoded.containsKey('result'))
        raw = decoded['result'];
      final data = raw is List && raw.isNotEmpty ? raw[0] : raw;
      // populate controllers
      _studentIdController.text = data['studentId'] ?? '';
      _admissionNumberController.text = data['admissionNumber'] ?? '';
      _fullNameController.text = data['fullName'] ?? '';
      _emailController.text = data['email'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _phone2Controller.text = data['phone2'] ?? '';
      _addressController.text = data['address'] ?? '';
      _photoUrlController.text = data['photoUrl'] ?? '';
      _courseTypeController.text = data['courseType'] ?? '';
      _gender = data['gender'];
      _course = data['course'];
      _duration = data['duration'];
      _isJoined = data['isJoined'] ?? false;
      _isCompleted = data['isCompleted'] ?? false;
      _courseFeeController.text = data['courseFee']?.toString() ?? '';
      _guardianNameController.text = data['guardianName'] ?? '';
      _guardianContactController.text = data['guardianContact'] ?? '';
      if (data['joiningDate'] != null)
        _joiningDate = DateTime.parse(data['joiningDate']);
      if (data['dateOfBirth'] != null)
        _dateOfBirth = DateTime.parse(data['dateOfBirth']);
      // existing follow-ups
      _existingFollowUps = [];
      if (data['followUps'] is List)
        _existingFollowUps = List<Map<String, dynamic>>.from(data['followUps']);
      // existing reports
      _existingReports = [];
      if (data['report'] is List)
        _existingReports = List<Map<String, dynamic>>.from(data['report']);
    }
    setState(() => _loadingData = false);
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _admissionNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _photoUrlController.dispose();
    _courseTypeController.dispose();
    _courseFeeController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _followUpNoteController.dispose();
    _feePaidController.dispose();
    _feeDueController.dispose();
    _reportNoteController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Future<void> _selectDate(
    BuildContext ctx,
    DateTime? initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    decoration: _decoration(label),
    validator:
        validator ?? (v) => v == null || v.trim().isEmpty ? 'Required' : null,
  );

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
    bool isRequired = false,
  }) => DropdownButtonFormField<String>(
    value: items.contains(value) ? value : null,
    decoration: _decoration(label),
    items: items
        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
        .toList(),
    onChanged: onChanged,
    validator: isRequired
        ? (v) => v == null || v.isEmpty ? 'Required' : null
        : null,
  );

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: InputDecorator(
      decoration: _decoration(label),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date == null
                ? 'Select Date'
                : DateFormat('dd-MM-yyyy').format(date),
            style: TextStyle(color: date == null ? Colors.grey : Colors.black),
          ),
          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
        ],
      ),
    ),
  );

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    // merge followUps
    final followUps = List<Map<String, dynamic>>.from(_existingFollowUps);
    if (_followUpDate != null &&
        _followUpNoteController.text.trim().isNotEmpty &&
        _feePaidController.text.trim().isNotEmpty &&
        _feeDueController.text.trim().isNotEmpty) {
      followUps.add({
        'date': _followUpDate!.toIso8601String(),
        'note': _followUpNoteController.text.trim(),
        'feePaid': double.tryParse(_feePaidController.text.trim()) ?? 0,
        'feeDue': double.tryParse(_feeDueController.text.trim()) ?? 0,
      });
    }

    // merge reports
    final reports = List<Map<String, dynamic>>.from(_existingReports);
    if (_reportDate != null && _reportNoteController.text.trim().isNotEmpty) {
      reports.add({
        'date': _reportDate!.toIso8601String(),
        'note': _reportNoteController.text.trim(),
      });
    }

    final payload = {
      'studentId': _studentIdController.text.trim(),
      'admissionNumber': _admissionNumberController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'phone2': _phone2Controller.text.trim(),
      'address': _addressController.text.trim(),
      'photoUrl': _photoUrlController.text.trim(),
      'courseType': _courseTypeController.text.trim(),
      'joiningDate': _joiningDate?.toIso8601String(),
      'dateOfBirth': _dateOfBirth?.toIso8601String(),
      'gender': _gender,
      'course': _course,
      'courseFee': double.tryParse(_courseFeeController.text.trim()) ?? 0,
      'duration': _duration,
      'guardianName': _guardianNameController.text.trim(),
      'guardianContact': _guardianContactController.text.trim(),
      'isJoined': _isJoined,
      'isCompleted': _isCompleted,
      'userId': userId,
      'followUps': followUps,
      'report': reports,
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/students/${widget.studentId}',
    );
    final res = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    final result = jsonDecode(res.body);
    if (res.statusCode == 200 &&
        (result['success'] == true || result['updated'] == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Student Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: 'Student ID',
                      controller: _studentIdController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Admission Number',
                      controller: _admissionNumberController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Full Name',
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Phone',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Alternate Phone',
                      controller: _phone2Controller,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Address',
                      controller: _addressController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Photo URL',
                      controller: _photoUrlController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Course Type',
                      controller: _courseTypeController,
                    ),
                    const SizedBox(height: 16),

                    _buildDateField(
                      label: 'Joining Date',
                      date: _joiningDate,
                      onTap: () => _selectDate(
                        context,
                        _joiningDate,
                        (p) => setState(() => _joiningDate = p),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      label: 'Date of Birth',
                      date: _dateOfBirth,
                      onTap: () => _selectDate(
                        context,
                        _dateOfBirth,
                        (p) => setState(() => _dateOfBirth = p),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Gender',
                      items: ['male', 'female', 'other'],
                      value: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Course',
                      items: _courses,
                      value: _course,
                      onChanged: (v) => setState(() => _course = v),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Course Fee',
                      controller: _courseFeeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null)
                          return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Duration',
                      items: _durations,
                      value: _duration,
                      onChanged: (v) => setState(() => _duration = v),
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Guardian Name',
                      controller: _guardianNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Guardian Contact',
                      controller: _guardianContactController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Joined'),
                      value: _isJoined,
                      onChanged: (v) => setState(() => _isJoined = v),
                    ),
                    SwitchListTile(
                      title: const Text('Completed'),
                      value: _isCompleted,
                      onChanged: (v) => setState(() => _isCompleted = v),
                    ),

                    if (_existingFollowUps.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Existing Follow-Ups',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._existingFollowUps.map((f) {
                        final dateStr = f['date'] != null
                            ? DateFormat(
                                'dd-MM-yyyy',
                              ).format(DateTime.parse(f['date']))
                            : '—';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: $dateStr'),
                                if (f['note'] != null)
                                  Text('Note: ${f['note']}'),
                                Text(
                                  'Paid: ₹${(f['feePaid'] ?? 0).toStringAsFixed(2)}',
                                ),
                                Text(
                                  'Due: ₹${(f['feeDue'] ?? 0).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 24),
                    const Text(
                      'Add New Follow-Up (optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: 'Follow-Up Date',
                      date: _followUpDate,
                      onTap: () => _selectDate(
                        context,
                        _followUpDate,
                        (p) => setState(() => _followUpDate = p),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Follow-Up Note',
                      controller: _followUpNoteController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Fee Paid',
                      controller: _feePaidController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v != null &&
                              v.isNotEmpty &&
                              double.tryParse(v) == null
                          ? 'Enter a number'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Fee Due',
                      controller: _feeDueController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          v != null &&
                              v.isNotEmpty &&
                              double.tryParse(v) == null
                          ? 'Enter a number'
                          : null,
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Add New Report (optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(
                      label: 'Report Date',
                      date: _reportDate,
                      onTap: () => _selectDate(
                        context,
                        _reportDate,
                        (p) => setState(() => _reportDate = p),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Report Note',
                      controller: _reportNoteController,
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
