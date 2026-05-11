import 'package:flutter/material.dart';

import '../models/attendance_models.dart';
import '../services/attendance_repository.dart';
import '../widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.attendanceRepository,
    required this.isDemo,
    required this.onMarkAttendance,
  });

  final AppUser user;
  final AttendanceRepository attendanceRepository;
  final bool isDemo;
  final VoidCallback onMarkAttendance;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<ClassSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = widget.attendanceRepository.loadActiveSession(
      widget.user.id,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionFuture = widget.attendanceRepository.loadActiveSession(
        widget.user.id,
      );
    });
    await _sessionFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClassSession?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        final session = snapshot.data;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Welcome, ${widget.user.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.matricNumber != null
                    ? 'Matric: ${widget.user.matricNumber} · UID: ${widget.user.id}'
                    : 'Account: ${widget.user.id}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (widget.isDemo)
                const InfoBanner(
                  icon: Icons.science_rounded,
                  title: 'Demo mode active',
                  message:
                      'Running with in-memory demo data. No live sessions or attendance data.',
                ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LoadingCard(message: 'Loading active class...')
              else if (snapshot.hasError)
                EmptyStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load session',
                  message: snapshot.error.toString(),
                )
              else if (session == null)
                const EmptyStateCard(
                  icon: Icons.event_busy_rounded,
                  title: 'No active session',
                  message:
                      'Attendance will open when a lecturer starts a class session.',
                )
              else
                ActiveSessionCard(
                  session: session,
                  onMarkAttendance: widget.onMarkAttendance,
                ),
              const SizedBox(height: 16),
              const RequirementChecklist(),
            ],
          ),
        );
      },
    );
  }
}

class RequirementChecklist extends StatelessWidget {
  const RequirementChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project requirements covered',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 12),
            ChecklistItem(text: 'Student authentication'),
            ChecklistItem(text: 'GPS geofence attendance'),
            ChecklistItem(text: 'Biometric anti-proxy re-check'),
            ChecklistItem(text: 'Attendance reports and analytics'),
          ],
        ),
      ),
    );
  }
}
