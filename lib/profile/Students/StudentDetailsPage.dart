// lib/pages/student_details_page.dart

import 'dart:convert';
import 'package:acculead_sales/profile/Students/AddFollowUp.dart';
import 'package:acculead_sales/profile/Students/AddNotes.dart';
import 'package:acculead_sales/profile/Students/EditStudentDetails.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class FollowUp {
  final String note;
  final DateTime date;
  final double feePaid;
  final double feeDue;

  FollowUp({
    required this.note,
    required this.date,
    required this.feePaid,
    required this.feeDue,
  });

  factory FollowUp.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Map && v['\$date'] != null) {
        return DateTime.tryParse(v['\$date'].toString()) ?? DateTime.now();
      } else if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return FollowUp(
      note: map['note']?.toString() ?? '',
      date: parseDate(map['date']),
      feePaid: (map['feePaid'] as num?)?.toDouble() ?? 0.0,
      feeDue: (map['feeDue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Student {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime joiningDate;
  final DateTime? dateOfBirth;
  final String? gender;
  final List<String> courses;
  final double? courseFee;
  final String? duration;
  final String? guardianName;
  final String? guardianContact;
  final List<FollowUp> followUps;
  final String studentId;
  final String admissionNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Student({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.address,
    required this.joiningDate,
    this.dateOfBirth,
    this.gender,
    required this.courses,
    this.courseFee,
    this.duration,
    this.guardianName,
    this.guardianContact,
    required this.followUps,
    required this.studentId,
    required this.admissionNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory Student.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Map && v['\$date'] != null) {
        return DateTime.tryParse(v['\$date'].toString()) ?? DateTime.now();
      } else if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    String parseString(dynamic v) => v?.toString() ?? '';
    String? parseOptionalString(dynamic v) => v?.toString();
    double? parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    List<String> parseCourses(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v != null) return [v.toString()];
      return [];
    }

    List<FollowUp> parseFollowUps(dynamic v) {
      if (v is List) {
        return v
            .where((e) => e is Map<String, dynamic>)
            .map((e) => FollowUp.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    bool parseActive(dynamic v) {
      if (v is bool) return v;
      if (v is String)
        return v.toLowerCase() == 'true' || v.toLowerCase() == 'active';
      return false;
    }

    String id = '';
    final rawId = map['_id'];
    if (rawId is Map && rawId['\$oid'] != null) {
      id = rawId['\$oid'].toString();
    } else {
      id = rawId?.toString() ?? '';
    }

    return Student(
      id: id,
      fullName: parseString(map['fullName']),
      email: parseOptionalString(map['email']),
      phone: parseOptionalString(
        map['phone'] is Map ? map['phone']['\$numberLong'] : map['phone'],
      ),
      address: parseOptionalString(map['address']),
      joiningDate: parseDate(map['joiningDate']),
      dateOfBirth: map['dateOfBirth'] != null
          ? parseDate(map['dateOfBirth'])
          : null,
      gender: parseOptionalString(map['gender']),
      courses: parseCourses(map['course']),
      courseFee: parseDouble(map['courseFee']),
      duration: parseOptionalString(map['duration']),
      guardianName: parseOptionalString(map['guardianName']),
      guardianContact: parseOptionalString(map['guardianContact']),
      followUps: parseFollowUps(map['followUps']),
      studentId: parseString(map['studentId']),
      admissionNumber: parseString(map['admissionNumber']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isActive: parseActive(map['isActive']),
    );
  }
}

class StudentDetailsPage extends StatefulWidget {
  final String studentId;

  const StudentDetailsPage({Key? key, required this.studentId})
    : super(key: key);

  @override
  _StudentDetailsPageState createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  late Future<Student> _futureStudent;

  @override
  void initState() {
    super.initState();
    _futureStudent = _fetchStudentById(widget.studentId);
  }

  Future<Student> _fetchStudentById(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/students/$id');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load student data');
    }

    final decoded = jsonDecode(response.body);
    dynamic rawResult = decoded;
    if (decoded is Map<String, dynamic> && decoded.containsKey('result')) {
      rawResult = decoded['result'];
    }

    Map<String, dynamic> studentMap;
    if (rawResult is List && rawResult.isNotEmpty && rawResult[0] is Map) {
      studentMap = rawResult[0] as Map<String, dynamic>;
    } else if (rawResult is Map<String, dynamic>) {
      studentMap = rawResult;
    } else {
      throw Exception('Unexpected student data format');
    }

    return Student.fromMap(studentMap);
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 10),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Student>(
      future: _futureStudent,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final s = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Student Details'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  s.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _detailRow(
                  'Status',
                  s.isActive ? 'Active' : 'Inactive',
                  Icons.check_circle_outline,
                ),
                _detailRow(
                  'Admission No',
                  s.admissionNumber,
                  Icons.confirmation_num_outlined,
                ),
                _detailRow(
                  'Joining Date',
                  DateFormat('dd MMM yyyy').format(s.joiningDate),
                  Icons.calendar_today,
                ),
                if (s.dateOfBirth != null)
                  _detailRow(
                    'Date of Birth',
                    DateFormat('dd MMM yyyy').format(s.dateOfBirth!),
                    Icons.cake,
                  ),
                _detailRow(
                  'Email',
                  s.email ?? 'Not provided',
                  Icons.email_outlined,
                ),
                _detailRow('Phone', s.phone ?? 'Not provided', Icons.phone),
                _detailRow('Address', s.address ?? 'Not provided', Icons.home),
                _detailRow(
                  'Gender',
                  s.gender ?? 'Not provided',
                  Icons.person_outline,
                ),
                _detailRow(
                  'Courses',
                  s.courses.join(', '),
                  Icons.book_outlined,
                ),
                if (s.courseFee != null)
                  _detailRow(
                    'Course Fee',
                    '₹${s.courseFee!.toStringAsFixed(2)}',
                    Icons.attach_money,
                  ),
                if (s.duration != null)
                  _detailRow('Duration', s.duration!, Icons.timelapse),
                if (s.guardianName != null)
                  _detailRow(
                    'Guardian',
                    s.guardianName!,
                    Icons.family_restroom,
                  ),
                if (s.guardianContact != null)
                  _detailRow(
                    'Guardian Contact',
                    s.guardianContact!,
                    Icons.phone_android,
                  ),
                const SizedBox(height: 20),
                if (s.followUps.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Follow Ups',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...s.followUps.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy – hh:mm a').format(f.date),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(f.note),
                          const SizedBox(height: 4),
                          Text('Paid: ₹${f.feePaid.toStringAsFixed(2)}'),
                          Text('Due: ₹${f.feeDue.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Payment (FollowUp) button
              FloatingActionButton(
                heroTag: 'editPayment',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditStudentDetails(studentId: widget.studentId),
                    ),
                  );
                },
                backgroundColor: Colors.green,
                child: const Icon(Icons.edit, color: Colors.white),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'addPayment',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddFollowUp(
                        studentId: widget.studentId,
                        courseFee: s.courseFee ?? 0.0,
                      ),
                    ),
                  );
                },
                backgroundColor: Colors.deepOrange,
                child: const Icon(Icons.money, color: Colors.white),
              ),
              const SizedBox(height: 12),
              // Add Notes button
              FloatingActionButton(
                heroTag: 'addNotes',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddNotes(studentId: widget.studentId),
                    ),
                  );
                },
                backgroundColor: Colors.blue,
                child: const Icon(Icons.notes, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }
}
