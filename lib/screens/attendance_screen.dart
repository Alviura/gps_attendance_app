import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

import '../models/attendance_models.dart';
import '../services/attendance_repository.dart';
import '../widgets/app_widgets.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.user,
    required this.attendanceRepository,
    this.onAttendanceSubmitted,
  });

  final AppUser user;
  final AttendanceRepository attendanceRepository;
  /// Called after attendance is successfully accepted so the shell can
  /// refresh other tabs (dashboard, reports) that display the new data.
  final VoidCallback? onAttendanceSubmitted;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  ClassSession? _session;
  Position? _position;
  AttendanceSubmission? _lastSubmission;
  String? _statusMessage;
  bool _isLoading = true;
  bool _isGpsLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });
    try {
      final session = await widget.attendanceRepository.loadActiveSession(
        widget.user.id,
      );
      setState(() => _session = session);
    } catch (e) {
      setState(() => _statusMessage = 'Could not load session: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isGpsLoading = true;
      _statusMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _statusMessage =
            'Please turn on location services to continue.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() =>
            _statusMessage = 'Location permission is required to mark attendance.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() => _position = pos);
    } catch (e) {
      setState(() => _statusMessage = 'GPS error: $e');
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  Future<bool> _verifyBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    if (!canCheck && !supported) {
      throw const AttendanceException(
          'Biometric verification is not available on this device.');
    }
    return _localAuth.authenticate(
      localizedReason: 'Confirm your identity to mark attendance.',
      biometricOnly: true,
    );
  }

  Future<void> _submitAttendance() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      if (_position == null) {
        await _refreshLocation();
      }
      final pos = _position;
      if (pos == null) return;

      setState(() => _statusMessage = 'Waiting for biometric confirmation…');
      final verified = await _verifyBiometric();
      if (!verified) {
        setState(() => _statusMessage = 'Biometric check was cancelled.');
        return;
      }

      setState(() => _statusMessage = 'Verifying and submitting…');
      final result = await widget.attendanceRepository.submitAttendance(
        student: widget.user.asStudent,
        session: session,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
      setState(() {
        _lastSubmission = result;
        _statusMessage = result.message;
      });
      if (result.accepted) {
        widget.onAttendanceSubmitted?.call();
      }
    } on AttendanceException catch (e) {
      setState(() => _statusMessage = e.message);
    } catch (e) {
      setState(() => _statusMessage = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final pos = _position;
    final distance = session != null && pos != null
        ? Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            session.latitude,
            session.longitude,
          )
        : null;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Page header ──────────────────────────────────────────────
        Text(
          'Mark Attendance',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete all three steps to record your attendance.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        if (session == null) ...[
          _NoSessionAttendCard(onRetry: _loadSession),
        ] else if (session.alreadyAttended) ...[
          ActiveSessionCard(session: session, alreadyAttended: true),
          const SizedBox(height: 20),
          _AlreadyAttendedCard(session: session),
        ] else ...[
          // Active session info
          ActiveSessionCard(session: session),
          const SizedBox(height: 20),

          // Step 1 – GPS
          _StepCard(
            stepNumber: 1,
            title: 'Get GPS Location',
            icon: Icons.gps_fixed_rounded,
            isDone: pos != null,
            child: pos == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allow the app to read your current location.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            (_isGpsLoading || _isSubmitting)
                                ? null
                                : _refreshLocation,
                        icon: _isGpsLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                            _isGpsLoading ? 'Getting location…' : 'Get Location'),
                      ),
                    ],
                  )
                : _GpsSuccessContent(position: pos),
          ),

          const SizedBox(height: 12),

          // Step 2 – Distance check
          _StepCard(
            stepNumber: 2,
            title: 'Distance Check',
            icon: Icons.social_distance_rounded,
            isDone: distance != null && distance <= session.radiusMeters,
            isLocked: pos == null,
            child: pos == null
                ? Text(
                    'Complete Step 1 first.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : _DistanceContent(
                    distance: distance!,
                    radius: session.radiusMeters,
                    roomName: session.roomName,
                  ),
          ),

          const SizedBox(height: 12),

          // Step 3 – Submit
          _StepCard(
            stepNumber: 3,
            title: 'Biometric & Submit',
            icon: Icons.fingerprint_rounded,
            isDone: _lastSubmission?.accepted == true,
            isLocked: pos == null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your fingerprint confirms you are personally present.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_isSubmitting || pos == null) ? null : _submitAttendance,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.how_to_reg_rounded),
                    label: Text(_isSubmitting
                        ? 'Submitting…'
                        : 'Submit Attendance'),
                  ),
                ),
              ],
            ),
          ),

          // ── Result banner ────────────────────────────────────────────
          if (_lastSubmission != null || _statusMessage != null) ...[
            const SizedBox(height: 16),
            _ResultBanner(
              submission: _lastSubmission,
              message: _statusMessage,
            ),
          ],
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Step card ─────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.icon,
    required this.isDone,
    required this.child,
    this.isLocked = false,
  });

  final int stepNumber;
  final String title;
  final IconData icon;
  final bool isDone;
  final bool isLocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final Color headerBg;
    final Color headerFg;
    if (isDone) {
      headerBg = Colors.green.shade600;
      headerFg = Colors.white;
    } else if (isLocked) {
      headerBg = colorScheme.surfaceContainerHighest;
      headerFg = colorScheme.onSurfaceVariant;
    } else {
      headerBg = colorScheme.primaryContainer;
      headerFg = colorScheme.onPrimaryContainer;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coloured header strip
          Container(
            color: headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: headerFg.withOpacity(0.2),
                  child: Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: headerFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 18, color: headerFg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: headerFg,
                    ),
                  ),
                ),
                if (isDone)
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: headerFg),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── GPS success content ───────────────────────────────────────────────────────

