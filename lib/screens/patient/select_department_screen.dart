import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/department.dart';
import 'live_status_screen.dart';
import '../auth_screen.dart';

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

    await queue.fetchDepartments();

    if (auth.currentUser != null) {
      final active = await queue.findActivePatientToken(auth.currentUser!.uid);
      if (mounted) {
        setState(() {
          _activeTokenInfo = active;
          _isCheckingActiveToken = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingActiveToken = false;
        });
      }
    }
  }

  void _confirmAndJoin(Department dept) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final queue = Provider.of<QueueProvider>(context, listen: false);

    if (auth.currentUser == null) return;

    // Check if patient already has an active ticket
    if (_activeTokenInfo != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Active Ticket Exists'),
          content: Text(
            'You already have an active ticket (#${_activeTokenInfo!['token'].tokenNumber}) '
            'in ${_activeTokenInfo!['departmentName']}.\n\n'
            'Please complete or cancel your active consultation before joining another department queue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LiveStatusScreen(
                      departmentId: _activeTokenInfo!['departmentId'],
                    ),
                  ),
                );
              },
              child: const Text('View Active Ticket'),
            ),
          ],
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Join ${dept.name} Queue?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Department: ${dept.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Est. consultation: ~${dept.avgConsultationMins} mins / patient'),
            const SizedBox(height: 12),
            const Text(
              'Would you like to take a token and enter this queue now?',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Join'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await queue.joinQueue(
        dept.id,
        auth.currentUser!.uid,
        auth.currentUser!.name.isNotEmpty ? auth.currentUser!.name : 'Patient',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LiveStatusScreen(departmentId: dept.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Department'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: (queue.isLoading && queue.departments.isEmpty) || _isCheckingActiveToken
          ? const Center(child: CircularProgressIndicator())
          : queue.departments.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No departments found.\n\nPlease check back shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_activeTokenInfo != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.confirmation_number,
                            color: Theme.of(context).primaryColor,
                            size: 32,
                          ),
                          title: Text(
                            'Active Ticket #${_activeTokenInfo!['token'].tokenNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_activeTokenInfo!['departmentName']} - Status: ${_activeTokenInfo!['token'].status.toUpperCase()}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => LiveStatusScreen(
                                    departmentId: _activeTokenInfo!['departmentId'],
                                  ),
                                ),
                              );
                            },
                            child: const Text('View'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: queue.departments.length,
                        itemBuilder: (context, index) {
                          final dept = queue.departments[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: StreamBuilder<int>(
                              stream: queue.listenToDepartmentQueueLength(dept.id),
                              builder: (context, queueSnap) {
                                final queueCount = queueSnap.data ?? 0;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.medical_services_outlined,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    dept.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: queueCount > 0
                                                ? Colors.orange.shade50
                                                : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: queueCount > 0
                                                  ? Colors.orange.shade300
                                                  : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            queueCount > 0
                                                ? '$queueCount waiting'
                                                : 'Queue empty',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: queueCount > 0
                                                  ? Colors.orange.shade900
                                                  : Colors.green.shade900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '~${dept.avgConsultationMins}m / patient',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _confirmAndJoin(dept),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
