import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/queue_token.dart';
import '../../models/department.dart';
import '../../providers/queue_provider.dart';
import '../../theme/app_theme.dart';

class BookingHistorySheet extends StatefulWidget {
  const BookingHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BookingHistorySheet(),
    );
  }

  @override
  State<BookingHistorySheet> createState() => _BookingHistorySheetState();
}

class _BookingHistorySheetState extends State<BookingHistorySheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<QueueToken> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queue = Provider.of<QueueProvider>(context, listen: false);
      final list = await queue.fetchBookingHistory();
      if (mounted) {
        setState(() {
          _tokens = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatTokenNum(int n) => '#${n.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $period';
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'served':
        bg = AppTheme.successColor.withValues(alpha: 0.12);
        fg = AppTheme.successColor;
        label = 'SERVED';
        break;
      case 'called':
        bg = AppTheme.primaryColor.withValues(alpha: 0.12);
        fg = AppTheme.primaryColor;
        label = 'CALLED';
        break;
      case 'waiting':
        bg = AppTheme.accentColor.withValues(alpha: 0.2);
        fg = AppTheme.primaryColor;
        label = 'WAITING';
        break;
      case 'cancelled':
        bg = AppTheme.textSecondary.withValues(alpha: 0.15);
        fg = AppTheme.textSecondary;
        label = 'CANCELLED';
        break;
      case 'no_show':
        bg = AppTheme.errorColor.withValues(alpha: 0.12);
        fg = AppTheme.errorColor;
        label = 'NO SHOW';
        break;
      default:
        bg = AppTheme.surfaceMuted;
        fg = AppTheme.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTheme.monoStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Booking History',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh History',
                    onPressed: _loadHistory,
                    color: AppTheme.textSecondary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 40,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Could not load booking history',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadHistory,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _tokens.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.borderColor,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 32,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No past bookings found',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Your queue tokens and consultation records will appear here.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount: _tokens.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final token = _tokens[index];
                                final deptName = token.departmentName.isNotEmpty
                                    ? token.departmentName
                                    : queue.departments
                                        .firstWhere(
                                          (d) => d.id == token.departmentId,
                                          orElse: () => Department(
                                            id: token.departmentId,
                                            name: 'Clinical Department',
                                            avgConsultationMins: 10,
                                          ),
                                        )
                                        .name;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Monospace Token Number Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.borderColor,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTokenNum(token.tokenNumber),
                                          style: AppTheme.monoStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Department & Date info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              deptName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatDate(token.joinedAt),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Status Badge
                                      _buildStatusBadge(token.status),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
