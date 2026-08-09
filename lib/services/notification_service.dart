import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize local notifications for Android & iOS
  static Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );

    // Request Android 13+ Notification Permission
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Trigger a system Popup Push Notification on the mobile device
  static Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await initialize();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_mart_orders_channel_v2',
        'Order Notifications',
        channelDescription: 'Notifications for order updates, status changes, and deliveries',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Daily Mart Notification',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing system notification: $e');
    }
  }

  /// Save persistent notification log entry for user role
  static Future<void> saveNotificationForUser({
    required String recipientKey, // e.g. "seller_krishna", "customer_8128859990", "delivery_boy"
    required String title,
    required String body,
    required String type, // "new_order", "ready", "picked_up", "delivered", "cancelled"
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String storageKey = 'user_notifications_$recipientKey';
      final String? existingStr = prefs.getString(storageKey);

      List<Map<String, dynamic>> notifications = [];
      if (existingStr != null && existingStr.isNotEmpty) {
        final List decoded = jsonDecode(existingStr);
        notifications = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final newNotif = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'read': false,
        if (data != null) ...data,
      };

      notifications.insert(0, newNotif); // latest first
      if (notifications.length > 50) {
        notifications = notifications.sublist(0, 50); // limit to last 50
      }

      await prefs.setString(storageKey, jsonEncode(notifications));
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Get persistent notification log list for user
  static Future<List<Map<String, dynamic>>> getNotificationsForUser(String recipientKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String storageKey = 'user_notifications_$recipientKey';
      final String? existingStr = prefs.getString(storageKey);

      if (existingStr != null && existingStr.isNotEmpty) {
        final List decoded = jsonDecode(existingStr);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    return [];
  }

  // =========================================================================
  // SPECIFIC ROLE NOTIFICATION HANDLERS (ALL 6 SCENARIOS)
  // =========================================================================

  /// 1. CUSTOMER PLACES NEW ORDER -> NOTIFY SELLER & ADMIN
  static Future<void> notifySellerNewOrder({
    required String sellerUsername,
    required String customerName,
    required String customerMobile,
    required String orderId,
  }) async {
    const String title = '🛍️ New Order Received!';
    final String body = 'Customer $customerName ($customerMobile) placed $orderId.';

    // Show native system popup notification
    await showSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'seller_new_order',
    );

    // Save to persistent storage for seller
    await saveNotificationForUser(
      recipientKey: 'seller_${sellerUsername.toLowerCase().trim()}',
      title: title,
      body: body,
      type: 'new_order',
      data: {'order_id': orderId, 'customer_mobile': customerMobile},
    );

    // ALSO Notify Admin with Popup Push Notification
    await notifyAdminNewOrder(
      sellerUsername: sellerUsername,
      customerName: customerName,
      customerMobile: customerMobile,
      orderId: orderId,
    );
  }

  /// NEW ORDER -> NOTIFY ADMIN WITH POPUP PUSH NOTIFICATION
  static Future<void> notifyAdminNewOrder({
    required String sellerUsername,
    required String customerName,
    required String customerMobile,
    required String orderId,
  }) async {
    const String title = '🛍️ New Order Placed!';
    final String body = 'Customer $customerName ($customerMobile) placed $orderId for $sellerUsername.';

    // Show native system popup notification for Admin
    await showSystemNotification(
      id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1,
      title: title,
      body: body,
      payload: 'admin_new_order',
    );

    // Save to persistent storage for Admin
    await saveNotificationForUser(
      recipientKey: 'admin',
      title: title,
      body: body,
      type: 'new_order',
      data: {'order_id': orderId, 'customer_mobile': customerMobile, 'seller_username': sellerUsername},
    );
  }

  /// 2. SELLER CANCELS ORDER -> NOTIFY CUSTOMER
  static Future<void> notifyCustomerOrderCancelled({
    required String customerMobile,
    required String sellerName,
    required String orderId,
    String reason = 'Cancelled by seller',
  }) async {
    const String title = '❌ Order Cancelled by Seller';
    final String body = '$sellerName has cancelled $orderId. Reason: $reason';

    await showSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'customer_order_cancelled',
    );

    await saveNotificationForUser(
      recipientKey: 'customer_${customerMobile.toLowerCase().trim()}',
      title: title,
      body: body,
      type: 'cancelled_by_seller',
      data: {'order_id': orderId, 'reason': reason},
    );
  }

  /// 3. SELLER MARKS ORDER READY / APPROVED -> NOTIFY CUSTOMER & DELIVERY BOYS
  static Future<void> notifyOrderReady({
    required String customerMobile,
    required String sellerUsername,
    required String sellerName,
    required String orderId,
  }) async {
    const String custTitle = '✅ Order Approved & Ready!';
    final String custBody = '$sellerName approved $orderId. It is ready for delivery!';

    // Save persistent notification log for Customer
    await saveNotificationForUser(
      recipientKey: 'customer_${customerMobile.toLowerCase().trim()}',
      title: custTitle,
      body: custBody,
      type: 'order_ready',
      data: {'order_id': orderId},
    );

    // Notify Delivery Boys
    const String delTitle = '📦 New Order Ready for Pickup!';
    final String delBody = '$orderId from $sellerName is ready for pickup.';

    await saveNotificationForUser(
      recipientKey: 'delivery_boy_all',
      title: delTitle,
      body: delBody,
      type: 'order_ready_pickup',
      data: {'order_id': orderId, 'seller_username': sellerUsername},
    );
  }

  /// 4. DELIVERY BOY PICKS UP ORDER -> NOTIFY CUSTOMER & SELLER
  static Future<void> notifyOrderPickedUp({
    required String customerMobile,
    required String sellerUsername,
    required String deliveryBoyName,
    required String orderId,
  }) async {
    // Notify Customer
    const String custTitle = '🚚 Order Picked Up!';
    final String custBody = 'Delivery boy $deliveryBoyName picked up $orderId and is on the way!';

    await showSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: custTitle,
      body: custBody,
      payload: 'customer_order_picked_up',
    );

    await saveNotificationForUser(
      recipientKey: 'customer_${customerMobile.toLowerCase().trim()}',
      title: custTitle,
      body: custBody,
      type: 'picked_up',
      data: {'order_id': orderId, 'delivery_boy': deliveryBoyName},
    );

    // Notify Seller
    const String sellTitle = '🚚 Order Out for Delivery';
    final String sellBody = '$deliveryBoyName picked up $orderId for delivery.';

    await saveNotificationForUser(
      recipientKey: 'seller_${sellerUsername.toLowerCase().trim()}',
      title: sellTitle,
      body: sellBody,
      type: 'picked_up',
      data: {'order_id': orderId, 'delivery_boy': deliveryBoyName},
    );
  }

  /// 5. DELIVERY BOY MARKS ORDER DELIVERED -> NOTIFY CUSTOMER & SELLER
  static Future<void> notifyOrderDelivered({
    required String customerMobile,
    required String sellerUsername,
    required String deliveryBoyName,
    required String orderId,
  }) async {
    // Notify Customer
    const String custTitle = '🎉 Order Delivered!';
    final String custBody = 'Your $orderId has been delivered by $deliveryBoyName. Thank you!';

    await showSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: custTitle,
      body: custBody,
      payload: 'customer_order_delivered',
    );

    await saveNotificationForUser(
      recipientKey: 'customer_${customerMobile.toLowerCase().trim()}',
      title: custTitle,
      body: custBody,
      type: 'delivered',
      data: {'order_id': orderId, 'delivery_boy': deliveryBoyName},
    );

    // Notify Seller
    const String sellTitle = '✅ Order Successfully Delivered';
    final String sellBody = '$orderId has been delivered by $deliveryBoyName.';

    await saveNotificationForUser(
      recipientKey: 'seller_${sellerUsername.toLowerCase().trim()}',
      title: sellTitle,
      body: sellBody,
      type: 'delivered',
      data: {'order_id': orderId, 'delivery_boy': deliveryBoyName},
    );
  }

  /// 6. DELIVERY BOY CANCELS ORDER -> NOTIFY CUSTOMER & SELLER
  static Future<void> notifyOrderCancelledByDelivery({
    required String customerMobile,
    required String sellerUsername,
    required String deliveryBoyName,
    required String orderId,
    required String reason,
  }) async {
    // Notify Customer
    const String custTitle = '❌ Delivery Cancelled';
    final String custBody = 'Delivery for $orderId was cancelled by $deliveryBoyName. Reason: $reason';

    await showSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: custTitle,
      body: custBody,
      payload: 'customer_delivery_cancelled',
    );

    await saveNotificationForUser(
      recipientKey: 'customer_${customerMobile.toLowerCase().trim()}',
      title: custTitle,
      body: custBody,
      type: 'cancelled_by_delivery',
      data: {'order_id': orderId, 'reason': reason},
    );

    // Notify Seller
    const String sellTitle = '⚠️ Delivery Cancelled by Delivery Boy';
    final String sellBody = '$deliveryBoyName cancelled delivery for $orderId. Reason: $reason';

    await saveNotificationForUser(
      recipientKey: 'seller_${sellerUsername.toLowerCase().trim()}',
      title: sellTitle,
      body: sellBody,
      type: 'cancelled_by_delivery',
      data: {'order_id': orderId, 'reason': reason},
    );
  }
}
