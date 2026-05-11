import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/gps_attendance_app.dart';
import 'firebase_options.dart';
import 'services/backend_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendStatus = await BackendStatus.initialize();
  if (backendStatus.isFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(GpsAttendanceApp(backendStatus: backendStatus));
}
