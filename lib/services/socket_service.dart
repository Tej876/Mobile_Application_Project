import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'api_config.dart';
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _currentDepartmentId;

  // StreamControllers for live events
  final _queueUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _tokenCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _tokenCalledController = StreamController<Map<String, dynamic>>.broadcast();
  final _tokenCancelledController = StreamController<Map<String, dynamic>>.broadcast();
  final _tokenCompletedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onQueueUpdated => _queueUpdatedController.stream;
  Stream<Map<String, dynamic>> get onTokenCreated => _tokenCreatedController.stream;
  Stream<Map<String, dynamic>> get onTokenCalled => _tokenCalledController.stream;
  Stream<Map<String, dynamic>> get onTokenCancelled => _tokenCancelledController.stream;
  Stream<Map<String, dynamic>> get onTokenCompleted => _tokenCompletedController.stream;

  /// Connects or re-connects the socket with the current authenticated Firebase ID token
  Future<void> connect() async {
    if (_socket != null && _isConnected) return;

    final token = await ApiService().getIdToken();

    _socket?.dispose();

    _socket = socket_io.io(
      ApiConfig.socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': token ?? ''})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('🔌 [SocketService] Connected to backend at ${ApiConfig.socketUrl}');
      if (_currentDepartmentId != null) {
        joinDepartment(_currentDepartmentId!);
      }
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('🔌 [SocketService] Disconnected ($reason)');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint('⚠️ [SocketService] Connection error: $err');
    });

    _socket!.on('queue:updated', (data) {
      if (data is Map) {
        _queueUpdatedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('token:created', (data) {
      if (data is Map) {
        _tokenCreatedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('token:called', (data) {
      if (data is Map) {
        _tokenCalledController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('token:cancelled', (data) {
      if (data is Map) {
        _tokenCancelledController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('token:completed', (data) {
      if (data is Map) {
        _tokenCompletedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  /// Subscribe to live updates for a specific department room
  void joinDepartment(String departmentId) {
    _currentDepartmentId = departmentId;
    if (_socket != null && _isConnected) {
      _socket!.emit('join:department', departmentId);
      debugPrint('📌 [SocketService] Joined department room: $departmentId');
    }
  }

  /// Leave department room
  void leaveDepartment(String departmentId) {
    if (_currentDepartmentId == departmentId) {
      _currentDepartmentId = null;
    }
    if (_socket != null && _isConnected) {
      _socket!.emit('leave:department', departmentId);
      debugPrint('📌 [SocketService] Left department room: $departmentId');
    }
  }

  /// Disconnect cleanly upon user logout
  void disconnect() {
    _currentDepartmentId = null;
    _isConnected = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    debugPrint('🔌 [SocketService] Disconnected and disposed');
  }
}
