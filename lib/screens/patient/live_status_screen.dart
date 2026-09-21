import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import 'select_department_screen.dart';

class LiveStatusScreen extends StatefulWidget {
  final String departmentId;
  const LiveStatusScreen({super.key, required this.departmentId});

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen> {
  @override
  void initState() {
    super.initState();
    NotificationService().init();
  }

  void _checkAndNotify(int position, String tokenId, DateTime? notifiedAt) {
    if (position == 3 && notifiedAt == null) {
      NotificationService().showNotification(
        id: tokenId.hashCode,
        title: 'Get Ready!',
        body: 'You are now 3rd in line.',
      );
      Provider.of<QueueProvider>(context, listen: false).updateNotifiedAt(widget.departmentId, tokenId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = Provider.of<QueueProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Find department for wait time calculation
    final dept = queue.departments.firstWhere((d) => d.id == widget.departmentId, orElse: () => queue.departments.first);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Queue Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SelectDepartmentScreen())),
        ),
      ),
      body: StreamBuilder(
        stream: queue.listenToPatientToken(widget.departmentId, auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final token = snapshot.data;
          
          if (token == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No active token found.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SelectDepartmentScreen())),
                    child: const Text('Join a Queue'),
                  )
                ],
              ),
            );
          }

          if (token.status == 'served' || token.status == 'no_show') {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(token.status == 'served' ? Icons.check_circle : Icons.cancel, size: 64, color: token.status == 'served' ? Colors.green : Colors.red),
                  const SizedBox(height: 16),
                  Text(token.status == 'served' ? 'Consultation Complete' : 'Marked as No Show', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SelectDepartmentScreen())),
                    child: const Text('Return Home'),
                  )
                ],
              ),
            );
          }
          
          // Current position is tracked by Provider
          final position = queue.currentPatientPosition;
          final waitTime = (position * dept.avgConsultationMins) + 5;
          
          // Post-frame callback for notification to avoid build during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndNotify(position, token.id, token.notifiedAt);
          });

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: token.status == 'called' ? Colors.green.shade100 : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: token.status == 'called' ? Colors.green : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          token.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: token.status == 'called' ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  Center(
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).primaryColor, width: 8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('YOUR TOKEN', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text('#${token.tokenNumber}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                          Text(position > 0 ? '$position ahead of you' : 'You are next!', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('NOW SERVING', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(position > 0 ? '#${token.tokenNumber - position}' : '-', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('EST. WAIT', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(position > 0 ? '~$waitTime mins' : 'Now', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  if (token.status == 'waiting')
                    OutlinedButton(
                      onPressed: () async {
                        await queue.cancelToken(widget.departmentId, token.id, token.tokenNumber, token.patientName);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SelectDepartmentScreen()));
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel Token'),
                    ),
                  
                  if (token.status == 'called')
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Please proceed to the doctor\'s room.', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
