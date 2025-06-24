// lib/pages/add_followup.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../utls/colors.dart';
import '../../utls/url.dart';

class AddFollowUp extends StatefulWidget {
  final String studentId;
  final double courseFee;
  const AddFollowUp({
    Key? key,
    required this.studentId,
    required this.courseFee,
  }) : super(key: key);

  @override
  _AddFollowUpState createState() => _AddFollowUpState();
}

class _AddFollowUpState extends State<AddFollowUp> {
  bool _loading = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _followUps = [];
  double _totalPaid = 0.0;
  DateTime? _date;
  final _noteController = TextEditingController();
  final _paidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paidController.addListener(_onPaidChanged);
    _fetchFollowUps();
  }

  void _onPaidChanged() {
    final val = double.tryParse(_paidController.text.trim()) ?? 0.0;
    _paidController.value = TextEditingValue(
      text: val.toStringAsFixed(0),
      selection: TextSelection.collapsed(offset: val.toStringAsFixed(0).length),
    );
  }

  double get _remainingDue =>
      (widget.courseFee - _totalPaid).clamp(0.0, double.infinity);

  Future<void> _fetchFollowUps() async {
    setState(() => _loading = true);
    try {
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
      if (res.statusCode != 200) throw Exception('Status: ${res.statusCode}');
      final decoded = jsonDecode(res.body);
      final raw = decoded['result'] is List
          ? decoded['result'][0]
          : (decoded['result'] ?? decoded);
      final ups = (raw['followUps'] as List<dynamic>?) ?? [];
      _followUps = ups.map((e) {
        final feePaid = (e['feePaid'] as num?)?.toDouble() ?? 0.0;
        final dt = DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
        return {'note': e['note'] ?? '', 'date': dt, 'feePaid': feePaid};
      }).toList();
      _totalPaid = _followUps.fold(
        0.0,
        (sum, f) => sum + (f['feePaid'] as double),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addFollowUp() async {
    final paid = double.tryParse(_paidController.text.trim()) ?? 0.0;
    if (_date == null ||
        _noteController.text.trim().isEmpty ||
        paid <= 0 ||
        paid > _remainingDue)
      return;

    setState(() => _submitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AccessToken.accessToken) ?? '';
      final payload = _followUps
          .map(
            (f) => {
              'note': f['note'],
              'date': (f['date'] as DateTime).toIso8601String(),
              'feePaid': f['feePaid'],
            },
          )
          .toList();
      final newItem = {
        'note': _noteController.text.trim(),
        'date': _date!.toIso8601String(),
        'feePaid': paid,
      };
      payload.add(newItem);

      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/students/${widget.studentId}',
      );
      final res = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'followUps': payload}),
      );
      if (res.statusCode != 200) throw Exception('Status: ${res.statusCode}');

      setState(() {
        _followUps.add({
          'note': newItem['note'] as String,
          'date': DateTime.parse(newItem['date'] as String),
          'feePaid': newItem['feePaid'] as double,
        });
        _totalPaid += paid;
        _noteController.clear();
        _paidController.clear();
        _date = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _paidController.removeListener(_onPaidChanged);
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = double.tryParse(_paidController.text.trim()) ?? 0.0;
    final remainingAfter = (_remainingDue - paid).clamp(0.0, double.infinity);
    final canSubmit =
        !_loading &&
        !_submitting &&
        _date != null &&
        _noteController.text.trim().isNotEmpty &&
        paid > 0 &&
        paid <= _remainingDue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Add Payment Update',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  reverse: true,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSummaryCard(
                              label: 'Total Paid',
                              value: '₹${_totalPaid.toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 12),
                            _buildSummaryCard(
                              label: 'Remaining',
                              value: '₹${_remainingDue.toStringAsFixed(0)}',
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // existing follow-ups
                        if (_followUps.isNotEmpty)
                          ..._followUps.map((f) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '₹${(f['feePaid'] as double).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f['note'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy, hh:mm a',
                                          ).format(f['date'] as DateTime),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 24),
                        // add new follow-up
                        TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.black54,
                          ),
                          label: Text(
                            _date == null
                                ? 'Select Date'
                                : DateFormat('dd-MM-yyyy').format(_date!),
                            style: const TextStyle(color: Colors.black87),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            hintText: 'Enter note',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _paidController,
                          keyboardType: const TextInputType.numberWithOptions(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: 'Fee Paid',
                            suffixText: '₹',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remaining after: ₹${remainingAfter.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: canSubmit ? _addFollowUp : null,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: Text(
                              _submitting ? 'Adding...' : 'Add Follow-Up',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: (color ?? primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                color: color ?? primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
