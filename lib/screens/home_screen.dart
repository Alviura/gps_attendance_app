import 'package:flutter/material.dart';

import '../models/attendance_models.dart';
import '../services/attendance_repository.dart';
import '../services/auth_service.dart';
import '../services/backend_status.dart';
import '../widgets/app_widgets.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'admin_shell.dart';
import 'join_class_screen.dart';
import 'lecturer_shell.dart';
import 'login_screen.dart';
import 'pending_lecturer_screen.dart';
import 'register_screen.dart';
import 'reports_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.backendStatus});

  final BackendStatus backendStatus;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late final AttendanceRepository _attendanceRepository;
  int _studentShellNonce = 0;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(widget.backendStatus);
    _attendanceRepository = widget.backendStatus.isFirebase
        ? FirebaseAttendanceRepository()
        : DemoAttendanceRepository();
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  Future<void> _openJoinClass(BuildContext context) async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => JoinClassScreen(authService: _authService),
      ),
    );
    if (joined == true && mounted) {
      await _authService.reloadProfile();
      setState(() => _studentShellNonce++);
    }
  }

  Widget _withSyncWarningStrip(BuildContext context, Widget child) {
    final msg = _authService.profileSyncWarning;
    if (msg == null) return child;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _authService.reloadProfile,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: _authService.dismissProfileSyncWarning,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authService,
      builder: (context, _) {
        if (_authService.isLoading) {
          return const LoadingScaffold(message: 'Checking session...');
        }

        final user = _authService.currentUser;
        if (user == null) {
          return LoginScreen(
            authService: _authService,
            onRegister: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => RegisterScreen(authService: _authService),
                ),
              );
            },
          );
        }

        final Widget shell;
        if (user.isAdmin) {
          shell = AdminShell(authService: _authService);
        } else if (user.isLecturer) {
          if (user.lecturerStatus == LecturerApprovalStatus.rejected) {
            shell = PendingLecturerScreen(
              authService: _authService,
              rejected: true,
            );
          } else if (user.lecturerStatus == LecturerApprovalStatus.pending ||
              user.lecturerStatus == null) {
            shell = PendingLecturerScreen(
              authService: _authService,
              rejected: false,
            );
          } else {
            shell = LecturerShell(authService: _authService);
          }
        } else {
          shell = StudentShell(
            key: ValueKey(_studentShellNonce),
            user: user,
            authService: _authService,
            attendanceRepository: _attendanceRepository,
            onJoinClass: () => _openJoinClass(context),
          );
        }

        return _withSyncWarningStrip(context, shell);
      },
    );
  }
}

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.user,
    required this.authService,
    required this.attendanceRepository,
    required this.onJoinClass,
  });

  final AppUser user;
  final AuthService authService;
  final AttendanceRepository attendanceRepository;
  final VoidCallback onJoinClass;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        user: widget.user,
        attendanceRepository: widget.attendanceRepository,
        isDemo: widget.authService.isDemo,
        onMarkAttendance: () => setState(() => _selectedIndex = 1),
      ),
      AttendanceScreen(
        user: widget.user,
        attendanceRepository: widget.attendanceRepository,
      ),
      ReportsScreen(
        user: widget.user,
        attendanceRepository: widget.attendanceRepository,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Attendance'),
        actions: [
          IconButton(
            tooltip: 'Join class',
            onPressed: widget.onJoinClass,
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.authService.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.pin_drop_outlined),
            selectedIcon: Icon(Icons.pin_drop_rounded),
            label: 'Attend',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
