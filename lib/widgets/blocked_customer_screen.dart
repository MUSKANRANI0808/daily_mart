import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../screens/role_selection_screen.dart';

/// Full-screen locked view shown whenever a customer's ID is blocked by the admin.
/// Strictly prevents any page navigation and prompts them to contact support.
class BlockedCustomerScreen extends StatefulWidget {
  final String customerMobile;
  final String customerName;
  final String? reason;

  const BlockedCustomerScreen({
    super.key,
    required this.customerMobile,
    required this.customerName,
    this.reason,
  });

  @override
  State<BlockedCustomerScreen> createState() => _BlockedCustomerScreenState();
}

class _BlockedCustomerScreenState extends State<BlockedCustomerScreen> {
  // Support number requested by user
  static const String supportPhone = '7480976513';

  Future<void> _contactSupport(BuildContext context) async {
    final Uri callUri = Uri.parse('tel:$supportPhone');
    final Uri waUri = Uri.parse(
        'https://wa.me/91$supportPhone?text=${Uri.encodeComponent("Hello Daily Mart Support, my customer account (${widget.customerMobile}) is showing blocked. Please help me unblock it.")}');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'सपोर्ट टीम से संपर्क करें',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'अपनी ID अनब्लॉक करवाने के लिए सपोर्ट टीम से बात करें:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF22C55E), size: 22),
                ),
                title: const Text('WhatsApp पर चैट करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                subtitle: const Text('तुरंत रिस्पॉन्स पाएं (+91 7480976513)', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (await canLaunchUrl(waUri)) {
                    await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                title: const Text('हेल्पलाइन पर कॉल करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                subtitle: const Text('+91 7480976513', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (await canLaunchUrl(callUri)) {
                    await launchUrl(callUri);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('लॉगआउट करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('क्या आप इस अकाउंट से लॉगआउट करना चाहते हैं?', style: TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('नहीं', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('लॉगआउट'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent bypassing via back button
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Custom Animated Illustration (Girl gesturing at phone + animated BLOCK stamp / mohar)
                  const BlockedPhoneGirlAnimation(),

                  const SizedBox(height: 24),

                  // 2. Hindi Title
                  const Text(
                    'आपकी ID ब्लॉक कर दी गई है',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Hindi Detailed Explanation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'आपकी ID को सुरक्षा कारणों अथवा एडमिन द्वारा ब्लॉक कर दिया गया है। जब तक आपकी ID ब्लॉक है, आप स्टोर या ऑर्डर्स एक्सेस नहीं कर सकते। सहायता के लिए कृपया हमारी सपोर्ट टीम से संपर्क करें।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (widget.reason != null && widget.reason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        'कारण: ${widget.reason}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFBE123C), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 4. Contact Support Button (Primary)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _contactSupport(context),
                      icon: const Icon(Icons.support_agent_rounded, size: 22),
                      label: const Text(
                        'सपोर्ट टीम से संपर्क करें',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Logout Button (Secondary)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF64748B)),
                      label: const Text(
                        'लॉगआउट करें',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

/// ---------------------------------------------------------------------------
/// ANIMATED BLOCKED PHONE & GIRL ILLUSTRATION WIDGET
/// - Moving girl's head (nodding/looking with concern)
/// - Moving girl's hand/arm (gesturing towards the phone)
/// - Animated BLOCK stamp ("मोहर") that stamps onto the phone screen with impact
/// ---------------------------------------------------------------------------
class BlockedPhoneGirlAnimation extends StatefulWidget {
  const BlockedPhoneGirlAnimation({super.key});

  @override
  State<BlockedPhoneGirlAnimation> createState() => _BlockedPhoneGirlAnimationState();
}

class _BlockedPhoneGirlAnimationState extends State<BlockedPhoneGirlAnimation>
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
        return CustomPaint(
          size: const Size(300, 240),
          painter: _BlockedIllustrationPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _BlockedIllustrationPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 cycle

  _BlockedIllustrationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background Smartphone (ANIMATED! Moves left & right continuously)
    final bgPhoneOffset = math.sin(progress * 2 * math.pi) * 15.0;
    _drawBackgroundPhone(canvas, w, h, bgPhoneOffset);

    // 2. Desk / Table
    _drawTable(canvas, w, h);

    // 3. Realistic Girl Model (Curved anatomy, animated head tilt & gesturing hand)
    final headAngle = math.sin(progress * 2 * math.pi) * 0.07;
    final armAngle = math.sin(progress * 2 * math.pi) * 0.13;
    _drawGirl(canvas, w, h, headAngle, armAngle);

    // 4. Large Smartphone in foreground
    _drawMainSmartphone(canvas, w, h);

    // 5. Block Stamp ("मोहर") stamping onto phone screen with shockwave
    _drawBlockStamp(canvas, w, h);
  }

  /// 1. Background Smartphone (Smoothly floats Left <--> Right)
  void _drawBackgroundPhone(Canvas canvas, double w, double h, double dxOffset) {
    final phoneWidth = w * 0.28;
    final phoneHeight = h * 0.52;
    final phoneLeft = w * 0.38 + dxOffset;
    final phoneTop = h * 0.12;

    final phoneRect = Rect.fromLTWH(phoneLeft, phoneTop, phoneWidth, phoneHeight);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(12));

    // Outer Shadow
    canvas.drawRRect(
      phoneRRect.inflate(1),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );

    // Phone Frame (Dark Slate)
    final framePaint = Paint()..color = const Color(0xFF334155);
    canvas.drawRRect(phoneRRect, framePaint);

    // Top Speaker slit
    final speakerRect = Rect.fromCenter(
      center: Offset(phoneRect.center.dx, phoneRect.top + 7),
      width: 26,
      height: 2.5,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(speakerRect, const Radius.circular(2)), Paint()..color = Colors.white54);

    // Screen (Blue Display)
    final screenRect = Rect.fromLTWH(phoneLeft + 4, phoneTop + 14, phoneWidth - 8, phoneHeight - 22);
    final screenRRect = RRect.fromRectAndRadius(screenRect, const Radius.circular(8));
    final screenPaint = Paint()..color = const Color(0xFF3B82F6);
    canvas.drawRRect(screenRRect, screenPaint);

    // Subtle blue screen gradient highlight
    final glossPath = Path()
      ..moveTo(screenRect.left, screenRect.top)
      ..lineTo(screenRect.right, screenRect.top)
      ..lineTo(screenRect.left, screenRect.top + 45)
      ..close();
    canvas.drawPath(glossPath, Paint()..color = Colors.white.withValues(alpha: 0.15));

    // Red Prohibition Circle on Screen
    final screenCenter = Offset(screenRect.center.dx, screenRect.center.dy - 8);
    final banPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(screenCenter, 18, banPaint);
    canvas.drawLine(
      Offset(screenCenter.dx - 12, screenCenter.dy - 12),
      Offset(screenCenter.dx + 12, screenCenter.dy + 12),
      banPaint,
    );

    // Red "BLOCK" Button Badge at bottom of screen
    final badgeRect = Rect.fromCenter(center: Offset(screenRect.center.dx, screenRect.bottom - 16), width: 46, height: 16);
    final badgePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)), badgePaint);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'BLOCK',
        style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(badgeRect.center.dx - tp.width / 2, badgeRect.center.dy - tp.height / 2));
  }

  /// 2. Table / Desk
  void _drawTable(Canvas canvas, double w, double h) {
    // Desk surface slab
    final tableRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.56, h * 0.60, w * 0.38, 9),
      const Radius.circular(3),
    );
    canvas.drawRRect(tableRect, Paint()..color = const Color(0xFF94A3B8));

    // Subtle table bevel shadow
    canvas.drawRect(
      Rect.fromLTWH(w * 0.56, h * 0.60 + 7, w * 0.38, 2),
      Paint()..color = const Color(0xFF64748B),
    );

    // Table legs (slender modern legs)
    final legPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.60, h * 0.61), Offset(w * 0.60, h * 0.93), legPaint);
    canvas.drawLine(Offset(w * 0.90, h * 0.61), Offset(w * 0.90, h * 0.93), legPaint);
  }

  /// 3. Realistic Girl Model (Curved organic anatomy, natural posture & graceful gestures)
  void _drawGirl(Canvas canvas, double w, double h, double headAngle, double armAngle) {
    // Color Palette
    final skinPaint = Paint()..color = const Color(0xFFFDBA74);
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    final jacketPaint = Paint()..color = const Color(0xFFEF4444);
    final jacketDarkPaint = Paint()..color = const Color(0xFFDC2626);
    final topPaint = Paint()..color = Colors.white;
    final pantsPaint = Paint()..color = const Color(0xFF1E293B);
    final shoePaint = Paint()..color = const Color(0xFF0F172A);

    // -------------------------------------------------------------
    // A. LEGS & PANTS (Curved, slender anatomy leaning gracefully against table)
    // -------------------------------------------------------------

    // Left leg (in back, supporting against table)
    final backLegPath = Path();
    backLegPath.moveTo(w * 0.74, h * 0.61);
    backLegPath.quadraticBezierTo(w * 0.71, h * 0.72, w * 0.68, h * 0.88); // Calf & ankle
    backLegPath.lineTo(w * 0.71, h * 0.88);
    backLegPath.quadraticBezierTo(w * 0.74, h * 0.73, w * 0.77, h * 0.61);
    backLegPath.close();
    canvas.drawPath(backLegPath, pantsPaint);

    // Left Shoe (back foot)
    final backShoe = Path();
    backShoe.moveTo(w * 0.67, h * 0.88);
    backShoe.lineTo(w * 0.73, h * 0.88);
    backShoe.quadraticBezierTo(w * 0.71, h * 0.91, w * 0.65, h * 0.90);
    backShoe.close();
    canvas.drawPath(backShoe, shoePaint);

    // Right leg (in front, crossing slightly forward)
    final frontLegPath = Path();
    frontLegPath.moveTo(w * 0.71, h * 0.60); // Hip
    frontLegPath.cubicTo(w * 0.68, h * 0.67, w * 0.66, h * 0.74, w * 0.64, h * 0.79); // Thigh & knee
    frontLegPath.quadraticBezierTo(w * 0.62, h * 0.84, w * 0.60, h * 0.89); // Calf to ankle
    frontLegPath.lineTo(w * 0.63, h * 0.89);
    frontLegPath.quadraticBezierTo(w * 0.65, h * 0.83, w * 0.67, h * 0.78);
    frontLegPath.cubicTo(w * 0.69, h * 0.73, w * 0.72, h * 0.67, w * 0.75, h * 0.60);
    frontLegPath.close();
    canvas.drawPath(frontLegPath, pantsPaint);

    // Right Shoe (pointed ballet flat)
    final frontShoe = Path();
    frontShoe.moveTo(w * 0.59, h * 0.89);
    frontShoe.lineTo(w * 0.64, h * 0.89);
    frontShoe.quadraticBezierTo(w * 0.61, h * 0.92, w * 0.56, h * 0.91); // Pointed toe
    frontShoe.close();
    canvas.drawPath(frontShoe, shoePaint);

    // -------------------------------------------------------------
    // B. TORSO & WAIST (Feminine silhouette with white top & red blazer)
    // -------------------------------------------------------------
    // White inner blouse
    final topPath = Path();
    topPath.moveTo(w * 0.71, h * 0.60); // Left waist
    topPath.quadraticBezierTo(w * 0.72, h * 0.50, w * 0.73, h * 0.44); // Chest
    topPath.lineTo(w * 0.77, h * 0.44); // Right shoulder
    topPath.quadraticBezierTo(w * 0.78, h * 0.51, w * 0.76, h * 0.60); // Right waist
    topPath.close();
    canvas.drawPath(topPath, topPaint);

    // Red Cardigan / Blazer (draped naturally over shoulders & torso)
    final jacketBackPath = Path();
    jacketBackPath.moveTo(w * 0.77, h * 0.43);
    jacketBackPath.quadraticBezierTo(w * 0.81, h * 0.49, w * 0.79, h * 0.61);
    jacketBackPath.lineTo(w * 0.75, h * 0.61);
    jacketBackPath.quadraticBezierTo(w * 0.76, h * 0.52, w * 0.75, h * 0.45);
    jacketBackPath.close();
    canvas.drawPath(jacketBackPath, jacketPaint);

    // Left Arm resting on table behind her
    final leftArmPath = Path();
    leftArmPath.moveTo(w * 0.78, h * 0.45);
    leftArmPath.quadraticBezierTo(w * 0.83, h * 0.52, w * 0.86, h * 0.59);
    canvas.drawPath(
      leftArmPath,
      Paint()
        ..color = jacketDarkPaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round,
    );

    // Left hand resting on table
    canvas.drawCircle(Offset(w * 0.86, h * 0.595), 4.5, skinPaint);

    // -------------------------------------------------------------
    // C. RIGHT ARM & GESTURING HAND (ANIMATED! Fluid pointing motion)
    // -------------------------------------------------------------
    canvas.save();
    // Shoulder pivot point
    final shoulderOffset = Offset(w * 0.725, h * 0.45);
    canvas.translate(shoulderOffset.dx, shoulderOffset.dy);
    canvas.rotate(armAngle);

    // Curved Upper arm & forearm path
    final rightArmPath = Path();
    rightArmPath.moveTo(0, 0);
    // Upper arm extending up and left
    rightArmPath.quadraticBezierTo(-w * 0.04, -h * 0.04, -w * 0.06, -h * 0.07);
    // Forearm angled towards phone
    rightArmPath.quadraticBezierTo(-w * 0.08, -h * 0.09, -w * 0.11, -h * 0.11);

    canvas.drawPath(
      rightArmPath,
      Paint()
        ..color = jacketPaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round,
    );

    // Hand and Pointing Index Finger
    final handPos = Offset(-w * 0.11, -h * 0.11);
    canvas.drawCircle(handPos, 4.0, skinPaint);
    // Index finger pointing directly at the phone screen
    canvas.drawLine(
      handPos,
      Offset(handPos.dx - 7, handPos.dy - 3),
      Paint()
        ..color = skinPaint.color
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // -------------------------------------------------------------
    // D. HEAD, FACE PROFILE & PONYTAIL (ANIMATED! Realistic feminine silhouette)
    // -------------------------------------------------------------
    canvas.save();
    // Neck pivot point
    final neckPivot = Offset(w * 0.74, h * 0.43);
    canvas.translate(neckPivot.dx, neckPivot.dy);
    canvas.rotate(headAngle);

    // Slender Neck
    final neckPath = Path();
    neckPath.moveTo(-3, 0);
    neckPath.lineTo(-2, -9);
    neckPath.lineTo(4, -9);
    neckPath.lineTo(3, 0);
    neckPath.close();
    canvas.drawPath(neckPath, skinPaint);

    // Head / Face Silhouette with nose contour and jawline
    final facePath = Path();
    facePath.moveTo(3, -9); // Base of jaw
    facePath.quadraticBezierTo(-2, -9, -5, -12); // Chin
    facePath.lineTo(-6, -14); // Lower lip
    facePath.lineTo(-5, -15);
    facePath.lineTo(-7, -17); // Nose tip
    facePath.lineTo(-4, -18); // Bridge of nose
    facePath.quadraticBezierTo(-5, -23, -2, -26); // Forehead
    facePath.quadraticBezierTo(5, -28, 8, -24); // Crown of head
    facePath.quadraticBezierTo(9, -15, 6, -10); // Back of head to neck
    facePath.close();
    canvas.drawPath(facePath, skinPaint);

    // Elegant Hair (Top volume + swept ponytail)
    final hairPath = Path();
    hairPath.moveTo(-3, -22);
    hairPath.quadraticBezierTo(-3, -27, 4, -28); // Hair top
    hairPath.quadraticBezierTo(10, -26, 9, -19); // Hair back
    hairPath.lineTo(6, -16);
    // Ponytail tie scrunchie
    hairPath.quadraticBezierTo(13, -16, 17, -11); // Ponytail curve sweeping back and down
    hairPath.quadraticBezierTo(19, -4, 15, 2);
    hairPath.quadraticBezierTo(13, -3, 11, -12);
    hairPath.quadraticBezierTo(8, -13, 2, -18);
    hairPath.close();
    canvas.drawPath(hairPath, hairPaint);

    // Ponytail hair tie detail (coral red)
    canvas.drawCircle(const Offset(9, -17), 2.2, Paint()..color = const Color(0xFFEF4444));

    canvas.restore();
  }

  /// 4. Large Smartphone in Foreground
  void _drawMainSmartphone(Canvas canvas, double w, double h) {
    final phoneRect = Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.44, h * 0.88);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(18));

    // Outer Phone Shadow
    canvas.drawRRect(
      phoneRRect.inflate(2),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.12),
    );

    // Phone Outer Frame / Bezel
    final bezelPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawRRect(phoneRRect, bezelPaint);

    // Phone Screen (Warm Amber Display)
    final screenRect = Rect.fromLTWH(phoneRect.left + 5.5, phoneRect.top + 14, phoneRect.width - 11, phoneRect.height - 30);
    final screenRRect = RRect.fromRectAndRadius(screenRect, const Radius.circular(12));

    final screenGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFFEF08A), // Light Amber
        Color(0xFFFDE047), // Vibrant Warm Yellow
      ],
    );
    canvas.drawRRect(
      screenRRect,
      Paint()..shader = screenGradient.createShader(screenRect),
    );

    // Top speaker slit
    final speakerRect = Rect.fromCenter(
      center: Offset(phoneRect.center.dx, phoneRect.top + 7.5),
      width: 42,
      height: 3.5,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(speakerRect, const Radius.circular(2)), Paint()..color = Colors.white70);

    // Bottom Home Button Circle
    canvas.drawCircle(
      Offset(phoneRect.center.dx, phoneRect.bottom - 9),
      6,
      Paint()..color = Colors.white70,
    );

    // Faint ban watermark on screen background
    final watermarkPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    final screenCenter = screenRect.center;
    canvas.drawCircle(screenCenter, 38, watermarkPaint);
    canvas.drawLine(
      Offset(screenCenter.dx - 27, screenCenter.dy - 27),
      Offset(screenCenter.dx + 27, screenCenter.dy + 27),
      watermarkPaint,
    );

    // Bottom slider button on phone screen
    final sliderRect = Rect.fromCenter(
      center: Offset(screenCenter.dx, screenRect.bottom - 22),
      width: screenRect.width * 0.72,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sliderRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFFB7185).withValues(alpha: 0.85),
    );
    // Arrow in slider
    canvas.drawCircle(
      Offset(sliderRect.right - 10, sliderRect.center.dy),
      6,
      Paint()..color = Colors.white,
    );
    final arrowPath = Path();
    arrowPath.moveTo(sliderRect.right - 12, sliderRect.center.dy - 3);
    arrowPath.lineTo(sliderRect.right - 8, sliderRect.center.dy);
    arrowPath.lineTo(sliderRect.right - 12, sliderRect.center.dy + 3);
    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFFFB7185));
  }

  /// 5. Animated BLOCK Stamp ("मोहर") that stamps onto phone screen
  void _drawBlockStamp(Canvas canvas, double w, double h) {
    final phoneRect = Rect.fromLTWH(w * 0.08, h * 0.06, w * 0.44, h * 0.88);
    final stampCenter = Offset(phoneRect.center.dx, phoneRect.center.dy - 8);

    // Animation cycle:
    // 0.0 - 0.22: Stamp drops from above and slams down
    // 0.22 - 0.45: Impact shockwave ring expands
    // 0.45 - 0.90: Held stamped with heartbeat pulse
    // 0.90 - 1.0: Repeats cycle

    double stampScale = 1.0;
    double rippleProgress = 0.0;

    if (progress < 0.22) {
      final t = progress / 0.22;
      stampScale = 2.4 - (1.4 * Curves.easeOutBack.transform(t));
    } else if (progress < 0.45) {
      final t = (progress - 0.22) / 0.23;
      stampScale = 1.0 + (0.05 * math.sin(t * math.pi));
      rippleProgress = t;
    } else if (progress < 0.90) {
      final t = (progress - 0.45) / 0.45;
      stampScale = 1.0 + (0.025 * math.sin(t * 2 * math.pi));
    } else {
      stampScale = 1.0;
    }

    canvas.save();
    canvas.translate(stampCenter.dx, stampCenter.dy);
    canvas.rotate(-0.24); // ~ -14 degrees dynamic rubber-stamp angle

    // Impact shockwave ripple
    if (rippleProgress > 0) {
      final ripplePaint = Paint()
        ..color = const Color(0xFFDC2626).withValues(alpha: (1.0 - rippleProgress) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(Offset.zero, 40 + (rippleProgress * 28), ripplePaint);
    }

    canvas.scale(stampScale);

    // Solid Vivid Crimson Red Rubber Stamp Color
    const stampColor = Color(0xFFDC2626);

    // Outer Thick Stamp Ring
    final outerRingPaint = Paint()
      ..color = stampColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2;
    canvas.drawCircle(Offset.zero, 38, outerRingPaint);

    // Inner Stamp Ring
    final innerRingPaint = Paint()
      ..color = stampColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset.zero, 33, innerRingPaint);

    // Star emblems in stamp
    final starPaint = Paint()..color = stampColor;
    canvas.drawCircle(const Offset(0, -25), 2.5, starPaint);
    canvas.drawCircle(const Offset(0, 25), 2.5, starPaint);

    // Solid Red Center Banner
    final bannerRect = Rect.fromCenter(center: Offset.zero, width: 70, height: 23);
    final bannerPaint = Paint()..color = stampColor;
    canvas.drawRRect(RRect.fromRectAndRadius(bannerRect, const Radius.circular(5)), bannerPaint);

    // Crisp White "BLOCKED" Text in the Stamp
    final tp = TextPainter(
      text: const TextSpan(
        text: 'BLOCKED',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlockedIllustrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
