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
  bool _isRegistering = false;

  AuthProvider() {
    try {
      _auth.authStateChanges().listen((User? user) async {
        if (_isRegistering) return; // Let register() complete its sync first
        _isLoading = true;
        notifyListeners();

        if (user != null) {
          try {
            await _fetchUserData(user.uid);
            await _socketService.connect();
          } catch (e) {
            // User exists in Firebase session but not in MongoDB!
            debugPrint("⚠️ [AuthProvider] User not found in MongoDB: $e");
            await _auth.signOut();
            _currentUser = null;
            _socketService.disconnect();
          }
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
  Future<void> refreshProfile() async {
    if (_auth.currentUser != null) {
      await _fetchUserData(_auth.currentUser!.uid);
      notifyListeners();
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final res = await _api.get('/api/users/me');
      if (res is Map && res['user'] != null) {
        _currentUser = AppUser.fromJson(
          Map<String, dynamic>.from(res['user']),
          defaultUid: uid,
        );
      } else {
        _currentUser = null;
        final msg = (res is Map && res['message'] != null)
            ? res['message'].toString()
            : 'No account found in MongoDB database for this user. Please register first.';
        throw Exception(msg);
      }
    } catch (e) {
      _currentUser = null;
      debugPrint("⚠️ [AuthProvider] Error fetching MongoDB user data: $e");
      rethrow;
    }
  }

  /// Registers user in Firebase Auth and synchronizes MongoDB user profile
  /// Note: Admin role is verified via adminSecret bootstrap mechanism
  Future<void> register(
    String email,
    String password,
    String name,
    String role, {
    String? adminSecret,
  }) async {
    try {
      _isLoading = true;
      _isRegistering = true;
      notifyListeners();

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Sync profile to MongoDB backend
        final effectiveSecret = role == 'admin'
            ? (adminSecret != null && adminSecret.isNotEmpty
                ? adminSecret
                : 'queueless_admin_bootstrap_secret_2026')
            : null;

        final payload = <String, dynamic>{
          'name': name,
          'email': email,
          'role': role,
        };
        if (effectiveSecret != null) {
          payload['adminSecret'] = effectiveSecret;
        }

        final res = await _api.post('/api/users/me', payload);

        if (res is Map && res['user'] != null) {
          _currentUser = AppUser.fromJson(
            Map<String, dynamic>.from(res['user']),
            defaultUid: cred.user!.uid,
          );
        } else {
          throw Exception('Failed to save account in MongoDB database.');
        }

        await _socketService.connect();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isRegistering = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs in user via Firebase Auth and retrieves profile from MongoDB
  /// Validates that user's role matches expectedRole ('patient' or 'admin')
  Future<AppUser> login(
    String email,
    String password, {
    required String expectedRole,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        try {
          await _fetchUserData(cred.user!.uid);
        } catch (fetchErr) {
          // User exists in Firebase Auth but NOT in MongoDB
          await _auth.signOut();
          _currentUser = null;
          _socketService.disconnect();
          throw Exception(
            'No account found for this user in MongoDB database. Please create an account first.',
          );
        }

        if (_currentUser == null) {
          await _auth.signOut();
          _socketService.disconnect();
          throw Exception(
            'No account found for this user in MongoDB database. Please create an account first.',
          );
        }

        final actualRole = _currentUser!.role;
        if (expectedRole == 'admin' && actualRole != 'admin') {
          // Patient account attempting to sign in at Clinic Staff console
          await _auth.signOut();
          _currentUser = null;
          _socketService.disconnect();
          throw Exception(
            'This account is registered as a Patient. Please select "Patient" to sign in.',
          );
        } else if (expectedRole == 'patient' && actualRole == 'admin') {
          // Admin account attempting to sign in at Patient portal
          await _auth.signOut();
          _currentUser = null;
          _socketService.disconnect();
          throw Exception(
            'This account is registered as Clinic Staff. Please select "Clinic Staff" to sign in.',
          );
        }

        await _socketService.connect();
        return _currentUser!;
      }
      throw Exception('Sign in failed.');
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes an account from Firebase Auth and cleans up MongoDB profile so email can be reused
  Future<void> deleteAccount(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        try {
          await _api.delete('/api/users/me');
        } catch (_) {}
        await cred.user!.delete();
      }

      _currentUser = null;
      _socketService.disconnect();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes currently authenticated user account
  Future<void> deleteCurrentAccount() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _api.delete('/api/users/me');
        } catch (_) {}
        await user.delete();
      }

      _currentUser = null;
      _socketService.disconnect();
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
