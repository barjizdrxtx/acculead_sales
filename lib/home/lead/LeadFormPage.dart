// lib/pages/lead_form_page.dart

import 'dart:convert';
import 'package:acculead_sales/components/CustomAppBar2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:country_picker/country_picker.dart';
import '../../utls/colors.dart';
import '../../utls/url.dart';

class LeadFormPage extends StatefulWidget {
  final String? leadId;

  const LeadFormPage({Key? key, this.leadId}) : super(key: key);

  @override
  _LeadFormPageState createState() => _LeadFormPageState();
}

class _LeadFormPageState extends State<LeadFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _placeController = TextEditingController();
  final _noteController = TextEditingController();

  String? _gender;
  String? _district;
  String? _course;
  String? _source;
  String? _status;
  DateTime? _enquiryDate;
  DateTime? _followUpDate;
  String _countryCode = '+91';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.leadId != null) {
      _loadLeadData();
    } else {
      isLoading = false;
    }
  }

  Future<void> _loadLeadData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/lead/${widget.leadId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['result'];
        final storedPhone = (data['phoneNumber'] as String? ?? '').trim();

        // extract country code and local part
        String local = storedPhone;
        if (storedPhone.contains(' ')) {
          final parts = storedPhone.split(' ');
          if (parts.length == 2 && parts[0].startsWith('+')) {
            _countryCode = parts[0];
            local = parts[1];
          }
        } else if (storedPhone.startsWith(_countryCode)) {
          local = storedPhone.substring(_countryCode.length);
        } else if (storedPhone.startsWith('+')) {
          final match = RegExp(r'^\+\d{1,3}').stringMatch(storedPhone) ?? '';
          if (match.isNotEmpty) {
            _countryCode = match;
            local = storedPhone.substring(match.length);
          }
        }

        setState(() {
          _fullNameController.text = data['fullName'] ?? '';
          _phoneController.text = local;
          _emailController.text = data['email'] ?? '';
          _placeController.text = data['place'] ?? '';
          _gender = data['gender'];
          _district = data['district'];
          _course = data['course'];
          _status = data['status'];
          _source = data['source'];
          _enquiryDate = data['enquiryDate'] != null
              ? DateTime.tryParse(data['enquiryDate'])
              : null;
          if (data['followUps'] != null && data['followUps'].isNotEmpty) {
            final fu = data['followUps'].last;
            _noteController.text = fu['note'] ?? '';
            _followUpDate = fu['date'] != null
                ? DateTime.tryParse(fu['date'])
                : null;
          }
        });
      }
    } catch (_) {
      // ignore errors
    }

    setState(() => isLoading = false);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AccessToken.accessToken) ?? '';
    final userId = prefs.getString('userId') ?? '';

    final followUps = <Map<String, dynamic>>[];
    if (_followUpDate != null && _noteController.text.trim().isNotEmpty) {
      followUps.add({
        'date': _followUpDate!.toIso8601String(),
        'note': _noteController.text.trim(),
        'updatedBy': userId,
      });
    }

    final finalPhone = '$_countryCode${_phoneController.text.trim()}';

    final payload = {
      'fullName': _fullNameController.text.trim(),
      'phoneNumber': finalPhone,
      'gender': _gender,
      'email': _emailController.text.trim(),
      'place': _placeController.text.trim(),
      'district': _district,
      'course': _course,
      'status': _status,
      'source': _source,
      'assignedTo': userId,
      'enquiryDate': _enquiryDate?.toIso8601String(),
      'followUps': followUps,
    };

    try {
      final uri = widget.leadId != null
          ? Uri.parse('${ApiConstants.baseUrl}/lead/${widget.leadId}')
          : Uri.parse('${ApiConstants.baseUrl}/lead');

      final response = widget.leadId != null
          ? await http.patch(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
          : await http.post(
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
          SnackBar(
            content: Text(
              widget.leadId != null
                  ? 'Lead updated successfully'
                  : 'Lead saved successfully',
            ),
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
    }
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
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    decoration: _decoration(label),
    validator: validator,
    maxLines: maxLines,
  );

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) => DropdownButtonFormField<String>(
    value: items.contains(value) ? value : null,
    decoration: _decoration(label),
    validator: validator,
    items: items
        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
        .toList(),
    onChanged: onChanged,
  );

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) => FormField<DateTime>(
    builder: (state) => GestureDetector(
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar2(
        title: widget.leadId != null ? 'Edit Lead' : 'Add New Lead',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Full Name',
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            showCountryPicker(
                              context: context,
                              showPhoneCode: true,
                              onSelect: (country) => setState(
                                () => _countryCode = '+${country.phoneCode}',
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _countryCode,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTextField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Phone Number is required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Gender',
                      items: ['Male', 'Female', 'Other'],
                      value: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Place',
                      controller: _placeController,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'District',
                      items: [
                        'Thiruvananthapuram',
                        'Kollam',
                        'Pathanamthitta',
                        'Alappuzha',
                        'Kottayam',
                        'Idukki',
                        'Ernakulam',
                        'Thrissur',
                        'Palakkad',
                        'Malappuram',
                        'Kozhikode',
                        'Wayanad',
                        'Kannur',
                        'Kasaragod',
                      ],
                      value: _district,
                      onChanged: (v) => setState(() => _district = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Course',
                      items: [
                        'Graphic Design',
                        'Digital Marketing',
                        'Web Development',
                        'UI/UX',
                      ],
                      value: _course,
                      onChanged: (v) => setState(() => _course = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Status',
                      items: ['new', 'in progress', 'hot', 'closed', 'lost'],
                      value: _status,
                      onChanged: (v) => setState(() => _status = v),
                      validator: (val) =>
                          val == null ? 'Status is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Source',
                      items: ['Instagram', 'Website', 'Referral', 'Other'],
                      value: _source,
                      onChanged: (v) => setState(() => _source = v),
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
                        child: Text(
                          widget.leadId != null ? 'Update Lead' : 'Save Lead',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
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
