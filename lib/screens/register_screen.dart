import 'package:flutter/material.dart';

import '../app/app_branding.dart';
import '../models/attendance_models.dart';
import '../services/auth_service.dart'
    show AuthService, normalizeLecturerRegistrationNumber;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _matricController = TextEditingController();
  final _lecturerRegController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  UserRole _role = UserRole.student;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _matricController.dispose();
    _lecturerRegController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateLecturerReg(String? v) {
    if (_role != UserRole.lecturer) return null;
    if (v == null || v.trim().isEmpty) {
      return 'Enter a lecturer registration number';
    }
    if (normalizeLecturerRegistrationNumber(v) == null) {
      return 'Use 4–24 characters (letters, digits, hyphen)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.authService.signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _role,
        matricNumber: _role == UserRole.student
            ? (_matricController.text.trim().isEmpty
                ? null
                : _matricController.text.trim())
            : null,
        lecturerRegNo: _role == UserRole.lecturer
            ? _lecturerRegController.text.trim()
            : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = widget.authService.isDemo;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(AppBranding.authHeaderTop),
                    Color(AppBranding.authHeaderBottom),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(AppBranding.authHeaderShadow),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppBranding.appName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppBranding.registerHeaderLine,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppBranding.registerTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.98),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      elevation: 5,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isDemo)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    color: colorScheme.secondaryContainer,
                                    child: const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: Text(
                                        'Demo mode: account is stored in memory only.',
                                      ),
                                    ),
                                  ),
                                ),
                              SegmentedButton<UserRole>(
                                segments: const [
                                  ButtonSegment(
                                    value: UserRole.student,
                                    label: Text('Student'),
                                    icon: Icon(Icons.school_outlined),
                                  ),
                                  ButtonSegment(
                                    value: UserRole.lecturer,
                                    label: Text('Lecturer'),
                                    icon: Icon(Icons.person_outline),
                                  ),
                                ],
                                selected: {_role},
                                onSelectionChanged: (s) {
                                  setState(() => _role = s.first);
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter your name'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || !v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              if (_role == UserRole.student) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _matricController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Student / matric number (optional)',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ],
                              if (_role == UserRole.lecturer) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _lecturerRegController,
                                  decoration: const InputDecoration(
                                    labelText: 'Lecturer registration number',
                                    helperText:
                                        '4–24 chars: letters, digits, hyphen. Must be unique.',
                                    prefixIcon:
                                        Icon(Icons.verified_user_outlined),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.next,
                                  validator: _validateLecturerReg,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Honor system: anyone can register as a lecturer. Pick a number colleagues will recognize. '
                                  'Accounts can be revoked if misused.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                                validator: (v) => v == null || v.length < 6
                                    ? 'At least 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmController,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                obscureText: true,
                                onFieldSubmitted: (_) => _submit(),
                                validator: (v) {
                                  if (v != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: _submitting ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _submitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.person_add_alt_1_rounded),
                                label: Text(
                                  _submitting
                                      ? 'Creating…'
                                      : 'Create account',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
