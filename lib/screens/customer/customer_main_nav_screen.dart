import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../dashboards/customer_dashboard.dart';
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
  late int _currentIndex;
  Map<String, String>? _lastSeller;
  bool _isLoadingSeller = true;
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _checkSellerStatus();
    _startPopupTimer();
  }

  void _startPopupTimer() {
    _popupTimer?.cancel();
    _popupTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPopupNotifications());
  }

  void _checkPopupNotifications() async {
    if (!mounted) return;
    final unreads = await AuthService.getAndConsumeUnreadPopupNotifications(
      role: 'customer',
      usernameOrMobile: widget.customer.mobile ?? '',
    );
    if (unreads.isNotEmpty && mounted) {
      for (var notif in unreads) {
        AuthService.showAppNotificationDialog(context, notif);
      }
    }
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
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

    if (activeSeller == null) {
      final chats = await AuthService.getCustomerConversations(cleanCust);
      final validChats = chats.where((c) => !deletedList.contains((c['seller_username'] ?? '').toString().trim())).toList();
      if (validChats.isNotEmpty) {
        final firstChat = validChats.first;
        final sUsername = (firstChat['seller_username'] ?? '').toString().trim();
        final sName = (firstChat['seller_name'] ?? sUsername).toString().trim();
        final sMobile = (firstChat['seller_mobile'] ?? '').toString().trim();
        if (sUsername.isNotEmpty && sUsername != 'seller') {
          await AuthService.saveLastSelectedSeller(username: sUsername, name: sName, mobile: sMobile, customerMobile: cleanCust);
          activeSeller = await AuthService.getLastSelectedSeller();
        }
      }
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
    // Render Bottom Navigation Bar for this active seller.
    final List<Widget> pages = [
      CustomerSellerOrdersScreen(
        customer: widget.customer,
        sellerUsername: _lastSeller!['username']!,
        sellerName: _lastSeller!['name']!,
        sellerMobile: _lastSeller!['mobile']!,
        hideBottomNav: true,
      ),
      CustomerProfileScreen(customer: widget.customer),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If user is not on Home tab (index 0), navigate to Home tab first!
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // If user is already on Home tab, show Exit Confirmation Dialog!
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
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
