import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final ApiService _api = ApiService();
  final SocketService _socketService = SocketService();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthProvider() {
    try {
      _auth.authStateChanges().listen((User? user) async {
        _isLoading = true;
        notifyListeners();

        if (user != null) {
          await _fetchUserData(user.uid);
          await _socketService.connect();
        } else {
          _currentUser = null;
          _socketService.disconnect();
        }

        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Firebase Auth not initialized: $e");
      _isLoading = false;
    }
  }

  /// Fetches the user profile from MongoDB via GET /api/users/me
  Future<void> _fetchUserData(String uid) async {
    try {
      final res = await _api.get('/api/users/me');
      if (res is Map && res['user'] != null) {
        _currentUser = AppUser.fromJson(
          Map<String, dynamic>.from(res['user']),
          defaultUid: uid,
        );
      } else {
        _fallbackUser(uid);
      }
    } catch (e) {
      debugPrint("⚠️ [AuthProvider] Error fetching MongoDB user data: $e");
      _fallbackUser(uid);
    }
  }

  void _fallbackUser(String uid) {
    if (_auth.currentUser != null) {
      _currentUser = AppUser(
        uid: uid,
        role: 'patient',
        name: _auth.currentUser!.displayName ?? 'Patient',
        email: _auth.currentUser!.email ?? '',
      );
    }
  }

  /// Registers user in Firebase Auth and synchronizes MongoDB user profile
  /// Note: Public registration creates a patient; role elevation is enforced by backend
  Future<void> register(String email, String password, String name, String role) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Sync profile to MongoDB backend
        try {
          final res = await _api.post('/api/users/me', {
            'name': name,
            'email': email,
            'role': role, // Backend validates and enforces role safety
          });

          if (res is Map && res['user'] != null) {
            _currentUser = AppUser.fromJson(
              Map<String, dynamic>.from(res['user']),
              defaultUid: cred.user!.uid,
            );
          }
        } catch (apiErr) {
          debugPrint("⚠️ [AuthProvider] MongoDB profile creation warning: $apiErr");
          _fallbackUser(cred.user!.uid);
        }

        await _socketService.connect();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs in user via Firebase Auth and retrieves profile from MongoDB
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        await _fetchUserData(cred.user!.uid);
        await _socketService.connect();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs out user, disconnects Socket.IO, and clears state
  Future<void> logout() async {
    _socketService.disconnect();
    _currentUser = null;
    await _auth.signOut();
    notifyListeners();
  }
}
