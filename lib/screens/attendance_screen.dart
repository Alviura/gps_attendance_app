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
  });

  final AppUser user;
  final AttendanceRepository attendanceRepository;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  ClassSession? _session;
  Position? _position;
  AttendanceSubmission? _lastSubmission;
  String? _statusMessage;
  bool _isLoading = true;
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
    } catch (error) {
      setState(() => _statusMessage = 'Could not load active session: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _statusMessage = 'Checking location services...');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Turn on location services to mark attendance.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Location permission is required for GPS verification.';
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      _position = position;
      _statusMessage =
          'Location captured with ${position.accuracy.toStringAsFixed(1)}m accuracy.';
    });
  }

  Future<bool> _verifyBiometric() async {
    final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
    final isDeviceSupported = await _localAuthentication.isDeviceSupported();
    if (!canCheckBiometrics && !isDeviceSupported) {
      throw const AttendanceException(
        'Biometric verification is not available on this device.',
      );
    }

    return _localAuthentication.authenticate(
      localizedReason: 'Confirm your identity before marking attendance.',
      biometricOnly: true,
    );
  }

  Future<void> _submitAttendance() async {
    final session = _session;
    if (session == null) {
      setState(() => _statusMessage = 'No active session is available.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_position == null) {
        await _refreshLocation();
      }

      final position = _position;
      if (position == null) {
        return;
      }

      setState(() => _statusMessage = 'Waiting for biometric verification...');
      final verified = await _verifyBiometric();
      if (!verified) {
        setState(() => _statusMessage = 'Biometric verification was cancelled.');
        return;
      }

      setState(() {
        _statusMessage = 'Submitting attendance for server validation...';
      });
      final result = await widget.attendanceRepository.submitAttendance(
        student: widget.user.asStudent,
        session: session,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _lastSubmission = result;
        _statusMessage = result.message;
      });
    } on AttendanceException catch (error) {
      setState(() => _statusMessage = error.message);
    } catch (error) {
      setState(() => _statusMessage = 'Attendance failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final position = _position;
    final distance = session != null && position != null
        ? Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            session.latitude,
            session.longitude,
          )
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Mark Attendance',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your location and biometric identity are checked before attendance is accepted.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const LoadingCard(message: 'Loading attendance session...')
        else if (session == null)
          const EmptyStateCard(
            icon: Icons.event_busy_rounded,
            title: 'Attendance closed',
            message:
                'There is no active class session for your account right now.',
          )
        else ...[
          ActiveSessionCard(session: session),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  VerificationRow(
                    icon: Icons.gps_fixed_rounded,
                    label: 'GPS location',
                    value: position == null
                        ? 'Not captured'
                        : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  ),
                  VerificationRow(
                    icon: Icons.social_distance_rounded,
                    label: 'Distance from class',
                    value: distance == null
                        ? 'Waiting for GPS'
                        : '${distance.toStringAsFixed(1)}m / ${session.radiusMeters.toStringAsFixed(0)}m radius',
                  ),
                  const VerificationRow(
                    icon: Icons.fingerprint_rounded,
                    label: 'Anti-proxy check',
                    value: 'Biometric required before submit',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _refreshLocation,
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Refresh GPS'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitAttendance,
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.how_to_reg_rounded),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit attendance',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 16),
          InfoBanner(
            icon: _lastSubmission?.accepted == true
                ? Icons.check_circle_rounded
                : Icons.info_rounded,
            title: _lastSubmission?.accepted == true
                ? 'Attendance accepted'
                : 'Status',
            message: _statusMessage!,
          ),
        ],
      ],
    );
  }
}
