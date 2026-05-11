import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class PendingLecturerScreen extends StatefulWidget {
  const PendingLecturerScreen({
    super.key,
    required this.authService,
    this.rejected = false,
  });

  final AuthService authService;
  final bool rejected;

  @override
  State<PendingLecturerScreen> createState() => _PendingLecturerScreenState();
}

class _PendingLecturerScreenState extends State<PendingLecturerScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    await widget.authService.reloadProfile();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRejected = widget.rejected;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status illustration
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isRejected
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected
                      ? Icons.block_rounded
                      : Icons.hourglass_top_rounded,
                  size: 52,
                  color: isRejected
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 28),

              // Headline
              Text(
                isRejected ? 'Access Denied' : 'Awaiting Approval',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Friendly explanation
              Text(
                isRejected
                    ? 'Your lecturer account has not been approved. '
                        'Please contact your institution administrator for assistance.'
                    : 'Your registration was successful! An administrator '
                        'needs to verify your account before you can get started. '
                        'This usually takes a short while.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Status steps — only shown for pending
              if (!isRejected) ...[
                _StepTile(
                  number: '1',
                  label: 'Account created',
                  done: true,
                  scheme: scheme,
                ),
                const SizedBox(height: 12),
                _StepTile(
                  number: '2',
                  label: 'Admin verification',
                  done: false,
                  scheme: scheme,
                ),
                const SizedBox(height: 12),
                _StepTile(
                  number: '3',
                  label: 'Access granted',
                  done: false,
                  scheme: scheme,
                ),
                const SizedBox(height: 40),
              ],

              const Spacer(),

              // Check again button (pending only)
              if (!isRejected)
                FilledButton.icon(
                  onPressed: _checking ? null : _checkStatus,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_checking ? 'Checking...' : 'Check status'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),

              if (!isRejected) const SizedBox(height: 12),

              // Sign out button
              OutlinedButton.icon(
                onPressed: widget.authService.signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.label,
    required this.done,
    required this.scheme,
  });

  final String number;
  final String label;
  final bool done;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done ? scheme.primary : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 20, color: scheme.onPrimary)
                : Text(
                    number,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: done ? FontWeight.w700 : FontWeight.normal,
            color: done ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
