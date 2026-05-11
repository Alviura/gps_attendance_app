import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attendance_models.dart';

abstract class AttendanceRepository {
  Future<ClassSession?> loadActiveSession(String studentId);
  Future<AttendanceSubmission> submitAttendance({
    required AppStudent student,
    required ClassSession session,
    required double latitude,
    required double longitude,
  });
  Future<AttendanceReport> loadLatestReport(String studentId);
}

class FirebaseAttendanceRepository implements AttendanceRepository {
  static final _db = FirebaseFirestore.instance;

  @override
  Future<ClassSession?> loadActiveSession(String studentId) async {
    final snap = await _db
        .collection('sessions')
        .where('status', isEqualTo: 'active')
        .where('enrolledStudentIds', arrayContains: studentId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final sessionDoc = snap.docs.first;
    final sessionData = sessionDoc.data();
    final classId = sessionData['classId'] as String;

    final classSnap = await _db.collection('classes').doc(classId).get();
    if (!classSnap.exists) return null;
    final classData = classSnap.data()!;

    return ClassSession(
      id: sessionDoc.id,
      classId: classId,
      classTitle: sessionData['title'] as String? ?? 'Class Session',
      roomName: classData['roomName'] as String? ?? 'Classroom',
      lecturerName: classData['lecturerName'] as String? ?? 'Lecturer',
      startsAt: (sessionData['startsAt'] as Timestamp).toDate(),
      endsAt: (sessionData['endsAt'] as Timestamp).toDate(),
      latitude: (classData['latitude'] as num).toDouble(),
      longitude: (classData['longitude'] as num).toDouble(),
      radiusMeters: (classData['radiusMeters'] as num?)?.toDouble() ?? 50,
    );
  }

  @override
  Future<AttendanceSubmission> submitAttendance({
    required AppStudent student,
    required ClassSession session,
    required double latitude,
    required double longitude,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AttendanceException('Not signed in.');

    // Client-side geofence check (mirrors server-side logic)
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      session.latitude,
      session.longitude,
    );

    if (distance > session.radiusMeters) {
      return AttendanceSubmission(
        accepted: false,
        distanceMeters: distance,
        message:
            'You are ${distance.toStringAsFixed(1)} m away — outside the '
            '${session.radiusMeters.toStringAsFixed(0)} m classroom radius.',
      );
    }

    // Deterministic document ID prevents duplicate submissions
    final attendanceId = '${session.id}_$uid';

    final existing =
        await _db.collection('attendance').doc(attendanceId).get();
    if (existing.exists) {
      return AttendanceSubmission(
        accepted: true,
        distanceMeters: distance,
        message: 'Attendance already recorded for this session.',
      );
    }

    // Write attendance + update report atomically
    await _db.runTransaction((tx) async {
      final sessionSnap =
          await tx.get(_db.collection('sessions').doc(session.id));
      if (!sessionSnap.exists ||
          sessionSnap.data()?['status'] != 'active') {
        throw const AttendanceException('Session is no longer active.');
      }

      final reportRef = _db.collection('reports').doc(session.id);
      final reportSnap = await tx.get(reportRef);

      final attendanceRef = _db.collection('attendance').doc(attendanceId);

      tx.set(attendanceRef, {
        'sessionId': session.id,
        'classId': session.classId,
        'studentId': uid,
        'studentName': student.name,
        'latitude': latitude,
        'longitude': longitude,
        'distanceMeters': distance,
        'verificationMethod': 'biometric',
        'markedAt': FieldValue.serverTimestamp(),
      });

      if (reportSnap.exists) {
        tx.update(reportRef, {
          'presentCount': FieldValue.increment(1),
          'generatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final enrolled = List<String>.from(
          sessionSnap.data()?['enrolledStudentIds'] as List? ?? [],
        );
        tx.set(reportRef, {
          'sessionId': session.id,
          'sessionTitle': session.classTitle,
          'classId': session.classId,
          'totalStudents': enrolled.length,
          'presentCount': 1,
          'absentCount': (enrolled.length - 1).clamp(0, enrolled.length),
          'generatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return AttendanceSubmission(
      accepted: true,
      distanceMeters: distance,
      message:
          'Attendance accepted. You are ${distance.toStringAsFixed(1)} m '
          'from ${session.roomName}.',
    );
  }

  @override
  Future<AttendanceReport> loadLatestReport(String studentId) async {
    final userDoc = await _db.collection('users').doc(studentId).get();
    final enrolledClassIds = List<String>.from(
      userDoc.data()?['enrolledClassIds'] as List? ?? [],
    );
    if (enrolledClassIds.isEmpty) return AttendanceReport.empty();

    final batch = enrolledClassIds.take(10).toList();
    final reportSnap =
        await _db.collection('reports').where('classId', whereIn: batch).get();

    if (reportSnap.docs.isEmpty) return AttendanceReport.empty();

    // Sort client-side by generatedAt to get the most recent report
    final sorted = reportSnap.docs.toList()
      ..sort((a, b) {
        final aMs =
            (a.data()['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
            0;
        final bMs =
            (b.data()['generatedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
            0;
        return bMs.compareTo(aMs);
      });

    final data = sorted.first.data();
    return AttendanceReport(
      sessionTitle: data['sessionTitle'] as String? ?? 'Latest session',
      totalStudents: data['totalStudents'] as int? ?? 0,
      presentCount: data['presentCount'] as int? ?? 0,
      absentCount: data['absentCount'] as int? ?? 0,
      generatedAt:
          (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DemoAttendanceRepository implements AttendanceRepository {
  AttendanceSubmission? _latestSubmission;

  final ClassSession _demoSession = ClassSession(
    id: 'session_demo_001',
    classId: 'mobile_computing',
    classTitle: 'Mobile Computing',
    roomName: 'Computer Lab A',
    lecturerName: 'Project Supervisor',
    startsAt: DateTime.now().subtract(const Duration(minutes: 20)),
    endsAt: DateTime.now().add(const Duration(minutes: 80)),
    latitude: 6.5244,
    longitude: 3.3792,
    radiusMeters: 80,
  );

  @override
  Future<ClassSession?> loadActiveSession(String studentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _demoSession;
  }

  @override
  Future<AttendanceSubmission> submitAttendance({
    required AppStudent student,
    required ClassSession session,
    required double latitude,
    required double longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      session.latitude,
      session.longitude,
    );
    final accepted = distance <= session.radiusMeters;
    final submission = AttendanceSubmission(
      accepted: accepted,
      distanceMeters: distance,
      message: accepted
          ? 'Attendance accepted. You are ${distance.toStringAsFixed(1)}m from ${session.roomName}.'
          : 'Attendance rejected. You are ${distance.toStringAsFixed(1)}m away, outside the ${session.radiusMeters.toStringAsFixed(0)}m classroom radius.',
    );
    _latestSubmission = submission;
    return submission;
  }

  @override
  Future<AttendanceReport> loadLatestReport(String studentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final present = _latestSubmission?.accepted == true ? 28 : 27;
    return AttendanceReport(
      sessionTitle: _demoSession.classTitle,
      totalStudents: 32,
      presentCount: present,
      absentCount: 32 - present,
      generatedAt: DateTime.now(),
    );
  }
}
