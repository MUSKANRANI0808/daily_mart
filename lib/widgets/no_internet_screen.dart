import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// Custom Animated "No Internet Connection" Screen
/// Features an animated cat biting a cable with moving eyes, wagging tail,
/// and an animated background WiFi signal with a red alert badge.
class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen>
    with TickerProviderStateMixin {
  // Tail wagging animation controller
  late AnimationController _tailController;
  late Animation<double> _tailAnimation;

  // Eyes glance and blink animation controller
  late AnimationController _eyesController;
  late Animation<double> _eyeGlanceAnimation;
  late Animation<double> _eyeBlinkAnimation;

  // WiFi signal waves animation controller
  late AnimationController _wifiController;

  // Red alert badge pulse controller
  late AnimationController _alertController;

  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();

    // 1. Tail Wagging: Smooth gentle oscillation
    _tailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _tailAnimation = Tween<double>(begin: -0.18, end: 0.18).animate(
      CurvedAnimation(parent: _tailController, curve: Curves.easeInOutSine),
    );

    // 2. Eyes Glance & Blink: Look left, look right, blink
    _eyesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _eyeGlanceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 3.5).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(3.5), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 3.5, end: -3.5).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(-3.5), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -3.5, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
    ]).animate(_eyesController);

    _eyeBlinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 92),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.1).chain(CurveTween(curve: Curves.easeIn)), weight: 4),
      TweenSequenceItem(tween: Tween<double>(begin: 0.1, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 4),
    ]).animate(_eyesController);

    // 3. WiFi Waves Pulsing
    _wifiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // 4. Red Alert Badge Pulse
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tailController.dispose();
    _eyesController.dispose();
    _wifiController.dispose();
    _alertController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    widget.onRetry?.call();
    final isOnline = await NetworkService.instance.checkConnection();

    if (mounted) {
      setState(() => _isRetrying = false);
      if (!isOnline) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Still offline. Please check your data connection.', style: TextStyle(fontSize: 12.5)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // Prevent navigating back while disconnected
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Illustration Box
                  SizedBox(
                    width: math.min(size.width * 0.90, 360),
                    height: 250,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. WiFi Waves in top-right background
                        Positioned(
                          right: 20,
                          top: 8,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_wifiController, _alertController]),
                            builder: (context, _) {
                              return CustomPaint(
                                size: const Size(125, 105),
                                painter: WifiSignalPainter(
                                  wifiProgress: _wifiController.value,
                                  alertScale: 0.92 + (_alertController.value * 0.16),
                                ),
                              );
                            },
                          ),
                        ),

                        // 2. Animated Cat with Moving Eyes, Wagging Tail, and Bitten Cable
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_tailAnimation, _eyeGlanceAnimation, _eyeBlinkAnimation]),
                            builder: (context, _) {
                              return CustomPaint(
                                size: const Size(360, 250),
                                painter: CatCablePainter(
                                  tailAngle: _tailAnimation.value,
                                  eyeOffsetX: _eyeGlanceAnimation.value,
                                  eyeBlinkScaleY: _eyeBlinkAnimation.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title Text as explicitly requested by user
                  const Text(
                    'Check your internet connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle in Hindi
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'अरे! लगता है हमारी शरारती बिल्ली ने इंटरनेट केबल कुतर दी है। कृपया अपना वाई-फ़ाई या मोबाइल डेटा चेक करें और फिर से कोशिश करें।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Retry Button
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isRetrying ? null : _handleRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Retry Connection',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter for Background WiFi Signal Waves and Red Alert Exclamation Badge
class WifiSignalPainter extends CustomPainter {
  final double wifiProgress;
  final double alertScale;

  WifiSignalPainter({
    required this.wifiProgress,
    required this.alertScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.46, size.height * 0.84);

    // 3 Concentric WiFi Arcs
    final radii = [32.0, 52.0, 72.0];
    final strokeWidths = [12.0, 13.0, 14.0];

    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];
      final sw = strokeWidths[i];

      // Staggered wave pulse
      final waveOffset = (wifiProgress + (i * 0.28)) % 1.0;
      final opacity = (0.28 + (0.42 * math.sin(waveOffset * math.pi))).clamp(0.20, 0.75);

      final paint = Paint()
        ..color = Color(0xFFD1D5DB).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(rect, -math.pi * 0.78, math.pi * 0.56, false, paint);
    }

    // WiFi bottom center dot
    final dotPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 9.0, dotPaint);

    // Red Circular Alert Badge on Top-Right
    final alertCenter = Offset(size.width * 0.88, size.height * 0.22);

    canvas.save();
    canvas.translate(alertCenter.dx, alertCenter.dy);
    canvas.scale(alertScale);

    // Red Badge Shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset.zero, 16.5, shadowPaint);

    // Red Badge Circle
    final redPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 15.0, redPaint);

    // White exclamation mark `!`
    final markPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Upper vertical rounded bar of `!`
    final barRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-2.0, -8.5, 4.0, 9.5),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(barRect, markPaint);

    // Lower dot of `!`
    canvas.drawCircle(const Offset(0, 4.8), 2.2, markPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WifiSignalPainter oldDelegate) {
    return oldDelegate.wifiProgress != wifiProgress || oldDelegate.alertScale != alertScale;
  }
}

