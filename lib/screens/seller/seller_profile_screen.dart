import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../role_selection_screen.dart';

import 'seller_sliders_screen.dart';

class SellerProfileScreen extends StatefulWidget {
  final UserModel seller;

  const SellerProfileScreen({super.key, required this.seller});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

enum FlipAxis { horizontal, vertical }

class _SellerProfileScreenState extends State<SellerProfileScreen> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _shimmerController;
  bool _isFlipped = false;
  FlipAxis _currentFlipAxis = FlipAxis.horizontal;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _toggleFlipCard({FlipAxis axis = FlipAxis.horizontal}) {
    setState(() {
      _currentFlipAxis = axis;
    });
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildCardFront() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A), // Dark Slate Navy
              Color(0xFF3B0764), // Deep Purple
              Color(0xFF6B21A8), // Bright Royal Violet
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Glass Sheen Diagonal Accent Overlay
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                ),
              ),
            ),

            // Top Header Overlay: Left Category Badge & Right Tap-to-Flip Button
            Positioned(
              top: 14,
              left: 16,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // VIP Business Pass Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFFBBF24)),
                        SizedBox(width: 4),
                        Text(
                          'VIP MERCHANT CARD',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tap to Flip Button
                  InkWell(
                    onTap: () => _toggleFlipCard(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flip_camera_android_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Tap to Flip 🔄', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Centered Content
            Padding(
              padding: const EdgeInsets.only(top: 48.0, bottom: 20.0, left: 16.0, right: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar Circle with Emerald Glow Ring & Verified Badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFF10B981), Colors.white],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 35,
                          backgroundColor: Color(0xFF0F172A),
                          child: Icon(Icons.storefront_rounded, size: 40, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, size: 17, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Store Name
                  Text(
                    widget.seller.name ?? widget.seller.username ?? 'Seller Store',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Single Line Clean Handle & Mobile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '@${widget.seller.username ?? ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFFDE047),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.seller.mobile != null && widget.seller.mobile!.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text('•', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ),
                        const Icon(Icons.phone_iphone_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text(
                          '+91 ${widget.seller.mobile}',
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Badges Row (2 Compact Horizontal Glass Badges)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badge 1: Verified Partner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text(
                              'Verified Partner',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Badge 2: Official Merchant
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF6EE7B7)),
                            SizedBox(width: 4),
                            Text(
                              'Official Merchant',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Continuous Glass Sheen Light Sweep Beam (Chamak Wala Effect!)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final progress = _shimmerController.value;
                    final double left = -1.5 + (progress * 4.0);

                    return FractionallySizedBox(
                      widthFactor: 0.35,
                      alignment: Alignment(left, 0),
                      child: Transform(
                        transform: Matrix4.skewX(-0.35),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A), // Dark Slate Navy
              Color(0xFF3B0764), // Deep Purple
              Color(0xFF0F172A), // Dark Slate Navy
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.store_rounded, color: Color(0xFFC084FC), size: 18),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'OFFICIAL MERCHANT PASS 🏪',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                        ),
                        child: const Text('VERIFIED ⚡', style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 76, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.seller.name ?? widget.seller.username ?? 'Seller Store',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'STORE: @${widget.seller.username ?? ''}',
                              style: const TextStyle(color: Color(0xFFC084FC), fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mobile: +91 ${widget.seller.mobile ?? ''}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Instant Chat Connected 💬',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Direct Store QR Code',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.flip_camera_android_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Tap to Flip Back 🔄', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Continuous Glass Sheen Light Sweep Beam (Chamak Wala Effect!)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    final progress = _shimmerController.value;
                    final double left = -1.5 + (progress * 4.0);

                    return FractionallySizedBox(
                      widthFactor: 0.35,
                      alignment: Alignment(left, 0),
                      child: Transform(
                        transform: Matrix4.skewX(-0.35),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.store_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 10),
            Text('Seller Business Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Interactive 3D Flip Header Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: GestureDetector(
                onTap: () => _toggleFlipCard(axis: FlipAxis.horizontal),
                onPanEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond;
                  final dx = velocity.dx.abs();
                  final dy = velocity.dy.abs();

                  if (dx > dy && dx > 80) {
                    // Left-to-Right or Right-to-Left Drag
                    _toggleFlipCard(axis: FlipAxis.horizontal);
                  } else if (dy > dx && dy > 80) {
                    // Top-to-Bottom or Bottom-to-Top Drag
                    _toggleFlipCard(axis: FlipAxis.vertical);
                  } else {
                    // Fallback tap toggle
                    _toggleFlipCard(axis: FlipAxis.horizontal);
                  }
                },
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * 3.141592653589793;
                    final isBack = angle >= (3.141592653589793 / 2);

                    final transform = Matrix4.identity()..setEntry(3, 2, 0.001);
                    if (_currentFlipAxis == FlipAxis.horizontal) {
                      transform.rotateY(angle);
                    } else {
                      transform.rotateX(angle);
                    }

                    final backTransform = Matrix4.identity();
                    if (_currentFlipAxis == FlipAxis.horizontal) {
                      backTransform.rotateY(3.141592653589793);
                    } else {
                      backTransform.rotateX(3.141592653589793);
                    }

                    return Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child: isBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: backTransform,
                              child: _buildCardBack(),
                            )
                          : _buildCardFront(),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Full-Width Edge-to-Edge Options Menu Container (0 side margin)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.view_carousel_rounded,
                    title: 'Manage Promo Banners & Sliders',
                    subtitle: 'Add offer tags, heading, paragraph & images',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SellerSlidersScreen(seller: widget.seller)),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.store_mall_directory_rounded,
                    title: 'Store Settings & Timings',
                    subtitle: 'Open 8:00 AM - 10:00 PM',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.delivery_dining_rounded,
                    title: 'Delivery Zone & Minimum Order',
                    subtitle: 'Within 5 km radius',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.qr_code_2_rounded,
                    title: 'Store QR & Link',
                    subtitle: 'Share store chat with customers',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.payments_rounded,
                    title: 'Payment & Bank Account',
                    subtitle: 'UPI & Cash on Delivery',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button with Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text(
                    'Logout Seller Account',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Daily Mart Merchant v2.4 • Powered by AntiGravity', style: TextStyle(color: Colors.black45, fontSize: 11)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF8B5CF6)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
