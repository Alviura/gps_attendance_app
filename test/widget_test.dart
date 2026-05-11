import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_attendance_app/app/gps_attendance_app.dart';
import 'package:gps_attendance_app/services/backend_status.dart';

void main() {
  testWidgets('shows GPS attendance login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
    );

    expect(find.text('GPS Student Attendance'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('demo login opens dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
    );

    final signInButton = find.text('Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome, Demo Student'), findsOneWidget);
    expect(find.text('Account: demo_student'), findsOneWidget);
  });

  testWidgets('demo admin email opens admin shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
    );

    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, 'admin@example.edu');
    await tester.pump();

    final signInButton = find.text('Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsOneWidget);
    expect(
      find.textContaining('admin screen is Firebase-specific'),
      findsOneWidget,
    );
  });
}
