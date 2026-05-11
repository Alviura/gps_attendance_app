import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendance_models.dart';

/// Live Firebase backend actions for lecturers and students.
class LecturerActions {
  LecturerActions._();

  static final _db = FirebaseFirestore.instance;

  // ── Private helpers ──────────────────────────────────────────────────

  static String _uid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AttendanceException('Not signed in.');
    return uid;
  }

  static String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Class management ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createClass({
    required String title,
    required String roomName,
    required double latitude,
    required double longitude,
    double radiusMeters = 50,
  }) async {
    final uid = _uid();

    // Fetch lecturer display name
    final userSnap = await _db.collection('users').doc(uid).get();
    final lecturerName =
        userSnap.data()?['name'] as String? ?? 'Lecturer';

    // Generate a unique 6-character join code
    String joinCode = _generateJoinCode();
    for (int attempt = 0; attempt < 5; attempt++) {
      final dup = await _db
          .collection('classes')
          .where('joinCode', isEqualTo: joinCode)
          .limit(1)
          .get();
      if (dup.docs.isEmpty) break;
      joinCode = _generateJoinCode();
    }

    final ref = _db.collection('classes').doc();
    await ref.set({
      'title': title.trim(),
      'roomName': roomName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'lecturerId': uid,
      'lecturerName': lecturerName,
      'joinCode': joinCode,
      'enrolledStudentIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'classId': ref.id, 'joinCode': joinCode};
  }

  // ── Session management ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> startSession({
    required String classId,
    String? title,
    int durationMinutes = 120,
  }) async {
    final uid = _uid();

    final classDoc = await _db.collection('classes').doc(classId).get();
    if (!classDoc.exists) {
      throw const AttendanceException('Class not found.');
    }
    final classData = classDoc.data()!;
    final enrolled = List<String>.from(
      classData['enrolledStudentIds'] as List? ?? [],
    );
    final sessionTitle = (title?.trim().isNotEmpty == true)
        ? title!.trim()
        : (classData['title'] as String? ?? 'Session');

    final now = DateTime.now();
    final endsAt = now.add(Duration(minutes: durationMinutes));

    final ref = _db.collection('sessions').doc();
    await ref.set({
      'classId': classId,
      'lecturerId': uid,
      'title': sessionTitle,
      'status': 'active',
      'startsAt': Timestamp.fromDate(now),
      'endsAt': Timestamp.fromDate(endsAt),
      'enrolledStudentIds': enrolled,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'sessionId': ref.id};
  }

  static Future<void> endSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Student joins a class ────────────────────────────────────────────

  static Future<Map<String, dynamic>> joinClassByCode(String joinCode) async {
    final uid = _uid();
    final code = joinCode.trim().toUpperCase();

    final snap = await _db
        .collection('classes')
        .where('joinCode', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw const AttendanceException(
          'No class found with that join code. Please check and try again.');
    }

    final classDoc = snap.docs.first;
    final classId = classDoc.id;
    final classTitle =
        classDoc.data()['title'] as String? ?? 'Class';

    final enrolled = List<String>.from(
      classDoc.data()['enrolledStudentIds'] as List? ?? [],
    );
    if (enrolled.contains(uid)) {
      return {'classId': classId, 'title': classTitle};
    }

    final batch = _db.batch();
    batch.update(_db.collection('classes').doc(classId), {
      'enrolledStudentIds': FieldValue.arrayUnion([uid]),
    });
    batch.update(_db.collection('users').doc(uid), {
      'enrolledClassIds': FieldValue.arrayUnion([classId]),
    });
    await batch.commit();

    return {'classId': classId, 'title': classTitle};
  }

  // ── Read-only queries ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listClasses(
    String lecturerId,
  ) async {
    final snap = await _db
        .collection('classes')
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<List<Map<String, dynamic>>> listSessions(
    String lecturerId,
  ) async {
    final snap = await _db
        .collection('sessions')
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('startsAt', descending: true)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'title': data['title'],
        'status': data['status'],
        'classId': data['classId'],
        'startsAt':
            (data['startsAt'] as Timestamp?)?.toDate().toIso8601String(),
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> listReports(
    String lecturerId,
  ) async {
    final classSnap = await _db
        .collection('classes')
        .where('lecturerId', isEqualTo: lecturerId)
        .get();
    if (classSnap.docs.isEmpty) return [];

    final classIds = classSnap.docs.map((d) => d.id).take(10).toList();
    final reportSnap = await _db
        .collection('reports')
        .where('classId', whereIn: classIds)
        .get();

    final reports = reportSnap.docs.map((d) {
      final data = d.data();
      return {
        'sessionId': d.id,
        'sessionTitle': data['sessionTitle'] ?? 'Session',
        'presentCount': data['presentCount'] ?? 0,
        'totalStudents': data['totalStudents'] ?? 0,
        'generatedAt': data['generatedAt'],
      };
    }).toList()
      ..sort((a, b) {
        final aMs =
            (a['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bMs =
            (b['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

    return reports;
  }
}

/// In-memory stubs used when BACKEND_MODE=demo.
class DemoLecturerActions {
  static Future<Map<String, dynamic>> createClass({
    required String title,
    required String roomName,
    required double latitude,
    required double longitude,
    double radiusMeters = 50,
  }) async {
    return {'classId': 'demo_class', 'joinCode': 'DEMO01'};
  }

  static Future<Map<String, dynamic>> startSession({
    required String classId,
    String? title,
    int durationMinutes = 120,
  }) async {
    return {'sessionId': 'session_demo_001'};
  }

  static Future<void> endSession(String sessionId) async {}

  static Future<Map<String, dynamic>> joinClassByCode(String joinCode) async {
    if (joinCode.toUpperCase() != 'DEMO01') {
      throw const AttendanceException('Invalid join code. Try DEMO01.');
    }
    return {'classId': 'demo_class', 'title': 'Demo class'};
  }
}
