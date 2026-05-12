import 'package:flutter/material.dart';

import '../app/app_branding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _ringCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoSlide;
  late final Animation<double> _ringPhase;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );
    _ringPhase = CurvedAnimation(parent: _ringCtrl, curve: Curves.linear);

    _logoCtrl.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(AppBranding.splashGradientA),
              Color(AppBranding.splashGradientB),
              Color(AppBranding.splashGradientC),
            ],
            stops: [0.0, 0.52, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Soft blobs
            Positioned(
              top: -80,
              right: -40,
              child: _GlowBlob(
                size: 220,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -60,
              child: _GlowBlob(
                size: 260,
                color: const Color(AppBranding.brandAccentColorValue)
                    .withValues(alpha: 0.06),
              ),
            ),

            // Radar rings
            Center(
              child: AnimatedBuilder(
                animation: _ringPhase,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(280, 280),
                    painter: _PulseRingsPainter(phase: _ringPhase.value),
                  );
                },
              ),
            ),

            // Brand block
            Center(
              child: FadeTransition(
                opacity: _logoFade,
                child: AnimatedBuilder(
                  animation: _logoSlide,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _logoSlide.value),
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mark
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.touch_app_rounded,
                            size: 44,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          Positioned(
                            bottom: 18,
                            right: 18,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(
                                    AppBranding.brandAccentColorValue),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                            AppBranding.brandAccentColorValue)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.near_me_rounded,
                                size: 14,
                                color: Color(AppBranding.splashIconOnAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        AppBranding.appName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.98),
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          AppBranding.splashTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom bar
            Positioned(
              left: 32,
              right: 32,
              bottom: 40,
              child: FadeTransition(
                opacity: _logoFade,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _PulseRingsPainter extends CustomPainter {
  _PulseRingsPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 4; i++) {
      final t = (phase + i * 0.22) % 1.0;
      final radius = 40 + t * 120;
      paint.color = Colors.white.withValues(alpha: (1 - t) * 0.35);
      canvas.drawCircle(c, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseRingsPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
