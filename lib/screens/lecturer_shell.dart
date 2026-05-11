import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth_service.dart';
import '../services/lecturer_actions.dart';
import 'profile_screen.dart';

class LecturerShell extends StatefulWidget {
  const LecturerShell({super.key, required this.authService});
  final AuthService authService;

  @override
  State<LecturerShell> createState() => _LecturerShellState();
}

class _LecturerShellState extends State<LecturerShell> {
  int _index = 0;
  int _reloadNonce = 0;

  String get _uid => widget.authService.currentUser!.id;
  String get _name => widget.authService.currentUser!.name;
  bool get _isDemo => widget.authService.isDemo;

  /// Tries to get the device's current GPS position for pre-filling the form.
  Future<Position?> _fetchCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _createClassDialog() async {
    // Fetch the lecturer's real location BEFORE opening the form so the
    // classroom coordinates default to where the lecturer actually is.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location…'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    final pos = await _fetchCurrentPosition();
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();

    final titleCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final latCtrl = TextEditingController(
      text: pos != null ? pos.latitude.toStringAsFixed(6) : '',
    );
    final lngCtrl = TextEditingController(
      text: pos != null ? pos.longitude.toStringAsFixed(6) : '',
    );
    final radiusCtrl = TextEditingController(text: '80');
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.class_rounded,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create New Class',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pos != null
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: pos != null
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pos != null
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      size: 16,
                      color: pos != null
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pos != null
                            ? 'Classroom location set to your current position '
                                '(±${pos.accuracy.toStringAsFixed(0)} m accuracy)'
                            : 'Could not get GPS — enter coordinates manually below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: pos != null
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course title',
                  prefixIcon: Icon(Icons.book_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a course title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room / venue',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a room name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: lngCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: radiusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Geofence radius (meters)',
                  prefixIcon: Icon(Icons.radio_button_unchecked_rounded),
                  helperText:
                      'Area students must be within to mark attendance',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Invalid radius' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final lat = double.parse(latCtrl.text.trim());
      final lng = double.parse(lngCtrl.text.trim());
      final r = double.parse(radiusCtrl.text.trim());

      if (!_isDemo) {
        final res = await LecturerActions.createClass(
          title: titleCtrl.text.trim(),
          roomName: roomCtrl.text.trim(),
          latitude: lat,
          longitude: lng,
          radiusMeters: r,
        );
        if (mounted) {
          _showJoinCodeDialog(
            res['joinCode'] as String? ?? '—',
            titleCtrl.text.trim(),
          );
        }
      } else {
        if (mounted) {
          _showJoinCodeDialog('DEMO01', titleCtrl.text.trim());
        }
      }
      setState(() => _reloadNonce++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _showJoinCodeDialog(String code, String classTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: Theme.of(ctx).colorScheme.primary,
          size: 40,
        ),
        title: const Text('Class created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this join code with students for "$classTitle":'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Join code copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: 'Copy',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateClassLocationDialog(
    String classId,
    double currentLat,
    double currentLng,
    double currentRadius,
  ) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location…'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    final pos = await _fetchCurrentPosition();
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();

    final latCtrl = TextEditingController(
      text: pos != null
          ? pos.latitude.toStringAsFixed(6)
          : currentLat.toStringAsFixed(6),
    );
    final lngCtrl = TextEditingController(
      text: pos != null
          ? pos.longitude.toStringAsFixed(6)
          : currentLng.toStringAsFixed(6),
    );
    final radiusCtrl =
        TextEditingController(text: currentRadius.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_location_alt_rounded,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Update Classroom Location',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Location status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: pos != null
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: pos != null
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      pos != null
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      size: 16,
                      color: pos != null
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pos != null
                            ? 'Pre-filled with your current GPS position '
                                '(±${pos.accuracy.toStringAsFixed(0)} m accuracy)'
                            : 'Could not get GPS — previous coordinates kept. Edit manually if needed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: pos != null
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon:
                            Icon(Icons.my_location_rounded, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: lngCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon:
                            Icon(Icons.my_location_rounded, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: radiusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Geofence radius (meters)',
                  prefixIcon:
                      Icon(Icons.radio_button_unchecked_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Invalid radius' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await LecturerActions.updateClassLocation(
        classId: classId,
        latitude: double.parse(latCtrl.text.trim()),
        longitude: double.parse(lngCtrl.text.trim()),
        radiusMeters: double.parse(radiusCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Classroom location updated.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _reloadNonce++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _startSession(String classId, String classTitle) async {
    try {
      if (!_isDemo) {
        await LecturerActions.startSession(
          classId: classId,
          title: '$classTitle — Attendance',
          durationMinutes: 120,
        );
      } else {
        await DemoLecturerActions.startSession(classId: classId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session started for $classTitle'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _reloadNonce++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmEndSession(String sessionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: Text(
            'End "$title"? Students will no longer be able to mark attendance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (!_isDemo) {
        await LecturerActions.endSession(sessionId);
      } else {
        await DemoLecturerActions.endSession(sessionId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _reloadNonce++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${_name.split(' ').first} 👋',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Lecturer Dashboard',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: [
        _ClassesTab(
          uid: _uid,
          reloadNonce: _reloadNonce,
          isDemo: _isDemo,
          onCreateClass: _createClassDialog,
          onStartSession: _startSession,
          onGoToSessions: () => setState(() => _index = 1),
          onUpdateLocation: _updateClassLocationDialog,
        ),
        _SessionsTab(
          uid: _uid,
          reloadNonce: _reloadNonce,
          isDemo: _isDemo,
          onEndSession: _confirmEndSession,
        ),
        _ReportsTab(uid: _uid, reloadNonce: _reloadNonce, isDemo: _isDemo),
        ProfileScreen(
          user: widget.authService.currentUser!,
          authService: widget.authService,
        ),
      ][_index],
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _createClassDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New class'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.class_outlined),
            selectedIcon: Icon(Icons.class_rounded),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_rounded),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Classes Tab ─────────────────────────────

class _ClassesTab extends StatelessWidget {
  const _ClassesTab({
    required this.uid,
    required this.reloadNonce,
    required this.isDemo,
    required this.onCreateClass,
    required this.onStartSession,
    required this.onGoToSessions,
    required this.onUpdateLocation,
  });

  final String uid;
  final int reloadNonce;
  final bool isDemo;
  final VoidCallback onCreateClass;
  final void Function(String classId, String title) onStartSession;
  final VoidCallback onGoToSessions;
  final void Function(
      String classId, double lat, double lng, double radius) onUpdateLocation;

  static Future<(List<Map<String, dynamic>>, Set<String>)> _loadData(
      String uid) async {
    final results = await Future.wait([
      LecturerActions.listClasses(uid),
      LecturerActions.listSessions(uid),
    ]);
    final classes = results[0];
    final sessions = results[1];
    // Build the set of classIds that currently have an active session
    final activeClassIds = {
      for (final s in sessions)
        if ((s['status'] as String?) == 'active') s['classId'] as String,
    };
    return (classes, activeClassIds);
  }

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return _DemoPlaceholder(
        icon: Icons.class_rounded,
        message: 'Demo lecturer mode',
        onPrimary: onCreateClass,
        primaryLabel: 'Create demo class',
        onSecondary: () => onStartSession('demo_class', 'Demo'),
        secondaryLabel: 'Start demo session',
      );
    }

    return FutureBuilder<(List<Map<String, dynamic>>, Set<String>)>(
      key: ValueKey(reloadNonce),
      future: _loadData(uid),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(error: snap.error.toString());
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (classes, activeClassIds) = snap.data!;
        final anySessionActive = activeClassIds.isNotEmpty;
        if (classes.isEmpty) {
          return _EmptyState(
            icon: Icons.class_outlined,
            title: 'No classes yet',
            message:
                'Create your first class and share the join code with your students.',
            actionLabel: 'Create class',
            onAction: onCreateClass,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = classes[i];
            final classId = data['id'] as String;
            final title = data['title'] as String? ?? 'Class';
            final room = data['roomName'] as String? ?? '';
            final code = data['joinCode'] as String? ?? '';
            final hasActive = activeClassIds.contains(classId);
            return _ClassCard(
              classId: classId,
              title: title,
              room: room,
              joinCode: code,
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
              radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 80,
              hasActiveSession: hasActive,
              anyOtherSessionActive: anySessionActive && !hasActive,
              onStartSession: () => onStartSession(classId, title),
              onViewSession: onGoToSessions,
              onUpdateLocation: () => onUpdateLocation(
                classId,
                (data['latitude'] as num?)?.toDouble() ?? 0,
                (data['longitude'] as num?)?.toDouble() ?? 0,
                (data['radiusMeters'] as num?)?.toDouble() ?? 80,
              ),
            );
          },
        );
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classId,
    required this.title,
    required this.room,
    required this.joinCode,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.hasActiveSession,
    required this.anyOtherSessionActive,
    required this.onStartSession,
    required this.onViewSession,
    required this.onUpdateLocation,
  });

  final String classId;
  final String title;
  final String room;
  final String joinCode;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool hasActiveSession;
  /// True when another of the lecturer's classes already has a live session.
  final bool anyOtherSessionActive;
  final VoidCallback onStartSession;
  final VoidCallback onViewSession;
  final VoidCallback onUpdateLocation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerColor =
        hasActiveSession ? Colors.green.shade600 : scheme.primaryContainer;
    final headerFg =
        hasActiveSession ? Colors.white : scheme.onPrimaryContainer;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coloured header strip — green when a session is live
          Container(
            color: headerColor,
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Icon(Icons.class_rounded, color: headerFg, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: headerFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (hasActiveSession) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Update location icon
                IconButton(
                  onPressed: onUpdateLocation,
                  icon: Icon(Icons.edit_location_alt_rounded,
                      color: headerFg, size: 20),
                  tooltip: 'Update classroom location',
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.meeting_room_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(room,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                const SizedBox(height: 10),
                // Join code chip
                Row(
                  children: [
                    Text('Join code: ',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Join code copied!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              joinCode,
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_rounded,
                                size: 14,
                                color: scheme.onSecondaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: hasActiveSession
                      ? OutlinedButton.icon(
                          onPressed: onViewSession,
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: const Text('View active session'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade400),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              onPressed: anyOtherSessionActive
                                  ? null
                                  : onStartSession,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start session'),
                            ),
                            if (anyOtherSessionActive) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 13,
                                      color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    'End your active session first.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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

// ─────────────────────────── Sessions Tab ────────────────────────────

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.uid,
    required this.reloadNonce,
    required this.isDemo,
    required this.onEndSession,
  });

  final String uid;
  final int reloadNonce;
  final bool isDemo;
  final void Function(String sessionId, String title) onEndSession;

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return const _EmptyState(
        icon: Icons.event_outlined,
        title: 'No sessions in demo mode',
        message: 'Sessions appear here once you start one from the Classes tab.',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(reloadNonce),
      future: LecturerActions.listSessions(uid),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(error: snap.error.toString());
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snap.data!;
        if (sessions.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_outlined,
            title: 'No sessions yet',
            message:
                'Go to the Classes tab and tap "Start session" to begin taking attendance.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = sessions[i];
            final status = data['status'] as String? ?? 'closed';
            final title = data['title'] as String? ?? 'Session';
            final isActive = status == 'active';
            return _SessionCard(
              title: title,
              isActive: isActive,
              onEnd: isActive
                  ? () => onEndSession(data['id'] as String, title)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.title,
    required this.isActive,
    this.onEnd,
  });

  final String title;
  final bool isActive;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : scheme.outlineVariant,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Live' : 'Closed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.green.shade700
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onEnd != null) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onEnd,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                ),
                child: const Text('End'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Reports Tab ─────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.uid,
    required this.reloadNonce,
    required this.isDemo,
  });

  final String uid;
  final int reloadNonce;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return const _EmptyState(
        icon: Icons.analytics_outlined,
        title: 'Reports appear after live sessions',
        message: 'Once students mark attendance, reports will show up here.',
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(reloadNonce),
      future: LecturerActions.listReports(uid),
      builder: (context, snap) {
        if (snap.hasError) return _ErrorCard(error: snap.error.toString());
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snap.data!;
        if (reports.isEmpty) {
          return const _EmptyState(
            icon: Icons.analytics_outlined,
            title: 'No reports yet',
            message:
                'Attendance reports will appear here after students mark their presence.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final rep = reports[i];
            final present = (rep['presentCount'] as int?) ?? 0;
            final total = (rep['totalStudents'] as int?) ?? 0;
            final rate = total > 0 ? present / total : 0.0;
            return _ReportCard(
              sessionTitle: rep['sessionTitle'] as String? ?? 'Session',
              present: present,
              total: total,
              rate: rate,
            );
          },
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.sessionTitle,
    required this.present,
    required this.total,
    required this.rate,
  });

  final String sessionTitle;
  final int present;
  final int total;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final absent = total - present;
    final pct = (rate * 100).toStringAsFixed(0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            // Attendance bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  rate >= 0.75
                      ? Colors.green
                      : rate >= 0.5
                          ? Colors.orange
                          : scheme.error,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatPill(
                  icon: Icons.check_circle_rounded,
                  label: '$present present',
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  icon: Icons.cancel_rounded,
                  label: '$absent absent',
                  color: scheme.error,
                ),
                const Spacer(),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: rate >= 0.75
                        ? Colors.green
                        : rate >= 0.5
                            ? Colors.orange
                            : scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─────────────────────────── Shared helpers ───────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemoPlaceholder extends StatelessWidget {
  const _DemoPlaceholder({
    required this.icon,
    required this.message,
    required this.onPrimary,
    required this.primaryLabel,
    this.onSecondary,
    this.secondaryLabel,
  });

  final IconData icon;
  final String message;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
            if (onSecondary != null && secondaryLabel != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonal(
                  onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
