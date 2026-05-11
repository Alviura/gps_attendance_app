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
    double accuracy = 0,
  });
  Future<AttendanceReport> loadLatestReport(String studentId);
}

class FirebaseAttendanceRepository implements AttendanceRepository {
  static final _db = FirebaseFirestore.instance;

  @override
  Future<ClassSession?> loadActiveSession(String studentId) async {
    // Step 1 — get the student's enrolled class IDs.
    final userDoc = await _db.collection('users').doc(studentId).get();
    final enrolledClassIds = List<String>.from(
      userDoc.data()?['enrolledClassIds'] as List? ?? [],
    );
    if (enrolledClassIds.isEmpty) return null;

    // Step 2 — run one simple query per enrolled class (max 10 in parallel).
    // Using per-class equality queries avoids the whereIn + where combination
    // that Firestore sometimes cannot optimise without a composite index.
    final futures = enrolledClassIds.take(10).map(
      (classId) => _db
          .collection('sessions')
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(),
    );

    final results = await Future.wait(futures);
    final activeDoc = results
        .expand((snap) => snap.docs)
        .firstOrNull;

    if (activeDoc == null) return null;

    final sessionData = activeDoc.data();
    final classId = sessionData['classId'] as String;

    // Step 3 — fetch class details (GPS coords, room name, etc.).
    final classSnap = await _db.collection('classes').doc(classId).get();
    if (!classSnap.exists) return null;
    final classData = classSnap.data()!;

    // Check whether this student has already submitted attendance.
    final attendanceId = '${activeDoc.id}_$studentId';
    final attendanceSnap =
        await _db.collection('attendance').doc(attendanceId).get();

    return ClassSession(
      id: activeDoc.id,
      classId: classId,
      classTitle: sessionData['title'] as String? ?? 'Class Session',
      roomName: classData['roomName'] as String? ?? 'Classroom',
      lecturerName: classData['lecturerName'] as String? ?? 'Lecturer',
      startsAt: (sessionData['startsAt'] as Timestamp).toDate(),
      endsAt: (sessionData['endsAt'] as Timestamp).toDate(),
      latitude: (classData['latitude'] as num).toDouble(),
      longitude: (classData['longitude'] as num).toDouble(),
      radiusMeters: (classData['radiusMeters'] as num?)?.toDouble() ?? 50,
      alreadyAttended: attendanceSnap.exists,
    );
  }

  @override
  Future<AttendanceSubmission> submitAttendance({
    required AppStudent student,
    required ClassSession session,
    required double latitude,
    required double longitude,
    double accuracy = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const AttendanceException('Not signed in.');

    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      session.latitude,
      session.longitude,
    );

    // Give the student the benefit of the GPS accuracy margin.
    // Only reject if, even accounting for the device's reported error,
    // they are still definitively outside the classroom radius.
    final effectiveDistance = (distance - accuracy).clamp(0.0, double.infinity);

    if (effectiveDistance > session.radiusMeters) {
      return AttendanceSubmission(
        accepted: false,
        distanceMeters: distance,
        message: 'You are ${distance.toStringAsFixed(1)} m from the classroom '
            '(±${accuracy.toStringAsFixed(0)} m GPS accuracy) — '
            'outside the ${session.radiusMeters.toStringAsFixed(0)} m radius.',
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

    // Fetch live enrollment count from the class document so the report
    // reflects students who joined after the session was started.
    final classSnap =
        await _db.collection('classes').doc(session.classId).get();
    final enrolledIds = List<String>.from(
      classSnap.data()?['enrolledStudentIds'] as List? ?? [],
    );
    final totalStudents = enrolledIds.isEmpty ? 1 : enrolledIds.length;

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
        'classTitle': session.classTitle,
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
          'absentCount': FieldValue.increment(-1),
          'generatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(reportRef, {
          'sessionId': session.id,
          'sessionTitle': session.classTitle,
          'classId': session.classId,
          'totalStudents': totalStudents,
          'presentCount': 1,
          'absentCount': (totalStudents - 1).clamp(0, totalStudents),
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
    // Query the student's own attendance records.
    // Sorting is done client-side to avoid a composite index on
    // (studentId + markedAt) which takes time to build in Firestore.
    final snap = await _db
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .limit(50)
        .get();

    if (snap.docs.isEmpty) return AttendanceReport.empty();

    // Sort newest-first on the client — avoids a composite Firestore index.
    final sortedDocs = snap.docs.toList()
      ..sort((a, b) {
        final aMs =
            (a.data()['markedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bMs =
            (b.data()['markedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

    final entries = sortedDocs.map((doc) {
      final d = doc.data();
      return PersonalAttendanceEntry(
        classTitle: d['classTitle'] as String? ??
            d['sessionTitle'] as String? ??
            'Class Session',
        markedAt: (d['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        distanceMeters: (d['distanceMeters'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    return AttendanceReport(
      sessionTitle: 'My Attendance',
      totalStudents: entries.length,
      presentCount: entries.length,
      absentCount: 0,
      generatedAt: entries.first.markedAt,
      entries: entries,
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
    double accuracy = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      session.latitude,
      session.longitude,
    );
    final effectiveDistance = (distance - accuracy).clamp(0.0, double.infinity);
    final accepted = effectiveDistance <= session.radiusMeters;
    final submission = AttendanceSubmission(
      accepted: accepted,
      distanceMeters: distance,
      message: accepted
          ? 'Attendance accepted. You are ${distance.toStringAsFixed(1)} m from ${session.roomName}.'
          : 'Attendance rejected. You are ${distance.toStringAsFixed(1)} m away, outside the ${session.radiusMeters.toStringAsFixed(0)} m classroom radius.',
    );
    _latestSubmission = submission;
    return submission;
  }

  @override
  Future<AttendanceReport> loadLatestReport(String studentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final demoEntries = [
      if (_latestSubmission?.accepted == true)
        PersonalAttendanceEntry(
          classTitle: _demoSession.classTitle,
          markedAt: now,
          distanceMeters: _latestSubmission?.distanceMeters ?? 12.0,
        ),
      PersonalAttendanceEntry(
        classTitle: 'Mobile Computing',
        markedAt: now.subtract(const Duration(days: 2)),
        distanceMeters: 8.3,
      ),
      PersonalAttendanceEntry(
        classTitle: 'Database Systems',
        markedAt: now.subtract(const Duration(days: 4)),
        distanceMeters: 21.7,
      ),
    ];

    if (demoEntries.isEmpty) return AttendanceReport.empty();

    return AttendanceReport(
      sessionTitle: 'My Attendance',
      totalStudents: demoEntries.length,
      presentCount: demoEntries.length,
      absentCount: 0,
      generatedAt: demoEntries.first.markedAt,
      entries: demoEntries,
    );
  }
}