/// Custom Painter for the Cat biting the cable, moving eyes, wagging tail,
/// severed cable, and exposed red/green copper wires.
class CatCablePainter extends CustomPainter {
  final double tailAngle;
  final double eyeOffsetX;
  final double eyeBlinkScaleY;

  CatCablePainter({
    required this.tailAngle,
    required this.eyeOffsetX,
    required this.eyeBlinkScaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Palette matching the uploaded artwork
    const catColor = Color(0xFFFDE68A); // Warm golden yellow
    const catShadowColor = Color(0xFFF6D872); // Slightly darker shade for depth
    const tummyColor = Color(0xFFFEF3C7); // Light creamy yellow
    const cableColor = Color(0xFF1E3A5F); // Deep slate blue cable
    const noseColor = Color(0xFF854D0E); // Warm brown nose

    // 0. Soft Floor Ellipse Shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.46, h * 0.88), width: w * 0.62, height: 26),
      shadowPaint,
    );

    // 1. Cat Tail ("puchh") with smooth rotation animation
    final tailPivot = Offset(w * 0.54, h * 0.80);
    canvas.save();
    canvas.translate(tailPivot.dx, tailPivot.dy);
    canvas.rotate(tailAngle);

    final tailPath = Path();
    tailPath.moveTo(0, 0);
    tailPath.cubicTo(20, 10, 45, -5, 75, -20);
    tailPath.cubicTo(95, -30, 115, -15, 105, 5);
    tailPath.cubicTo(95, 20, 70, 20, 40, 18);
    tailPath.cubicTo(20, 16, 10, 10, 0, 0);
    tailPath.close();

    final tailPaint = Paint()
      ..color = catColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(tailPath, tailPaint);

    canvas.restore();

    // 2. Right Arm / Paw
    final rightArmPath = Path();
    rightArmPath.moveTo(w * 0.50, h * 0.58);
    rightArmPath.quadraticBezierTo(w * 0.62, h * 0.62, w * 0.65, h * 0.59);
    rightArmPath.quadraticBezierTo(w * 0.63, h * 0.66, w * 0.52, h * 0.66);
    rightArmPath.close();
    canvas.drawPath(rightArmPath, Paint()..color = catColor);

    // 3. Cat Body & Head Base
    final bodyPath = Path();
    // Start at bottom-left foot
    bodyPath.moveTo(w * 0.35, h * 0.85);
    // Left side curving up to head
    bodyPath.cubicTo(w * 0.34, h * 0.70, w * 0.36, h * 0.46, w * 0.40, h * 0.36);
    // Left ear
    bodyPath.lineTo(w * 0.39, h * 0.24);
    bodyPath.lineTo(w * 0.45, h * 0.28);
    // Top of head
    bodyPath.quadraticBezierTo(w * 0.50, h * 0.26, w * 0.55, h * 0.27);
    // Right ear
    bodyPath.lineTo(w * 0.61, h * 0.24);
    bodyPath.lineTo(w * 0.59, h * 0.35);
    // Right side curving down to bottom
    bodyPath.cubicTo(w * 0.63, h * 0.48, w * 0.63, h * 0.72, w * 0.60, h * 0.85);
    // Right foot
    bodyPath.quadraticBezierTo(w * 0.66, h * 0.88, w * 0.54, h * 0.87);
    // Belly bottom
    bodyPath.quadraticBezierTo(w * 0.46, h * 0.88, w * 0.38, h * 0.87);
    // Left foot
    bodyPath.quadraticBezierTo(w * 0.32, h * 0.88, w * 0.35, h * 0.85);
    bodyPath.close();

    final bodyPaint = Paint()
      ..color = catColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, bodyPaint);

