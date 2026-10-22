import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/department.dart';
import '../../models/queue_token.dart';
import '../../services/notification_service.dart';
import '../../services/email_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'live_status_screen.dart';
import 'booking_history_sheet.dart';
import '../auth_screen.dart';
import '../admin/dashboard_screen.dart';

class SelectDepartmentScreen extends StatefulWidget {
  const SelectDepartmentScreen({super.key});

  @override
  State<SelectDepartmentScreen> createState() => _SelectDepartmentScreenState();
}

class _SelectDepartmentScreenState extends State<SelectDepartmentScreen> {
  Map<String, dynamic>? _activeTokenInfo;
  bool _isCheckingActiveToken = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final queue = Provider.of<QueueProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      await auth.refreshProfile();
    } catch (_) {}

    if (auth.currentUser?.role == 'admin' && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }

    try {
      await queue.fetchDepartments();
    } catch (_) {}

    if (auth.currentUser != null) {
      try {
        final active = await queue.findActivePatientToken(auth.currentUser!.uid);
        if (mounted) {
          setState(() {
            _activeTokenInfo = active;
            _isCheckingActiveToken = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isCheckingActiveToken = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingActiveToken = false;
        });
      }
    }
  }

  String _formatTokenNum(int n) => '#${n.toString().padLeft(2, '0')}';

  Widget _buildReceiptRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.monoStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: highlight
                  ? AppTheme.monoStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    )
                  : const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndJoin(Department dept) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final queue = Provider.of<QueueProvider>(context, listen: false);

    if (auth.currentUser == null) return;

    if (_activeTokenInfo != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text(
            'Active Queue Pass Found',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Text(
            'You already hold an active pass (${_formatTokenNum(_activeTokenInfo!['token'].tokenNumber)}) '
            'in ${_activeTokenInfo!['departmentName']}.\n\n'
            'Please complete or cancel your current visit before booking another department.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveStatusScreen(
                      departmentId: _activeTokenInfo!['departmentId'],
                    ),
                  ),
                );
              },
              child: const Text('Open Active Pass'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Text(
          'Join ${dept.name}?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Department', dept.name),
                  const Divider(height: 12),
                  _buildReceiptRow(
                    'Avg. pace',
                    '~${dept.avgConsultationMins} min / patient',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We will issue your live token number immediately and notify you as your turn approaches.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Join'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final patientName = auth.currentUser!.name.isNotEmpty
          ? auth.currentUser!.name
          : 'Patient';
      final patientEmail = auth.currentUser!.email;

      QueueToken? newToken;
      try {
        newToken = await queue.joinQueue(
          dept.id,
          auth.currentUser!.uid,
          patientName,
        );
      } on ApiException catch (e) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            title: Row(
              children: [
                Icon(
                  e.statusCode == 409
                      ? Icons.warning_amber_rounded
                      : Icons.error_outline_rounded,
                  color: e.statusCode == 409
                      ? AppTheme.accentColor
                      : AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  e.statusCode == 409
                      ? 'Booking Conflict'
                      : 'Booking Failed',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              e.message,
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadData();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join queue: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      if (!mounted || newToken == null) return;
      final createdToken = newToken;

      // Determine effective position for fallback calculation if position is 0
      final int effectivePos = createdToken.position > 0
          ? createdToken.position
          : createdToken.tokenNumber;
      final int peopleAhead = effectivePos > 0 ? effectivePos - 1 : 0;

      // Use backend authoritative wait estimate if provided, falling back to formula
      final int estWaitMins = createdToken.estWaitMins > 0
          ? createdToken.estWaitMins
          : (peopleAhead * dept.avgConsultationMins) + 5;

      // Only claim "Next in line" when backend explicitly confirms position == 1
      final String estWait = createdToken.position == 1
          ? '~5 min (Next in line)'
          : '~$estWaitMins min';

      // Trigger booking confirmation email (Single trigger point per faculty rubric)
      if (patientEmail.isNotEmpty) {
        EmailService().sendBookingConfirmation(
          recipientEmail: patientEmail,
          patientName: patientName,
          departmentName: dept.name,
          tokenNumber: createdToken.tokenNumber,
          estWaitMins: estWaitMins,
          departmentId: dept.id,
        );
      }

      await NotificationService().showNotification(
        id: createdToken.tokenNumber,
        title: 'Booking Confirmed • QueueLess',
        body:
            'Pass ${_formatTokenNum(createdToken.tokenNumber)} issued for ${dept.name} ($estWait).',
        context: context,
      );

      if (!mounted) return;

      // Post-booking acknowledgment receipt modal (Rubric D1)
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Booking Confirmed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your booking has been registered in the live department queue.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow(
                      'Assigned token',
                      _formatTokenNum(createdToken.tokenNumber),
                      highlight: true,
                    ),
                    const Divider(height: 14),
                    _buildReceiptRow('Department', dept.name),
                    const Divider(height: 14),
                    _buildReceiptRow('Patient', patientName),
                    const Divider(height: 14),
                    _buildReceiptRow('Estimated wait', estWait),
                    if (patientEmail.isNotEmpty) ...[
                      const Divider(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            size: 15,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confirmation email sent to $patientEmail',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveStatusScreen(departmentId: dept.id),
                    ),
                  );
                },
                child: const Text('Open Live Queue Pass'),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userName = auth.currentUser?.name.isNotEmpty == true
        ? auth.currentUser!.name
        : 'Patient';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (No eyebrow kicker per craft-floor.md)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Departments',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Signed in as $userName',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (auth.currentUser?.role == 'admin') ...[
                        _buildHeaderActionButton(
                          icon: Icons.admin_panel_settings_rounded,
                          tooltip: 'Staff Console',
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildHeaderActionButton(
                        icon: Icons.history_rounded,
                        tooltip: 'Booking History',
                        onTap: () => BookingHistorySheet.show(context),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.refresh,
                        tooltip: 'Refresh Directory',
                        onTap: _loadData,
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderActionButton(
                        icon: Icons.logout,
                        tooltip: 'Sign Out',
                        onTap: () async {
                          await auth.logout();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const AuthScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: (queue.isLoading && queue.departments.isEmpty) ||
                          _isCheckingActiveToken
                      ? const Center(child: CircularProgressIndicator())
                      : queue.departments.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.apartment_outlined,
                                      size: 48,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No clinical departments available right now.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Please ensure the clinic backend server is running.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      onPressed: _loadData,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Retry Connection'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (_activeTokenInfo != null) ...[
                                  _buildActivePassBanner(),
                                  const SizedBox(height: 20),
                                ],
                                ...queue.departments.map(
                                  (dept) => _buildDepartmentRow(dept, queue),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(icon, size: 19, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _buildActivePassBanner() {
    final token = _activeTokenInfo!['token'];
    final deptName = _activeTokenInfo!['departmentName'];
    final deptId = _activeTokenInfo!['departmentId'];

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LiveStatusScreen(departmentId: deptId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _formatTokenNum(token.tokenNumber),
                style: AppTheme.monoStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deptName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active pass • ${token.status}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.peach,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.blush,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: AppTheme.charcoal,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentRow(
    Department dept,
    QueueProvider queue,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _confirmAndJoin(dept),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: StreamBuilder<int>(
            stream: queue.listenToDepartmentQueueLength(dept.id),
            builder: (context, queueSnap) {
              final queueCount = queueSnap.data ?? 0;
              final isBusy = queueCount > 0;

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dept.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '~${dept.avgConsultationMins} min avg consultation',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isBusy
                          ? AppTheme.peach
                          : AppTheme.successColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isBusy
                                ? AppTheme.maroon
                                : AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isBusy ? '$queueCount waiting' : '0 waiting',
                          style: AppTheme.monoStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isBusy
                                ? AppTheme.maroon
                                : AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

