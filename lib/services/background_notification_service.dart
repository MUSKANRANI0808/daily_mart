import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class BackgroundNotificationService {
  static final Set<String> _notifiedKeys = {};

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.initialize();

    Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();

        final userStr = prefs.getString('current_user');
        if (userStr != null && userStr.isNotEmpty) {
          try {
            final userMap = jsonDecode(userStr);
            final role = (userMap['role'] ?? '').toString().toLowerCase();
            final username = (userMap['username'] ?? '').toString().trim();
            final mobile = (userMap['mobile'] ?? '').toString().trim();

            if (role == 'seller' && username.isNotEmpty) {
              // --- SELLER AUTOMATIC BACKGROUND NOTIFICATION ---
              final convs = await AuthService.getSellerConversations(username);
              for (var c in convs) {
                final custMobile = (c['customer_mobile'] ?? '').toString().trim();
                final msgId = (c['last_message_id'] ?? c['id'] ?? 0).toString();
                final unreadCount = (c['unread_count'] as num?)?.toInt() ?? 0;
                final senderType = (c['last_sender_type'] ?? '').toString().toLowerCase();

                final key = 'seller_${username}_${custMobile}_${msgId}_$unreadCount';

                if (unreadCount > 0 && (senderType == 'customer' || senderType.isEmpty) && !_notifiedKeys.contains(key)) {
                  _notifiedKeys.add(key);
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
            } else if (role == 'customer' && mobile.isNotEmpty) {
              // --- CUSTOMER AUTOMATIC BACKGROUND NOTIFICATION ---
              final convs = await AuthService.getCustomerConversations(mobile);
              for (var c in convs) {
                final sellerUsername = (c['seller_username'] ?? '').toString().trim();
                final sellerName = (c['seller_name'] ?? 'Store').toString().trim();
                final orderStatus = (c['order_status'] ?? '').toString().toLowerCase();
                final msgId = (c['last_message_id'] ?? c['id'] ?? 0).toString();
                final orderId = (c['last_order_id'] ?? 'Order #$msgId').toString();
                final unreadCount = (c['unread_count'] as num?)?.toInt() ?? 0;
                final senderType = (c['last_sender_type'] ?? '').toString().toLowerCase();

                final key = 'cust_${mobile}_${sellerUsername}_${msgId}_$orderStatus';

                if ((orderStatus == 'ready' || orderStatus == 'approved') && !_notifiedKeys.contains(key)) {
                  _notifiedKeys.add(key);
                  NotificationService.showSystemNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: '✅ Order Approved & Ready!',
                    body: '$sellerName approved $orderId. It is ready for delivery!',
                    payload: 'customer_order_ready',
                  );
                } else if (unreadCount > 0 && senderType == 'seller' && !_notifiedKeys.contains('msg_$key')) {
                  _notifiedKeys.add('msg_$key');
                  final lastMsg = (c['last_message'] ?? 'New message from seller').toString();
                  NotificationService.showSystemNotification(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: '💬 New Message from $sellerName',
                    body: lastMsg,
                    payload: 'customer_new_message',
                  );
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    });
  }
}
