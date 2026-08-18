import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../dashboards/customer_dashboard.dart';
import '../seller/seller_order_cart_screen.dart';
import 'seller_orders_screen.dart';
import 'profile_screen.dart';

class CustomerMainNavScreen extends StatefulWidget {
  final UserModel customer;
  final int initialTab;

  const CustomerMainNavScreen({
    super.key,
    required this.customer,
    this.initialTab = 0,
  });

  @override
  State<CustomerMainNavScreen> createState() => _CustomerMainNavScreenState();
}

class _CustomerMainNavScreenState extends State<CustomerMainNavScreen> {
  final GlobalKey _sellerOrdersKey = GlobalKey();
  late int _currentIndex;
  Map<String, String>? _lastSeller;
  bool _isLoadingSeller = true;
  int _cartBadgeCount = 0;
  double _cartTotalAmount = 0.0;
  Timer? _cartPoller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkSellerStatus();
    _startCartPoller();
  }

  @override
  void dispose() {
    _cartPoller?.cancel();
    super.dispose();
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
      if (mounted) {
        setState(() {
          _lastSeller = activeSeller;
          _isLoadingSeller = false;
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF10B981), // Emerald Green
            unselectedItemColor: const Color(0xFF64748B), // Slate Grey
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: _cartTotalAmount > 0
                    ? Badge(
                        label: Text(
                          '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        child: const Icon(Icons.receipt_long_rounded),
                      )
                    : const Icon(Icons.receipt_long_rounded),
                activeIcon: _cartTotalAmount > 0
                    ? Badge(
                        label: Text(
                          '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        child: const Icon(Icons.receipt_long_rounded, size: 26),
                      )
                    : const Icon(Icons.receipt_long_rounded, size: 26),
                label: 'My Order',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded, size: 26),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
