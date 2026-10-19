import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/queue_token.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'select_department_screen.dart';

class LiveStatusScreen extends StatefulWidget {
  final String departmentId;
  const LiveStatusScreen({super.key, required this.departmentId});

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  int? _lastNotifiedPosition;
  bool _hasNotifiedCalled = false;
  Stream<QueueToken?>? _tokenStream;

  @override
  void initState() {
    super.initState();
    NotificationService().init();
  }

  String _formatTokenNum(int n) => '#${n.toString().padLeft(2, '0')}';

  void _checkAndNotify(
    int position,
    String status,
    String tokenId,
    String deptName,
    DateTime? notifiedAt,
  ) {
    if (status == 'called' && !_hasNotifiedCalled) {
      _hasNotifiedCalled = true;
      NotificationService().showNotification(
        id: tokenId.hashCode + 100,
        title: 'It\'s Your Turn • QueueLess',
        body:
            'Pass ${_formatTokenNum(position)} has been called to $deptName. Please proceed to the consultation room.',
        context: context,
      );
      return;
    }

    if (status == 'waiting' &&
        position <= 3 &&
        _lastNotifiedPosition != position) {
      _lastNotifiedPosition = position;
      NotificationService().showNotification(
        id: tokenId.hashCode + position,
        title: 'Queue Update • QueueLess',
        body: position == 1
            ? 'You are #01 (next in line) for $deptName!'
            : 'Queue advanced: you are now ${_formatTokenNum(position)} in line for $deptName.',
        context: context,
      );
      if (notifiedAt == null) {
        Provider.of<QueueProvider>(context, listen: false)
            .updateNotifiedAt(widget.departmentId, tokenId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final dept = queue.departments.firstWhere(
      (d) => d.id == widget.departmentId,
      orElse: () => queue.departments.first,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SelectDepartmentScreen(),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 16,
                                color: AppTheme.textPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Directory',
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
                      const Spacer(),
                      Text(
                        'LIVE QUEUE PASS',
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: StreamBuilder<QueueToken?>(
                    stream: _tokenStream ??= queue.listenToPatientToken(
                      widget.departmentId,
                      auth.currentUser!.uid,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final token = snapshot.data;

                      if (token == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'No active queue pass found.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    } else {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SelectDepartmentScreen(),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Return to Directory'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (token.status == 'served' ||
                          token.status == 'no_show') {
                        final isServed = token.status == 'served';
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: (isServed
                                              ? AppTheme.successColor
                                              : AppTheme.errorColor)
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isServed
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      size: 36,
                                      color: isServed
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    isServed
                                        ? 'Consultation Complete'
                                        : 'Marked as No-Show',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isServed
                                        ? 'Thank you for visiting ${dept.name}.'
                                        : 'Your pass was closed by clinic staff.',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.of(context).pop();
                                        } else {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const SelectDepartmentScreen(),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text('Back to Directory'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final position = token.tokenNumber;
                      final peopleAhead = position > 0 ? position - 1 : 0;
                      final waitTime =
                          (peopleAhead * dept.avgConsultationMins) + 5;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _checkAndNotify(
                            position,
                            token.status,
                            token.id,
                            dept.name,
                            token.notifiedAt,
                          );
                        }
                      });

                      final isCalled = token.status == 'called';

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Physical / Wallet Style Clinical Pass Card
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCalled
                                      ? AppTheme.successColor
                                      : AppTheme.borderColor,
                                  width: isCalled ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top Pass Header Band
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCalled
                                          ? AppTheme.successColor
                                          : AppTheme.maroon,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isCalled
                                                    ? Colors.white
                                                    : AppTheme.peach,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'BOOKING CONFIRMED',
                                              style: AppTheme.monoStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.9,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            token.status.toUpperCase(),
                                            style: AppTheme.monoStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Department & Patient Info Section
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'DEPARTMENT',
                                                style: AppTheme.monoStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                dept.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 20,
                                                  color: AppTheme.textPrimary,
                                                  letterSpacing: -0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'PATIENT',
                                              style: AppTheme.monoStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              token.patientName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Perforated Ticket Divider
                                  _buildPerforatedDivider(),

                                  // Hero Token Number Section
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 28,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'ASSIGNED QUEUE POSITION',
                                          style: AppTheme.monoStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _formatTokenNum(token.tokenNumber),
                                          style: AppTheme.monoStyle(
                                            fontSize: 68,
                                            fontWeight: FontWeight.w800,
                                            color: isCalled
                                                ? AppTheme.successColor
                                                : AppTheme.primaryColor,
                                            letterSpacing: -2.0,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCalled
                                                ? AppTheme.successColor
                                                    .withValues(alpha: 0.12)
                                                : AppTheme.surfaceMuted,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isCalled
                                                ? 'CALLED • PROCEED TO CONSULTATION ROOM'
                                                : (token.tokenNumber > 1
                                                    ? '${token.tokenNumber - 1} PATIENT${token.tokenNumber - 1 == 1 ? '' : 'S'} AHEAD OF YOU'
                                                    : 'YOU ARE #01 • NEXT IN LINE'),
                                            style: AppTheme.monoStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: isCalled
                                                  ? AppTheme.successColor
                                                  : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Divider(height: 1),

                                  // 2-Column Architectural Metrics Footer
                                  IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                              horizontal: 16,
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'FRONT OF LINE',
                                                  style: AppTheme.monoStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  isCalled
                                                      ? _formatTokenNum(
                                                          token.tokenNumber,
                                                        )
                                                      : '#01',
                                                  style: AppTheme.monoStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const VerticalDivider(
                                          width: 1,
                                          thickness: 1,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                              horizontal: 16,
                                            ),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'ESTIMATED WAIT',
                                                  style: AppTheme.monoStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  isCalled
                                                      ? 'NOW'
                                                      : (token.tokenNumber > 1
                                                          ? '~$waitTime MIN'
                                                          : '~5 MIN'),
                                                  style: AppTheme.monoStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                    color: isCalled
                                                        ? AppTheme.successColor
                                                        : AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            if (token.status == 'called')
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.successColor
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.meeting_room_outlined,
                                      color: AppTheme.successColor,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'The doctor is ready for you. Please head directly to the consultation room.',
                                        style: TextStyle(
                                          color: AppTheme.successColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (token.status == 'waiting')
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final shouldCancel = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppTheme.surfaceColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: const BorderSide(
                                          color: AppTheme.borderColor,
                                        ),
                                      ),
                                      title: const Text(
                                        'Cancel Queue Pass?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      content: const Text(
                                        'This will remove your token from the live queue and move waiting patients up.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Keep Pass'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.errorColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Cancel Pass'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldCancel == true && context.mounted) {
                                    await queue.cancelToken(
                                      widget.departmentId,
                                      token.id,
                                      token.tokenNumber,
                                      token.patientName,
                                    );
                                    if (context.mounted) {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      } else {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SelectDepartmentScreen(),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Cancel Queue Pass'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  side: BorderSide(
                                    color: AppTheme.errorColor
                                        .withValues(alpha: 0.4),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerforatedDivider() {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dashCount = (constraints.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (_) {
                    return Container(
                      width: 5,
                      height: 1.2,
                      color: AppTheme.borderColor,
                    );
                  }),
                );
              },
            ),
          ),
          Container(
            width: 12,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

