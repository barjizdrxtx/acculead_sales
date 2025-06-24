// lib/pages/user_detail_page.dart

import 'dart:convert';
import 'package:acculead_sales/profile/Users/ChangePasswordPage.dart';
import 'package:acculead_sales/profile/Users/EditUserDetails.dart';
import 'package:acculead_sales/utls/url.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class User {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String role;
  final bool isActive;
  final String avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.isActive,
    required this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      email: map['email']?.toString() ?? 'Not provided',
      phone: map['phone']?.toString() ?? 'Not provided',
      address: map['address']?.toString() ?? 'Not provided',
      role: map['role']?.toString() ?? '',
      isActive: map['isActive'] == true,
      avatarUrl: map['profilePhotoUrl']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class UserDetailPage extends StatefulWidget {
  final String userId;

  const UserDetailPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserDetailPageState createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late Future<User> _futureUser;

  @override
  void initState() {
    super.initState();
    _futureUser = _fetchUserById(widget.userId);
  }

  Future<User> _fetchUserById(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/auth/user/$id');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load user data');
    }
    // If your API wraps the user in a `data` field, uncomment the next two lines:
    // final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    // final map = (decoded['data'] as Map<String, dynamic>?) ?? {};
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromMap(map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // make the title visible on white
        elevation: 0,
      ),
      body: FutureBuilder<User>(
        future: _futureUser,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final user = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  backgroundColor: Colors.grey.shade200,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.fullName.isNotEmpty
                              ? user.fullName[0].toUpperCase()
                              : '',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(user.email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _detailRow(
                        'Username',
                        user.username,
                        Icons.person_outline,
                      ),
                      _detailRow('Phone', user.phone, Icons.phone),
                      _detailRow('Address', user.address, Icons.home),
                      _detailRow('Role', user.role, Icons.verified_user),
                      _detailRow(
                        'Status',
                        user.isActive ? 'Active' : 'Inactive',
                        Icons.toggle_on,
                      ),
                      _detailRow(
                        'Created',
                        DateFormat('dd MMM yyyy').format(user.createdAt),
                        Icons.calendar_today,
                      ),
                      _detailRow(
                        'Updated',
                        DateFormat('dd MMM yyyy').format(user.updatedAt),
                        Icons.update,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // pass the full user into your edit screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditUserDetails(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Details',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangePasswordPage(username: user.username),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock, color: Colors.white),
                        label: const Text(
                          'Change Password',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
