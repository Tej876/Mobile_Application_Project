import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/queue_token.dart';
import '../../theme/app_theme.dart';
import '../auth_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _selectedDepartmentId;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final queue = Provider.of<QueueProvider>(context, listen: false);
      await queue.fetchDepartments();
      if (queue.departments.isNotEmpty && mounted) {
        setState(() {
          _selectedDepartmentId = queue.departments.first.id;
        });
      }
    });
  }

  String _formatTokenNum(int n) => '#${n.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _selectedDepartmentId == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Staff Console Header (No eyebrow kicker per craft-floor.md)
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
                                    'Queue Dispatch',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Call patients and manage live department queues',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
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
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: AppTheme.borderColor),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      size: 16,
                                      color: AppTheme.textPrimary,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Sign Out',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Horizontal Department Filter Pills
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: queue.departments.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final d = queue.departments[index];
                            final selected = d.id == _selectedDepartmentId;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedDepartmentId = d.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    d.name,
                                    style: TextStyle(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      color: selected
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Segmented View Switcher (Active Queue vs Activity Log)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildViewTab(
                                  label: 'Active Queue',
                                  index: 0,
                                ),
                              ),
                              Expanded(
                                child: _buildViewTab(
                                  label: 'Activity Audit Log',
                                  index: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),

                      Expanded(
                        child: _currentIndex == 0
                            ? _buildQueueView(queue)
                            : _buildActivityLogView(queue),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewTab({required String label, required int index}) {
    final selected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: selected
              ? Border.all(color: AppTheme.borderColor)
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
            color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQueueView(QueueProvider queue) {
    return StreamBuilder<List<QueueToken>>(
      stream: queue.listenToAdminQueue(_selectedDepartmentId!),
      builder: (streamCtx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tokens = snapshot.data ?? [];
        final waitingCount = tokens.where((t) => t.status == 'waiting').length;
        final hasWaiting = waitingCount > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dispatch Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  bottom: BorderSide(color: AppTheme.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WAITING IN LINE',
                        style: AppTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$waitingCount patient${waitingCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: hasWaiting
                        ? () => queue.callNextPatient(_selectedDepartmentId!)
                        : null,
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: const Text('Call Next Patient (#01)'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: tokens.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'QUEUE CLEAR',
                            style: AppTheme.monoStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'No active patients waiting in this department.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: tokens.length,
                      padding: const EdgeInsets.all(20),
                      itemBuilder: (context, index) {
                        final token = tokens[index];
                        final isCalled = token.status == 'called';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCalled
                                  ? AppTheme.successColor
                                  : AppTheme.borderColor,
                              width: isCalled ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isCalled
                                      ? AppTheme.successColor
                                          .withValues(alpha: 0.12)
                                      : AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCalled
                                        ? AppTheme.successColor
                                            .withValues(alpha: 0.35)
                                        : AppTheme.borderColor,
                                  ),
                                ),
                                child: Text(
                                  _formatTokenNum(token.tokenNumber),
                                  style: AppTheme.monoStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isCalled
                                        ? AppTheme.successColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      token.patientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isCalled
                                          ? 'CALLED • IN CONSULTATION'
                                          : 'WAITING IN QUEUE',
                                      style: AppTheme.monoStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isCalled
                                            ? AppTheme.successColor
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCalled) ...[
                                OutlinedButton(
                                  onPressed: () => queue.markTokenDone(
                                    _selectedDepartmentId!,
                                    token,
                                    false,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.successColor,
                                    side: const BorderSide(
                                      color: AppTheme.successColor,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text('Done'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => queue.markTokenDone(
                                    _selectedDepartmentId!,
                                    token,
                                    true,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: BorderSide(
                                      color: AppTheme.errorColor
                                          .withValues(alpha: 0.5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text('No-Show'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityLogView(QueueProvider queue) {
    return StreamBuilder(
      stream: queue.listenToActivityLog(_selectedDepartmentId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Center(
            child: Text(
              'No completed or cancelled queue events recorded yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            final isServed = log.action == 'served';
            final isCancelled = log.action == 'cancelled';
            final badgeColor = isServed
                ? AppTheme.successColor
                : (isCancelled ? AppTheme.accentColor : AppTheme.errorColor);

            final timeStr =
                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatTokenNum(log.tokenNumber),
                      style: AppTheme.monoStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.action.toUpperCase(),
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeStr,
                    style: AppTheme.monoStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

