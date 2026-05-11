import 'package:flutter/material.dart';

import '../models/attendance_models.dart';
import '../services/admin_approval_service.dart';
import '../services/auth_service.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = AdminApprovalService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final adminName = widget.authService.currentUser?.name ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Dashboard',
                style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Signed in as $adminName',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.authService.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pending Approval'),
            Tab(text: 'All Lecturers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PendingTab(service: _service),
          _AllLecturersTab(service: _service),
        ],
      ),
    );
  }
}

// ─────────────────────────── Pending Tab ────────────────────────────

class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.service});
  final AdminApprovalService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: service.watchPendingLecturers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snapshot.data!;
        if (pending.isEmpty) {
          return const _EmptyPending();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              label:
                  '${pending.length} lecturer${pending.length == 1 ? '' : 's'} waiting for your review',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: pending.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _LecturerCard(
                  user: pending[i],
                  service: service,
                  showActions: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── All Lecturers Tab ───────────────────────

class _AllLecturersTab extends StatelessWidget {
  const _AllLecturersTab({required this.service});
  final AdminApprovalService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: service.watchAllLecturers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lecturers = snapshot.data!;
        if (lecturers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No lecturer accounts yet.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Group by status
        final active =
            lecturers.where((u) => u.lecturerStatus == LecturerApprovalStatus.active).toList();
        final pending =
            lecturers.where((u) => u.lecturerStatus == LecturerApprovalStatus.pending).toList();
        final rejected =
            lecturers.where((u) => u.lecturerStatus == LecturerApprovalStatus.rejected).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (pending.isNotEmpty) ...[
              _SectionHeader(label: 'Pending (${pending.length})'),
              ...pending.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LecturerCard(
                        user: u, service: service, showActions: true),
                  )),
            ],
            if (active.isNotEmpty) ...[
              _SectionHeader(label: 'Active (${active.length})'),
              ...active.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LecturerCard(
                        user: u, service: service, showActions: false),
                  )),
            ],
            if (rejected.isNotEmpty) ...[
              _SectionHeader(label: 'Rejected (${rejected.length})'),
              ...rejected.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LecturerCard(
                        user: u, service: service, showActions: false),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Lecturer Card ───────────────────────────

class _LecturerCard extends StatefulWidget {
  const _LecturerCard({
    required this.user,
    required this.service,
    required this.showActions,
  });

  final AppUser user;
  final AdminApprovalService service;
  final bool showActions;

  @override
  State<_LecturerCard> createState() => _LecturerCardState();
}

class _LecturerCardState extends State<_LecturerCard> {
  bool _loading = false;

  Future<void> _setStatus(LecturerApprovalStatus status) async {
    setState(() => _loading = true);
    try {
      await widget.service.setLecturerStatus(widget.user.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject account?'),
        content: Text(
          '${widget.user.name} will be notified that their account was not approved '
          'and they will not be able to use the app.',
        ),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setStatus(LecturerApprovalStatus.rejected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = widget.user;
    final status = user.lecturerStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with initials
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                _initials(user.name),
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  if (user.lecturerRegNo != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          user.lecturerRegNo!,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Status badge
                  if (status != null && !widget.showActions)
                    _StatusBadge(status: status, scheme: scheme),

                  // Action buttons (pending cards)
                  if (widget.showActions) ...[
                    const SizedBox(height: 4),
                    _loading
                        ? const SizedBox(
                            height: 36,
                            child: Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _confirmReject,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: scheme.error,
                                    side: BorderSide(color: scheme.error),
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _setStatus(LecturerApprovalStatus.active),
                                  child: const Text('Approve'),
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
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────── Supporting widgets ──────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.scheme});

  final LecturerApprovalStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      LecturerApprovalStatus.active => (
          'Active',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      LecturerApprovalStatus.pending => (
          'Pending',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      LecturerApprovalStatus.rejected => (
          'Rejected',
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EmptyPending extends StatelessWidget {
  const _EmptyPending();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No lecturer accounts are waiting for approval right now.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

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
            const Text(
              'Could not load data',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
