import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/queue_provider.dart';
import '../theme/app_theme.dart';
import 'patient/select_department_screen.dart';
import 'patient/live_status_screen.dart';
import 'admin/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  String _selectedRole = 'patient';

  String? _emailError;
  String? _passwordError;
  String? _nameError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _formatAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-not-found':
          return 'No account exists with this email. Please check your email or create an account.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'No account found with these credentials, or incorrect password. Please check your email or register.';
        case 'email-already-in-use':
          return 'An account already exists with this email. Please sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    setState(() {
      _emailError = null;
      _passwordError = null;
      _nameError = null;
    });

    bool hasError = false;

    if (!_isLogin && name.isEmpty) {
      setState(() => _nameError = 'Please enter your full name.');
      hasError = true;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter your password.');
      hasError = true;
    } else if (password.length < 6) {
      setState(
        () => _passwordError = 'Password must be at least 6 characters long.',
      );
      hasError = true;
    }

    if (hasError) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_isLogin) {
        final user = await auth.login(
          email,
          password,
          expectedRole: _selectedRole,
        );

        if (!mounted) return;

        if (user.role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        } else {
          final queue = Provider.of<QueueProvider>(context, listen: false);
          final active = await queue.findActivePatientToken(user.uid);
          if (!mounted) return;
          if (active != null && active['departmentId'] != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LiveStatusScreen(
                  departmentId: active['departmentId'].toString(),
                ),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SelectDepartmentScreen()),
            );
          }
        }
      } else {
        await auth.register(email, password, name);

        if (!mounted) return;

        for (int i = 0; i < 25; i++) {
          if (auth.currentUser != null) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (auth.currentUser == null) {
          await auth.refreshProfile();
        }

        if (!mounted) return;

        if (auth.currentUser != null) {
          if (auth.currentUser!.role == 'admin') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            );
          } else {
            final queue = Provider.of<QueueProvider>(context, listen: false);
            final active = await queue.findActivePatientToken(
              auth.currentUser!.uid,
            );
            if (!mounted) return;
            if (active != null && active['departmentId'] != null) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LiveStatusScreen(
                    departmentId: active['departmentId'].toString(),
                  ),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const SelectDepartmentScreen(),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _formatAuthError(e);
      if (errorMsg.toLowerCase().contains('email')) {
        setState(() => _emailError = errorMsg);
      } else if (errorMsg.toLowerCase().contains('password')) {
        setState(() => _passwordError = errorMsg);
      } else {
        _showErrorSnackBar(errorMsg);
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final delEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final delPasswordController = TextEditingController();
    String? delError;
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Delete Account & Reuse Email',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the email and password of the account you want to permanently delete from Firebase Auth and MongoDB:',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: delEmailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: delPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: delError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      final email = delEmailController.text.trim();
                      final password = delPasswordController.text.trim();
                      if (email.isEmpty || password.isEmpty) {
                        setDialogState(
                          () => delError = 'Please fill in both fields.',
                        );
                        return;
                      }

                      setDialogState(() {
                        isDeleting = true;
                        delError = null;
                      });

                      final auth = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await auth.deleteAccount(email, password);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Account deleted successfully! You can now reuse this email.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (err) {
                        setDialogState(() {
                          isDeleting = false;
                          delError = _formatAuthError(err);
                        });
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 36.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QueueLess',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin
                        ? 'Sign in to your clinic pass'
                        : 'Create your patient account',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Check live department wait times or manage patient dispatch.'
                        : 'Create a patient account to join and track queues.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Segmented Mode Switcher
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildModeTab(
                            title: 'Sign in',
                            selected: _isLogin,
                            onTap: () => setState(() {
                              _isLogin = true;
                              _emailError = null;
                              _passwordError = null;
                              _nameError = null;
                            }),
                          ),
                        ),
                        Expanded(
                          child: _buildModeTab(
                            title: 'Create account',
                            selected: !_isLogin,
                            onTap: () => setState(() {
                              _isLogin = false;
                              _selectedRole = 'patient';
                              _emailError = null;
                              _passwordError = null;
                              _nameError = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLogin) ...[
                          _buildFieldLabel('Account role'),
                          Row(
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  'patient',
                                  'Patient',
                                  'Book & track token',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildRoleCard(
                                  'admin',
                                  'Clinic Staff',
                                  'Call & manage queue',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Admin accounts must be provisioned by an authorized operator. Contact your administrator for access.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        if (!_isLogin) ...[
                          _buildFieldLabel('Full name'),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Aarav Sharma',
                              errorText: _nameError,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        _buildFieldLabel('Email address'),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'name@example.com',
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildFieldLabel('Password'),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'At least 6 characters',
                            errorText: _passwordError,
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: auth.isLoading ? null : _submit,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_isLogin ? 'Sign in' : 'Create account'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _emailError = null;
                          _passwordError = null;
                          _nameError = null;
                          if (!_isLogin) _selectedRole = 'patient';
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'First visit? Create a patient account →'
                            : 'Already registered? Sign in to your account →',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showDeleteAccountDialog(context),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 15,
                        color: AppTheme.textSecondary,
                      ),
                      label: const Text(
                        'Want to reuse an email? Delete existing account',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: selected
              ? Border.all(color: AppTheme.borderColor)
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13.5,
            color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, String title, String subtitle) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : AppTheme.backgroundColor,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                      width: isSelected ? 4.5 : 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
