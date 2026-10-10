import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Animated sharp zigzag receipt tear transition divider with moving blue beam effect
class ReceiptScallopDivider extends StatefulWidget {
  final Color cardColor;
  final Color stripColor;
  final double height;
  final double scallopWidth;
  final double scallopDepth;

  const ReceiptScallopDivider({
    super.key,
    this.cardColor = Colors.white,
    this.stripColor = const Color(0xFFEFF6FF),
    this.height = 14.0,
    this.scallopWidth = 12.0,
    this.scallopDepth = 6.5,
  });

  @override
  State<ReceiptScallopDivider> createState() => _ReceiptScallopDividerState();
}

class _ReceiptScallopDividerState extends State<ReceiptScallopDivider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          height: widget.height,
          child: CustomPaint(
            painter: _ReceiptZigzagPainter(
              cardColor: widget.cardColor,
              stripColor: widget.stripColor,
              toothWidth: widget.scallopWidth,
              toothDepth: widget.scallopDepth,
              animationValue: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptZigzagPainter extends CustomPainter {
  final Color cardColor;
  final Color stripColor;
  final double toothWidth;
  final double toothDepth;
  final double animationValue;

  _ReceiptZigzagPainter({
    required this.cardColor,
    required this.stripColor,
    required this.toothWidth,
    required this.toothDepth,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill entire strip with stripColor (light blue)
    final stripPaint = Paint()..color = stripColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), stripPaint);

    // 2. Draw white sharp zigzag dipping into the light blue from the top
    int count = (size.width / toothWidth).round();
    if (count <= 0) count = 1;
    final double actualToothWidth = size.width / count;

    final whitePaint = Paint()..color = cardColor;
    final path = Path();
    final strokePath = Path();

    path.moveTo(0, 0);
    strokePath.moveTo(0, 0);

    for (int i = 0; i < count; i++) {
      final double startX = i * actualToothWidth;
      final double midX = startX + actualToothWidth / 2;
      final double endX = startX + actualToothWidth;

      path.lineTo(midX, toothDepth);
      path.lineTo(endX, 0);

      strokePath.lineTo(midX, toothDepth);
      strokePath.lineTo(endX, 0);
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, whitePaint);

    // 3. Subtle neutral baseline on zigzag edge (so the whole line isn't blue)
    final baseLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0);
    canvas.drawPath(strokePath, baseLinePaint);

    // 4. Snake-style crawling blue light effect ("sap ki tarah aata hua dikhe")
    final metrics = strokePath.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final double totalLength = metric.length;

      // Length of the glowing blue snake
      final double snakeLength = (totalLength * 0.28).clamp(65.0, 115.0);

      // Travel distance allowing snake to fully enter from left and exit to right
      final double totalTravel = totalLength + snakeLength * 2.0;
      final double headDist = (animationValue * totalTravel) - snakeLength;
      final double tailDist = headDist - snakeLength;

      final double start = tailDist.clamp(0.0, totalLength);
      final double end = headDist.clamp(0.0, totalLength);

      if (end > start) {
        final Path snakePath = metric.extractPath(start, end);

        // A. Soft outer neon glow
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawPath(snakePath, glowPaint);

        // B. Vibrant electric blue snake body with gradient from tail to head
        final Rect bounds = snakePath.getBounds();
        final Rect shaderRect = bounds.width > 0 && bounds.height > 0
            ? bounds
            : Rect.fromLTWH(0, 0, size.width, size.height);

        final snakePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF93C5FD).withValues(alpha: 0.05), // Faded tail
              const Color(0xFF60A5FA).withValues(alpha: 0.6),
              const Color(0xFF2563EB),
              const Color(0xFF38BDF8), // Bright leading head
            ],
            stops: const [0.0, 0.35, 0.75, 1.0],
          ).createShader(shaderRect);
        canvas.drawPath(snakePath, snakePaint);

        // C. Bright glowing Snake Head dot
        if (headDist >= 0 && headDist <= totalLength) {
          final ui.Tangent? headTangent = metric.getTangentForOffset(headDist);
          if (headTangent != null) {
            // Glow around head
            final headGlowPaint = Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFF38BDF8).withValues(alpha: 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
            canvas.drawCircle(headTangent.position, 3.2, headGlowPaint);

            // Bright white-hot center of head
            final headCorePaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill;
            canvas.drawCircle(headTangent.position, 1.8, headCorePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptZigzagPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.cardColor != cardColor ||
        oldDelegate.stripColor != stripColor ||
        oldDelegate.toothWidth != toothWidth ||
        oldDelegate.toothDepth != toothDepth;
  }
}
