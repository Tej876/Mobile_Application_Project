import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import 'live_status_screen.dart';
import '../auth_screen.dart';

class SelectDepartmentScreen extends StatefulWidget {
  const SelectDepartmentScreen({super.key});

  @override
  State<SelectDepartmentScreen> createState() => _SelectDepartmentScreenState();
}

class _SelectDepartmentScreenState extends State<SelectDepartmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QueueProvider>(context, listen: false).fetchDepartments();
    });
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
            onPressed: () {
              Provider.of<QueueProvider>(context, listen: false).fetchDepartments();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
              }
            },
          ),
        ],
      ),
      body: queue.isLoading && queue.departments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : queue.departments.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No departments found.\n\nPlease make sure you created the "departments" collection in Firestore.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: queue.departments.length,
                  itemBuilder: (context, index) {
                    final dept = queue.departments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Icon(Icons.medical_services_outlined, color: Theme.of(context).primaryColor),
                        title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Est. wait: ~${dept.avgConsultationMins} mins / patient'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (auth.currentUser == null) return;
                          await queue.joinQueue(dept.id, auth.currentUser!.uid, auth.currentUser!.name);
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => LiveStatusScreen(departmentId: dept.id)));
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
