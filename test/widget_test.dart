import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_attendance_app/app/app_branding.dart';
import 'package:gps_attendance_app/app/gps_attendance_app.dart';
import 'package:gps_attendance_app/services/backend_status.dart';

void main() {
  testWidgets('shows SpotRoll login after splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
    );
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();

    expect(find.text(AppBranding.appName), findsWidgets);
    expect(find.text(AppBranding.loginHeadline), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('demo login opens student shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
    );
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'student@example.edu');
    await tester.enterText(fields.at(1), 'demo');
    await tester.pump();

    final signInButton = find.text('Sign in');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Demo Student'), findsOneWidget);
    expect(find.textContaining('Hello, Demo'), findsOneWidget);
  });

  /// Skipped: AdminShell uses Firestore; Firebase is not initialized in widget tests.
  testWidgets(
    'demo admin email opens admin shell',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const GpsAttendanceApp(backendStatus: BackendStatus.demo()),
      );
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'admin@example.edu');
      await tester.enterText(fields.at(1), 'demo');
      await tester.pump();

      final signInButton = find.text('Sign in');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Admin'), findsWidgets);
      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
    },
    skip: true,
  );
}
