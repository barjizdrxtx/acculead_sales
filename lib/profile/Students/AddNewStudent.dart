// lib/pages/student_form_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../utls/colors.dart';
import '../../utls/url.dart';

class AddNewStudent extends StatefulWidget {
  const AddNewStudent({Key? key}) : super(key: key);

  @override
  _AddNewStudentState createState() => _AddNewStudentState();
}

class _AddNewStudentState extends State<AddNewStudent> {
  final _formKey = GlobalKey<FormState>();

  // basic info
  final _studentIdController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _courseTypeController = TextEditingController();
  // final _photoUrlController = TextEditingController();

  // dropdowns
  String? _gender;
  String? _course;
  String? _duration;

  // dates
  DateTime? _joiningDate;
  DateTime? _dateOfBirth;

  // financials
  final _courseFeeController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();

  // initial follow-up
  DateTime? _followUpDate;
  final _followUpNoteController = TextEditingController();
  final _feePaidController = TextEditingController();
  final _feeDueController = TextEditingController();

  // initial report
  DateTime? _reportDate;
  final _reportNoteController = TextEditingController();

  // flags
  bool _isCompleted = false;
  bool _isJoined = false;
  bool _isLoading = false;

  final List<String> _courses = [
    'UI UX',
    'Digital Marketing',
    'Graphic Design',
    'Web Development',
  ];
  final List<String> _durations = [
    '2 months',
    '3 months',
    '4 months',
    '6 months',
    '8 months',
    '10 months',
    '1 year',
  ];

  @override
  void dispose() {
    _studentIdController.dispose();
    _admissionNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    _courseTypeController.dispose();
    // _photoUrlController.dispose();
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
  }) => FormField<DateTime>(
    builder: (_) => GestureDetector(
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
              style: TextStyle(
                color: date == null ? Colors.grey : Colors.black,
              ),
            ),
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          ],
        ),
      ),
    ),
  );

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    // build followUps list
    final followUps = <Map<String, dynamic>>[];
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

    // build report list
    final reports = <Map<String, dynamic>>[];
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
      // 'photoUrl': _photoUrlController.text.trim(),
      'courseType': _courseTypeController.text.trim(),
      'joiningDate': _joiningDate?.toIso8601String(),
      'dateOfBirth': _dateOfBirth?.toIso8601String(),
      'gender': _gender,
      'course': _course,
      'courseFee': double.tryParse(_courseFeeController.text.trim()) ?? 0,
      'duration': _duration,
      'guardianName': _guardianNameController.text.trim(),
      'guardianContact': _guardianContactController.text.trim(),
      'isCompleted': _isCompleted,
      'isJoined': _isJoined,
      'userId': userId,
      'followUps': followUps,
      'report': reports,
    };

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/students');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Student'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Student & Admission IDs
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

                    // Basic info
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
                    // _buildTextField(
                    //   label: 'Photo URL',
                    //   controller: _photoUrlController,
                    // ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Course Type',
                      controller: _courseTypeController,
                    ),
                    const SizedBox(height: 16),

                    // Dates & dropdowns
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

                    // Status switches
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
                    const SizedBox(height: 24),

                    // Initial Follow-Up
                    const Text(
                      'Initial Follow-Up (optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
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

                    // Initial Report
                    const Text(
                      'Initial Report (optional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
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

                    // Save button
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
                          'Save Student',
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
