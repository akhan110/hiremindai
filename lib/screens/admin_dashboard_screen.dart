import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../services/firebase_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await FirebaseService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlockStatus(AppUser user) async {
    final newStatus = !user.isBlocked;
    try {
      await FirebaseService.updateUserStatus(user.uid, isBlocked: newStatus);
      await _loadUsers(); // Refresh list
    } catch (e) {
      debugPrint('Error updating user status: $e');
    }
  }

  Future<void> _editQuota(AppUser user) async {
    final TextEditingController controller = TextEditingController(text: user.monthlyQuota.toString());
    
    final int? newQuota = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Monthly Quota'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'AI Resumes Quota',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null) {
                  Navigator.pop(context, val);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newQuota != null && newQuota != user.monthlyQuota) {
      try {
        await FirebaseService.updateUserStatus(user.uid, monthlyQuota: newQuota);
        await _loadUsers();
      } catch (e) {
        debugPrint('Error updating quota: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: Text('Admin Dashboard', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF6B7280)),
                      columns: const [
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Tokens Used')),
                        DataColumn(label: Text('Monthly Quota')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _users.map((user) {
                        return DataRow(
                          cells: [
                            DataCell(Text(user.email, style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.isAdmin ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user.isAdmin ? 'Admin' : 'User',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: user.isAdmin ? Colors.purple : Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                user.tokensUsed.toString(),
                                style: GoogleFonts.inter(
                                  color: user.tokensUsed >= user.monthlyQuota ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Text(user.monthlyQuota.toString()),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                                    onPressed: () => _editQuota(user),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.isBlocked ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user.isBlocked ? 'Blocked' : 'Active',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: user.isBlocked ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              user.isAdmin 
                                ? const SizedBox() // Don't allow blocking admins easily here
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: user.isBlocked ? Colors.green : Colors.red,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    onPressed: () => _toggleBlockStatus(user),
                                    child: Text(user.isBlocked ? 'Unblock' : 'Block'),
                                  ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
