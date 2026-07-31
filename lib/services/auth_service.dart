import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../vps_api_service.dart';

class AuthService {
  static const String _currentUserKey = 'current_user';
  static const String _sellersKey = 'sellers_list';

  // Admin Credentials provided by User
  static const String defaultAdminId = 'admin';
  static const String defaultAdminPass = '1234';

  /// Check active logged-in user session
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonStr = prefs.getString(_currentUserKey);
    if (userJsonStr != null) {
      return UserModel.fromJson(jsonDecode(userJsonStr));
    }
    return null;
  }

  /// Save logged in user session
  static Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }

  static const String _lastSellerUsernameKey = 'last_seller_username';
  static const String _lastSellerNameKey = 'last_seller_name';
  static const String _lastSellerMobileKey = 'last_seller_mobile';

  /// Save last selected seller for persistent app launch directly to seller recent orders
  static Future<void> saveLastSelectedSeller({
    required String username,
    required String name,
    required String mobile,
    String customerMobile = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSellerUsernameKey, username);
    await prefs.setString(_lastSellerNameKey, name);
    await prefs.setString(_lastSellerMobileKey, mobile);

    if (customerMobile.trim().isNotEmpty) {
      final key = 'deleted_sellers_${customerMobile.trim()}';
      final List<String> deletedList = prefs.getStringList(key) ?? [];
      if (deletedList.contains(username.trim())) {
        deletedList.remove(username.trim());
        await prefs.setStringList(key, deletedList);
      }
    }
  }

  /// Get last selected seller session
  static Future<Map<String, String>?> getLastSelectedSeller() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_lastSellerUsernameKey);
    final name = prefs.getString(_lastSellerNameKey);
    final mobile = prefs.getString(_lastSellerMobileKey);
    if (username != null && username.isNotEmpty) {
      return {
        'username': username,
        'name': name ?? username,
        'mobile': mobile ?? '',
      };
    }
    return null;
  }

  /// Clear last selected seller when customer switches seller
  static Future<void> clearLastSelectedSeller() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSellerUsernameKey);
    await prefs.remove(_lastSellerNameKey);
    await prefs.remove(_lastSellerMobileKey);
  }

  /// Logout current user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await clearLastSelectedSeller();
  }

  /// Admin Login Check
  static Future<UserModel?> loginAdmin(String id, String password) async {
    if (id.trim() == defaultAdminId && password.trim() == defaultAdminPass) {
      final adminUser = UserModel(
        id: 'admin_1',
        name: 'Administrator',
        username: defaultAdminId,
        role: UserRole.admin,
      );
      await saveUserSession(adminUser);
      return adminUser;
    }
    return null;
  }

  /// Seller Login Check
  static Future<UserModel?> loginSeller(String username, String password) async {
    try {
      final res = await VpsApiService.post('seller-login', {
        'username': username.trim(),
        'password': password.trim(),
      });
      if (res != null && res['success'] == true) {
        final sellerUser = UserModel(
          id: res['seller']['id'].toString(),
          name: res['seller']['name'],
          username: res['seller']['username'],
          mobile: res['seller']['mobile'],
          role: UserRole.seller,
        );
        await saveUserSession(sellerUser);
        return sellerUser;
      }
    } catch (_) {}

    // Local fallback check
    final sellers = await getLocalSellers();
    for (var seller in sellers) {
      if (seller['username']?.toString().trim() == username.trim() &&
          seller['password']?.toString().trim() == password.trim()) {
        final sellerUser = UserModel(
          id: seller['id']?.toString() ?? 'seller_${DateTime.now().millisecondsSinceEpoch}',
          name: seller['name'] ?? username,
          username: username,
          mobile: seller['mobile'],
          role: UserRole.seller,
        );
        await saveUserSession(sellerUser);
        return sellerUser;
      }
    }
    return null;
  }

  /// Seller Mobile OTP Login Check
  static Future<UserModel?> loginSellerByMobile(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10Digits = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

    // 1. Check VPS API sellers list
    try {
      final sellers = await getSellersList();
      for (var seller in sellers) {
        final sMobile = (seller['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMobile.length >= 10 ? sMobile.substring(sMobile.length - 10) : sMobile;
        if (sLast10.isNotEmpty && sLast10 == last10Digits) {
          final sellerUser = UserModel(
            id: seller['id']?.toString() ?? 'seller_${seller['username']}',
            name: seller['name'] ?? seller['username'],
            username: seller['username'] ?? seller['name'],
            mobile: seller['mobile'] ?? last10Digits,
            role: UserRole.seller,
          );
          await saveUserSession(sellerUser);
          return sellerUser;
        }
      }
    } catch (_) {}

    // 2. Check Local Sellers fallback list
    try {
      final sellers = await getLocalSellers();
      for (var seller in sellers) {
        final sMobile = (seller['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMobile.length >= 10 ? sMobile.substring(sMobile.length - 10) : sMobile;
        if (sLast10.isNotEmpty && sLast10 == last10Digits) {
          final sellerUser = UserModel(
            id: seller['id']?.toString() ?? 'seller_${seller['username']}',
            name: seller['name'] ?? seller['username'],
            username: seller['username'] ?? seller['name'],
            mobile: seller['mobile'] ?? last10Digits,
            role: UserRole.seller,
          );
          await saveUserSession(sellerUser);
          return sellerUser;
        }
      }
    } catch (_) {}

    // 3. Fallback: Auto-create seller session for mobile login
    final sellerUser = UserModel(
      id: 'seller_$last10Digits',
      name: 'Seller Store ($last10Digits)',
      username: 'seller_$last10Digits',
      mobile: last10Digits,
      role: UserRole.seller,
    );
    await saveUserSession(sellerUser);
    return sellerUser;
  }

  /// Get Saved Customer Profile Data (Name, etc.)
  static Future<Map<String, dynamic>?> getCustomerProfile(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('customer_profile_${mobile.trim()}');
    if (str != null && str.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(str));
      } catch (_) {}
    }
    return null;
  }

  /// Save Customer Profile Data
  static Future<void> saveCustomerProfile(String mobile, {required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {'mobile': mobile.trim(), 'name': name.trim()};
    await prefs.setString('customer_profile_${mobile.trim()}', jsonEncode(data));
  }

  /// Deep Customer Name Resolver for Seller Dashboard & Delivery Boy (VPS DB + Local Cache)
  static Future<String> getCustomerDisplayName(String custMobile, {String? dbCustomerName}) async {
    final cleanMobile = custMobile.trim();
    if (cleanMobile.isEmpty) return 'Customer';

    // 0. If backend database provided a non-empty customer_name that isn't generic
    if (dbCustomerName != null && dbCustomerName.trim().isNotEmpty) {
      final dbName = dbCustomerName.trim();
      if (!dbName.toLowerCase().startsWith('customer')) {
        await saveCustomerProfile(cleanMobile, name: dbName);
        return dbName;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. Query VPS API Database directly for customer profile
    try {
      final encMobile = Uri.encodeComponent(cleanMobile);
      final res = await VpsApiService.get('get-customer-profile&mobile=$encMobile');
      if (res != null && res['success'] == true && res['profile'] != null) {
        final Map<String, dynamic> pMap = Map<String, dynamic>.from(res['profile']);
        final vpsName = (pMap['name'] ?? pMap['customer_name'] ?? '').toString().trim();
        if (vpsName.isNotEmpty && !vpsName.toLowerCase().startsWith('customer')) {
          await saveCustomerProfile(cleanMobile, name: vpsName);
          return vpsName;
        }
      }
    } catch (_) {}

    // 2. Check local saved customer profile
    final profile = await getCustomerProfile(cleanMobile);
    if (profile != null && profile['name'] != null) {
      final name = profile['name'].toString().trim();
      if (name.isNotEmpty && !name.toLowerCase().startsWith('customer')) {
        return name;
      }
    }

    // 3. Check current_user in prefs
    final currentUserStr = prefs.getString('current_user');
    if (currentUserStr != null && currentUserStr.isNotEmpty) {
      try {
        final Map<String, dynamic> cUser = jsonDecode(currentUserStr);
        final uMobile = (cUser['mobile'] ?? '').toString().trim();
        final uName = (cUser['name'] ?? '').toString().trim();
        if (uMobile == cleanMobile && uName.isNotEmpty && !uName.toLowerCase().startsWith('customer')) {
          await saveCustomerProfile(cleanMobile, name: uName);
          return uName;
        }
      } catch (_) {}
    }

    // 4. Check customer saved addresses
    final jsonStr = prefs.getString('customer_addresses_$cleanMobile');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        for (var addr in list) {
          if (addr is Map) {
            final rName = (addr['receiverName'] ?? addr['name'] ?? addr['contactName'] ?? '').toString().trim();
            if (rName.isNotEmpty && !rName.toLowerCase().startsWith('customer')) {
              await saveCustomerProfile(cleanMobile, name: rName);
              return rName;
            }
          }
        }
      } catch (_) {}
    }

    // 5. Check saved_order_delivery_details
    final detailsStr = prefs.getString('saved_order_delivery_details');
    if (detailsStr != null && detailsStr.isNotEmpty) {
      try {
        final Map<String, dynamic> detailsMap = jsonDecode(detailsStr);
        for (var entry in detailsMap.values) {
          if (entry is Map && entry['address'] is Map) {
            final addr = Map<String, dynamic>.from(entry['address']);
            final rName = (addr['receiverName'] ?? addr['name'] ?? addr['contactName'] ?? '').toString().trim();
            if (rName.isNotEmpty && !rName.toLowerCase().startsWith('customer')) {
              await saveCustomerProfile(cleanMobile, name: rName);
              return rName;
            }
          }
        }
      } catch (_) {}
    }

    // 6. Check messages for receiverName or customerName
    final pName = profile?['name']?.toString().trim() ?? '';
    if (pName.isNotEmpty && !pName.toLowerCase().startsWith('customer')) {
      return pName;
    }

    return 'Customer ($cleanMobile)';
  }

  /// Customer Mobile Login
  static Future<UserModel> loginCustomer(String mobile, {String? customName}) async {
    final trimmedMobile = mobile.trim();
    try {
      await VpsApiService.post('customer-login', {
        'mobile': trimmedMobile,
        'name': customName?.trim(),
      });
    } catch (_) {}

    String name = customName?.trim() ?? '';
    if (name.isEmpty) {
      final savedProfile = await getCustomerProfile(trimmedMobile);
      if (savedProfile != null && savedProfile['name'] != null && savedProfile['name'].toString().trim().isNotEmpty) {
        name = savedProfile['name'].toString().trim();
      } else {
        name = 'Customer ($trimmedMobile)';
      }
    } else {
      await saveCustomerProfile(trimmedMobile, name: name);
    }

    final customerUser = UserModel(
      id: 'cust_$trimmedMobile',
      name: name,
      mobile: trimmedMobile,
      role: UserRole.customer,
    );
    await saveUserSession(customerUser);
    return customerUser;
  }

  /// Get list of all created Sellers
  static Future<List<Map<String, dynamic>>> getSellersList() async {
    try {
      final res = await VpsApiService.get('sellers');
      if (res != null && res['sellers'] != null) {
        final List<dynamic> list = res['sellers'];
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    return getLocalSellers();
  }

  /// Search Sellers by Mobile Number
  static Future<List<Map<String, dynamic>>> searchSellersByMobile(String mobile) async {
    try {
      final encoded = Uri.encodeComponent(mobile.trim());
      final res = await VpsApiService.get('search-seller&mobile=$encoded');
      if (res != null && res['sellers'] != null) {
        final List<dynamic> list = res['sellers'];
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    final all = await getSellersList();
    return all.where((s) {
      final m = s['mobile']?.toString() ?? '';
      final u = s['username']?.toString() ?? '';
      return m.contains(mobile) || u.contains(mobile);
    }).toList();
  }

  static final Map<String, int> _memoryOrderCounters = {};

  /// Generate next sequential Order ID in dual format: Order CustomerSeq/GlobalSeq (e.g. Order 1/1, Order 1/3, Order 2/4)
  static Future<String> getNextGlobalOrderId(
    String sellerUsername, {
    required String customerMobile,
    List<Map<String, dynamic>>? activeMessages,
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();
    final prefs = await SharedPreferences.getInstance();

    final globalKey = 'lifetime_global_counter_$cleanSeller';
    final custKey = 'lifetime_cust_counter_${cleanSeller}_$cleanCust';

    int storedGlobal = prefs.getInt(globalKey) ?? 0;
    int storedCust = prefs.getInt(custKey) ?? 0;

    int memGlobal = _memoryOrderCounters['global_$cleanSeller'] ?? 0;
    int memCust = _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] ?? 0;

    int maxGlobal = storedGlobal > memGlobal ? storedGlobal : memGlobal;
    int maxCust = storedCust > memCust ? storedCust : memCust;

    if (activeMessages != null && activeMessages.isNotEmpty) {
      for (var m in activeMessages) {
        final rawOrd = (m['order_id'] ?? '').toString().trim();
        if (rawOrd.contains('/')) {
          final parts = rawOrd.replaceAll('Order', '').trim().split('/');
          if (parts.length == 2) {
            final cVal = int.tryParse(parts[0].trim()) ?? 0;
            final gVal = int.tryParse(parts[1].trim()) ?? 0;
            if (cVal > maxCust) maxCust = cVal;
            if (gVal > maxGlobal) maxGlobal = gVal;
          }
        } else {
          final numMatch = RegExp(r'\d+').firstMatch(rawOrd);
          if (numMatch != null) {
            final val = int.tryParse(numMatch.group(0)!) ?? 0;
            if (val > maxCust) maxCust = val;
          }
        }
      }
    }

    int nextCust = maxCust + 1;
    int nextGlobal = maxGlobal + 1;

    _memoryOrderCounters['global_$cleanSeller'] = nextGlobal;
    _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] = nextCust;

    await prefs.setInt(globalKey, nextGlobal);
    await prefs.setInt(custKey, nextCust);

    return 'Order $nextCust/$nextGlobal';
  }

  /// Annotate messages with deletion-proof lifetime hierarchical dual order numbers (CustomerSeq/GlobalSeq)
  static Future<void> annotateMessagesWithLifetimeHierarchy({
    required String sellerUsername,
    required String customerMobile,
    required List<Map<String, dynamic>> messages,
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();
    if (cleanSeller.isEmpty || messages.isEmpty) return;

    messages.sort((a, b) {
      final tA = (a['created_at'] ?? '').toString();
      final tB = (b['created_at'] ?? '').toString();
      final idA = (a['id'] as num?)?.toInt() ?? 0;
      final idB = (b['id'] as num?)?.toInt() ?? 0;
      if (tA != tB && tA.isNotEmpty && tB.isNotEmpty) return tA.compareTo(tB);
      return idA.compareTo(idB);
    });

    final prefs = await SharedPreferences.getInstance();
    final globalKey = 'lifetime_global_counter_$cleanSeller';
    final custKey = 'lifetime_cust_counter_${cleanSeller}_$cleanCust';

    int storedGlobal = prefs.getInt(globalKey) ?? 0;
    int storedCust = prefs.getInt(custKey) ?? 0;

    int memGlobal = _memoryOrderCounters['global_$cleanSeller'] ?? 0;
    if (memGlobal > storedGlobal) storedGlobal = memGlobal;

    int memCust = _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] ?? 0;
    if (memCust > storedCust) storedCust = memCust;

    int startCustCount = storedCust > messages.length ? (storedCust - messages.length) : 0;
    int custCount = startCustCount;

    int startGlobalCount = storedGlobal > messages.length ? (storedGlobal - messages.length) : 0;
    int globalCount = startGlobalCount;

    for (var m in messages) {
      final rawOrd = (m['order_id'] ?? '').toString().trim();
      if (rawOrd.isNotEmpty && rawOrd != 'null') {
        if (rawOrd.contains('/')) {
          final parts = rawOrd.replaceAll('Order', '').trim().split('/');
          if (parts.length == 2) {
            final cVal = int.tryParse(parts[0].trim()) ?? 0;
            final gVal = int.tryParse(parts[1].trim()) ?? 0;
            if (cVal > custCount) custCount = cVal;
            if (gVal > globalCount) globalCount = gVal;
          }
        } else {
          final numMatch = RegExp(r'\d+').firstMatch(rawOrd);
          if (numMatch != null) {
            final cVal = int.tryParse(numMatch.group(0)!) ?? 0;
            if (cVal > custCount) custCount = cVal;
            globalCount++;
            m['order_id'] = 'Order $cVal/$globalCount';
          } else {
            custCount++;
            globalCount++;
            m['order_id'] = 'Order $custCount/$globalCount';
          }
        }
      } else {
        custCount++;
        globalCount++;
        m['order_id'] = 'Order $custCount/$globalCount';
      }
    }

    if (custCount > storedCust) {
      _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] = custCount;
      await prefs.setInt(custKey, custCount);
    }
    if (globalCount > storedGlobal) {
      _memoryOrderCounters['global_$cleanSeller'] = globalCount;
      await prefs.setInt(globalKey, globalCount);
    }
  }

  /// Send Message (Customer or Seller)
  static Future<bool> sendMessage({
    required String sellerUsername,
    required String customerMobile,
    required String message,
    String senderType = 'customer',
    String? customOrderId,
  }) async {
    try {
      String? orderTag = customOrderId;
      if ((orderTag == null || orderTag.trim().isEmpty) && senderType == 'customer') {
        orderTag = await getNextGlobalOrderId(sellerUsername, customerMobile: customerMobile);
      }

      final res = await VpsApiService.post('send-message', {
        'seller_username': sellerUsername.trim(),
        'customer_mobile': customerMobile.trim(),
        'message': message.trim(),
        'sender_type': senderType,
        'order_id': orderTag ?? '',
      });
      if (res != null && res['success'] == true) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Update Order Item Checkbox Status & Record Action Log (Seller only)
  static Future<bool> updateItemStatus({
    required int messageId,
    required List<dynamic> items,
    String sellerName = 'SELLER',
    int itemNum = 1,
    int status = 1,
  }) async {
    try {
      final res = await VpsApiService.post('update-item-status', {
        'message_id': messageId,
        'items': items,
        'seller_name': sellerName,
        'item_num': itemNum,
        'status': status,
      });
      return res != null && res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// Update Order Overall Status (e.g. "Ready" or "Cancelled") by Seller
  static Future<bool> updateOrderStatus({
    required int messageId,
    required String orderStatus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final msgIdStr = messageId.toString();

      // 1. Update persistent saved_order_statuses map
      Map<String, dynamic> savedStatuses = {};
      try {
        final str = prefs.getString('saved_order_statuses');
        if (str != null && str.isNotEmpty) {
          savedStatuses = Map<String, dynamic>.from(jsonDecode(str));
        }
      } catch (_) {}
      savedStatuses[msgIdStr] = orderStatus;
      await prefs.setString('saved_order_statuses', jsonEncode(savedStatuses));

      // 2. Update local msgs_ and messages_ keys
      final keys = prefs.getKeys().where((k) => k.startsWith('msgs_') || k.startsWith('messages_')).toList();
      for (var key in keys) {
        final str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          try {
            final List decoded = jsonDecode(str);
            final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            bool modified = false;
            for (var item in list) {
              if (item['id'] == messageId || item['id'].toString() == msgIdStr) {
                item['order_status'] = orderStatus;
                modified = true;
              }
            }
            if (modified) {
              await prefs.setString(key, jsonEncode(list));
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      final res = await VpsApiService.post('update-order-status', {
        'message_id': messageId,
        'order_status': orderStatus,
      });
      return res != null && res['success'] == true;
    } catch (_) {}
    return true;
  }

  /// Update Order Amount by Seller (With 100% Persistent SharedPreferences Local Cache & VPS API Sync)
  static Future<bool> updateOrderAmount({
    required int messageId,
    required double orderAmount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final amountsStr = prefs.getString('saved_order_amounts') ?? '{}';
      Map<String, dynamic> amountsMap = {};
      try {
        amountsMap = Map<String, dynamic>.from(jsonDecode(amountsStr));
      } catch (_) {}
      amountsMap[messageId.toString()] = orderAmount;
      await prefs.setString('saved_order_amounts', jsonEncode(amountsMap));

      // Also update any saved msgs_ cache keys
      final keys = prefs.getKeys().where((k) => k.startsWith('msgs_')).toList();
      for (var key in keys) {
        final str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          try {
            final List decoded = jsonDecode(str);
            final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            bool modified = false;
            for (var item in list) {
              if (item['id'] == messageId || item['id'].toString() == messageId.toString()) {
                item['order_amount'] = orderAmount;
                item['amount'] = orderAmount;
                modified = true;
              }
            }
            if (modified) {
              await prefs.setString(key, jsonEncode(list));
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      final res = await VpsApiService.post('update-order-amount', {
        'message_id': messageId,
        'order_amount': orderAmount,
      });
      return res != null && res['success'] == true;
    } catch (_) {}
    return true;
  }

  /// Delete a Message (Soft Delete: Marks order status as 'Deleted' so order hierarchy is preserved)
  static Future<bool> deleteMessage(int messageId) async {
    try {
      final res = await VpsApiService.post('update-order-status', {
        'message_id': messageId,
        'order_status': 'Deleted',
      });
      if (res != null && res['success'] == true) {
        return true;
      }
    } catch (_) {}

    try {
      final res = await VpsApiService.post('delete-message', {
        'message_id': messageId,
      });
      return res != null && res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// Mark Messages as Read
  static Future<void> markMessagesRead({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    try {
      final encSeller = Uri.encodeComponent(sellerUsername.trim());
      final encCust = Uri.encodeComponent(customerMobile.trim());
      await VpsApiService.get('mark-read&seller_username=$encSeller&customer_mobile=$encCust');
    } catch (_) {}
  }

  /// Get Grouped Customer Conversations for Seller Dashboard
  static Future<List<Map<String, dynamic>>> getSellerConversations(String sellerUsername) async {
    try {
      final encSeller = Uri.encodeComponent(sellerUsername.trim());
      final res = await VpsApiService.get('get-seller-conversations&seller_username=$encSeller');
      if (res != null && res['conversations'] != null) {
        final List<dynamic> list = res['conversations'];
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Get Grouped Seller Conversations for Customer Dashboard Home Page (Excluding deleted sellers)
  static Future<List<Map<String, dynamic>>> getCustomerConversations(String customerMobile) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCust = customerMobile.trim();
    final List<String> deletedList = prefs.getStringList('deleted_sellers_$cleanCust') ?? [];

    List<Map<String, dynamic>> result = [];
    try {
      final encCust = Uri.encodeComponent(cleanCust);
      final res = await VpsApiService.get('get-customer-conversations&customer_mobile=$encCust');
      if (res != null && res['conversations'] != null) {
        final List<dynamic> list = res['conversations'];
        final msgs = list.cast<Map<String, dynamic>>();
        result = msgs.where((c) {
          final sUsername = (c['seller_username'] ?? '').toString().trim();
          return !deletedList.contains(sUsername);
        }).toList();
      }
    } catch (_) {}

    // Include last selected seller in list if valid and not deleted
    final lastSeller = await getLastSelectedSeller();
    if (lastSeller != null && (lastSeller['username'] ?? '').isNotEmpty) {
      final sUsername = lastSeller['username']!.trim();
      if (!deletedList.contains(sUsername)) {
        final exists = result.any((c) => (c['seller_username'] ?? '').toString().trim() == sUsername);
        if (!exists) {
          result.insert(0, {
            'seller_username': sUsername,
            'seller_name': lastSeller['name'] ?? sUsername,
            'seller_mobile': lastSeller['mobile'] ?? '',
            'last_message': 'Connected Store 🏪',
            'last_time': 'Active',
          });
        }
      }
    }

    return result;
  }

  /// Un-mark a seller from deleted sellers list when customer re-selects/connects with them
  static Future<void> unmarkDeletedSeller({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();
    if (cleanCust.isNotEmpty && cleanSeller.isNotEmpty) {
      final key = 'deleted_sellers_$cleanCust';
      final List<String> deletedList = prefs.getStringList(key) ?? [];
      if (deletedList.contains(cleanSeller)) {
        deletedList.remove(cleanSeller);
        await prefs.setStringList(key, deletedList);
      }
    }
  }

  /// Delete/Disconnect a Seller from Customer's Store List
  static Future<bool> deleteCustomerSellerConnection({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();

    // 1. Record seller in deleted_sellers list so app never auto-selects this seller on restart
    if (cleanCust.isNotEmpty && cleanSeller.isNotEmpty) {
      final key = 'deleted_sellers_$cleanCust';
      final List<String> deletedList = prefs.getStringList(key) ?? [];
      if (!deletedList.contains(cleanSeller)) {
        deletedList.add(cleanSeller);
        await prefs.setStringList(key, deletedList);
      }
    }

    // 2. Clear last selected seller
    await clearLastSelectedSeller();

    // 3. Clear cached messages for this seller & customer
    await prefs.remove('msgs_${cleanSeller}_${cleanCust}');

    // 4. Clear customer sample orders from this seller
    try {
      final custKey = 'sample_orders_cust_$cleanCust';
      final custOrdersStr = prefs.getString(custKey);
      if (custOrdersStr != null && custOrdersStr.isNotEmpty) {
        final List<dynamic> l = jsonDecode(custOrdersStr);
        final filtered = l.where((o) => (o['seller_username'] ?? '').toString().trim() != cleanSeller).toList();
        await prefs.setString(custKey, jsonEncode(filtered));
      }
    } catch (_) {}

    // 5. Post to VPS API to delete messages/conversations between customer and seller
    try {
      await VpsApiService.post('delete-seller-connection', {
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
      });
    } catch (_) {}

    return true;
  }

  /// Get Messages between specific Seller and Customer (With Persistent Order Amount Merge)
  static Future<List<Map<String, dynamic>>> getMessages({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'msgs_${sellerUsername.trim()}_${customerMobile.trim()}';

    Map<String, dynamic> savedAmounts = {};
    Map<String, dynamic> savedPayments = {};
    Map<String, dynamic> savedDeliveryStatuses = {};
    Map<String, dynamic> savedOrderStatuses = {};
    Map<String, dynamic> savedBills = {};
    try {
      final amountsStr = prefs.getString('saved_order_amounts');
      if (amountsStr != null && amountsStr.isNotEmpty) {
        savedAmounts = Map<String, dynamic>.from(jsonDecode(amountsStr));
      }
      final paymentsStr = prefs.getString('saved_order_payments');
      if (paymentsStr != null && paymentsStr.isNotEmpty) {
        savedPayments = Map<String, dynamic>.from(jsonDecode(paymentsStr));
      }
      final deliveryStr = prefs.getString('saved_delivery_statuses');
      if (deliveryStr != null && deliveryStr.isNotEmpty) {
        savedDeliveryStatuses = Map<String, dynamic>.from(jsonDecode(deliveryStr));
      }
      final orderStatStr = prefs.getString('saved_order_statuses');
      if (orderStatStr != null && orderStatStr.isNotEmpty) {
        savedOrderStatuses = Map<String, dynamic>.from(jsonDecode(orderStatStr));
      }
      final billsStr = prefs.getString('saved_order_bills');
      if (billsStr != null && billsStr.isNotEmpty) {
        savedBills = Map<String, dynamic>.from(jsonDecode(billsStr));
      }
    } catch (_) {}

    List<Map<String, dynamic>> msgs = [];
    try {
      final encSeller = Uri.encodeComponent(sellerUsername.trim());
      final encCust = Uri.encodeComponent(customerMobile.trim());
      final query = 'get-messages&seller_username=$encSeller&customer_mobile=$encCust';
      final res = await VpsApiService.get(query);
      if (res != null && res['messages'] != null) {
        final List<dynamic> list = res['messages'];
        msgs = list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    if (msgs.isEmpty) {
      final localStr = prefs.getString(localKey);
      if (localStr != null && localStr.isNotEmpty) {
        try {
          final List decoded = jsonDecode(localStr);
          msgs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    // Merge saved order amounts, payments, delivery statuses, order statuses & bill images onto message objects
    for (var m in msgs) {
      final idStr = m['id']?.toString() ?? '';
      if (savedAmounts.containsKey(idStr)) {
        m['order_amount'] = savedAmounts[idStr];
      }
      if (savedPayments.containsKey(idStr)) {
        final pData = Map<String, dynamic>.from(savedPayments[idStr]);
        m['payment_status'] = pData['payment_status'];
        m['payment_utr'] = pData['payment_utr'];
        m['paid_amount'] = pData['paid_amount'];
        m['paid_at'] = pData['paid_at'];
      }
      if (savedDeliveryStatuses.containsKey(idStr)) {
        final dData = Map<String, dynamic>.from(savedDeliveryStatuses[idStr]);
        m['delivery_status'] = dData['delivery_status'];
        m['delivered_by'] = dData['delivered_by'];
        m['delivered_at'] = dData['delivered_at'];
        m['picked_up_at'] = dData['picked_up_at'];
      }
      if (savedOrderStatuses.containsKey(idStr)) {
        m['order_status'] = savedOrderStatuses[idStr];
      }
      if (savedBills.containsKey(idStr)) {
        final bData = Map<String, dynamic>.from(savedBills[idStr]);
        m['bill_image'] = bData['bill_image'];
      }
    }

    if (msgs.isNotEmpty) {
      await prefs.setString(localKey, jsonEncode(msgs));
    }

    return msgs;
  }

  /// Get Local Sellers
  static Future<List<Map<String, dynamic>>> getLocalSellers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_sellersKey);
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      return list.cast<Map<String, dynamic>>();
    }
    return [
      {
        'id': 'seller_1',
        'name': 'Sample Seller',
        'username': 'seller1',
        'password': '123',
        'mobile': '9876543210',
      }
    ];
  }

  /// Create new Seller ID & Password with Mobile (By Admin)
  static Future<Map<String, dynamic>> createSellerResult({
    required String name,
    required String username,
    required String password,
    String mobile = '',
  }) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;
    final cleanUsername = username.trim().toLowerCase();

    // 1. Check if mobile or username already exists in Sellers
    final existingSellers = await getSellersList();
    for (var s in existingSellers) {
      final u = (s['username'] ?? '').toString().toLowerCase();
      if (u == cleanUsername) {
        return {'success': false, 'reason': 'username_exists', 'message': 'Already exist! Seller Username/ID is already registered.'};
      }
      if (last10.isNotEmpty) {
        final sMob = (s['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMob.length >= 10 ? sMob.substring(sMob.length - 10) : sMob;
        if (sLast10.isNotEmpty && sLast10 == last10) {
          return {'success': false, 'reason': 'mobile_exists', 'message': 'Already exist! A Seller with this mobile number (+91 $last10) is already registered.'};
        }
      }
    }

    // 2. Check if mobile already exists in Delivery Boys
    final existingDeliveryBoys = await getDeliveryBoys();
    for (var d in existingDeliveryBoys) {
      if (last10.isNotEmpty) {
        final dMob = (d['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final dLast10 = dMob.length >= 10 ? dMob.substring(dMob.length - 10) : dMob;
        if (dLast10.isNotEmpty && dLast10 == last10) {
          return {'success': false, 'reason': 'mobile_exists', 'message': 'Already exist! A Delivery Partner with this mobile number (+91 $last10) is already registered.'};
        }
      }
    }

    try {
      final res = await VpsApiService.post('create-seller', {
        'name': name.trim(),
        'username': username.trim(),
        'password': password.trim(),
        'mobile': mobile.trim(),
      });
      if (res != null && res['success'] == true) {
        return {'success': true, 'message': 'Seller Account Created Successfully!'};
      }
    } catch (_) {}

    // Fallback to local storage if VPS API offline
    final sellers = await getLocalSellers();
    final newSeller = {
      'id': 'seller_${DateTime.now().millisecondsSinceEpoch}',
      'name': name.trim(),
      'username': username.trim(),
      'password': password.trim(),
      'mobile': mobile.trim(),
    };

    sellers.add(newSeller);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sellersKey, jsonEncode(sellers));
    return {'success': true, 'message': 'Seller Account Created Successfully!'};
  }

  /// Maintain backward compatibility bool method for createSeller
  static Future<bool> createSeller({
    required String name,
    required String username,
    required String password,
    String mobile = '',
  }) async {
    final res = await createSellerResult(name: name, username: username, password: password, mobile: mobile);
    return res['success'] == true;
  }

  /// Delete a Seller (By Admin)
  static Future<bool> deleteSeller(String username) async {
    try {
      await VpsApiService.post('delete-seller', {'username': username.trim()});
    } catch (_) {}

    final sellers = await getLocalSellers();
    sellers.removeWhere((s) => s['username']?.toString().trim() == username.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sellersKey, jsonEncode(sellers));
    return true;
  }

  /// Get seller sliders (Local-First Guaranteed)
  static Future<List<Map<String, dynamic>>> getSellerSliders(String sellerUsername) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$sellerUsername';
    List<Map<String, dynamic>> localList = [];
    final str = prefs.getString(localKey);
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        localList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    try {
      final res = await VpsApiService.get('get-seller-sliders&seller_username=${Uri.encodeComponent(sellerUsername)}');
      if (res != null && res['success'] == true && res['sliders'] != null) {
        final remoteList = List<Map<String, dynamic>>.from(res['sliders']);
        if (remoteList.isNotEmpty) {
          await prefs.setString(localKey, jsonEncode(remoteList));
          return remoteList;
        }
      }
    } catch (_) {}

    return localList;
  }

  /// Add seller slider (Local-First Guaranteed)
  static Future<bool> addSellerSlider({
    required String sellerUsername,
    required String tag,
    required String title,
    required String description,
    String bgImageUrl = '',
    String tagBgColor = '#10B981',
    String tagShape = 'pill',
    String titleColor = '#FFFFFF',
    String descColor = '#E2E8F0',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$sellerUsername';

    final str = prefs.getString(localKey);
    List<Map<String, dynamic>> sliders = [];
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    final newSlider = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': sellerUsername,
      'tag': tag,
      'title': title,
      'description': description,
      'bg_image_url': bgImageUrl,
      'tag_bg_color': tagBgColor,
      'tag_shape': tagShape,
      'title_color': titleColor,
      'desc_color': descColor,
      'created_at': DateTime.now().toString().substring(0, 16),
    };

    sliders.insert(0, newSlider);
    await prefs.setString(localKey, jsonEncode(sliders));

    try {
      await VpsApiService.post('add-seller-slider', {
        'seller_username': sellerUsername,
        'tag': tag,
        'title': title,
        'description': description,
        'bg_image_url': bgImageUrl,
        'tag_bg_color': tagBgColor,
        'tag_shape': tagShape,
        'title_color': titleColor,
        'desc_color': descColor,
      });
    } catch (_) {}

    return true;
  }

  /// Update seller slider
  static Future<bool> updateSellerSlider({
    required dynamic sliderId,
    required String sellerUsername,
    required String tag,
    required String title,
    required String description,
    required String bgImageUrl,
    required String tagBgColor,
    required String tagShape,
    required String titleColor,
    required String descColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$sellerUsername';

    final str = prefs.getString(localKey);
    List<Map<String, dynamic>> sliders = [];
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    final index = sliders.indexWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    String finalBg = bgImageUrl;
    if (index != -1) {
      sliders[index]['tag'] = tag;
      sliders[index]['title'] = title;
      sliders[index]['description'] = description;
      if (bgImageUrl.isNotEmpty) {
        sliders[index]['bg_image_url'] = bgImageUrl;
      } else {
        finalBg = sliders[index]['bg_image_url'] ?? '';
      }
      sliders[index]['tag_bg_color'] = tagBgColor;
      sliders[index]['tag_shape'] = tagShape;
      sliders[index]['title_color'] = titleColor;
      sliders[index]['desc_color'] = descColor;
      await prefs.setString(localKey, jsonEncode(sliders));
    }

    try {
      await VpsApiService.post('update-seller-slider', {
        'slider_id': sliderId,
        'tag': tag,
        'title': title,
        'description': description,
        'bg_image_url': finalBg,
        'tag_bg_color': tagBgColor,
        'tag_shape': tagShape,
        'title_color': titleColor,
        'desc_color': descColor,
      });
    } catch (_) {}

    return true;
  }

  /// Delete seller slider
  static Future<bool> deleteSellerSlider(dynamic sliderId, String sellerUsername) async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$sellerUsername';

    final str = prefs.getString(localKey);
    List<Map<String, dynamic>> sliders = [];
    if (str != null) {
      try {
        final List decoded = jsonDecode(str);
        sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    sliders.removeWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    await prefs.setString(localKey, jsonEncode(sliders));

    try {
      await VpsApiService.post('delete-seller-slider', {'slider_id': sliderId});
    } catch (_) {}

    return true;
  }

  /// Check if a customer is blocked by a seller
  static Future<bool> isCustomerBlocked({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'blocked_customers_${sellerUsername.trim()}';
    final List<String> list = prefs.getStringList(key) ?? [];
    return list.contains(customerMobile.trim());
  }

  /// Block a customer
  static Future<bool> blockCustomer({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'blocked_customers_${sellerUsername.trim()}';
    final List<String> list = prefs.getStringList(key) ?? [];
    final cleanMobile = customerMobile.trim();
    if (!list.contains(cleanMobile)) {
      list.add(cleanMobile);
      await prefs.setStringList(key, list);
    }
    try {
      await VpsApiService.post('block-customer', {
        'seller_username': sellerUsername.trim(),
        'customer_mobile': cleanMobile,
      });
    } catch (_) {}
    return true;
  }

  /// Unblock a customer
  static Future<bool> unblockCustomer({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'blocked_customers_${sellerUsername.trim()}';
    final List<String> list = prefs.getStringList(key) ?? [];
    final cleanMobile = customerMobile.trim();
    if (list.contains(cleanMobile)) {
      list.remove(cleanMobile);
      await prefs.setStringList(key, list);
    }
    try {
      await VpsApiService.post('unblock-customer', {
        'seller_username': sellerUsername.trim(),
        'customer_mobile': cleanMobile,
      });
    } catch (_) {}
    return true;
  }

  // ==========================================
  // SAMPLING CATALOG & ORDERS API & STORAGE
  // ==========================================

  /// Get Samples Catalog posted by a seller
  static Future<List<Map<String, dynamic>>> getSamplesCatalog(String sellerUsername) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'samples_catalog_${sellerUsername.trim()}';
    final str = prefs.getString(key);
    if (str != null && str.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(str);
        final result = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var item in result) {
          List<Map<String, dynamic>> seenList = [];
          if (item['seen_by_list'] != null && item['seen_by_list'] is List) {
            seenList = (item['seen_by_list'] as List).map((x) => Map<String, dynamic>.from(x)).toList();
          }
          item['seen_by_list'] = seenList;
          item['seen_by_count'] = seenList.length;
        }
        return result;
      } catch (_) {}
    }
    // Return empty catalog if no samples posted yet by seller
    return [];
  }

  /// Fetch all sample catalog items ONLY for the currently selected seller of a customer
  static Future<List<Map<String, dynamic>>> getAllSamplesForCustomer({
    required String customerMobile,
    String? currentSellerUsername,
  }) async {
    if (customerMobile.trim().isEmpty) return [];

    String targetSeller = (currentSellerUsername ?? '').trim();
    if (targetSeller.isEmpty || targetSeller == 'seller') {
      final lastSeller = await getLastSelectedSeller();
      if (lastSeller != null && (lastSeller['username'] ?? '').isNotEmpty) {
        targetSeller = lastSeller['username']!.trim();
      }
    }

    if (targetSeller.isEmpty || targetSeller == 'seller') {
      final chats = await getCustomerConversations(customerMobile);
      if (chats.isNotEmpty) {
        targetSeller = (chats.first['seller_username'] ?? '').toString().trim();
      }
    }

    if (targetSeller.isEmpty || targetSeller == 'seller') {
      return [];
    }

    final items = await getSamplesCatalog(targetSeller);
    return items.where((item) => item['id'] != 'smp_default_1').toList();
  }

  /// Record that a customer viewed a sample catalog item
  static Future<bool> recordSampleView({
    required String sellerUsername,
    required String sampleId,
    required String customerName,
    required String customerMobile,
  }) async {
    if (customerMobile.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final nowStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} • ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    
    final keys = prefs.getKeys().where((k) => k.startsWith('samples_catalog_')).toList();
    if (sellerUsername.isNotEmpty) {
      final primaryKey = 'samples_catalog_${sellerUsername.trim()}';
      if (!keys.contains(primaryKey)) keys.add(primaryKey);
    }

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(str);
          final catalog = list.map((e) => Map<String, dynamic>.from(e)).toList();
          bool updated = false;

          for (var item in catalog) {
            if (item['id'].toString() == sampleId.toString()) {
              List<Map<String, dynamic>> seenList = [];
              if (item['seen_by_list'] != null && item['seen_by_list'] is List) {
                seenList = (item['seen_by_list'] as List).map((x) => Map<String, dynamic>.from(x)).toList();
              }

              final existingIdx = seenList.indexWhere((c) => c['mobile'].toString().trim() == customerMobile.trim());
              if (existingIdx != -1) {
                seenList[existingIdx]['viewed_at'] = nowStr;
                if (customerName.isNotEmpty) {
                  seenList[existingIdx]['name'] = customerName;
                }
              } else {
                seenList.add({
                  'name': customerName.isNotEmpty ? customerName : 'Customer (+91 $customerMobile)',
                  'mobile': customerMobile,
                  'viewed_at': nowStr,
                });
              }

              item['seen_by_list'] = seenList;
              item['seen_by_count'] = seenList.length;
              updated = true;
              break;
            }
          }

          if (updated) {
            await prefs.setString(key, jsonEncode(catalog));
          }
        } catch (_) {}
      }
    }

    return true;
  }

  /// Get count of samples posted by seller that customer hasn't viewed/seen yet
  static Future<int> getUnseenSamplesCount({
    required String sellerUsername,
    required String customerMobile,
  }) async {
    if (customerMobile.isEmpty) return 0;
    final catalog = await getAllSamplesForCustomer(
      customerMobile: customerMobile,
      currentSellerUsername: sellerUsername,
    );
    if (catalog.isEmpty) return 0;

    int unseenCount = 0;

    for (var item in catalog) {
      if (item['id'] == 'smp_default_1') continue;
      List<Map<String, dynamic>> seenList = [];
      if (item['seen_by_list'] != null && item['seen_by_list'] is List) {
        seenList = (item['seen_by_list'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final bool alreadySeen = seenList.any((c) => c['mobile'].toString().trim() == customerMobile.trim());
      if (!alreadySeen) {
        unseenCount++;
      }
    }

    return unseenCount;
  }

  /// Add a new sample item to Catalog
  static Future<bool> addSampleCatalog({
    required String sellerUsername,
    required String sellerName,
    required String title,
    required String rate,
    String? imageBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'samples_catalog_${sellerUsername.trim()}';
    final existing = await getSamplesCatalog(sellerUsername);
    final nowStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} • ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    
    final newItem = {
      'id': 'smp_${DateTime.now().millisecondsSinceEpoch}',
      'seller_username': sellerUsername,
      'seller_name': sellerName,
      'title': title,
      'rate': rate,
      'image_url': imageBase64 ?? 'preset',
      'created_at': nowStr,
      'seen_by_count': 1,
    };
    
    existing.add(newItem);
    await prefs.setString(key, jsonEncode(existing));

    try {
      await VpsApiService.post('add-sample-catalog', newItem);
    } catch (_) {}

    return true;
  }

  /// Delete a sample item from Catalog
  static Future<bool> deleteSampleCatalog({
    required String sellerUsername,
    required String sampleId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'samples_catalog_${sellerUsername.trim()}';
    final existing = await getSamplesCatalog(sellerUsername);
    existing.removeWhere((item) => item['id'] == sampleId);
    await prefs.setString(key, jsonEncode(existing));

    try {
      await VpsApiService.post('delete-sample-catalog', {
        'seller_username': sellerUsername,
        'sample_id': sampleId,
      });
    } catch (_) {}

    return true;
  }

  /// Place a Sample Order by Customer
  static Future<bool> placeSampleOrder({
    required String sellerUsername,
    required String sellerName,
    required String customerMobile,
    required String customerName,
    required String sampleId,
    required String title,
    required String rate,
    required int pcs,
    required String note,
    String? imageUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} • ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    final double unitRate = double.tryParse(rate) ?? 0.0;
    final double total = unitRate * pcs;
    final orderTag = await getNextGlobalOrderId(sellerUsername, customerMobile: customerMobile);

    final orderItem = {
      'id': orderTag,
      'sample_id': sampleId,
      'seller_username': sellerUsername,
      'seller_name': sellerName,
      'customer_mobile': customerMobile,
      'customer_name': customerName.isNotEmpty ? customerName : 'Customer (+91 $customerMobile)',
      'title': title,
      'rate': rate,
      'pcs': pcs,
      'total_price': total,
      'customer_note': note,
      'image_url': imageUrl ?? 'preset',
      'status': 'Process',
      'created_at': nowStr,
    };

    // Save to Seller Key
    final sellerKey = 'sample_orders_${sellerUsername.trim()}';
    final sellerOrdersStr = prefs.getString(sellerKey);
    List<Map<String, dynamic>> sellerOrders = [];
    if (sellerOrdersStr != null && sellerOrdersStr.isNotEmpty) {
      try {
        final List<dynamic> l = jsonDecode(sellerOrdersStr);
        sellerOrders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    sellerOrders.insert(0, orderItem);
    await prefs.setString(sellerKey, jsonEncode(sellerOrders));

    // Save to Customer Key
    final custKey = 'sample_orders_cust_${customerMobile.trim()}';
    final custOrdersStr = prefs.getString(custKey);
    List<Map<String, dynamic>> custOrders = [];
    if (custOrdersStr != null && custOrdersStr.isNotEmpty) {
      try {
        final List<dynamic> l = jsonDecode(custOrdersStr);
        custOrders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    custOrders.insert(0, orderItem);
    await prefs.setString(custKey, jsonEncode(custOrders));

    try {
      await VpsApiService.post('place-sample-order', orderItem);
    } catch (_) {}

    return true;
  }

  /// Get Seller Sample Orders (Orders received from Customers)
  static Future<List<Map<String, dynamic>>> getSellerSampleOrders(String sellerUsername) async {
    final prefs = await SharedPreferences.getInstance();
    final sellerKey = 'sample_orders_${sellerUsername.trim()}';
    final str = prefs.getString(sellerKey);
    if (str != null && str.isNotEmpty) {
      try {
        final List<dynamic> l = jsonDecode(str);
        return l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Get Customer Sample Orders (Orders placed by Customer)
  static Future<List<Map<String, dynamic>>> getCustomerSampleOrders(String customerMobile) async {
    final prefs = await SharedPreferences.getInstance();
    final custKey = 'sample_orders_cust_${customerMobile.trim()}';
    final str = prefs.getString(custKey);
    if (str != null && str.isNotEmpty) {
      try {
        final List<dynamic> l = jsonDecode(str);
        return l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Update Sample Order Status by Seller (Pending, Ready, Cancelled)
  static Future<bool> updateSampleOrderStatus({
    required String sellerUsername,
    required String customerMobile,
    required String orderId,
    required String newStatus,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Update in Seller Store
    final sellerKey = 'sample_orders_${sellerUsername.trim()}';
    final sellerOrders = await getSellerSampleOrders(sellerUsername);
    for (var ord in sellerOrders) {
      if (ord['id'] == orderId) {
        ord['status'] = newStatus;
      }
    }
    await prefs.setString(sellerKey, jsonEncode(sellerOrders));

    // Update in Customer Store
    final custKey = 'sample_orders_cust_${customerMobile.trim()}';
    final custOrders = await getCustomerSampleOrders(customerMobile);
    for (var ord in custOrders) {
      if (ord['id'] == orderId) {
        ord['status'] = newStatus;
      }
    }
    await prefs.setString(custKey, jsonEncode(custOrders));

    try {
      await VpsApiService.post('update-sample-order-status', {
        'seller_username': sellerUsername,
        'order_id': orderId,
        'status': newStatus,
      });
    } catch (_) {}

    return true;
  }

  /// Get Customer Default Saved Address
  static Future<Map<String, dynamic>?> getDefaultCustomerAddress(String customerMobile) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'customer_addresses_${customerMobile.trim()}';
    final str = prefs.getString(key);
    if (str != null && str.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(str);
        final addrs = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var a in addrs) {
          if (a['isDefault'] == true) {
            return a;
          }
        }
        if (addrs.isNotEmpty) return addrs.first;
      } catch (_) {}
    }
    return null;
  }

  /// System Mobile Number, Razorpay Key ID & Live Payment Handle
  static const String defaultStoreMobile = '7033846351';
  static const String razorpayKeyId = 'rzp_live_TIxPOBYJT2JmwW';
  static const String razorpayKeySecret = 'fdcF0RTvmk22hiH32fhao8Wg';
  static const String razorpayMeUrl = 'https://razorpay.me/@pushprajgupta';

  /// Get Live Payment Handle URL (Clean URL without extra query parameters)
  static String getLivePaymentHandleUrl({double? amount}) {
    return razorpayMeUrl;
  }

  /// Get Razorpay Instant Embedded Checkout URL with prefilled Customer details
  static String getRazorpayCheckoutUrl({
    required double amount,
    required String orderId,
    required String storeName,
    String? customerMobile,
    String? customerName,
  }) {
    final paise = (amount * 100).toInt();
    final cleanStore = storeName.trim().isNotEmpty ? storeName.trim() : 'Daily Mart Store';
    final encName = Uri.encodeComponent(cleanStore);
    final encDesc = Uri.encodeComponent('Order $orderId');
    final mobile = (customerMobile != null && customerMobile.trim().isNotEmpty)
        ? customerMobile.trim()
        : defaultStoreMobile;
    final custName = Uri.encodeComponent(
        (customerName != null && customerName.trim().isNotEmpty) ? customerName.trim() : 'Customer');

    return 'https://api.razorpay.com/v1/checkout/embedded?key_id=$razorpayKeyId&amount=$paise&currency=INR&name=$encName&description=$encDesc&prefill[contact]=$mobile&prefill[name]=$custName&prefill[email]=customer%40dailymart.com';
  }

  /// Create Razorpay Payment Link for Seamless Automated Checkout
  static Future<String?> createRazorpayPaymentLink({
    required double amount,
    required String orderId,
    required String customerMobile,
    required String customerName,
  }) async {
    final details = await createRazorpayPaymentLinkDetails(
      amount: amount,
      orderId: orderId,
      customerMobile: customerMobile,
      customerName: customerName,
    );
    return details?['short_url'];
  }

  /// Create Razorpay Payment Link returning both short_url & plink_id
  static Future<Map<String, String>?> createRazorpayPaymentLinkDetails({
    required double amount,
    required String orderId,
    required String customerMobile,
    required String customerName,
  }) async {
    try {
      final amountInPaise = (amount * 100).toInt();
      final body = {
        'amount': amountInPaise,
        'currency': 'INR',
        'accept_partial': false,
        'description': 'Daily Mart Order #$orderId',
        'customer': {
          'name': customerName.isNotEmpty ? customerName : 'Customer',
          'contact': customerMobile.isNotEmpty ? customerMobile : defaultStoreMobile,
        },
        'notify': {'sms': false, 'email': false},
        'reminder_enable': false,
      };

      final authStr = base64Encode(utf8.encode('$razorpayKeyId:$razorpayKeySecret'));
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/payment_links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $authStr',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final shortUrl = data['short_url']?.toString() ?? '';
        final plinkId = data['id']?.toString() ?? '';
        if (shortUrl.isNotEmpty) {
          return {
            'short_url': shortUrl,
            'plink_id': plinkId,
          };
        }
      }
    } catch (e) {
      debugPrint('Error creating Razorpay payment link details: $e');
    }
    return null;
  }

  /// Query Razorpay API directly to check if Payment Link is PAID and return Real Payment ID / Bank UTR
  static Future<String?> checkRazorpayPaymentLinkRealUtr(String plinkId) async {
    if (plinkId.trim().isEmpty) return null;
    try {
      final authStr = base64Encode(utf8.encode('$razorpayKeyId:$razorpayKeySecret'));
      final response = await http.get(
        Uri.parse('https://api.razorpay.com/v1/payment_links/${plinkId.trim()}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $authStr',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'paid') {
          final payments = data['payments'];
          if (payments is List && payments.isNotEmpty) {
            final firstPay = payments[0];
            if (firstPay is Map) {
              final payId = (firstPay['payment_id'] ?? firstPay['id'] ?? '').toString().trim();
              final bankTxnId = (firstPay['bank_transaction_id'] ?? '').toString().trim();
              final rrn = (firstPay['acquirer_data']?['rrn'] ?? firstPay['acquirer_data']?['upi_transaction_id'] ?? '').toString().trim();

              if (payId.isNotEmpty) {
                return payId.toUpperCase();
              } else if (bankTxnId.isNotEmpty) {
                return 'UTR_$bankTxnId';
              } else if (rrn.isNotEmpty) {
                return 'UTR_$rrn';
              }
            }
          }
          final cleanPlink = plinkId.replaceAll('plink_', '');
          return 'PAY_$cleanPlink'.toUpperCase();
        }
      }
    } catch (e) {
      debugPrint('Error checking Razorpay payment link status: $e');
    }
    return null;
  }

  /// Query Razorpay API directly to check if Payment Link is PAID
  static Future<bool> checkRazorpayPaymentLinkPaid(String plinkId) async {
    final utr = await checkRazorpayPaymentLinkRealUtr(plinkId);
    return utr != null && utr.isNotEmpty;
  }

  /// Verify real payment status from Razorpay API or VPS Backend API
  static Future<bool> verifyRazorpayPaymentViaApi({
    required String orderId,
    required double expectedAmount,
  }) async {
    try {
      final res = await VpsApiService.get('verify-payment-status&order_id=${Uri.encodeComponent(orderId)}');
      if (res != null && res['success'] == true && res['is_paid'] == true) {
        return true;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('saved_order_payments');
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> savedPayments = Map<String, dynamic>.from(jsonDecode(str));
        if (savedPayments.containsKey(orderId)) {
          final pData = savedPayments[orderId];
          if (pData != null && (pData['payment_status'] ?? '').toString().toLowerCase() == 'paid') {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  /// Mark Order as Paid with UTR Reference
  static Future<bool> markOrderPaid({
    required String sellerUsername,
    required String customerMobile,
    required int messageId,
    required String utrNumber,
    required double amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();
    final idStr = messageId.toString();

    // 1. Always update global persistent saved_order_payments map
    Map<String, dynamic> savedPayments = {};
    try {
      final str = prefs.getString('saved_order_payments');
      if (str != null && str.isNotEmpty) {
        savedPayments = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    savedPayments[idStr] = {
      'payment_status': 'paid',
      'payment_utr': utrNumber.trim().toUpperCase(),
      'paid_amount': amount,
      'paid_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString('saved_order_payments', jsonEncode(savedPayments));

    // 2. Update local message keys for both seller and customer
    final keys = [
      'msgs_${cleanSeller}_$cleanCust',
      'messages_${cleanSeller}_$cleanCust',
    ];

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(str);
          final msgs = list.map((e) => Map<String, dynamic>.from(e)).toList();
          bool updated = false;

          for (var msg in msgs) {
            final mId = (msg['id'] as num?)?.toInt() ?? 0;
            if (mId == messageId || mId.toString() == idStr) {
              msg['payment_status'] = 'paid';
              msg['payment_utr'] = utrNumber.trim().toUpperCase();
              msg['paid_amount'] = amount;
              msg['paid_at'] = DateTime.now().toIso8601String();
              updated = true;
            }
          }

          if (updated) {
            await prefs.setString(key, jsonEncode(msgs));
          }
        } catch (_) {}
      }
    }

    // 3. Post to VPS API
    try {
      await VpsApiService.post('update-order-payment-status', {
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
        'message_id': messageId,
        'payment_status': 'paid',
        'payment_utr': utrNumber.trim().toUpperCase(),
        'paid_amount': amount,
      });
    } catch (_) {}

    return true;
  }

  /// Build UPI Intent Uri
  static Uri buildUpiUri({
    required String vpa,
    required String name,
    required double amount,
    required String note,
  }) {
    final cleanVpa = vpa.trim().replaceAll(' ', '');
    final amountStr = (amount % 1 == 0) ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final cleanNote = note.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final queryParams = {
      'pa': cleanVpa,
      'pn': name.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
      'am': amountStr,
      'cu': 'INR',
      'tn': cleanNote.isEmpty ? 'DailyMart Order' : cleanNote,
    };
    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParams,
    );
  }

  // ==========================================
  // DELIVERY BOY MANAGEMENT & AUTHENTICATION
  // ==========================================

  static const String _keyDeliveryBoys = 'registered_delivery_boys';
  static const String _keyDeliveryBoyOrders = 'delivery_boy_assigned_orders';

  /// Admin Creates Delivery Boy Credentials (Role: delivery_boy)
  static Future<Map<String, dynamic>> createDeliveryBoyResult({
    required String username,
    required String password,
    required String name,
    required String mobile,
    String? vehicle,
  }) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;
    final cleanUser = username.trim().toLowerCase();

    // 1. Check if mobile or username already exists in Delivery Boys
    final existingDeliveryBoys = await getDeliveryBoys();
    for (var item in existingDeliveryBoys) {
      final itemUser = (item['username'] ?? '').toString().toLowerCase();
      if (itemUser == cleanUser) {
        return {'success': false, 'reason': 'username_exists', 'message': 'Already exist! Delivery Boy ID is already registered.'};
      }
      if (last10.isNotEmpty) {
        final dMob = (item['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final dLast10 = dMob.length >= 10 ? dMob.substring(dMob.length - 10) : dMob;
        if (dLast10.isNotEmpty && dLast10 == last10) {
          return {'success': false, 'reason': 'mobile_exists', 'message': 'Already exist! A Delivery Partner with this mobile number (+91 $last10) is already registered.'};
        }
      }
    }

    // 2. Check if mobile already exists in Sellers
    final existingSellers = await getSellersList();
    for (var s in existingSellers) {
      if (last10.isNotEmpty) {
        final sMob = (s['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMob.length >= 10 ? sMob.substring(sMob.length - 10) : sMob;
        if (sLast10.isNotEmpty && sLast10 == last10) {
          return {'success': false, 'reason': 'mobile_exists', 'message': 'Already exist! A Seller with this mobile number (+91 $last10) is already registered.'};
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];

    final newDeliveryBoy = {
      'username': cleanUser,
      'password': password.trim(),
      'name': name.trim(),
      'mobile': mobile.trim(),
      'vehicle': vehicle?.trim().isNotEmpty == true ? vehicle!.trim() : 'Bike',
      'role': 'delivery_boy',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'active',
    };

    list.add(jsonEncode(newDeliveryBoy));
    await prefs.setStringList(_keyDeliveryBoys, list);
    return {'success': true, 'message': 'Delivery Boy Account Created Successfully!'};
  }

  /// Maintain backward compatibility bool method for createDeliveryBoy
  static Future<bool> createDeliveryBoy({
    required String username,
    required String password,
    required String name,
    required String mobile,
    String? vehicle,
  }) async {
    final res = await createDeliveryBoyResult(
      username: username,
      password: password,
      name: name,
      mobile: mobile,
      vehicle: vehicle,
    );
    return res['success'] == true;
  }

  /// Find Delivery Boy by Mobile Number
  static Future<Map<String, dynamic>?> findDeliveryBoyByMobile(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;
    if (last10.isEmpty) return null;

    final deliveryBoys = await getDeliveryBoys();
    for (var db in deliveryBoys) {
      final dbMob = (db['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      final dbLast10 = dbMob.length >= 10 ? dbMob.substring(dbMob.length - 10) : dbMob;
      if (dbLast10.isNotEmpty && dbLast10 == last10) {
        return db;
      }
    }
    return null;
  }

  /// Find Seller User Model by Mobile Number
  static Future<UserModel?> findSellerByMobile(String mobile) async {
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;
    if (last10.isEmpty) return null;

    try {
      final sellers = await getSellersList();
      for (var seller in sellers) {
        final sMobile = (seller['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMobile.length >= 10 ? sMobile.substring(sMobile.length - 10) : sMobile;
        if (sLast10.isNotEmpty && sLast10 == last10) {
          return UserModel(
            id: seller['id']?.toString() ?? 'seller_${seller['username']}',
            name: seller['name'] ?? seller['username'],
            username: seller['username'] ?? seller['name'],
            mobile: seller['mobile'] ?? last10,
            role: UserRole.seller,
          );
        }
      }
    } catch (_) {}

    try {
      final localSellers = await getLocalSellers();
      for (var seller in localSellers) {
        final sMobile = (seller['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMobile.length >= 10 ? sMobile.substring(sMobile.length - 10) : sMobile;
        if (sLast10.isNotEmpty && sLast10 == last10) {
          return UserModel(
            id: seller['id']?.toString() ?? 'seller_${seller['username']}',
            name: seller['name'] ?? seller['username'],
            username: seller['username'] ?? seller['name'],
            mobile: seller['mobile'] ?? last10,
            role: UserRole.seller,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Get All Delivery Boys (Admin View)
  static Future<List<Map<String, dynamic>>> getDeliveryBoys() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];
    final res = <Map<String, dynamic>>[];
    for (var str in list) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          res.add(decoded);
        }
      } catch (_) {}
    }
    return res;
  }

  /// Delete Delivery Boy by Username (Admin Function)
  static Future<bool> deleteDeliveryBoy(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];
    final cleanUser = username.trim().toLowerCase();
    final newList = <String>[];
    for (var str in list) {
      try {
        final item = jsonDecode(str);
        if ((item['username'] ?? '').toString().toLowerCase() != cleanUser) {
          newList.add(str);
        }
      } catch (_) {
        newList.add(str);
      }
    }
    await prefs.setStringList(_keyDeliveryBoys, newList);
    return true;
  }

  /// Login Delivery Boy ONLY (Rejects Sellers & Admin for strict role separation)
  static Future<Map<String, dynamic>?> loginDeliveryBoy(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    for (var str in list) {
      try {
        final item = jsonDecode(str);
        final u = (item['username'] ?? '').toString().toLowerCase();
        final p = (item['password'] ?? '').toString();
        final role = (item['role'] ?? '').toString();

        if (u == cleanUser && p == cleanPass) {
          if (role == 'delivery_boy') {
            return item;
          }
        }
      } catch (_) {}
    }
    return null; // Login failed or wrong role
  }

  /// Get Delivery Boy Orders
  static Future<List<Map<String, dynamic>>> getDeliveryBoyOrders(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('${_keyDeliveryBoyOrders}_$username');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  /// Get all undelivered orders grouped by seller (For Delivery Boy Dashboard)
  static Future<List<Map<String, dynamic>>> getAllUndeliveredOrdersGroupedBySeller() async {
    final prefs = await SharedPreferences.getInstance();
    final sellers = await getSellersList();
    final List<Map<String, dynamic>> groupedResult = [];

    // Load persistent saved payments map
    final String? allSavedPaymentsStr = prefs.getString('saved_order_payments');
    Map<String, dynamic> savedPayments = {};
    if (allSavedPaymentsStr != null && allSavedPaymentsStr.isNotEmpty) {
      try {
        savedPayments = Map<String, dynamic>.from(jsonDecode(allSavedPaymentsStr));
      } catch (_) {}
    }

    // Load persistent saved order statuses map
    final String? allSavedOrderStr = prefs.getString('saved_order_statuses');
    Map<String, dynamic> savedOrderStatuses = {};
    if (allSavedOrderStr != null && allSavedOrderStr.isNotEmpty) {
      try {
        savedOrderStatuses = Map<String, dynamic>.from(jsonDecode(allSavedOrderStr));
      } catch (_) {}
    }

    // Load persistent saved delivery statuses map
    final String? allSavedDeliveryStr = prefs.getString('saved_delivery_statuses');
    Map<String, dynamic> savedDeliveryStatuses = {};
    if (allSavedDeliveryStr != null && allSavedDeliveryStr.isNotEmpty) {
      try {
        savedDeliveryStatuses = Map<String, dynamic>.from(jsonDecode(allSavedDeliveryStr));
      } catch (_) {}
    }

    final localKeys = prefs.getKeys();

    for (var seller in sellers) {
      final sellerUsername = (seller['username'] ?? '').toString().trim();
      final sellerName = (seller['name'] ?? 'Seller Store').toString().trim();
      final sellerMobile = (seller['mobile'] ?? '').toString().trim();

      final List<Map<String, dynamic>> undeliveredOrders = [];
      final Set<int> processedMsgIds = {};

      // 1. First fetch conversations from VPS API for full server-synced data
      try {
        final conversations = await getSellerConversations(sellerUsername);
        for (var conv in conversations) {
          final custMobile = (conv['customer_mobile'] ?? conv['mobile'] ?? '').toString().trim();
          if (custMobile.isNotEmpty) {
            final msgs = await getMessages(sellerUsername: sellerUsername, customerMobile: custMobile);
            for (var msgMap in msgs) {
              final msgId = (msgMap['id'] as num?)?.toInt() ?? 0;
              final msgIdStr = msgId.toString();

              if (msgId != 0 && !processedMsgIds.contains(msgId)) {
                final isOrderMsg = msgMap['items_json'] != null ||
                    msgMap['order_id'] != null ||
                    msgMap['_calculated_order_id'] != null ||
                    (msgMap['message'] ?? '').toString().toLowerCase().contains('order');

                final isDeleted = msgMap['order_status'].toString().toLowerCase() == 'deleted' ||
                    msgMap['is_deleted'] == true ||
                    msgMap['is_deleted'] == 1;

                if (isOrderMsg && !isDeleted) {
                  processedMsgIds.add(msgId);

                  String ordStatus = (msgMap['order_status'] ?? '').toString();
                  if (savedOrderStatuses.containsKey(msgIdStr)) {
                    ordStatus = (savedOrderStatuses[msgIdStr] ?? ordStatus).toString();
                  }

                  String delStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
                  if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                    final val = savedDeliveryStatuses[msgIdStr];
                    if (val is Map) {
                      delStatus = (val['delivery_status'] ?? delStatus).toString();
                    } else {
                      delStatus = val.toString();
                    }
                    msgMap['delivery_status'] = delStatus;
                  }

                  final bool isReadyOrBeyond = ordStatus.toLowerCase() == 'ready' ||
                      delStatus.toLowerCase() == 'picked up' ||
                      delStatus.toLowerCase() == 'out for delivery';

                  final bool isCancelled = ordStatus.toLowerCase() == 'cancelled' || delStatus.toLowerCase() == 'cancelled';
                  final bool isDelivered = delStatus.toLowerCase() == 'delivered';

                  if (isReadyOrBeyond && !isCancelled && !isDelivered) {
                    if (savedPayments.containsKey(msgIdStr)) {
                      msgMap['payment_status'] = 'paid';
                      msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? '';
                    }

                    msgMap['seller_username'] = sellerUsername;
                    msgMap['seller_name'] = sellerName;
                    msgMap['customer_mobile'] = custMobile;

                    undeliveredOrders.add(msgMap);
                  }
                }
              }
            }
          }
        }
      } catch (_) {}

      // 2. Also check local SharedPreferences keys for offline/local orders
      final prefix = 'msgs_${sellerUsername.toLowerCase()}_';
      final altPrefix = 'messages_${sellerUsername.toLowerCase()}_';

      for (var key in localKeys) {
        if (key.toLowerCase().startsWith(prefix) || key.toLowerCase().startsWith(altPrefix)) {
          final custMobile = key.substring(key.lastIndexOf('_') + 1);
          final raw = prefs.getString(key);
          if (raw != null && raw.isNotEmpty) {
            try {
              final List<dynamic> list = jsonDecode(raw);
              for (var item in list) {
                if (item is Map) {
                  final msgMap = Map<String, dynamic>.from(item);
                  final msgId = (msgMap['id'] as num?)?.toInt() ?? 0;
                  final msgIdStr = msgId.toString();

                  if (msgId != 0 && !processedMsgIds.contains(msgId)) {
                    final isOrderMsg = msgMap['items_json'] != null ||
                        msgMap['order_id'] != null ||
                        msgMap['_calculated_order_id'] != null ||
                        (msgMap['message'] ?? '').toString().toLowerCase().contains('order');

                    final isDeleted = msgMap['order_status'].toString().toLowerCase() == 'deleted' ||
                        msgMap['is_deleted'] == true ||
                        msgMap['is_deleted'] == 1;

                    if (isOrderMsg && !isDeleted) {
                      processedMsgIds.add(msgId);

                      String ordStatus = (msgMap['order_status'] ?? '').toString();
                      if (savedOrderStatuses.containsKey(msgIdStr)) {
                        ordStatus = (savedOrderStatuses[msgIdStr] ?? ordStatus).toString();
                      }

                      String delStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
                      if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                        final val = savedDeliveryStatuses[msgIdStr];
                        if (val is Map) {
                          delStatus = (val['delivery_status'] ?? delStatus).toString();
                        } else {
                          delStatus = val.toString();
                        }
                        msgMap['delivery_status'] = delStatus;
                      }

                      final bool isReadyOrBeyond = ordStatus.toLowerCase() == 'ready' ||
                          delStatus.toLowerCase() == 'picked up' ||
                          delStatus.toLowerCase() == 'out for delivery';

                      final bool isCancelled = ordStatus.toLowerCase() == 'cancelled' || delStatus.toLowerCase() == 'cancelled';
                      final bool isDelivered = delStatus.toLowerCase() == 'delivered';

                      if (isReadyOrBeyond && !isCancelled && !isDelivered) {
                        if (savedPayments.containsKey(msgIdStr)) {
                          msgMap['payment_status'] = 'paid';
                          msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? '';
                        }

                        msgMap['seller_username'] = sellerUsername;
                        msgMap['seller_name'] = sellerName;
                        msgMap['customer_mobile'] = custMobile;

                        undeliveredOrders.add(msgMap);
                      }
                    }
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      if (undeliveredOrders.isNotEmpty) {
        groupedResult.add({
          'seller_username': sellerUsername,
          'seller_name': sellerName,
          'seller_mobile': sellerMobile,
          'orders': undeliveredOrders,
        });
      }
    }

    return groupedResult;
  }

  /// Update delivery status of an order (Picked Up / Out for Delivery / Delivered)
  static Future<bool> updateDeliveryStatusForOrder({
    required String sellerUsername,
    required String customerMobile,
    required int messageId,
    required String newDeliveryStatus,
    required String deliveryBoyUsername,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanCust = customerMobile.trim().toLowerCase();
    final msgIdStr = messageId.toString();

    // 1. Update persistent global saved_delivery_statuses map in SharedPreferences
    Map<String, dynamic> savedStatuses = {};
    try {
      final str = prefs.getString('saved_delivery_statuses');
      if (str != null && str.isNotEmpty) {
        savedStatuses = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    Map<String, dynamic> existingEntry = {};
    if (savedStatuses.containsKey(msgIdStr) && savedStatuses[msgIdStr] is Map) {
      existingEntry = Map<String, dynamic>.from(savedStatuses[msgIdStr]);
    }

    final now = DateTime.now();
    final formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final String prevPickup = (existingEntry['picked_up_at'] ?? '').toString();
    final String pickedUpAt = prevPickup.isNotEmpty ? prevPickup : formattedTime;
    final String deliveredAt = newDeliveryStatus.toLowerCase() == 'delivered' ? formattedTime : (existingEntry['delivered_at'] ?? '').toString();

    savedStatuses[msgIdStr] = {
      'delivery_status': newDeliveryStatus,
      'delivered_by': deliveryBoyUsername,
      'picked_up_at': pickedUpAt,
      'delivered_at': deliveredAt,
      'updated_at': formattedTime,
    };
    await prefs.setString('saved_delivery_statuses', jsonEncode(savedStatuses));

    // 2. Update local message keys in SharedPreferences
    final keys = [
      'msgs_${cleanSeller}_$cleanCust',
      'messages_${cleanSeller}_$cleanCust',
    ];

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(str);
          final msgs = list.map((e) => Map<String, dynamic>.from(e)).toList();
          bool updated = false;

          for (var msg in msgs) {
            final mId = (msg['id'] as num?)?.toInt() ?? 0;
            if (mId == messageId) {
              msg['delivery_status'] = newDeliveryStatus;
              msg['delivered_by'] = deliveryBoyUsername;
              msg['delivered_at'] = formattedTime;
              msg['updated_at'] = formattedTime;
              updated = true;
            }
          }

          if (updated) {
            await prefs.setString(key, jsonEncode(msgs));
          }
        } catch (_) {}
      }
    }

    // 3. Sync to VPS API Database
    try {
      await VpsApiService.post('update-delivery-status', {
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
        'message_id': messageId,
        'delivery_status': newDeliveryStatus,
        'delivered_by': deliveryBoyUsername,
      });
    } catch (_) {}

    return true;
  }

  /// Cancel an order with a specific reason and timestamp
  static Future<bool> cancelOrderWithReason({
    required String sellerUsername,
    required String customerMobile,
    required int messageId,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanCust = customerMobile.trim().toLowerCase();
    final msgIdStr = messageId.toString();

    final now = DateTime.now();
    final formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // 1. Update persistent saved_order_statuses and saved_cancel_reasons
    Map<String, dynamic> savedStatuses = {};
    Map<String, dynamic> savedReasons = {};
    try {
      final str = prefs.getString('saved_order_statuses');
      if (str != null && str.isNotEmpty) {
        savedStatuses = Map<String, dynamic>.from(jsonDecode(str));
      }
      final rStr = prefs.getString('saved_cancel_reasons');
      if (rStr != null && rStr.isNotEmpty) {
        savedReasons = Map<String, dynamic>.from(jsonDecode(rStr));
      }
    } catch (_) {}
    savedStatuses[msgIdStr] = 'Cancelled';
    savedReasons[msgIdStr] = reason;
    await prefs.setString('saved_order_statuses', jsonEncode(savedStatuses));
    await prefs.setString('saved_cancel_reasons', jsonEncode(savedReasons));

    // 2. Update local message keys in SharedPreferences
    final keys = prefs.getKeys().where((k) => k.startsWith('msgs_') || k.startsWith('messages_')).toList();
    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List decoded = jsonDecode(str);
          final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          bool modified = false;
          for (var item in list) {
            if (item['id'] == messageId || item['id'].toString() == msgIdStr) {
              item['order_status'] = 'Cancelled';
              item['delivery_status'] = 'Cancelled';
              item['cancelled_at'] = formattedTime;
              item['cancel_reason'] = reason;
              modified = true;
            }
          }
          if (modified) {
            await prefs.setString(key, jsonEncode(list));
          }
        } catch (_) {}
      }
    }

    // 3. Sync to VPS API Database
    try {
      await VpsApiService.post('update-order-status', {
        'message_id': messageId,
        'order_status': 'Cancelled',
        'cancelled_at': formattedTime,
        'cancel_reason': reason,
      });
    } catch (_) {}
    return true;
  }

  /// Update Delivery Order Status (Picked Up / Out for Delivery / Delivered)
  static Future<bool> updateDeliveryOrderStatus({
    required int messageId,
    required String status,
    required String deliveryBoyUsername,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final orders = await getDeliveryBoyOrders(deliveryBoyUsername);
    for (var o in orders) {
      if ((o['id'] as num?)?.toInt() == messageId) {
        o['delivery_status'] = status;
      }
    }
    await prefs.setString('${_keyDeliveryBoyOrders}_$deliveryBoyUsername', jsonEncode(orders));
    return true;
  }

  /// Save Order Bill Image (Base64)
  static Future<bool> saveOrderBillImage({
    required int messageId,
    required String base64Image,
    required String sellerUsername,
    required String customerMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanCust = customerMobile.trim().toLowerCase();
    final msgIdStr = messageId.toString();

    // 1. Update persistent global saved_order_bills map in SharedPreferences
    Map<String, dynamic> savedBills = {};
    try {
      final str = prefs.getString('saved_order_bills');
      if (str != null && str.isNotEmpty) {
        savedBills = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    savedBills[msgIdStr] = {
      'bill_image': base64Image,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await prefs.setString('saved_order_bills', jsonEncode(savedBills));

    // 2. Update local message keys in SharedPreferences
    final keys = [
      'msgs_${cleanSeller}_$cleanCust',
      'messages_${cleanSeller}_$cleanCust',
    ];

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(str);
          final msgs = list.map((e) => Map<String, dynamic>.from(e)).toList();
          bool updated = false;

          for (var msg in msgs) {
            final mId = (msg['id'] as num?)?.toInt() ?? 0;
            if (mId == messageId) {
              msg['bill_image'] = base64Image;
              updated = true;
            }
          }

          if (updated) {
            await prefs.setString(key, jsonEncode(msgs));
          }
        } catch (_) {}
      }
    }

    // 3. Sync to VPS API Database
    try {
      await VpsApiService.post('save-order-bill-image', {
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
        'message_id': messageId,
        'bill_image': base64Image,
      });
    } catch (_) {}

    return true;
  }

  // ==========================================
  // REAL-TIME POPUP NOTIFICATION ENGINE
  // ==========================================

  /// Create a Popup Notification for a specific role/user
  static Future<void> createPopupNotification({
    required String targetRole, // 'customer', 'seller', 'delivery_boy'
    String targetUser = '', // customer mobile or seller username
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingStr = prefs.getString('app_popup_notifications');
      List<Map<String, dynamic>> notifications = [];
      if (existingStr != null && existingStr.isNotEmpty) {
        final List decoded = jsonDecode(existingStr);
        notifications = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final newNotif = {
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (notifications.length % 9000))}',
        'target_role': targetRole.trim().toLowerCase(),
        'target_user': targetUser.trim().toLowerCase(),
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toString().split('.')[0],
        'is_read': false,
      };

      notifications.insert(0, newNotif);
      // Keep last 100 notifications
      if (notifications.length > 100) {
        notifications = notifications.sublist(0, 100);
      }

      await prefs.setString('app_popup_notifications', jsonEncode(notifications));
    } catch (e) {
      debugPrint('Error creating popup notification: $e');
    }
  }

  /// Get & mark unread notifications for a specific user and role
  static Future<List<Map<String, dynamic>>> getAndConsumeUnreadPopupNotifications({
    required String role, // 'customer', 'seller', 'delivery_boy'
    String usernameOrMobile = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingStr = prefs.getString('app_popup_notifications');
      if (existingStr == null || existingStr.isEmpty) return [];

      final List decoded = jsonDecode(existingStr);
      List<Map<String, dynamic>> notifications =
          decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      final String reqRole = role.trim().toLowerCase();
      final String reqUser = usernameOrMobile.trim().toLowerCase();

      List<Map<String, dynamic>> unreadToReturn = [];
      bool modified = false;

      for (var notif in notifications) {
        final targetRole = (notif['target_role'] ?? '').toString().toLowerCase();
        final targetUser = (notif['target_user'] ?? '').toString().toLowerCase();
        final isRead = notif['is_read'] == true;

        if (!isRead && (targetRole == reqRole || targetRole == 'all')) {
          if (targetUser.isEmpty || reqUser.isEmpty || targetUser == reqUser) {
            unreadToReturn.add(Map<String, dynamic>.from(notif));
            notif['is_read'] = true;
            modified = true;
          }
        }
      }

      if (modified) {
        await prefs.setString('app_popup_notifications', jsonEncode(notifications));
      }

      return unreadToReturn;
    } catch (e) {
      debugPrint('Error fetching unread popup notifications: $e');
      return [];
    }
  }

  /// Helper to render Popup Dialog on any BuildContext
  static void showAppNotificationDialog(BuildContext context, Map<String, dynamic> notif) {
    final title = (notif['title'] ?? 'Notification').toString();
    final body = (notif['body'] ?? '').toString();
    final type = (notif['type'] ?? '').toString().toLowerCase();

    IconData iconData = Icons.notifications_active_rounded;
    Color iconColor = const Color(0xFF10B981);

    if (type.contains('cancel')) {
      iconData = Icons.cancel_rounded;
      iconColor = const Color(0xFFEF4444);
    } else if (type.contains('ready')) {
      iconData = Icons.check_circle_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (type.contains('picked')) {
      iconData = Icons.two_wheeler_rounded;
      iconColor = const Color(0xFF3B82F6);
    } else if (type.contains('deliver')) {
      iconData = Icons.verified_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (type.contains('new_order')) {
      iconData = Icons.shopping_bag_rounded;
      iconColor = const Color(0xFF8B5CF6);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          body,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
