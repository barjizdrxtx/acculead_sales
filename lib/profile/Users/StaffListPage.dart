// lib/pages/users_list_page.dart

import 'dart:convert';
import 'package:acculead_sales/profile/Users/AddNewUser.dart';
import 'package:acculead_sales/profile/Users/UserDetailsPage.dart';
import 'package:acculead_sales/utls/colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../utls/url.dart';

class StaffListPage extends StatefulWidget {
  const StaffListPage({Key? key}) : super(key: key);

  @override
  _StaffListPageState createState() => _StaffListPageState();
}

class _StaffListPageState extends State<StaffListPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/auth/users');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() => _users = data);
        } else {
          setState(() => _error = 'Invalid server response');
        }
      } else {
        final body = jsonDecode(response.body);
        setState(() => _error = body['message'] ?? 'Failed to load users');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final username = user['username'] ?? '—';
    final isActive = user['isActive'] == true;
    final userId = user['id'];
    // Parse and format creation date
    final createdAtStr = user['createdAt'] ?? '';
    final createdAt = DateTime.tryParse(createdAtStr);
    final joinedDate = createdAt != null
        ? DateFormat('dd-MM-yyyy').format(createdAt)
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isActive ? secondaryColor : Colors.grey[400],
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          username,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Date: $joinedDate',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive ? Colors.green.shade800 : Colors.red.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to UserDetailPage, passing the whole user map
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserDetailPage(userId: userId)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staffs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchUsers,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 150),
                    Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                )
              : _users.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 150),
                    Center(child: Text('No users found')),
                  ],
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    return _buildUserCard(_users[i] as Map<String, dynamic>);
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: secondaryColor,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddNewUser()),
          ).then((_) => _fetchUsers());
        },
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}
