import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

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
        } else {
          _currentUser = null;
        }
        
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Firebase not initialized: $e");
      _isLoading = false;
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> register(String email, String password, String name, String role) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (cred.user != null) {
        AppUser newUser = AppUser(
          uid: cred.user!.uid,
          role: role,
          name: name,
          email: email,
        );
        
        await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
        _currentUser = newUser;
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