class _GpsSuccessContent extends StatelessWidget {
  const _GpsSuccessContent({required this.position});
  final Position position;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded,
            color: Colors.green.shade600, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}\n'
            'Accuracy: ±${position.accuracy.toStringAsFixed(1)} m',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// ── Distance content ──────────────────────────────────────────────────────────

class _DistanceContent extends StatelessWidget {
  const _DistanceContent({
    required this.distance,
    required this.radius,
    required this.roomName,
  });

  final double distance;
  final double radius;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final isInside = distance <= radius;
    final progress = (distance / radius).clamp(0.0, 1.0);

    final Color statusColor =
        isInside ? Colors.green.shade600 : Colors.orange.shade700;
    final IconData statusIcon = isInside
        ? Icons.check_circle_rounded
        : Icons.warning_amber_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isInside
                    ? 'You\'re inside the classroom radius!'
                    : 'You\'re ${distance.toStringAsFixed(0)} m from $roomName',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isInside ? 1.0 : progress,
            minHeight: 8,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: statusColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${distance.toStringAsFixed(1)} m  ·  max ${radius.toStringAsFixed(0)} m radius',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ── No session card ───────────────────────────────────────────────────────────

class _NoSessionAttendCard extends StatelessWidget {
  const _NoSessionAttendCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              'No active session',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Attendance will open once your lecturer starts a class session.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Already attended card ─────────────────────────────────────────────────────

class _AlreadyAttendedCard extends StatelessWidget {
  const _AlreadyAttendedCard({required this.session});
  final ClassSession session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: Colors.green.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Attendance Recorded!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'You\'re all set for this session.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You have already marked attendance for '
                    '${session.classTitle}. '
                    'Check the Reports tab to see your history.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.submission, required this.message});

  final AttendanceSubmission? submission;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final accepted = submission?.accepted == true;
    final colorScheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;
    final IconData icon;

    if (submission == null) {
      bg = colorScheme.secondaryContainer;
      fg = colorScheme.onSecondaryContainer;
      icon = Icons.info_rounded;
    } else if (accepted) {
      bg = Colors.green.shade600;
      fg = Colors.white;
      icon = Icons.check_circle_rounded;
    } else {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
      icon = Icons.cancel_rounded;
    }

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    accepted ? 'Attendance Accepted!' : 'Status Update',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: TextStyle(color: fg.withOpacity(0.9)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
