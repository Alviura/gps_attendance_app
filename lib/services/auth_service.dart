import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_models.dart';
import 'backend_status.dart';

String? normalizeLecturerRegistrationNumber(String raw) {
  final n = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (n.length < 4 || n.length > 24) return null;
  if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(n)) return null;
  return n;
}

class AuthService extends ChangeNotifier {
  AuthService(this._backendStatus) {
    if (_backendStatus.isFirebase) {
      _authSubscription = FirebaseAuth.instance
          .authStateChanges()
          .listen(_onAuthStateChanged);
    } else {
      _isLoading = false;
    }
  }

  final BackendStatus _backendStatus;
  StreamSubscription<User?>? _authSubscription;

  AppUser? _currentUser;
  bool _isLoading = true;
  String? _profileSyncWarning;

  AppUser? get currentUser => _currentUser;
  AppStudent? get currentStudent =>
      _currentUser?.isStudent == true ? _currentUser!.asStudent : null;
  bool get isLoading => _isLoading;
  bool get isDemo => _backendStatus.isDemo;
  String? get profileSyncWarning => _profileSyncWarning;

  void dismissProfileSyncWarning() {
    _profileSyncWarning = null;
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (doc.exists) {
        _currentUser = AppUser.fromFirestore(doc.id, doc.data()!);
        _profileSyncWarning = null;
      } else {
        _currentUser = null;
      }
    } catch (e) {
      _profileSyncWarning = 'Could not load profile: $e';
      _currentUser = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (_backendStatus.isDemo) {
      final normalized = email.trim().toLowerCase();
      if (normalized == 'admin@example.edu') {
        _currentUser = const AppUser(
          id: 'demo_admin',
          name: 'Demo Admin',
          email: 'admin@example.edu',
          role: UserRole.admin,
        );
      } else {
        _currentUser = AppUser(
          id: 'demo_student',
          name: 'Demo Student',
          email: email,
          role: UserRole.student,
        );
      }
      notifyListeners();
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // _onAuthStateChanged handles the rest
    } on FirebaseAuthException catch (e) {
      throw AttendanceException(_friendlyAuthMessage(e));
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? matricNumber,
    String? lecturerRegNo,
  }) async {
    if (role == UserRole.admin) {
      throw const AttendanceException('Admin accounts cannot self-register.');
    }
    if (role == UserRole.lecturer &&
        normalizeLecturerRegistrationNumber(lecturerRegNo ?? '') == null) {
      throw const AttendanceException('Invalid lecturer registration number.');
    }
    if (_backendStatus.isDemo) {
      _currentUser = AppUser(
        id: 'demo_${email.hashCode}',
        name: name,
        email: email,
        role: role,
        matricNumber: matricNumber,
        lecturerRegNo: lecturerRegNo,
        lecturerStatus:
            role == UserRole.lecturer ? LecturerApprovalStatus.active : null,
      );
      notifyListeners();
      return;
    }

    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AttendanceException(_friendlyAuthMessage(e));
    }

    final uid = cred.user!.uid;

    try {
      if (role == UserRole.student) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'role': 'student',
          'matricNumber': matricNumber,
          'enrolledClassIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Lecturer: batch write to atomically claim the reg number and
        // create the user doc. New lecturers start as 'pending' and must
        // be approved by an admin before accessing the app.
        // We use a batch (not a transaction) because the
        // lecturer_registrations collection blocks reads from clients.
        // Uniqueness is enforced by the !exists() Firestore rule on
        // lecturer_registrations, and the existsAfter() rule on users
        // verifies both writes are in the same batch.
        final normalizedRegNo =
            normalizeLecturerRegistrationNumber(lecturerRegNo!)!;
        final claimRef = FirebaseFirestore.instance
            .collection('lecturer_registrations')
            .doc(normalizedRegNo);
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(uid);

        final batch = FirebaseFirestore.instance.batch();
        batch.set(claimRef, {
          'uid': uid,
          'lecturerRegNo': normalizedRegNo,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(userRef, {
          'name': name.trim(),
          'email': email.trim(),
          'role': 'lecturer',
          'lecturerStatus': 'pending',
          'lecturerRegNo': normalizedRegNo,
          'matricNumber': null,
          'enrolledClassIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      }
    } on AttendanceException {
      await cred.user?.delete();
      rethrow;
    } catch (e) {
      await cred.user?.delete();
      throw AttendanceException('Registration failed: $e');
    }
    // _onAuthStateChanged will fire and load the Firestore user doc
  }

  /// Updates the user's editable profile fields (name for all; matricNumber
  /// for students). Reloads the cached profile after a successful write.
  Future<void> updateProfile({
    required String name,
    String? matricNumber,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const AttendanceException('Name cannot be empty.');

    if (_backendStatus.isDemo) {
      _currentUser = AppUser(
        id: _currentUser!.id,
        name: trimmed,
        email: _currentUser!.email,
        role: _currentUser!.role,
        matricNumber: matricNumber?.trim().isEmpty == true
            ? null
            : matricNumber?.trim() ?? _currentUser!.matricNumber,
        lecturerRegNo: _currentUser!.lecturerRegNo,
        lecturerStatus: _currentUser!.lecturerStatus,
        enrolledClassIds: _currentUser!.enrolledClassIds,
      );
      notifyListeners();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AttendanceException('Not signed in.');

    final updates = <String, dynamic>{'name': trimmed};
    if (_currentUser?.isStudent == true) {
      final m = matricNumber?.trim();
      updates['matricNumber'] = (m == null || m.isEmpty) ? null : m;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);
      await reloadProfile();
    } catch (e) {
      throw AttendanceException('Could not save profile: $e');
    }
  }

  /// Sends a password-reset email to the currently signed-in user's address.
  Future<void> sendPasswordResetEmail() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) throw const AttendanceException('No email on file.');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AttendanceException(_friendlyAuthMessage(e));
    }
  }

  Future<void> signOut() async {
    if (_backendStatus.isFirebase) {
      await FirebaseAuth.instance.signOut();
    } else {
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    if (_backendStatus.isDemo || _currentUser == null) return;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (doc.exists) {
        _currentUser = AppUser.fromFirestore(doc.id, doc.data()!);
        _profileSyncWarning = null;
      }
    } catch (e) {
      _profileSyncWarning = 'Could not refresh profile: $e';
    }
    notifyListeners();
  }

  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
