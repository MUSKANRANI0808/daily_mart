import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/blocked_customer_screen.dart';
import '../dashboards/customer_dashboard.dart';
import '../seller/seller_order_cart_screen.dart';
import 'seller_orders_screen.dart';
import 'profile_screen.dart';

class CustomerMainNavScreen extends StatefulWidget {
  final UserModel customer;
  final int initialTab;
  final Map<String, String>? initialSeller;

  const CustomerMainNavScreen({
    super.key,
    required this.customer,
    this.initialTab = 0,
    this.initialSeller,
  });

  @override
  State<CustomerMainNavScreen> createState() => _CustomerMainNavScreenState();
}

class _CustomerMainNavScreenState extends State<CustomerMainNavScreen> {
  final GlobalKey _sellerOrdersKey = GlobalKey();
  final GlobalKey<SellerOrderCartScreenState> _cartScreenKey = GlobalKey<SellerOrderCartScreenState>();
  late int _currentIndex;
  Map<String, String>? _lastSeller;
  bool _isLoadingSeller = true;
  int _cartBadgeCount = 0;
  double _cartTotalAmount = 0.0;
  Timer? _cartPoller;
  Timer? _blockedStatusPoller;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkBlockedStatus();
    _blockedStatusPoller = Timer.periodic(const Duration(seconds: 4), (_) => _checkBlockedStatus());

