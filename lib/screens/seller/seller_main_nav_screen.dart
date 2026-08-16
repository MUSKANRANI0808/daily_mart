import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../dashboards/seller_dashboard.dart';
import 'seller_accounts_screen.dart';
import 'seller_order_cart_screen.dart';
import 'seller_products_screen.dart';
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
      SellerProductsScreen(seller: widget.seller),
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
              _updateCartBadge();
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF8B5CF6),
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10.5),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, size: 25),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_rounded),
                activeIcon: Icon(Icons.account_balance_wallet_rounded, size: 25),
                label: 'Account',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_rounded),
                activeIcon: Icon(Icons.inventory_2_rounded, size: 25),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: _cartBadgeCount > 0
                    ? Badge(
                        label: Text('$_cartBadgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF10B981),
                        child: const Icon(Icons.receipt_long_rounded),
                      )
                    : const Icon(Icons.receipt_long_rounded),
                activeIcon: _cartBadgeCount > 0
                    ? Badge(
                        label: Text('$_cartBadgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF10B981),
                        child: const Icon(Icons.receipt_long_rounded, size: 25),
                      )
                    : const Icon(Icons.receipt_long_rounded, size: 25),
                label: 'Order',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded, size: 25),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
