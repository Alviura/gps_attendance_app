enum UserRole { student, lecturer, admin }

enum LecturerApprovalStatus { pending, active, rejected }

/// Canonical profile for Firebase-backed accounts.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.matricNumber,
    this.lecturerRegNo,
    this.lecturerStatus,
    this.enrolledClassIds = const [],
  });

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) {
    final roleStr = data['role'] as String? ?? 'student';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.student,
    );
    LecturerApprovalStatus? ls;
    final lsStr = data['lecturerStatus'] as String?;
    if (lsStr != null) {
      ls = LecturerApprovalStatus.values.firstWhere(
        (s) => s.name == lsStr,
        orElse: () => LecturerApprovalStatus.pending,
      );
    }
    return AppUser(
      id: id,
      name: data['name'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      role: role,
      matricNumber: data['matricNumber'] as String?,
      lecturerRegNo: data['lecturerRegNo'] as String?,
      lecturerStatus: role == UserRole.lecturer ? ls : null,
      enrolledClassIds:
          List<String>.from(data['enrolledClassIds'] as List? ?? []),
    );
  }

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? matricNumber;
  /// Honor-system ID chosen at sign-up; enforced unique server-side.
  final String? lecturerRegNo;
  final LecturerApprovalStatus? lecturerStatus;
  final List<String> enrolledClassIds;

  bool get isStudent => role == UserRole.student;

  bool get isLecturer => role == UserRole.lecturer;

  bool get isAdmin => role == UserRole.admin;

  /// Honor-system: any lecturer may teach unless explicitly rejected (e.g. by admin).
  bool get canTeach =>
      role == UserRole.lecturer &&
      lecturerStatus != LecturerApprovalStatus.rejected;

  /// Student-facing subset for attendance screens.
  AppStudent get asStudent => AppStudent(
        id: id,
        name: name,
        email: email,
        matricNumber: matricNumber,
      );
}

class AppStudent {
  const AppStudent({
    required this.id,
    required this.name,
    required this.email,
    this.matricNumber,
  });

  final String id;
  final String name;
  final String email;
  final String? matricNumber;
}

class ClassSession {
  const ClassSession({
    required this.id,
    required this.classId,
    required this.classTitle,
    required this.roomName,
    required this.lecturerName,
    required this.startsAt,
    required this.endsAt,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.alreadyAttended = false,
  });

  final String id;
  final String classId;
  final String classTitle;
  final String roomName;
  final String lecturerName;
  final DateTime startsAt;
  final DateTime endsAt;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  /// True when the signed-in student has already submitted attendance for
  /// this session, so the dashboard can hide the "Mark attendance" button.
  final bool alreadyAttended;
}

class AttendanceSubmission {
  const AttendanceSubmission({
    required this.accepted,
    required this.message,
    this.distanceMeters,
  });

  final bool accepted;
  final String message;
  final double? distanceMeters;
}

/// A single entry in a student's personal attendance history.
class PersonalAttendanceEntry {
  const PersonalAttendanceEntry({
    required this.classTitle,
    required this.markedAt,
    required this.distanceMeters,
  });

  final String classTitle;
  final DateTime markedAt;
  final double distanceMeters;
}

class AttendanceReport {
  const AttendanceReport({
    required this.sessionTitle,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.generatedAt,
    this.entries = const [],
  });

  factory AttendanceReport.empty() {
    return AttendanceReport(
      sessionTitle: 'No report',
      totalStudents: 0,
      presentCount: 0,
      absentCount: 0,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      entries: const [],
    );
  }

  final String sessionTitle;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final DateTime generatedAt;
  /// Per-student personal attendance records (newest first).
  final List<PersonalAttendanceEntry> entries;

  double get attendanceRate {
    if (totalStudents == 0) return 0;
    return presentCount / totalStudents;
  }
}

class AttendanceException implements Exception {
  const AttendanceException(this.message);

  final String message;

  @override
  String toString() => message;
}
