import 'package:flutter/material.dart';

import '../models/attendance_models.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  final AppUser user;
  final AuthService authService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _matricCtrl;

  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _matricCtrl =
        TextEditingController(text: widget.user.matricNumber ?? '');
    _nameCtrl.addListener(_markDirty);
    _matricCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _matricCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.user.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.user.name.isNotEmpty
        ? widget.user.name[0].toUpperCase()
        : '?';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await widget.authService.updateProfile(
        name: _nameCtrl.text,
        matricNumber: widget.user.isStudent ? _matricCtrl.text : null,
      );
      if (mounted) {
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AttendanceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, size: 36),
        title: const Text('Change password?'),
        content: Text(
          'A password-reset link will be sent to\n${widget.user.email}.\n\nOpen the link to set a new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.authService.sendPasswordResetEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password-reset email sent. Check your inbox.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AttendanceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your account.'),
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
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = widget.user;
    final isStudent = user.isStudent;
    final isDemo = widget.authService.isDemo;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Avatar header ────────────────────────────────────────────────
        Container(
          color: colorScheme.primaryContainer,
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: colorScheme.primary,
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                user.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              _RoleBadge(user: user),
            ],
          ),
        ),

        // ── Edit form ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Text(
            'Edit Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name cannot be empty'
                      : null,
                ),
                const SizedBox(height: 12),

                // Email (read-only)
                TextFormField(
                  initialValue: user.email,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    suffixIcon: Icon(Icons.lock_outline_rounded,
                        size: 18, color: colorScheme.onSurfaceVariant),
                    helperText: 'Email cannot be changed',
                  ),
                ),
                const SizedBox(height: 12),

                // Matric number (student only, editable)
                if (isStudent)
                  TextFormField(
                    controller: _matricCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Matric / student number',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textInputAction: TextInputAction.done,
                  ),

                // Lecturer reg no (read-only)
                if (!isStudent && user.lecturerRegNo != null) ...[
                  TextFormField(
                    initialValue: user.lecturerRegNo,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Lecturer registration number',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      suffixIcon: Icon(Icons.lock_outline_rounded,
                          size: 18, color: colorScheme.onSurfaceVariant),
                      helperText: 'Registration number cannot be changed',
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_isSaving || !_isDirty || isDemo)
                        ? null
                        : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving…' : 'Save changes'),
                  ),
                ),

                if (isDemo) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Profile editing is disabled in demo mode.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Account actions ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Change password
        _ActionTile(
          icon: Icons.lock_reset_rounded,
          label: 'Change password',
          subtitle: 'A reset link will be sent to your email',
          onTap: (isDemo || widget.authService.isDemo) ? null : _changePassword,
          iconColor: colorScheme.primary,
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 24),
        ),

        // Sign out
        _ActionTile(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          subtitle: 'Sign out of your account',
          onTap: _confirmSignOut,
          iconColor: colorScheme.error,
          labelColor: colorScheme.error,
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final String label;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (user.isAdmin) {
      label = 'Administrator';
      bg = colorScheme.tertiaryContainer;
      fg = colorScheme.onTertiaryContainer;
      icon = Icons.admin_panel_settings_rounded;
    } else if (user.isLecturer) {
      label = 'Lecturer';
      bg = colorScheme.secondaryContainer;
      fg = colorScheme.onSecondaryContainer;
      icon = Icons.school_rounded;
    } else {
      label = 'Student';
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
      icon = Icons.person_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = onTap == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDisabled ? 0.05 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isDisabled
                    ? colorScheme.onSurfaceVariant
                    : iconColor,
                size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDisabled
                  ? colorScheme.onSurfaceVariant
                  : (labelColor ?? colorScheme.onSurface),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              color: isDisabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant),
          onTap: onTap,
        ),
      ),
    );
  }
}
