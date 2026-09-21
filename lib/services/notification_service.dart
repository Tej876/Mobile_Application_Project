import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  Future<void> showNotification({required int id, required String title, required String body}) async {
    if (!_isInitialized) await init();
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'queueless_channel', 'Queue Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _flutterLocalNotificationsPlugin.show(
      id: id, 
      title: title, 
      body: body, 
      notificationDetails: platformChannelSpecifics,
    );
  }
}
