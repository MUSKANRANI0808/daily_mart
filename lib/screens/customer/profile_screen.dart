import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../dashboards/customer_dashboard.dart';
import '../role_selection_screen.dart';
import 'customer_addresses_screen.dart';
import 'search_seller_screen.dart';

enum FlipAxis { horizontal, vertical }

class CustomerProfileScreen extends StatefulWidget {
  final UserModel customer;

  const CustomerProfileScreen({super.key, required this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> with SingleTickerProviderStateMixin {
  String _addressSubtitle = 'Home, Work, Other';
  late String _currentName;
  String _selectedSellerUsername = '';
  String _selectedSellerName = '';
  String _selectedSellerMobile = '';

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  FlipAxis _currentFlipAxis = FlipAxis.horizontal;

  @override
  void initState() {
    super.initState();
    _currentName = widget.customer.name ?? 'Customer';
    _loadProfileAndAddress();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
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

  Future<void> _loadProfileAndAddress() async {
    final mobile = widget.customer.mobile ?? '';

    // Load saved customer profile name if available
    final profile = await AuthService.getCustomerProfile(mobile);
    if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
      final pName = profile['name'].toString().trim();
      if (!pName.startsWith('Customer')) {
        widget.customer.name = pName;
        _currentName = pName;
      }
    }

    // Load active selected seller
    final savedSeller = await AuthService.getLastSelectedSeller();
    if (savedSeller != null) {
      if (mounted) {
        setState(() {
          _selectedSellerUsername = savedSeller['username'] ?? '';
          _selectedSellerName = savedSeller['name'] ?? savedSeller['username'] ?? '';
          _selectedSellerMobile = savedSeller['mobile'] ?? '';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedSellerUsername = '';
          _selectedSellerName = '';
          _selectedSellerMobile = '';
        });
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('customer_addresses_$mobile');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        if (list.isNotEmpty) {
          final defaultAddr = list.firstWhere((a) => a['isDefault'] == true, orElse: () => list.first);
          final tag = defaultAddr['tag'] ?? 'Address';
          final house = defaultAddr['houseNo'] ?? '';
          final city = defaultAddr['city'] ?? '';

          if (mounted) {
            setState(() {
              _addressSubtitle = '$tag: $house, $city (${list.length} Saved)';
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Error parsing profile address subtitle: $e');
      }
    }

    if (mounted) {
      setState(() {
        _addressSubtitle = 'Tap to add Home, Work or Delivery address';
      });
    }
  }

  void _deleteSeller() async {
    final sellerName = _selectedSellerName.isNotEmpty ? _selectedSellerName : 'this seller';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Delete Seller?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$sellerName" from your connected store list?\n\nYou will need to search for this seller again if you wish to re-connect in the future.',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
            label: const Text('Delete 🗑️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.deleteCustomerSellerConnection(
        sellerUsername: _selectedSellerUsername,
        customerMobile: widget.customer.mobile ?? '',
      );
      await AuthService.clearLastSelectedSeller();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seller "$sellerName" removed! 🗑️'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (ctx) => CustomerDashboard(customer: widget.customer),
          ),
          (route) => false,
        );
      }
    }
  }

  void _editCustomerName() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Your Name ✏️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextFormField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final mobile = widget.customer.mobile ?? '';
                await AuthService.saveCustomerProfile(mobile, name: newName);
                widget.customer.name = newName;
                await AuthService.saveUserSession(widget.customer);
                setState(() {
                  _currentName = newName;
                });
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name updated successfully! ✨'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Save Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A), // Dark Slate Navy
              Color(0xFF065F46), // Deep Emerald
              Color(0xFF10B981), // Bright Emerald
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative Background Circle Highlights
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -10,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Card Main Content (Bigger & Taller Layout)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26.0, horizontal: 20.0),
              child: Column(
                children: [
                  // Top Flip Badge Hint
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flip_camera_android_rounded, size: 12, color: Colors.white70),
                          SizedBox(width: 4),
                          Text('Tap to Flip 🔄', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Larger Avatar with Gold-Emerald Ring & Verified Badge
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFF10B981), Colors.white],
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 42,
                          backgroundColor: Color(0xFF0F172A),
                          child: Icon(Icons.person_rounded, size: 52, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Customer Name & Edit Pencil
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _currentName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _editCustomerName,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, size: 17, color: Color(0xFFA7F3D0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Mobile Number Text
                  Text(
                    'Mobile: +91 ${widget.customer.mobile ?? ''}',
                    style: const TextStyle(fontSize: 14.5, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),

                  // Glassmorphic Verified Premium Account Pill Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFFBBF24)),
                        SizedBox(width: 7),
                        Text(
                          'Verified Premium Account',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ],
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
              Color(0xFF1E293B), // Midnight Slate
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
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
                            Icon(Icons.badge_rounded, color: Color(0xFF34D399), size: 18),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'DAILY MART VIP PASS 💳',
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                        ),
                        child: const Text('ACTIVE ✅', style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
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
                              _currentName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: DM-CUST-${widget.customer.mobile ?? '812885'}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Member Tier: VIP Platinum 💎',
                              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Priority Express Support',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
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
                        'Scan at Merchant Store',
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
            Icon(Icons.person_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

            // Full-Width Edge-to-Edge Profile Options Menu Container (0 side margin)
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
                    icon: Icons.location_on_rounded,
                    title: 'Saved Delivery Addresses',
                    subtitle: _addressSubtitle,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerAddressesScreen(customer: widget.customer),
                        ),
                      );
                      _loadProfileAndAddress();
                    },
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.notifications_rounded,
                    title: 'Order Notifications',
                    subtitle: 'SMS, WhatsApp, App Alert',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.language_rounded,
                    title: 'App Language',
                    subtitle: 'Hindi / English',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Customer Care',
                    subtitle: '24/7 Support Desk',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // My Selected Seller Card with Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Selected Seller 🏪', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedSellerName.isNotEmpty ? _selectedSellerName : 'No Seller Selected',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (_selectedSellerMobile.isNotEmpty)
                              Text('Mobile: +91 $_selectedSellerMobile', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF8B5CF6)),
                            label: const Text('Switch', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              await AuthService.clearLastSelectedSeller();
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => CustomerDashboard(customer: widget.customer),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                          if (_selectedSellerName.isNotEmpty && _selectedSellerName != 'No Seller Selected') ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _deleteSeller,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                    'Logout from Daily Mart',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Daily Mart App v2.4 • Powered by AntiGravity', style: TextStyle(color: Colors.black45, fontSize: 11)),
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
        child: Icon(icon, color: const Color(0xFF10B981)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
