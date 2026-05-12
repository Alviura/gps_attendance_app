import 'package:flutter/material.dart';

import '../app/app_branding.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    this.onRegister,
  });

  final AuthService authService;
  final VoidCallback? onRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDemo = widget.authService.isDemo;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Curved header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 48),
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
                  bottom: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(AppBranding.authHeaderShadow),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.layers_rounded,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppBranding.appName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.98),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Smart attendance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppBranding.loginHeadline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.98),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppBranding.loginSubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Form card (overlaps slightly)
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                          elevation: 6,
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
                                  Text(
                                    'Your credentials',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon:
                                          Icon(Icons.alternate_email_rounded),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Enter your email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon:
                                          Icon(Icons.lock_outline_rounded),
                                    ),
                                    obscureText: true,
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: (value) {
                                      if (value == null ||
                                          value.length < 4) {
                                        return 'Enter a valid password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 22),
                                  FilledButton.icon(
                                    onPressed:
                                        _isSubmitting ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: _isSubmitting
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.login_rounded),
                                    label: Text(
                                      _isSubmitting
                                          ? 'Signing in…'
                                          : 'Sign in',
                                    ),
                                  ),
                                  if (widget.onRegister != null) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: TextButton(
                                        onPressed: widget.onRegister,
                                        child: Text(
                                          'New here? Create an account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isDemo) ...[
                          const SizedBox(height: 18),
                          const InfoBanner(
                            icon: Icons.science_rounded,
                            title: 'Demo mode active',
                            message:
                                'Use any email and password to preview as a '
                                'student. Sign in as admin@example.edu to '
                                'open the admin screen.',
                          ),
                        ],
                      ],
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
