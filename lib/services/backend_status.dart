enum BackendKind { firebase, demo }

class BackendStatus {
  const BackendStatus({required this.kind, this.message});

  const BackendStatus.demo()
      : kind = BackendKind.demo,
        message = 'Running in demo mode.';

  const BackendStatus.firebase()
      : kind = BackendKind.firebase,
        message = null;

  final BackendKind kind;
  final String? message;

  bool get isFirebase => kind == BackendKind.firebase;
  bool get isDemo => kind == BackendKind.demo;

  static Future<BackendStatus> initialize() async {
    const mode = String.fromEnvironment(
      'BACKEND_MODE',
      defaultValue: 'firebase',
    );
    if (mode == 'demo') return const BackendStatus.demo();
    return const BackendStatus.firebase();
  }
}
