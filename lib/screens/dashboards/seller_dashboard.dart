import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../customer/seller_orders_screen.dart';

class SellerDashboard extends StatefulWidget {
  final UserModel seller;

  SellerDashboard({
    super.key,
    UserModel? seller,
    UserModel? user,
  }) : seller = seller ?? user!;

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  Timer? _sellerDashboardPoller;
  final Set<String> _notifiedSellerOrderKeys = {};

  @override
  void initState() {
    super.initState();
    _startSellerDashboardPolling();
  }

  @override
  void dispose() {
    _sellerDashboardPoller?.cancel();
    super.dispose();
  }

  void _startSellerDashboardPolling() {
    _sellerDashboardPoller?.cancel();
    _sellerDashboardPoller = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      if (!mounted) return;
      try {
        final sellerUser = _sellerUsername;
        if (sellerUser.isEmpty) return;
        final convs = await AuthService.getSellerConversations(sellerUser);

        for (var c in convs) {
          final custMobile = (c['customer_mobile'] ?? '').toString().trim();
          final msgId = (c['last_message_id'] ?? c['id'] ?? 0).toString();
          final unreadCount = (c['unread_count'] as num?)?.toInt() ?? 0;
          final senderType = (c['last_sender_type'] ?? '').toString().toLowerCase();

          final notifKey = '${custMobile}_${msgId}_$unreadCount';

          if (unreadCount > 0 && (senderType == 'customer' || senderType.isEmpty) && !_notifiedSellerOrderKeys.contains(notifKey)) {
            _notifiedSellerOrderKeys.add(notifKey);
            final custName = (c['display_name'] ?? c['customer_name'] ?? 'Customer').toString();
            final orderId = (c['last_order_id'] ?? 'New Order').toString();

            NotificationService.showSystemNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: '🛍️ New Order Received!',
              body: 'Customer $custName ($custMobile) placed $orderId.',
              payload: 'seller_new_order',
            );
          }
        }
      } catch (_) {}
    });
  }

  String get _sellerUsername {
    final u = (widget.seller.username ?? '').trim();
    if (u.isNotEmpty) return u;
    final m = (widget.seller.mobile ?? '').trim();
    if (m.isNotEmpty) return m;
    return (widget.seller.name).trim();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerSellerOrdersScreen(
      customer: widget.seller,
      sellerUsername: _sellerUsername,
      sellerName: widget.seller.name,
      sellerMobile: widget.seller.mobile ?? '',
      hideBottomNav: true,
      isSellerView: true,
    );
  }
}
