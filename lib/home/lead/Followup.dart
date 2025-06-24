// lib/pages/follow_up_form_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../utls/colors.dart';
import '../../utls/url.dart';

class FollowUpFormPage extends StatefulWidget {
  final String leadId;

  const FollowUpFormPage({Key? key, required this.leadId}) : super(key: key);

  @override
  _FollowUpFormPageState createState() => _FollowUpFormPageState();
}

class _FollowUpFormPageState extends State<FollowUpFormPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _followUpDate;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _existingFollowUps = [];

  @override
  void initState() {
    super.initState();
    _loadExistingFollowUps();
  }

  Future<void> _loadExistingFollowUps() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final url = Uri.parse('${ApiConstants.baseUrl}/lead/${widget.leadId}');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['result'];
      if (data['followUps'] != null && data['followUps'] is List) {
        _existingFollowUps = List<Map<String, dynamic>>.from(data['followUps']);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _submitFollowUp() async {
    if (_followUpDate == null || _noteController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    final newEntry = {
      'date': _followUpDate!.toIso8601String(),
      'note': _noteController.text.trim(),
      'updatedBy': userId,
    };

    final combined = List<Map<String, dynamic>>.from(_existingFollowUps)
      ..add(newEntry);

    final payload = {'followUps': combined};

    final uri = Uri.parse('${ApiConstants.baseUrl}/lead/${widget.leadId}');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    final result = jsonDecode(response.body);

    if (response.statusCode == 200 && result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error adding follow-up'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Progress'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Follow-Up Date',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  _followUpDate == null
                      ? 'Select Date'
                      : DateFormat('dd-MM-yyyy').format(_followUpDate!),
                  style: TextStyle(
                    color: _followUpDate == null ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Progress Note',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 4,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFollowUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isSubmitting ? 'Saving...' : 'Save Progress',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
