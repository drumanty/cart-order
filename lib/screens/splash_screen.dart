import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';

// The vector artwork follows the supplied square C/cart/O logo.
// Keep that same square image (including its blue background) at this path.
const _logoAsset = 'assets/logo.png';
const _brandBlue = Color(0xFF083BD6);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    )..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Preload while the entrance plays; a vector fallback handles missing assets.
    precacheImage(const AssetImage(_logoAsset), context, onError: (_, __) {});
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 0.85;
    }
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _navigated || !mounted) return;
    _navigated = true;
    // Preserve your existing destination. No authentication logic is changed.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBlue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(
              constraints.maxWidth,
              math.min(420.0, constraints.maxHeight * 0.63),
            );
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final reveal = _phase(t, 0.70, 0.83);
                final title = _phase(t, 0.57, 0.76);
                return Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: 'Cart and Order logo',
                              image: true,
                              child: SizedBox(
                                width: side,
                                height: side,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(painter: _LogoPainter(t)),
                                    Opacity(
                                      opacity: reveal,
                                      child: Image.asset(
                                        _logoAsset,
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, 16 * (1 - title)),
                              child: Opacity(
                                opacity: title,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Cart & Order',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Shop Best Quality Products',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 74,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: t,
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

double _phase(double t, double start, double end) => Curves.easeInOutCubic
    .transform(((t - start) / (end - start)).clamp(0.0, 1.0).toDouble());

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinates trace the reference's 1254 x 1254 composition.
    canvas.save();
    canvas.scale(size.width / 1254, size.height / 1254);
    final c = _phase(t, 0.02, 0.30);
    final o = _phase(t, 0.09, 0.37);
    final cartT = ((t - 0.30) / 0.29).clamp(0.0, 1.0).toDouble();
    final cart = Curves.easeOutBack.transform(cartT);
    final cartOpacity = _phase(t, 0.30, 0.39);

    // Right-hand O: the same bold, rounded ring, not a font character.
    canvas.save();
    canvas.translate(180 * (1 - o), -30 * (1 - o));
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(const Rect.fromLTWH(590, 399, 449, 452))
      ..addOval(const Rect.fromLTWH(686, 494, 259, 260));
    canvas.drawPath(ring, Paint()..color = Colors.white.withOpacity(o));
    // A blue-to-white folded highlight where the cart joins the O.
    canvas.save();
    canvas.clipPath(ring);
    canvas.drawRect(
      const Rect.fromLTWH(590, 575, 220, 280),
      Paint()
        ..shader = LinearGradient(
          colors: [
            _brandBlue.withOpacity(o),
            const Color(0xFF6198FF).withOpacity(o),
            Colors.white.withOpacity(o),
          ],
        ).createShader(const Rect.fromLTWH(590, 575, 200, 280)),
    );
    canvas.restore();
    canvas.restore();

    // Left-hand C, including the pointed lower terminal in the reference.
    canvas.save();
    canvas.translate(-180 * (1 - c), 25 * (1 - c));
    final cPath = Path()
      ..moveTo(598, 457)
      ..cubicTo(500, 361, 335, 392, 263, 479)
      ..cubicTo(162, 600, 220, 803, 410, 845)
      ..quadraticBezierTo(430, 852, 410, 832)
      ..quadraticBezierTo(377, 804, 398, 764)
      ..quadraticBezierTo(403, 757, 393, 754)
      ..cubicTo(283, 711, 279, 563, 371, 514)
      ..cubicTo(429, 483, 490, 499, 527, 529)
      ..quadraticBezierTo(535, 536, 541, 528)
      ..lineTo(598, 470)
      ..quadraticBezierTo(606, 464, 598, 457)
      ..close();
    canvas.drawPath(cPath, Paint()..color = Colors.white.withOpacity(c));
    canvas.restore();

    // Cart comes from the left and gently overshoots before docking.
    canvas.save();
    canvas.translate(-640 * (1 - cart), -14 * math.sin(cartT * math.pi));
    final basket = Path()
      ..moveTo(340, 599)
      ..lineTo(386, 599)
      ..quadraticBezierTo(394, 599, 397, 607)
      ..lineTo(406, 636)
      ..lineTo(562, 636)
      ..quadraticBezierTo(573, 636, 577, 622)
      ..lineTo(615, 535)
      ..lineTo(707, 562)
      ..lineTo(626, 708)
      ..quadraticBezierTo(604, 747, 547, 747)
      ..lineTo(430, 747)
      ..quadraticBezierTo(415, 747, 409, 730)
      ..lineTo(377, 625)
      ..lineTo(351, 625)
      ..quadraticBezierTo(342, 625, 340, 617)
      ..lineTo(336, 607)
      ..quadraticBezierTo(333, 599, 340, 599)
      ..close();
    final slots = Path()
      ..moveTo(424, 662)
      ..lineTo(557, 662)
      ..lineTo(548, 679)
      ..lineTo(426, 679)
      ..quadraticBezierTo(419, 679, 418, 672)
      ..quadraticBezierTo(415, 662, 424, 662)
      ..close()
      ..moveTo(438, 705)
      ..lineTo(533, 705)
      ..quadraticBezierTo(528, 721, 516, 721)
      ..lineTo(440, 721)
      ..quadraticBezierTo(433, 721, 432, 715)
      ..quadraticBezierTo(428, 705, 438, 705)
      ..close();
    final paint = Paint()..color = Colors.white.withOpacity(cartOpacity);
    canvas.drawPath(
      Path.combine(PathOperation.difference, basket, slots),
      paint,
    );
    canvas.drawCircle(const Offset(439, 792), 27, paint);
    canvas.drawCircle(const Offset(544, 792), 27, paint);
    canvas.restore();

    // A restrained expanding halo marks the cart's arrival.
    final halo = _phase(t, 0.56, 0.70);
    if (halo > 0 && halo < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(627, 625),
          width: 850 + 100 * halo,
          height: 490 + 80 * halo,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withOpacity(0.22 * (1 - halo)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => t != oldDelegate.t;
}