    // Subtle ear inside shading
    final earPaint = Paint()
      ..color = catShadowColor
      ..style = PaintingStyle.fill;
    final leftEarInner = Path()
      ..moveTo(w * 0.40, h * 0.27)
      ..lineTo(w * 0.40, h * 0.25)
      ..lineTo(w * 0.44, h * 0.28)
      ..close();
    canvas.drawPath(leftEarInner, earPaint);

    final rightEarInner = Path()
      ..moveTo(w * 0.58, h * 0.28)
      ..lineTo(w * 0.60, h * 0.25)
      ..lineTo(w * 0.58, h * 0.33)
      ..close();
    canvas.drawPath(rightEarInner, earPaint);

    // 4. Creamy Tummy Patch
    final tummyPath = Path();
    tummyPath.addOval(Rect.fromCenter(
      center: Offset(w * 0.47, h * 0.62),
      width: w * 0.16,
      height: h * 0.38,
    ));
    canvas.drawPath(tummyPath, Paint()..color = tummyColor);

    // 5. Left Arm / Paw holding the cable
    final leftArmPath = Path();
    leftArmPath.moveTo(w * 0.40, h * 0.56);
    leftArmPath.quadraticBezierTo(w * 0.34, h * 0.58, w * 0.34, h * 0.56);
    leftArmPath.addOval(Rect.fromCenter(
      center: Offset(w * 0.33, h * 0.56),
      width: 22,
      height: 20,
    ));
    canvas.drawPath(leftArmPath, Paint()..color = catColor);

    // 6. LAN Cable running into mouth and on floor
    final cablePaint = Paint()
      ..color = cableColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;

    // Segment A: From bottom-left floor up through paw into cat's mouth
    final cablePathLeft = Path();
    cablePathLeft.moveTo(w * 0.16, h * 0.90);
    cablePathLeft.cubicTo(w * 0.22, h * 0.89, w * 0.25, h * 0.76, w * 0.25, h * 0.72);
    cablePathLeft.cubicTo(w * 0.25, h * 0.66, w * 0.31, h * 0.62, w * 0.33, h * 0.56);
    cablePathLeft.cubicTo(w * 0.35, h * 0.50, w * 0.39, h * 0.44, w * 0.44, h * 0.43);
    canvas.drawPath(cablePathLeft, cablePaint);

    // Segment B: From mouth arching down to the right (Severed end)
    final cablePathRight = Path();
    cablePathRight.moveTo(w * 0.46, h * 0.43);
    cablePathRight.cubicTo(w * 0.48, h * 0.41, w * 0.51, h * 0.43, w * 0.53, h * 0.49);
    canvas.drawPath(cablePathRight, cablePaint);

