/// Product name and copy used across splash, auth, and shell chrome.
abstract final class AppBranding {
  static const String appName = 'SpotRoll';

  static const String splashTagline =
      'Roll call, tied to the spot you\'re standing in.';

  static const String loginHeadline = 'Welcome back';
  static const String loginSubtitle =
      'Location-aware attendance with a quick biometric check—honest marks every time.';

  static const String registerTitle = 'Create account';
  static const String registerHeaderLine = 'Join SpotRoll';

  /// Accent used on splash / auth headers (works on dark gradients).
  static const int brandAccentColorValue = 0xFFFBBF24;

  // ── Cyan / blue palette (distinct from a purple-themed sibling app) ──

  /// Material 3 seed — drives buttons, nav, and component accents app-wide.
  static const int seedColorValue = 0xFF0891B2;

  /// Curved header on login & registration.
  static const int authHeaderTop = 0xFF06B6D4;
  static const int authHeaderBottom = 0xFF0E7490;
  static const int authHeaderShadow = 0x330E7490;

  /// Splash full-screen gradient (top → middle → bottom): cyan into teal into blue.
  static const int splashGradientA = 0xFF0891B2;
  static const int splashGradientB = 0xFF155E75;
  static const int splashGradientC = 0xFF1D4ED8;

  /// Glyph color on the amber pin chip (high contrast on light accent).
  static const int splashIconOnAccent = 0xFF164E63;
}
