import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/queue_token.dart';
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

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).primaryColor,
        actions: [
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
      body: _selectedDepartmentId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDepartmentId,
                    decoration: const InputDecoration(
                      labelText: 'Select Department',
                    ),
                    items: queue.departments.map((d) {
                      return DropdownMenuItem(value: d.id, child: Text(d.name));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDepartmentId = val;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _currentIndex == 0
                      ? _buildQueueView(queue)
                      : _buildActivityLogView(queue),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Active Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Activity Log',
          ),
        ],
      ),
    );
  }

  Widget _buildQueueView(QueueProvider queue) {
    return StreamBuilder<List<QueueToken>>(
      stream: queue.listenToAdminQueue(_selectedDepartmentId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tokens = snapshot.data ?? [];
        final hasWaiting = tokens.any((t) => t.status == 'waiting');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasWaiting)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ElevatedButton(
                  onPressed: () =>
                      queue.callNextPatient(_selectedDepartmentId!),
                  child: const Text('Call Next Patient'),
                ),
              ),
            Expanded(
              child: tokens.isEmpty
                  ? const Center(child: Text('No active patients in queue.'))
                  : ListView.builder(
                      itemCount: tokens.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final token = tokens[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: token.status == 'called'
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '#${token.tokenNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        token.patientName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Status: ${token.status.toUpperCase()}',
                                        style: TextStyle(
                                          color: token.status == 'called'
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (token.status == 'called') ...[
                                  OutlinedButton(
                                    onPressed: () => queue.markTokenDone(
                                      _selectedDepartmentId!,
                                      token,
                                      false,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(
                                        color: Colors.green,
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
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    child: const Text('No Show'),
                                  ),
                                ],
                              ],
                            ),
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
          return const Center(child: Text('No activity yet.'));
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: log.action == 'served'
                    ? Colors.green.shade100
                    : (log.action == 'cancelled'
                          ? Colors.orange.shade100
                          : Colors.red.shade100),
                child: Icon(
                  log.action == 'served'
                      ? Icons.check
                      : (log.action == 'cancelled'
                            ? Icons.cancel_outlined
                            : Icons.person_off),
                  color: log.action == 'served'
                      ? Colors.green
                      : (log.action == 'cancelled'
                            ? Colors.orange
                            : Colors.red),
                ),
              ),
              title: Text('${log.patientName} (Token #${log.tokenNumber})'),
              subtitle: Text(log.action.toUpperCase()),
              trailing: Text(
                '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
              ),
            );
          },
        );
      },
    );
  }
}
