import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../data/databases/app_database.dart';
import '../../widgets/common/manager_override_dialog.dart';
import '../../themes/colors.dart';
import '../../themes/text_styles.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserRepository _userRepository = sl<UserRepository>();
  List<User> _users = [];
  List<AuditLogEntry> _auditLogs = [];
  List<AuditLogEntry> _filteredAuditLogs = [];
  bool _isLoading = true;
  bool _isAuthorized = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _searchController.addListener(_filterAuditLogs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser != null && currentUser.role == 'admin') {
        setState(() {
          _isAuthorized = true;
        });
        await _loadData();
      } else {
        setState(() {
          _isAuthorized = false;
          _isLoading = false;
        });
        // Prompt for Admin override
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestAdminOverride();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error verifying privileges: $e', isError: true);
    }
  }

  Future<void> _requestAdminOverride() async {
    final manager = await ManagerOverrideDialog.show(
      context,
      actionName: 'Access Administrative Settings & Logs',
    );
    if (manager != null) {
      if (manager.role == 'admin') {
        setState(() {
          _isAuthorized = true;
        });
        await _loadData();
      } else {
        _showSnackBar('Access denied. Administrator role required.', isError: true);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userRepository.getEmployees();
      final logs = await _userRepository.getAuditLogs();
      setState(() {
        _users = users;
        _auditLogs = logs;
        _filteredAuditLogs = logs;
      });
    } catch (e) {
      _showSnackBar('Failed to load system records: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAuditLogs() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredAuditLogs = _auditLogs;
      });
    } else {
      setState(() {
        _filteredAuditLogs = _auditLogs.where((log) {
          final action = log.action.toLowerCase();
          final details = log.details.toLowerCase();
          final userId = log.userId.toLowerCase();
          return action.contains(query) || details.contains(query) || userId.contains(query);
        }).toList();
      });
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _addEmployeeDialog() {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'cashier';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('Register Employee', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'System Role'),
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier (POS Checkout only)')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager (POS, Stock Adjust, Reports)')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin (Full system credentials)')),
                  ],
                  onChanged: (val) {
                    if (val != null) role = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final newUser = User(
                      id: 'user_${const Uuid().v4().substring(0, 8)}',
                      email: emailCtrl.text.trim(),
                      role: role,
                      passwordHash: _hashPassword(passwordCtrl.text),
                      isActive: true,
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                      syncStatus: 'pending',
                    );
                    await _userRepository.register(newUser, passwordCtrl.text);
                    Navigator.pop(context);
                    _showSnackBar('Successfully registered ${emailCtrl.text.trim()}');
                    _loadData();
                  } catch (e) {
                    _showSnackBar('Registration failed: $e', isError: true);
                  }
                }
              },
              child: const Text('REGISTER'),
            ),
          ],
        );
      },
    );
  }

  void _editEmployeeDialog(User user) {
    String role = user.role;
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manage: ${user.email}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'System Role'),
                  items: const [
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) role = val;
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Reset Password (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Leave blank to keep current',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    var updatedUser = user.copyWith(
                      role: role,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    
                    if (passwordCtrl.text.isNotEmpty) {
                      updatedUser = updatedUser.copyWith(
                        passwordHash: _hashPassword(passwordCtrl.text),
                      );
                    }

                    await _userRepository.updateProfile(updatedUser);
                    
                    // Log the admin edit action
                    await _userRepository.logAuditAction(
                      'admin_edit_user',
                      'Admin modified user: ${user.email}. Role updated: $role. Password reset: ${passwordCtrl.text.isNotEmpty}.',
                    );

                    Navigator.pop(context);
                    _showSnackBar('Successfully updated user ${user.email}');
                    _loadData();
                  } catch (e) {
                    _showSnackBar('Failed to update employee: $e', isError: true);
                  }
                }
              },
              child: const Text('SAVE CHANGES'),
            ),
          ],
        );
      },
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildLockScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(24.0),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.error,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Admin Access Restricted',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The User Management panel is restricted to system administrators. Please authorize with administrator credentials.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _requestAdminOverride,
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  label: const Text('Authorize Admin Panel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    context.go('/');
                  },
                  child: const Text(
                    'Return to POS',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getAuditIcon(String action) {
    if (action.contains('login_failed') || action.contains('blocked')) {
      return Icons.gpp_bad_rounded;
    } else if (action.contains('login')) {
      return Icons.vpn_key_outlined;
    } else if (action.contains('void')) {
      return Icons.cancel_presentation_rounded;
    } else if (action.contains('override')) {
      return Icons.admin_panel_settings_rounded;
    } else if (action.contains('stock') || action.contains('inventory')) {
      return Icons.adjust_rounded;
    } else {
      return Icons.info_outline_rounded;
    }
  }

  Color _getAuditColor(String action) {
    if (action.contains('login_failed') || action.contains('blocked')) {
      return Colors.red;
    } else if (action.contains('login')) {
      return Colors.green;
    } else if (action.contains('void')) {
      return Colors.red.shade800;
    } else if (action.contains('override')) {
      return Colors.orange;
    } else if (action.contains('stock')) {
      return Colors.blue;
    } else {
      return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('System Administration'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: _buildLockScreen(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('System Administration'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Employees'),
              Tab(icon: Icon(Icons.history_toggle_off), text: 'System Audit Logs'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Employees List
            RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: _users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final color = _getRoleBadgeColor(user.role);
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(Icons.person, color: color),
                      ),
                      title: Text(
                        user.email,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user.isActive ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.isActive ? 'ACTIVE' : 'DISABLED',
                              style: TextStyle(
                                color: user.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: user.isActive,
                            onChanged: (val) async {
                              final updatedUser = user.copyWith(
                                isActive: val,
                                updatedAt: DateTime.now().millisecondsSinceEpoch,
                              );
                              await _userRepository.updateProfile(updatedUser);
                              
                              // Log status change
                              await _userRepository.logAuditAction(
                                'admin_toggle_user_status',
                                'Admin toggled isActive for employee ${user.email} to: $val.',
                              );

                              _loadData();
                              _showSnackBar(val ? '${user.email} activated!' : '${user.email} deactivated!');
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            onPressed: () => _editEmployeeDialog(user),
                            tooltip: 'Manage Employee',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Tab 2: System Audit Logs
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter logs by activity, details, or userId...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filteredAuditLogs.isEmpty
                        ? const Center(
                            child: Text(
                              'No audit logs found matching your query.',
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.separated(
                              itemCount: _filteredAuditLogs.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                final log = _filteredAuditLogs[index];
                                final dt = DateTime.fromMillisecondsSinceEpoch(log.createdAt);
                                final timeStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                final actionColor = _getAuditColor(log.action);
                                final actionIcon = _getAuditIcon(log.action);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: actionColor.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(actionIcon, color: actionColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  log.action.toUpperCase(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: actionColor,
                                                  ),
                                                ),
                                                Text(
                                                  timeStr,
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log.details,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Actor: ${log.userId}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return DefaultTabController.of(context).index == 0
                ? FloatingActionButton(
                    onPressed: _addEmployeeDialog,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.add),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