    if (widget.initialSeller != null && (widget.initialSeller!['username'] ?? '').isNotEmpty) {
      _lastSeller = widget.initialSeller;
      _isLoadingSeller = false;
      AuthService.getSellerWelcomePopupImage(_lastSeller!['username']!);
      _syncInitialCart();
    }
    _checkSellerStatus();
    _startCartPoller();
    CartService.cartUpdateNotifier.addListener(_onCartStateChanged);
  }

  void _checkBlockedStatus() async {
    final mob = (widget.customer.mobile ?? '').trim();
    if (mob.isEmpty) return;
    final blocked = await AuthService.isCustomerBlockedByAdmin(mob);
    if (mounted && blocked != _isBlocked) {
      setState(() {
        _isBlocked = blocked;
      });
    }
  }

  void _syncInitialCart() async {
    if (_lastSeller != null && (_lastSeller!['username'] ?? '').isNotEmpty) {
      final items = await CartService.getCartItems(_lastSeller!['username']!);
      if (mounted) {
        setState(() {
          _cartBadgeCount = CartService.getTotalCount(items);
          _cartTotalAmount = CartService.getTotalAmount(items);
        });
      }
    }
  }

  @override
  void dispose() {
    _blockedStatusPoller?.cancel();
    CartService.cartUpdateNotifier.removeListener(_onCartStateChanged);
    _cartPoller?.cancel();
    super.dispose();
  }

  void _onCartStateChanged() {
    if (!mounted || _lastSeller == null) return;
    final sellerUsername = _lastSeller!['username'] ?? '';
    if (sellerUsername.isEmpty) return;
    final items = CartService.getCachedCartItems(sellerUsername);
    final totalCount = CartService.getTotalCount(items);
    final totalAmount = CartService.getTotalAmount(items);
    if (totalCount != _cartBadgeCount || totalAmount != _cartTotalAmount) {
      setState(() {
        _cartBadgeCount = totalCount;
        _cartTotalAmount = totalAmount;
      });
      _cartScreenKey.currentState?.refreshCartInstantly();
    }
  }

  void _startCartPoller() {
    _cartPoller = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_lastSeller != null && (_lastSeller!['username'] ?? '').isNotEmpty) {
        final items = await CartService.getCartItems(_lastSeller!['username']!);
        final totalCount = CartService.getTotalCount(items);
        final totalAmount = CartService.getTotalAmount(items);
        if (mounted && (totalCount != _cartBadgeCount || totalAmount != _cartTotalAmount)) {
          setState(() {
            _cartBadgeCount = totalCount;
            _cartTotalAmount = totalAmount;
          });
          _cartScreenKey.currentState?.refreshCartInstantly();
        }
      }
    });
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

  Future<void> _checkSellerStatus() async {
    final seller = await AuthService.getLastSelectedSeller();
    Map<String, String>? activeSeller = seller;

    final prefs = await SharedPreferences.getInstance();
    final cleanCust = (widget.customer.mobile ?? '').trim();
    final List<String> deletedList = prefs.getStringList('deleted_sellers_$cleanCust') ?? [];

    if (activeSeller != null && deletedList.contains(activeSeller['username'])) {
      await AuthService.clearLastSelectedSeller();
      activeSeller = null;
    }

    final bool hasValidSeller = activeSeller != null &&
        (activeSeller['username'] ?? '').isNotEmpty &&
        activeSeller['username'] != 'seller' &&
        !deletedList.contains(activeSeller['username']);

    if (hasValidSeller) {
      // Instant Preload Welcome Popup Image into memory
      AuthService.getSellerWelcomePopupImage(activeSeller['username']!);
      final items = await CartService.getCartItems(activeSeller['username']!);
      final totalCount = CartService.getTotalCount(items);
      final totalAmount = CartService.getTotalAmount(items);
      if (mounted) {
        setState(() {
          _lastSeller = activeSeller;
          _isLoadingSeller = false;
          _cartBadgeCount = totalCount;
          _cartTotalAmount = totalAmount;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _lastSeller = null;
          _isLoadingSeller = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) {
      return BlockedCustomerScreen(
        customerMobile: widget.customer.mobile ?? '',
        customerName: widget.customer.name,
      );
    }

    if (_isLoadingSeller) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    // 1. CUSTOMER HAS NOT ADDED/CONNECTED ANY SELLER YET:
    // Hide Bottom Navigation Bar completely! Render CustomerDashboard search screen.
    if (_lastSeller == null || (_lastSeller!['username'] ?? '').isEmpty) {
      return CustomerDashboard(customer: widget.customer);
    }

    // 2. CUSTOMER HAS ADDED/SELECTED A SELLER:
    // Render 3 Bottom Navigation Bar tabs for this active seller.
    final sellerModel = UserModel(
      id: _lastSeller!['username']!,
      name: _lastSeller!['name']!,
      mobile: _lastSeller!['mobile']!,
      username: _lastSeller!['username']!,
      role: UserRole.seller,
    );

    final List<Widget> pages = [
      CustomerSellerOrdersScreen(
        key: _sellerOrdersKey,
        customer: widget.customer,
        sellerUsername: _lastSeller!['username']!,
        sellerName: _lastSeller!['name']!,
        sellerMobile: _lastSeller!['mobile']!,
        hideBottomNav: true,
      ),
      SellerOrderCartScreen(
        key: _cartScreenKey,
        seller: sellerModel,
        customer: widget.customer,
      ),
      CustomerProfileScreen(customer: widget.customer),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If user is on Home tab (index 0), check if Category or Search filter is active!
        if (_currentIndex == 0) {
          final dynamic ordersState = _sellerOrdersKey.currentState;
          if (ordersState != null) {
            try {
              if (ordersState.hasActiveFilter == true) {
                ordersState.clearFilters();
                return;
              }
            } catch (_) {}
          }
        } else {
          // If user is on My Order tab (index 1) or Profile tab (index 2), go to Home tab first!
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 2. On Home tab AND no category/search filter active -> show Exit App Confirmation Dialog ONLY NOW!
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
            final badgeString = _cartTotalAmount > 0
                ? (_cartTotalAmount >= 100000
                    ? '₹${(_cartTotalAmount / 100000).toStringAsFixed(1)}L'
                    : (_cartTotalAmount >= 10000
                        ? '₹${(_cartTotalAmount / 1000).toStringAsFixed(1)}k'
                        : '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(0)}'))
                : null;

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
                        _buildDynamicNavItem(
                          index: 0,
                          icon: Icons.home_rounded,
                          label: 'Home',
                        ),
                        _buildDynamicNavItem(
                          index: 1,
                          icon: Icons.receipt_long_rounded,
                          label: 'My Order',
                          badgeText: badgeString,
                        ),
                        _buildDynamicNavItem(
                          index: 2,
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

  Widget _buildDynamicNavItem({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentIndex == index) return;
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            _cartScreenKey.currentState?.refreshCartInstantly(showDraftBillTab: true);
          }
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
                  key: ValueKey('active_$index'),
                  minHeight: 0,
                  maxHeight: 120,
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Floating Pink Aura Ring + Vibrant Red Gradient Circle
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(4),
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
                                  size: 23,
                                ),
                                if (badgeText != null)
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
                                        badgeText,
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : OverflowBox(
                  key: ValueKey('inactive_$index'),
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
                            size: 23,
                            color: const Color(0xFF64748B),
                          ),
                          if (badgeText != null)
                            Positioned(
                              top: -6,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
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
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
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
                          fontSize: 10.5,
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

