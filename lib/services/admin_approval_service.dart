import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_models.dart';

class AdminApprovalService {
  AdminApprovalService([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchPendingLecturers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'lecturer')
        .where('lecturerStatus', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<AppUser>> watchAllLecturers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'lecturer')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppUser.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setLecturerStatus(
    String userId,
    LecturerApprovalStatus status,
  ) async {
    await _db.collection('users').doc(userId).update({
      'lecturerStatus': status.name,
    });
  }
}