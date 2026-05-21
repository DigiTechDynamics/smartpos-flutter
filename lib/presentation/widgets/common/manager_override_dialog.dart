import 'package:flutter/material.dart';
import '../../../core/services/service_locator.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../data/databases/app_database.dart';
import '../../themes/colors.dart';
import '../../themes/text_styles.dart';

class ManagerOverrideDialog extends StatefulWidget {
  final String actionName;

  const ManagerOverrideDialog({
    Key? key,
    required this.actionName,
  }) : super(key: key);

  static Future<User?> show(BuildContext context, {required String actionName}) async {
    return showDialog<User>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManagerOverrideDialog(actionName: actionName),
    );
  }

  @override
  State<ManagerOverrideDialog> createState() => _ManagerOverrideDialogState();
}

class _ManagerOverrideDialogState extends State<ManagerOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userRepo = sl<UserRepository>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // 1. Authenticate user
      final user = await userRepo.authenticate(email, password);

      if (user == null) {
        setState(() {
          _errorMessage = 'Invalid email or password';
          _isLoading = false;
        });
        return;
      }

      // 2. Validate role is Manager or Admin
      if (user.role != 'manager' && user.role != 'admin') {
        setState(() {
          _errorMessage = 'Access denied. Manager or Admin credentials required.';
          _isLoading = false;
        });
        return;
      }

      // 3. Log manager override action
      await userRepo.logAuditAction(
        'manager_override',
        'Manager/Admin ${user.email} authorized override for sensitive action: "${widget.actionName}"',
      );

      if (mounted) {
        Navigator.of(context).pop(user);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred during authentication: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.secondary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Override',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.actionName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'A manager or administrator must authorize this sensitive action by entering their credentials.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Manager Email',
                    hintText: 'manager@smartpos.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Authorize'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