    // Tiny exposed wires sticking out of the severed cable in the mouth
    final wirePaintRed = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final wirePaintGreen = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.53, h * 0.49), Offset(w * 0.535, h * 0.51), wirePaintRed);
    canvas.drawLine(Offset(w * 0.53, h * 0.49), Offset(w * 0.54, h * 0.48), wirePaintGreen);

    // Segment C: Severed cable lying on the floor below the cat
    final cableFloorPath = Path();
    cableFloorPath.moveTo(w * 0.50, h * 0.93);
    cableFloorPath.quadraticBezierTo(w * 0.62, h * 0.93, w * 0.76, h * 0.78);
    canvas.drawPath(cableFloorPath, cablePaint);

    // Exposed copper wires on the floor severed end
    canvas.drawLine(Offset(w * 0.50, h * 0.93), Offset(w * 0.49, h * 0.94), wirePaintRed);
    canvas.drawLine(Offset(w * 0.50, h * 0.93), Offset(w * 0.49, h * 0.92), wirePaintGreen);

    // 7. Cat Mouth & Teeth clenching the cable
    final mouthRect = Rect.fromCenter(center: Offset(w * 0.45, h * 0.43), width: 18, height: 11);
    final mouthPaint = Paint()
      ..color = const Color(0xFF451A03)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(mouthRect, const Radius.circular(5)), mouthPaint);

    // Sharp cute little teeth
    final teethPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final teethPath = Path();
    // Upper teeth
    teethPath.moveTo(w * 0.425, h * 0.395);
    teethPath.lineTo(w * 0.435, h * 0.42);
    teethPath.lineTo(w * 0.445, h * 0.395);
    teethPath.lineTo(w * 0.455, h * 0.42);
    teethPath.lineTo(w * 0.465, h * 0.395);
    teethPath.close();
    canvas.drawPath(teethPath, teethPaint);

    // Lower teeth
    final lowerTeethPath = Path();
    lowerTeethPath.moveTo(w * 0.43, h * 0.455);
    lowerTeethPath.lineTo(w * 0.44, h * 0.435);
    lowerTeethPath.lineTo(w * 0.45, h * 0.455);
    lowerTeethPath.lineTo(w * 0.46, h * 0.435);
    lowerTeethPath.lineTo(w * 0.47, h * 0.455);
    lowerTeethPath.close();
    canvas.drawPath(lowerTeethPath, teethPaint);

    // 8. Cat Cute Brown Nose
    final noseCenter = Offset(w * 0.45, h * 0.39);
    final nosePath = Path();
    nosePath.moveTo(noseCenter.dx - 3.5, noseCenter.dy - 2.0);
    nosePath.lineTo(noseCenter.dx + 3.5, noseCenter.dy - 2.0);
    nosePath.lineTo(noseCenter.dx, noseCenter.dy + 2.5);
    nosePath.close();
    canvas.drawPath(nosePath, Paint()..color = noseColor);

    // 9. Cat Eyes with Moving Pupils & Blinking
    final leftEyeCenter = Offset(w * 0.43, h * 0.34);
    final rightEyeCenter = Offset(w * 0.49, h * 0.355);

    _drawAnimatedEye(canvas, leftEyeCenter, 11.5, eyeOffsetX, eyeBlinkScaleY);
    _drawAnimatedEye(canvas, rightEyeCenter, 10.5, eyeOffsetX, eyeBlinkScaleY);
  }

  void _drawAnimatedEye(
    Canvas canvas,
    Offset center,
    double radius,
    double pupilShiftX,
    double blinkScaleY,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, blinkScaleY);

    // Eye Outline & Sclera (White)
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final eyeBorderPaint = Paint()
      ..color = const Color(0xFF451A03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawCircle(Offset.zero, radius, eyePaint);
    canvas.drawCircle(Offset.zero, radius, eyeBorderPaint);

    // Pupil (Black with slight glance movement)
    if (blinkScaleY > 0.35) {
      final pupilPaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.fill;
      final pupilCenter = Offset(pupilShiftX.clamp(-radius * 0.45, radius * 0.45), 0.5);
      canvas.drawCircle(pupilCenter, radius * 0.44, pupilPaint);

      // Cute white catchlight / glint
      final glintPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(pupilCenter.dx - 1.5, pupilCenter.dy - 1.5), radius * 0.16, glintPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CatCablePainter oldDelegate) {
    return oldDelegate.tailAngle != tailAngle ||
        oldDelegate.eyeOffsetX != eyeOffsetX ||
        oldDelegate.eyeBlinkScaleY != eyeBlinkScaleY;
  }
}
