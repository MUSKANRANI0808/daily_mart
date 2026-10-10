import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../dashboards/seller_dashboard.dart';
import 'seller_accounts_screen.dart';
import 'seller_masters_screen.dart';
import 'seller_order_cart_screen.dart';
import 'seller_profile_screen.dart';

class SellerMainNavScreen extends StatefulWidget {
  final UserModel seller;
  final int initialTab;

  const SellerMainNavScreen({
    super.key,
    required this.seller,
    this.initialTab = 0,
  });

  @override
  State<SellerMainNavScreen> createState() => _SellerMainNavScreenState();
}

class _SellerMainNavScreenState extends State<SellerMainNavScreen> {
  late int _currentIndex;
  int _cartBadgeCount = 0;
  Timer? _cartPoller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _updateCartBadge();
    _cartPoller = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      _updateCartBadge();
    });
  }

  @override
  void dispose() {
    _cartPoller?.cancel();
    super.dispose();
  }

  Future<void> _updateCartBadge() async {
    final sellerUser = (widget.seller.username ?? widget.seller.mobile ?? '').trim();
    if (sellerUser.isEmpty) return;

    try {
      final orders = await AuthService.getSellerCustomerOrders(sellerUser);
      int unreadyPendingCount = 0;
      for (var o in orders) {
        final st = (o['order_status'] ?? o['status'] ?? 'PENDING').toString().toUpperCase();
        final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        final isDelivered = st == 'DELIVERED' || delSt == 'DELIVERED';
        final isCancelled = st == 'CANCELLED' || st == 'DELETED';
        final isReady = st == 'READY';

        if (!isDelivered && !isCancelled && !isReady) {
          unreadyPendingCount++;
        }
      }

      if (mounted && unreadyPendingCount != _cartBadgeCount) {
        setState(() {
          _cartBadgeCount = unreadyPendingCount;
        });
      }
    } catch (_) {}
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444), size: 22),
                SizedBox(width: 8),
                Text('Exit App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: const Text(
              'Are you sure you want to exit Daily Mart?',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SellerDashboard(seller: widget.seller),
      SellerAccountsScreen(seller: widget.seller),
      SellerMastersScreen(seller: widget.seller),
      SellerOrderCartScreen(seller: widget.seller),
      SellerProfileScreen(seller: widget.seller),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Builder(
          builder: (context) {
            final bottomInset = MediaQuery.of(context).padding.bottom;

            return SizedBox(
              height: 64 + bottomInset,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 1. Curved White Bottom Bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60 + bottomInset,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, -4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                        border: const Border(
                          top: BorderSide(color: Color(0xFFFEE2E2), width: 1.2),
                        ),
                      ),
                    ),
                  ),

                  // 2. Dynamic Nav Items (Active Tab gets elevated red circle with pink aura)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset,
                    height: 64,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildSellerNavItem(
                          index: 0,
                          icon: Icons.home_rounded,
                          label: 'Home',
                        ),
                        _buildSellerNavItem(
                          index: 1,
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Account',
                        ),
                        _buildSellerNavItem(
                          index: 2,
                          icon: Icons.grid_view_rounded,
                          label: 'Master',
                        ),
                        _buildSellerNavItem(
                          index: 3,
                          icon: Icons.receipt_long_rounded,
                          label: 'Order',
                          badgeCount: _cartBadgeCount,
                        ),
                        _buildSellerNavItem(
                          index: 4,
                          icon: Icons.person_rounded,
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerNavItem({
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentIndex == index) return;
          setState(() {
            _currentIndex = index;
          });
          _updateCartBadge();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isSelected
              ? OverflowBox(
                  key: ValueKey('active_seller_$index'),
                  minHeight: 0,
                  maxHeight: 120,
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -11),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Floating Pink Aura Ring + Vibrant Red Gradient Circle
                        Container(
                          width: 46,
                          height: 46,
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFE4E6), // Soft Pink Aura Ring
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 21,
                                ),
                                if (badgeCount > 0)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$badgeCount',
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : OverflowBox(
                  key: ValueKey('inactive_seller_$index'),
                  minHeight: 0,
                  maxHeight: 120,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icon,
                            size: 22,
                            color: const Color(0xFF64748B),
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              top: -5,
                              right: -8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$badgeCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

