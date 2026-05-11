import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/lecturer_actions.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      if (!widget.authService.isDemo) {
        await LecturerActions.joinClassByCode(code);
      } else {
        await DemoLecturerActions.joinClassByCode(code);
      }
      await widget.authService.reloadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined class successfully.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join class')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the join code from your lecturer.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (widget.authService.isDemo) ...[
              const SizedBox(height: 8),
              Text(
                'Demo mode: use code DEMO01',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Join code',
                prefixIcon: Icon(Icons.tag),
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _join,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_rounded),
              label: Text(_busy ? 'Joining...' : 'Join class'),
            ),
          ],
        ),
      ),
    );
  }
}
