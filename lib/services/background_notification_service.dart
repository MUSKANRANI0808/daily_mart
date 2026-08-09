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
        isForegroundMode: false, // Silent background task without forcing persistent banner
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

    Timer.periodic(const Duration(milliseconds: 3000), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();

        // 1. Check Seller Background Notifications
        final userStr = prefs.getString('auth_user');
        if (userStr != null && userStr.isNotEmpty) {
          try {
            final userMap = jsonDecode(userStr);
            final role = (userMap['role'] ?? '').toString().toLowerCase();
            final username = (userMap['username'] ?? userMap['mobile'] ?? '').toString().trim();

            if (role == 'seller' && username.isNotEmpty) {
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
            } else if (role == 'customer' && username.isNotEmpty) {
              // 2. Check Customer Background Notifications
              final lastSellerStr = prefs.getString('last_selected_seller');
              if (lastSellerStr != null && lastSellerStr.isNotEmpty) {
                try {
                  final sMap = jsonDecode(lastSellerStr);
                  final sellerUsername = (sMap['username'] ?? '').toString().trim();
                  final sellerName = (sMap['name'] ?? 'Store').toString().trim();

                  if (sellerUsername.isNotEmpty) {
                    final msgs = await AuthService.getMessages(
                      sellerUsername: sellerUsername,
                      customerMobile: username,
                    );

                    for (var m in msgs) {
                      final idStr = (m['id'] ?? '').toString();
                      final status = (m['order_status'] ?? '').toString().toLowerCase();
                      final rawOrderId = (m['order_id'] ?? 'Order #$idStr').toString();
                      final key = 'cust_${username}_${idStr}_$status';

                      if ((status == 'ready' || status == 'approved') && !_notifiedKeys.contains(key)) {
                        _notifiedKeys.add(key);
                        NotificationService.showSystemNotification(
                          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          title: '✅ Order Approved & Ready!',
                          body: '$sellerName approved $rawOrderId. It is ready for delivery!',
                          payload: 'customer_order_ready',
                        );
                      }
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    });
  }
}
