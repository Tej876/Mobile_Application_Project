import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/api_service.dart';
import '../services/profile_sync.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final ApiService _api = ApiService();
  final SocketService _socketService = SocketService();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  bool _isAuthOperationInProgress = false;

  AuthProvider() {
    try {
      _auth.authStateChanges().listen((User? user) async {
        if (_isAuthOperationInProgress) return;
        _isLoading = true;
        notifyListeners();

        if (user != null) {
          _currentUser = null;
          try {
            await _fetchUserData(user.uid);
            await _socketService.connect();
          } catch (e) {
            debugPrint(
              "⚠️ [AuthProvider] Could not load MongoDB user profile: $e",
            );
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
      _setUserFromResponse(res, uid);
    } catch (e) {
      _currentUser = null;
      debugPrint("⚠️ [AuthProvider] Error fetching MongoDB user data: $e");
      rethrow;
    }
  }

  void _setUserFromResponse(dynamic response, String uid) {
    if (response is Map && response['user'] is Map) {
      _currentUser = AppUser.fromJson(
        Map<String, dynamic>.from(response['user']),
        defaultUid: uid,
      );
      return;
    }

    _currentUser = null;
    final message = response is Map && response['message'] != null
        ? response['message'].toString()
        : 'The backend did not return a user profile.';
    throw Exception(message);
  }

  /// Registers a Firebase account and synchronizes its MongoDB profile.
  Future<void> register(String email, String password, String name) async {
    try {
      _isLoading = true;
      _isAuthOperationInProgress = true;
      notifyListeners();

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        final payload = <String, dynamic>{'name': name};

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
      _isAuthOperationInProgress = false;
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
      _isAuthOperationInProgress = true;
      _currentUser = null;
      notifyListeners();

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        final user = cred.user!;
        final profileResponse = await fetchProfileWithPatientRecovery(
          fetchProfile: () => _api.get('/api/users/me'),
          recoverPatientProfile: () => _api.post('/api/users/me/recover', {
            'name': user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (user.email?.split('@').first ?? 'Patient'),
          }),
          allowPatientRecovery: expectedRole == 'patient',
        );
        _setUserFromResponse(profileResponse, user.uid);

        if (_currentUser == null) {
          throw Exception('The backend did not return a user profile.');
        }

        final actualRole = _currentUser!.role;
        if (expectedRole == 'admin' && actualRole != 'admin') {
          await _auth.signOut();
          _currentUser = null;
          _socketService.disconnect();
          throw Exception(
            'This account is registered as a Patient. Please select "Patient" to sign in.',
          );
        } else if (expectedRole == 'patient' && actualRole == 'admin') {
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
      _isAuthOperationInProgress = false;
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
