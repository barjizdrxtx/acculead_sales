// lib/pages/follow_up_form_page.dart

import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar2.dart';
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
  String? _status;
  bool _isSubmitting = false;

  final List<String> _statusOptions = [
    'in progress',
    'hot',
    'closed',
    'lost',
    'not connected',
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';

    final payload = {
      'note': _noteController.text.trim(),
      'status': _status!,
      if (_followUpDate != null)
        'followUpDate': _followUpDate!.toIso8601String(),
    };

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/lead/follow-up/${widget.leadId}',
    );
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

  void _showSaveWarning() {
    if (!_formKey.currentState!.validate()) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirm",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Confirm Follow-Up',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none, // remove underline
                    ),
                  ),
                ),

                const SizedBox(height: 12), // tightened
                // Icon & message
                Icon(
                  Icons.warning_rounded,
                  size: 48,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Are you sure you want to save this follow-up?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      decoration: TextDecoration.none, // remove underline
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              decoration: TextDecoration.none,
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _submitFollowUp();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              decoration: TextDecoration.none,
                            ),
                          ),
                          child: const Text(
                            'Confirm',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar2(title: "Add Progress"),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Date picker (optional)
              GestureDetector(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Follow-Up Date (optional)',
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
                        ? 'Select date'
                        : DateFormat('dd-MM-yyyy').format(_followUpDate!),
                    style: TextStyle(
                      color: _followUpDate == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Progress note (required)
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Progress Note *',
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
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a note'
                    : null,
              ),

              const SizedBox(height: 16),

              // Status dropdown (required)
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'Status *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                ),
                items: _statusOptions
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _status = val),
                validator: (val) =>
                    val == null ? 'Please select a status' : null,
              ),

              const Spacer(),

              // Save button with confirmation dialog
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _showSaveWarning,
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
      ),
    );
  }
}
