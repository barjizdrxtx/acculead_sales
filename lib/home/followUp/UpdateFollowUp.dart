// lib/home/followUp/UpdateFollowUp.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utls/url.dart';

/// Now returns a Future<bool?> which completes true on successful save.
Future<bool?> showAddFollowUpSheet(BuildContext context, String leadId) {
  final TextEditingController _noteController = TextEditingController();
  DateTime? _selectedDate;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    backgroundColor: Colors.white,
    builder: (ctx) {
      final height = MediaQuery.of(ctx).size.height * 0.9;
      return Container(
        height: height,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            bool canSubmit =
                _noteController.text.trim().isNotEmpty && _selectedDate != null;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add Follow-Up',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Date picker
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        _selectedDate = picked;
                        setState(() {});
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Follow-Up Date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate != null
                                ? DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_selectedDate!)
                                : 'Select date',
                            style: TextStyle(
                              color: _selectedDate != null
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Note input
                  TextFormField(
                    controller: _noteController
                      ..addListener(() {
                        setState(() {});
                      }),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Note',
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.note_alt),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit
                          ? () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final token =
                                  prefs.getString(AccessToken.accessToken) ??
                                  '';
                              final updatedBy = prefs.getString('userId') ?? '';
                              final payload = {
                                'note': _noteController.text.trim(),
                                'date': _selectedDate!.toIso8601String(),
                                'updatedBy': updatedBy,
                              };
                              final uri = Uri.parse(
                                '${ApiConstants.baseUrl}/lead/follow-up/$leadId',
                              );
                              try {
                                final resp = await http.patch(
                                  uri,
                                  headers: {
                                    'Content-Type': 'application/json',
                                    'Authorization': 'Bearer $token',
                                  },
                                  body: jsonEncode(payload),
                                );
                                if (resp.statusCode == 200) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('Follow-up added!'),
                                    ),
                                  );
                                  // return true to caller
                                  Navigator.of(ctx).pop(true);
                                } else {
                                  throw Exception(
                                    'Server returned ${resp.statusCode}',
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                                // return false on error
                                Navigator.of(ctx).pop(false);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save Follow-Up',
                        style: TextStyle(
                          fontSize: 16,
                          color: canSubmit ? Colors.white : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
