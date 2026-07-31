import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/apitxt_otp_service.dart';
import '../role_selection_screen.dart';

class DeliveryBoyDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> deliveryBoy;

  const DeliveryBoyDashboardScreen({
    super.key,
    required this.deliveryBoy,
  });

  @override
  State<DeliveryBoyDashboardScreen> createState() => _DeliveryBoyDashboardScreenState();
}

class _DeliveryBoyDashboardScreenState extends State<DeliveryBoyDashboardScreen> {
  bool _isOnline = true;
  List<Map<String, dynamic>> _groupedSellerOrders = [];
  bool _isLoading = true;
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    _loadDeliveryData();
    _startPopupTimer();
  }

  void _startPopupTimer() {
    _popupTimer?.cancel();
    _popupTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkPopupNotifications());
  }

  void _checkPopupNotifications() async {
    if (!mounted) return;
    final unreads = await AuthService.getAndConsumeUnreadPopupNotifications(
      role: 'delivery_boy',
      usernameOrMobile: widget.deliveryBoy['username']?.toString() ?? '',
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

  Future<void> _loadDeliveryData() async {
    setState(() => _isLoading = true);
    final groupedData = await AuthService.getAllUndeliveredOrdersGroupedBySeller();
    if (mounted) {
      setState(() {
        _groupedSellerOrders = groupedData;
        _isLoading = false;
      });
    }
  }

  void _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isNotEmpty) {
      final Uri uri = Uri.parse('tel:$cleanPhone');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (e) {
        debugPrint('Error launching phone call: $e');
      }
    }
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Logout Delivery Portal?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Do you want to log out and return to the main Role Selection Screen?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout & Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
    return false;
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout Delivery Portal?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out and go to Role Selection?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.deliveryBoy['name'] ?? 'Delivery Partner';
    final mobile = widget.deliveryBoy['mobile'] ?? '';
    final vehicle = widget.deliveryBoy['vehicle'] ?? 'Bike';

    int totalUndeliveredCount = 0;
    for (var group in _groupedSellerOrders) {
      final orders = (group['orders'] as List?) ?? [];
      totalUndeliveredCount += orders.length;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEA580C),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$vehicle • $mobile',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFDBA74)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _isOnline ? const Color(0xFF34D399) : Colors.grey,
                ),
              ),
              Switch(
                value: _isOnline,
                activeTrackColor: const Color(0xFF34D399).withValues(alpha: 0.4),
                activeColor: const Color(0xFF34D399),
                onChanged: (val) => setState(() => _isOnline = val),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: !_isOnline
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.do_not_disturb_on_rounded,
                        size: 60,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You are Currently OFFLINE (Off Duty) ⏸️',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Turn ON the toggle switch at the top right to go ON-DUTY and view live seller delivery orders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 18),
                      label: const Text('Go ONLINE Now 🟢', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _isOnline = true),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDeliveryData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                  : _groupedSellerOrders.isEmpty
                      ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                size: 60,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'All Deliveries Completed! 🎉',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'There are no pending orders right now. Pull down to refresh.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                              label: const Text('Refresh Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              onPressed: _loadDeliveryData,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    children: [
                      // Executive Header Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDBA74).withValues(alpha: 0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFEA580C)),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Color(0xFFF97316), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_groupedSellerOrders.length} Active Seller${_groupedSellerOrders.length == 1 ? '' : 's'} Available',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalUndeliveredCount Customer Order${totalUndeliveredCount == 1 ? '' : 's'} Ready for Pick Up',
                                    style: const TextStyle(color: Color(0xFFFDBA74), fontWeight: FontWeight.w600, fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Seller List Cards (Modern Sleek Compact Design)
                      ..._groupedSellerOrders.map((sellerGroup) {
                        final sellerName = sellerGroup['seller_name'] ?? 'Seller Store';
                        final sellerMobile = sellerGroup['seller_mobile'] ?? '';
                        final orders = (sellerGroup['orders'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SellerCustomerDeliveriesScreen(
                                      sellerName: sellerName,
                                      sellerMobile: sellerMobile,
                                      orders: orders,
                                      deliveryBoyUsername: widget.deliveryBoy['username'] ?? '',
                                    ),
                                  ),
                                );
                                _loadDeliveryData();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    // Left Gradient Storefront Icon
                                    Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 14),

                                    // Center Seller Info Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sellerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF7ED),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFFDBA74)),
                                                ),
                                                child: Text(
                                                  '${orders.length} Order${orders.length == 1 ? '' : 's'} Pending',
                                                  style: const TextStyle(
                                                    color: Color(0xFFC2410C),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (sellerMobile.isNotEmpty)
                                                Text(
                                                  '+91 $sellerMobile',
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w500),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Call Button
                                    if (sellerMobile.isNotEmpty)
                                      Material(
                                        color: const Color(0xFFDCFCE7),
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _makePhoneCall(sellerMobile),
                                          child: const Padding(
                                            padding: EdgeInsets.all(9),
                                            child: Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 18),
                                          ),
                                        ),
                                      ),

                                    const SizedBox(width: 8),

                                    // Sleek Chevron Arrow Pill
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFFEDD5)),
                                      ),
                                      child: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEA580C), size: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
      ),
    ),
  );
}
}

