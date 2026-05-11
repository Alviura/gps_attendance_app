import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    required this.onJoinClass,
  });

  final AppUser user;
  final AttendanceRepository attendanceRepository;
  final bool isDemo;
  final VoidCallback onMarkAttendance;
  final VoidCallback onJoinClass;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<ClassSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sessionFuture = widget.attendanceRepository.loadActiveSession(
      widget.user.id,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _sessionFuture;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ClassSession?>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          final session = snapshot.data;
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header card ──────────────────────────────────────────
              _StudentHeaderCard(
                user: widget.user,
                onJoinClass: widget.onJoinClass,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'Today\'s Session',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Session state ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isLoading
                    ? const LoadingCard(message: 'Looking for active sessions…')
                    : snapshot.hasError
                        ? _ErrorCard(error: snapshot.error.toString())
                        : session == null
                            ? _NoSessionCard(onRefresh: _refresh)
                            : ActiveSessionCard(
                                session: session,
                                onMarkAttendance: session.alreadyAttended
                                    ? null
                                    : widget.onMarkAttendance,
                                alreadyAttended: session.alreadyAttended,
                              ),
              ),

              // ── Demo banner ──────────────────────────────────────────
              if (widget.isDemo) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InfoBanner(
                    icon: Icons.science_rounded,
                    title: 'Demo mode',
                    message:
                        'Using sample data. No real sessions or submissions.',
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Quick tips ───────────────────────────────────────────
              if (session == null && !isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _QuickTipsCard(),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Header card ──────────────────────────────────────────────────────────────

class _StudentHeaderCard extends StatelessWidget {
  const _StudentHeaderCard({
    required this.user,
    required this.onJoinClass,
  });

  final AppUser user;
  final VoidCallback onJoinClass;

  String get _initials {
    final parts = user.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final classCount = user.enrolledClassIds.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primary,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (user.matricNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.matricNumber!,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.class_rounded,
                label: classCount == 0
                    ? 'No classes'
                    : '$classCount ${classCount == 1 ? 'class' : 'classes'}',
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.calendar_today_rounded,
                label: DateFormat('EEE, d MMM').format(DateTime.now()),
                colorScheme: colorScheme,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onJoinClass,
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('Join a Class'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary.withOpacity(0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── No session card ───────────────────────────────────────────────────────────

class _NoSessionCard extends StatelessWidget {
  const _NoSessionCard({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Active Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your lecturer hasn\'t started a class yet.\nPull down to refresh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load session',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick tips ────────────────────────────────────────────────────────────────

class _QuickTipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'How attendance works',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TipRow(
              step: '1',
              text: 'Join your lecturer\'s class using a join code',
              colorScheme: colorScheme,
            ),
            _TipRow(
              step: '2',
              text: 'When a session starts it will appear here',
              colorScheme: colorScheme,
            ),
            _TipRow(
              step: '3',
              text: 'Tap "Attend" and verify with GPS + fingerprint',
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.step,
    required this.text,
    required this.colorScheme,
  });

  final String step;
  final String text;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              step,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