/// DEDICATED SCREEN: Customer Deliveries for Selected Seller
class SellerCustomerDeliveriesScreen extends StatefulWidget {
  final String sellerName;
  final String sellerMobile;
  final List<Map<String, dynamic>> orders;
  final String deliveryBoyUsername;

  const SellerCustomerDeliveriesScreen({
    super.key,
    required this.sellerName,
    required this.sellerMobile,
    required this.orders,
    required this.deliveryBoyUsername,
  });

  @override
  State<SellerCustomerDeliveriesScreen> createState() => _SellerCustomerDeliveriesScreenState();
}

class _SellerCustomerDeliveriesScreenState extends State<SellerCustomerDeliveriesScreen> {
  late List<Map<String, dynamic>> _currentOrders;
  Map<String, String> _customerNamesMap = {};

  @override
  void initState() {
    super.initState();
    _currentOrders = List.from(widget.orders);
    _loadCustomerNames();
  }

  void _loadCustomerNames() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> loadedMap = {};

    // 1. Check order delivery details for receiver names
    try {
      final str = prefs.getString('saved_order_delivery_details');
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> deliveryDetails = Map<String, dynamic>.from(jsonDecode(str));
        deliveryDetails.forEach((key, value) {
          if (value is Map && value['address'] is Map) {
            final addr = Map<String, dynamic>.from(value['address']);
            final recName = (addr['receiverName'] ?? addr['name'] ?? '').toString().trim();
            if (recName.isNotEmpty) {
              loadedMap[key] = recName;
            }
          }
        });
      }
    } catch (_) {}

    // 2. Check saved customer addresses for each unique mobile
    final Set<String> mobiles = _currentOrders.map((o) => (o['customer_mobile'] ?? '').toString().trim()).where((m) => m.isNotEmpty).toSet();
    for (var mobile in mobiles) {
      try {
        final String key = 'customer_addresses_$mobile';
        final String? addressesJson = prefs.getString(key);
        if (addressesJson != null && addressesJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(addressesJson);
          for (var item in decoded) {
            if (item is Map) {
              final recName = (item['receiverName'] ?? item['name'] ?? '').toString().trim();
              if (recName.isNotEmpty) {
                loadedMap[mobile] = recName;
                break;
              }
            }
          }
        }
      } catch (_) {}

      // 3. Check direct profile name keys
      try {
        final profName = prefs.getString('customer_name_$mobile') ?? prefs.getString('customer_profile_name_$mobile');
        if (profName != null && profName.trim().isNotEmpty) {
          loadedMap[mobile] = profName.trim();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _customerNamesMap = loadedMap;
      });
    }
  }

  void _updateDeliveryStatus(Map<String, dynamic> order, String newStatus) async {
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final sellerUsername = (order['seller_username'] ?? '').toString();
    final customerMobile = (order['customer_mobile'] ?? '').toString();

    await AuthService.updateDeliveryStatusForOrder(
      sellerUsername: sellerUsername,
      customerMobile: customerMobile,
      messageId: msgId,
      newDeliveryStatus: newStatus,
      deliveryBoyUsername: widget.deliveryBoyUsername,
    );

    final String boyName = (widget.deliveryBoyUsername.isNotEmpty ? widget.deliveryBoyUsername : 'Delivery Boy');

    if (newStatus == 'Out for Delivery') {
      AuthService.createPopupNotification(
        targetRole: 'customer',
        targetUser: customerMobile,
        title: '🛵 Order Picked Up!',
        body: 'Delivery Boy $boyName has picked up your Order #$msgId and is on the way.',
        type: 'order_picked_up',
      );
      AuthService.createPopupNotification(
        targetRole: 'seller',
        targetUser: sellerUsername,
        title: '🛵 Order Picked Up by Delivery Boy!',
        body: 'Delivery Boy $boyName picked up Order #$msgId.',
        type: 'order_picked_up',
      );
    } else if (newStatus == 'Delivered') {
      AuthService.createPopupNotification(
        targetRole: 'customer',
        targetUser: customerMobile,
        title: '🎉 Order Delivered Successfully!',
        body: 'Your Order #$msgId has been delivered.',
        type: 'order_delivered',
      );
      AuthService.createPopupNotification(
        targetRole: 'seller',
        targetUser: sellerUsername,
        title: '✅ Order Delivered to Customer!',
        body: 'Delivery Boy $boyName successfully delivered Order #$msgId.',
        type: 'order_delivered',
      );
    }

    setState(() {
      if (newStatus == 'Delivered') {
        _currentOrders.removeWhere((o) => (o['id'] as num?)?.toInt() == msgId);
      } else {
        for (var o in _currentOrders) {
          if ((o['id'] as num?)?.toInt() == msgId) {
            o['delivery_status'] = newStatus;
          }
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'Delivered'
              ? 'Order Delivered Successfully! ✅'
              : 'Status updated to $newStatus 🚀'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _collectCashPayment(Map<String, dynamic> order, double amount) async {
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final sellerUsername = (order['seller_username'] ?? '').toString();
    final customerMobile = (order['customer_mobile'] ?? '').toString();
    final amtStr = (amount % 1 == 0) ? amount.toInt().toString() : amount.toStringAsFixed(2);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Confirm Cash Payment', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Did customer pay ₹ $amtStr in CASH?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cash Received 💵', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.markOrderPaid(
        sellerUsername: sellerUsername,
        customerMobile: customerMobile,
        messageId: msgId,
        utrNumber: 'CASH',
        amount: amount,
      );

      setState(() {
        order['payment_status'] = 'paid';
        order['payment_utr'] = 'CASH';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash Payment Recorded! Order marked PAID ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _showUpiQrPaymentModal(Map<String, dynamic> order, double amount) async {
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final sellerUsername = (order['seller_username'] ?? '').toString();
    final customerMobile = (order['customer_mobile'] ?? '').toString();
    final rawOrderId = (order['order_id'] ?? order['_calculated_order_id'] ?? msgId.toString()).toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();
    final amtStr = (amount % 1 == 0) ? amount.toInt().toString() : amount.toStringAsFixed(2);

    // Show quick progress while generating official Razorpay payment link
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
    );

    // 1. Create Official Razorpay Payment Link returning both short_url & plink_id
    final rzpDetails = await AuthService.createRazorpayPaymentLinkDetails(
      amount: amount > 0 ? amount : 1.0,
      orderId: cleanOrderId,
      customerMobile: customerMobile,
      customerName: 'Customer',
    );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
    }

    final rzpPaymentUrl = rzpDetails?['short_url'] ?? 'https://razorpay.me/@pushprajgupta';
    final plinkId = rzpDetails?['plink_id'] ?? '';
    final targetQrData = rzpPaymentUrl;
    final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(targetQrData)}';

    Timer? autoVerifyTimer;
    bool isPaymentVerified = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            autoVerifyTimer ??= Timer.periodic(const Duration(seconds: 2), (timer) async {
              if (isPaymentVerified) {
                timer.cancel();
                return;
              }

              // Check 1: Direct Razorpay API for this payment link (Fetch Real Payment ID / Bank UTR)
              String? realUtr;
              if (plinkId.isNotEmpty) {
                realUtr = await AuthService.checkRazorpayPaymentLinkRealUtr(plinkId);
              }

              // Check 2: Fallback VPS / Local verification
              final bool verified = (realUtr != null && realUtr.isNotEmpty) ||
                  await AuthService.verifyRazorpayPaymentViaApi(
                    orderId: cleanOrderId,
                    expectedAmount: amount,
                  );

              if (verified && modalContext.mounted && !isPaymentVerified) {
                isPaymentVerified = true;
                timer.cancel();

                final finalUtr = (realUtr != null && realUtr.isNotEmpty)
                    ? realUtr
                    : 'PAY_${cleanOrderId}_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                await AuthService.markOrderPaid(
                  sellerUsername: sellerUsername,
                  customerMobile: customerMobile,
                  messageId: msgId,
                  utrNumber: finalUtr,
                  amount: amount,
                );

                if (mounted) {
                  setState(() {
                    order['payment_status'] = 'paid';
                    order['payment_utr'] = finalUtr;
                  });

                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Razorpay Payment Verified! Order marked PAID ✅ (UTR: $finalUtr)'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              }
            });

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Razorpay Official Payment QR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan with PhonePe, Google Pay, Paytm or Camera',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrImageUrl,
                            width: 190,
                            height: 190,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 190,
                                height: 190,
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 190,
                                height: 190,
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2_rounded, size: 70, color: Color(0xFF0F172A)),
                                      SizedBox(height: 6),
                                      Text('Pushpraj Gupta • Razorpay', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'AMOUNT: ₹ $amtStr',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Order #$cleanOrderId • Razorpay Secured 🔒',
                          style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Real-Time Automatic Payment Detector Status Bar (With Flexible layout fix)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Waiting for payment... (Auto Detecting)',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Manual Confirmation Link (Backup)
                  TextButton(
                    onPressed: () async {
                      autoVerifyTimer?.cancel();
                      final autoUtr = 'UPI${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
                      await AuthService.markOrderPaid(
                        sellerUsername: sellerUsername,
                        customerMobile: customerMobile,
                        messageId: msgId,
                        utrNumber: autoUtr,
                        amount: amount,
                      );

                      setState(() {
                        order['payment_status'] = 'paid';
                        order['payment_utr'] = autoUtr;
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment Confirmed (UTR: $autoUtr)! Order marked PAID ✅'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Payment received? Confirm Manually',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      autoVerifyTimer?.cancel();
    });
  }

  void _showCustomerDetailsBottomSheet(Map<String, dynamic> order) async {
    final customerMobile = (order['customer_mobile'] ?? '').toString();
    final customerName = (order['customer_name'] ?? order['name'] ?? customerMobile).toString();
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    final rawOrderId = (order['order_id'] ?? order['_calculated_order_id'] ?? msgId.toString()).toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();

    final prefs = await SharedPreferences.getInstance();

    // 1. Fetch saved addresses list for fallback
    final String key = 'customer_addresses_$customerMobile';
    final String? addressesJson = prefs.getString(key);
    List<Map<String, dynamic>> savedAddresses = [];
    if (addressesJson != null && addressesJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(addressesJson);
        savedAddresses = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // 2. Fetch specific address and distance chosen when order was sent
    Map<String, dynamic> deliveryDetailsMap = {};
    try {
      final str = prefs.getString('saved_order_delivery_details');
      if (str != null && str.isNotEmpty) {
        deliveryDetailsMap = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    Map<String, dynamic>? specificOrderDetails;
    if (deliveryDetailsMap.containsKey(cleanOrderId) && deliveryDetailsMap[cleanOrderId] is Map) {
      specificOrderDetails = Map<String, dynamic>.from(deliveryDetailsMap[cleanOrderId]);
    } else if (deliveryDetailsMap.containsKey(rawOrderId) && deliveryDetailsMap[rawOrderId] is Map) {
      specificOrderDetails = Map<String, dynamic>.from(deliveryDetailsMap[rawOrderId]);
    } else if (deliveryDetailsMap.containsKey(msgId.toString()) && deliveryDetailsMap[msgId.toString()] is Map) {
      specificOrderDetails = Map<String, dynamic>.from(deliveryDetailsMap[msgId.toString()]);
    }

    final String? orderDistance = specificOrderDetails?['distance']?.toString();
    Map<String, dynamic>? chosenAddressMap;

    // Direct order object check first
    if (order['address'] is Map) {
      chosenAddressMap = Map<String, dynamic>.from(order['address']);
    } else if (order['selected_address'] is Map) {
      chosenAddressMap = Map<String, dynamic>.from(order['selected_address']);
    } else if (order['delivery_address'] is Map) {
      chosenAddressMap = Map<String, dynamic>.from(order['delivery_address']);
    } else if (specificOrderDetails?['address'] is Map) {
      chosenAddressMap = Map<String, dynamic>.from(specificOrderDetails!['address']);
    } else if (savedAddresses.isNotEmpty) {
      // Fallback: Pick ONLY 1 default address, never list multiple addresses
      chosenAddressMap = savedAddresses.firstWhere((a) => a['isDefault'] == true, orElse: () => savedAddresses.first);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.70,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF8B5CF6),
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName.isNotEmpty ? customerName : 'Customer Profile',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mobile: +91 $customerMobile',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Verified Customer Account',
                                style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons Row: [ Delivered ✅ ] | [ Cancel Order ❌ ]
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          label: const Text('Delivered ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _requireCustomerOtpAndProceed(
                              order: order,
                              actionTitle: 'Delivery',
                              onVerified: () async => _updateDeliveryStatus(order, 'Delivered'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                          label: const Text('Cancel Order ❌', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCancelOrderDialog(order);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Distance Badge (If Distance was entered when sending order)
                  if (orderDistance != null && orderDistance.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten_rounded, color: Color(0xFFC2410C), size: 20),
                          const SizedBox(width: 10),
                          const Text('Distance to Seller:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFFC2410C))),
                          const SizedBox(width: 6),
                          Text(orderDistance, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF9A3412))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Delivery Address Header (Only Single Selected Address Shown)
                  const Text('Customer Delivery Address 📍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),

                  if (chosenAddressMap != null) ...[
                    // Render the exact SINGLE address chosen for this specific order
                    Builder(builder: (context) {
                      final tag = chosenAddressMap!['tag'] ?? 'Selected Address';
                      final houseNo = (chosenAddressMap['houseNo'] ?? '').toString();
                      final building = (chosenAddressMap['building'] ?? '').toString();
                      final locality = (chosenAddressMap['locality'] ?? '').toString();
                      final landmark = (chosenAddressMap['landmark'] ?? '').toString();
                      final city = (chosenAddressMap['city'] ?? '').toString();
                      final pincode = (chosenAddressMap['pincode'] ?? '').toString();
                      final receiver = (chosenAddressMap['receiverName'] ?? chosenAddressMap['name'] ?? customerName).toString();
                      final phone = (chosenAddressMap['mobile'] ?? customerMobile).toString();

                      final fullAddressString = (chosenAddressMap['fullAddressString'] ?? '').toString();

                      final fullAddress = fullAddressString.isNotEmpty
                          ? fullAddressString
                          : [
                              if (houseNo.isNotEmpty) houseNo,
                              if (building.isNotEmpty) building,
                              if (locality.isNotEmpty) locality,
                              if (landmark.isNotEmpty) 'Near $landmark',
                              if (city.isNotEmpty) city,
                              if (pincode.isNotEmpty) 'PIN: $pincode',
                            ].join(', ');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(tag.toString().toUpperCase(), style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF9C3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('ORDER ADDRESS 📍', style: TextStyle(color: Color(0xFFA16207), fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: '$receiver\n$fullAddress\nPhone: +91 $phone'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Address copied to clipboard! 📋'), backgroundColor: Color(0xFF10B981)),
                                    );
                                  },
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, size: 14, color: Color(0xFF10B981)),
                                      SizedBox(width: 4),
                                      Text('Copy', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (receiver.isNotEmpty)
                              Text(receiver, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                            const SizedBox(height: 2),
                            Text(fullAddress, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3)),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Phone: +91 $phone', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      );
                    }),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_off_rounded, color: Colors.grey, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No delivery address found for this order.',
                              style: TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCancelOrderDialog(Map<String, dynamic> order) {
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    final rawOrderId = (order['order_id'] ?? order['_calculated_order_id'] ?? msgId.toString()).toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();
    final customerMobile = (order['customer_mobile'] ?? '').toString();

    int selectedOption = 1;
    final otherReasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancel Order #$cleanOrderId',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a reason for cancellation:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      RadioListTile<int>(
                        value: 1,
                        groupValue: selectedOption,
                        activeColor: const Color(0xFFEF4444),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Customer ne cancel kiya',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedOption = val);
                        },
                      ),

                      RadioListTile<int>(
                        value: 2,
                        groupValue: selectedOption,
                        activeColor: const Color(0xFFEF4444),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Customer ka location galat diya tha',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedOption = val);
                        },
                      ),

                      RadioListTile<int>(
                        value: 3,
                        groupValue: selectedOption,
                        activeColor: const Color(0xFFEF4444),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Other',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedOption = val);
                        },
                      ),

                      if (selectedOption == 3) ...[
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: otherReasonController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter custom cancellation reason';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter custom reason...',
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Keep Order', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (selectedOption == 3 && !formKey.currentState!.validate()) {
                      return;
                    }

                    String reason = 'Customer ne cancel kiya';
                    if (selectedOption == 2) {
                      reason = 'Customer ka location galat diya tha';
                    } else if (selectedOption == 3) {
                      reason = otherReasonController.text.trim();
                    }

                    Navigator.pop(dialogCtx);

                    _requireCustomerOtpAndProceed(
                      order: order,
                      actionTitle: 'Cancellation',
                      onVerified: () async {
                        await AuthService.cancelOrderWithReason(
                          sellerUsername: (order['seller_username'] ?? widget.sellerName).toString(),
                          customerMobile: customerMobile,
                          messageId: msgId,
                          reason: reason,
                        );

                        AuthService.createPopupNotification(
                          targetRole: 'customer',
                          targetUser: customerMobile,
                          title: '❌ Order Delivery Cancelled!',
                          body: 'Delivery Boy could not deliver Order #$cleanOrderId. Reason: $reason',
                          type: 'delivery_cancelled',
                        );
                        AuthService.createPopupNotification(
                          targetRole: 'seller',
                          targetUser: (order['seller_username'] ?? widget.sellerName).toString(),
                          title: '⚠️ Delivery Cancelled by Delivery Boy!',
                          body: 'Delivery Boy cancelled delivery for Order #$cleanOrderId. Reason: $reason',
                          type: 'delivery_cancelled',
                        );

                        if (mounted) {
                          setState(() {
                            _currentOrders.removeWhere((o) => (o['id'] as num?)?.toInt() == msgId);
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order #$cleanOrderId Cancelled ❌ ($reason)'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                    );
                  },
                  child: const Text('Confirm Cancel ❌', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Require Customer OTP SMS Verification for Delivery / Cancellation
  void _requireCustomerOtpAndProceed({
    required Map<String, dynamic> order,
    required String actionTitle,
    required Future<void> Function() onVerified,
  }) async {
    final customerMobile = (order['customer_mobile'] ?? '').toString();
    final msgId = (order['id'] as num?)?.toInt() ?? 0;
    final rawOrderId = (order['order_id'] ?? order['_calculated_order_id'] ?? msgId.toString()).toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();

    if (customerMobile.isEmpty) {
      await onVerified();
      return;
    }

    // Show loading progress dialog while sending OTP SMS
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFEA580C)),
      ),
    );

    // Send Customer OTP SMS via Apitxt.com API
    final otpResult = await ApitxtOtpService.sendOtp(customerMobile);

    if (mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (!mounted) return;

    final otpController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: actionTitle.toLowerCase().contains('deliv') ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  child: Icon(
                    actionTitle.toLowerCase().contains('deliv') ? Icons.verified_user_rounded : Icons.shield_rounded,
                    size: 34,
                    color: actionTitle.toLowerCase().contains('deliv') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Customer OTP Verification 🔐',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'An OTP SMS was sent to Customer (+91 $customerMobile) to confirm $actionTitle for Order #$cleanOrderId.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ask customer for the 4-digit OTP code received on their phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFEA580C), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 2)),
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final otp = otpController.text.trim();
                        if (otp.isEmpty) {
                          setModalState(() => errorText = 'Please enter the OTP sent to customer');
                          return;
                        }

                        setModalState(() {
                          isVerifying = true;
                          errorText = null;
                        });

                        final result = await ApitxtOtpService.verifyOtp(customerMobile, otp);
                        final bool isSuccess = result['success'] == true;

                        if (!isSuccess) {
                          setModalState(() {
                            isVerifying = false;
                            errorText = result['message'] ?? 'Invalid OTP code';
                          });
                          return;
                        }

                        setModalState(() => isVerifying = false);

                        if (mounted) {
                          Navigator.pop(bottomCtx);
                          await onVerified();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionTitle.toLowerCase().contains('deliv') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Verify OTP & Confirm $actionTitle ✅',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(bottomCtx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final resendResult = await ApitxtOtpService.resendOtp(customerMobile);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resendResult['message'] ?? 'OTP Resent to Customer SMS')),
                        );
                      }
                    },
                    child: const Text('Resend Customer SMS', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isNotEmpty) {
      final Uri uri = Uri.parse('tel:$cleanPhone');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch (e) {
        debugPrint('Error launching phone call: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED), // Light Warm Orange Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sellerName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentOrders.length} Customer Deliveries Pending',
              style: const TextStyle(fontSize: 11, color: Color(0xFFFDBA74), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          if (widget.sellerMobile.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
              onPressed: () => _makePhoneCall(widget.sellerMobile),
              tooltip: 'Call Seller',
            ),
        ],
      ),
      body: _currentOrders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 60, color: Color(0xFF10B981)),
                    const SizedBox(height: 14),
                    Text(
                      'All orders for ${widget.sellerName} delivered!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Sellers List', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: _currentOrders.length,
              itemBuilder: (ctx, idx) {
                final order = _currentOrders[idx];
                final msgId = (order['id'] as num?)?.toInt() ?? 0;
                final rawOrderId = (order['order_id'] ?? order['_calculated_order_id'] ?? msgId.toString()).toString();
                final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();
                final customerMobile = (order['customer_mobile'] ?? '').toString();
                final rawCustomerName = (order['customer_name'] ?? order['name'] ?? order['receiver_name'] ?? '').toString().trim();
                final delStatus = (order['delivery_status'] ?? 'Pending').toString();
                final isOut = delStatus.toLowerCase() == 'out for delivery';

                String resolvedName = rawCustomerName.isNotEmpty && rawCustomerName != customerMobile ? rawCustomerName : '';

                if (resolvedName.isEmpty) {
                  resolvedName = (_customerNamesMap[cleanOrderId] ??
                      _customerNamesMap[rawOrderId] ??
                      _customerNamesMap[msgId.toString()] ??
                      _customerNamesMap[customerMobile] ??
                      '').trim();
                }

                String displayName = resolvedName.isNotEmpty
                    ? resolvedName
                    : (customerMobile.isNotEmpty ? '+91 $customerMobile' : 'Customer');

                return InkWell(
                  onTap: () => _showCustomerDetailsBottomSheet(order),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          // Order # Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDBA74)),
                            ),
                            child: Text(
                              '#$cleanOrderId',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFC2410C)),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Customer Info & Status Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOut ? 'Out for Delivery 🚚' : 'Ready for Pickup 📦',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOut ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Green Circular Call Icon Button (1-tap direct call)
                          if (customerMobile.isNotEmpty)
                            Material(
                              color: const Color(0xFFDCFCE7),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _makePhoneCall(customerMobile),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(Icons.phone_rounded, color: Color(0xFF16A34A), size: 16),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),

                          // Compact Pick Up / Delivered Action Button
                          if (!isOut)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C), // Vibrant Warm Orange
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                              ),
                              onPressed: () => _updateDeliveryStatus(order, 'Out for Delivery'),
                              child: const Text(
                                'Pick Up 📦',
                                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), // Emerald Green
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 1,
                              ),
                              onPressed: () => _showCustomerDetailsBottomSheet(order),
                              child: const Text(
                                'Delivered ✅',
                                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
