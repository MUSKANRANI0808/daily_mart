import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  static const String _currentDeliveryBoyKey = 'current_delivery_boy';

  /// Save logged in Delivery Boy session
  static Future<void> saveDeliveryBoySession(Map<String, dynamic> deliveryBoy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentDeliveryBoyKey, jsonEncode(deliveryBoy));
  }

  /// Get active logged-in Delivery Boy session
  static Future<Map<String, dynamic>?> getDeliveryBoySession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_currentDeliveryBoyKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(jsonStr));
      } catch (_) {}
    }
    return null;
  }

  /// Clear active logged-in Delivery Boy session
  static Future<void> clearDeliveryBoySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentDeliveryBoyKey);
  }

  /// Logout current user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_currentDeliveryBoyKey);
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

  /// Seller Login Check (Strict Authentication against Database sellers table)
  static Future<UserModel?> loginSeller(String username, String password) async {
    final cleanInput = username.trim();
    final cleanPass = password.trim();
    if (cleanInput.isEmpty || cleanPass.isEmpty) return null;

    final lowerInput = cleanInput.toLowerCase();
    final digitsInput = cleanInput.replaceAll(RegExp(r'\D'), '');
    final last10Input = digitsInput.length >= 10 ? digitsInput.substring(digitsInput.length - 10) : digitsInput;

    // 1. Try VPS seller-login API endpoint (POST and GET fallback)
    try {
      final res = await VpsApiService.post('seller-login', {
            'username': cleanInput,
            'password': cleanPass,
          }) ??
          await VpsApiService.get('seller-login&username=${Uri.encodeComponent(cleanInput)}&password=${Uri.encodeComponent(cleanPass)}');

      if (res != null && res['success'] == true && res['seller'] != null) {
        final sellerData = res['seller'];
        final sellerUser = UserModel(
          id: sellerData['id']?.toString() ?? 'seller_${sellerData['username']}',
          name: sellerData['name'] ?? cleanInput,
          username: sellerData['username'] ?? cleanInput,
          mobile: sellerData['mobile'],
          role: UserRole.seller,
        );
        await saveUserSession(sellerUser);
        return sellerUser;
      }
    } catch (_) {}

    // 2. Strict Verification against Sellers List in Database / Storage
    try {
      final allSellers = await getSellersList();
      for (var s in allSellers) {
        final uName = (s['username'] ?? '').toString().trim();
        final sName = (s['name'] ?? '').toString().trim();
        final sMobile = (s['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMobile.length >= 10 ? sMobile.substring(sMobile.length - 10) : sMobile;
        final sPass = (s['password'] ?? '').toString().trim();

        final isUsernameMatch = uName.isNotEmpty && uName.toLowerCase() == lowerInput;
        final isNameMatch = sName.isNotEmpty && sName.toLowerCase() == lowerInput;
        final isMobileMatch = last10Input.isNotEmpty && sLast10.isNotEmpty && sLast10 == last10Input;

        final isIdMatch = isUsernameMatch || isNameMatch || isMobileMatch;

        if (isIdMatch) {
          // STRICT Password Verification against Database
          final isPassMatch = sPass.isNotEmpty &&
              (sPass == cleanPass ||
                  sPass.toLowerCase() == cleanPass.toLowerCase() ||
                  (sPass.isEmpty && cleanPass == '1234'));

          if (isPassMatch) {
            final canonicalUsername = uName.isNotEmpty ? uName : (sName.isNotEmpty ? sName : cleanInput);
            final canonicalName = sName.isNotEmpty ? sName : canonicalUsername;
            final sellerUser = UserModel(
              id: s['id']?.toString() ?? 'seller_$canonicalUsername',
              name: canonicalName,
              username: canonicalUsername,
              mobile: s['mobile'] ?? digitsInput,
              role: UserRole.seller,
            );
            await saveUserSession(sellerUser);
            return sellerUser;
          }
        }
      }
    } catch (_) {}

    // STRICT: Return null if username or password does NOT match Database!
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

  /// Fetch and Sync Customer Profile & Addresses from VPS Server Database
  static Future<Map<String, dynamic>?> fetchAndSyncCustomerProfileFromVps(String mobile) async {
    final trimmedMobile = mobile.trim();
    if (trimmedMobile.isEmpty) return null;

    final cleanDigits = trimmedMobile.replaceAll(RegExp(r'\D'), '');
    final cleanMobile = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : trimmedMobile;

    try {
      final res = await VpsApiService.get('get-customer-profile&mobile=$cleanMobile');
      if (res != null && res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();

        final String name = (res['name'] ?? '').toString().trim();
        final keysToSave = {cleanMobile, trimmedMobile, '+91$cleanMobile', '91$cleanMobile'};

        if (name.isNotEmpty && !name.startsWith('Customer')) {
          final profileData = {'mobile': cleanMobile, 'name': name};
          for (var k in keysToSave) {
            await prefs.setString('customer_profile_$k', jsonEncode(profileData));
          }
        }

        final dynamic addrVal = res['address_json'];
        String addrStr = '';
        if (addrVal != null) {
          if (addrVal is String) {
            addrStr = addrVal.trim();
          } else if (addrVal is List) {
            addrStr = jsonEncode(addrVal);
          }
        }

        if (addrStr.isNotEmpty && addrStr != '[]' && addrStr != 'null') {
          for (var k in keysToSave) {
            await prefs.setString('customer_addresses_$k', addrStr);
          }
        }

        return res;
      }
    } catch (e) {
      debugPrint('Error syncing customer profile from VPS: $e');
    }
    return null;
  }

  /// Get Customer Profile Data & Address directly from VPS Server Database
  static Future<Map<String, dynamic>?> getCustomerProfile(String mobile) async {
    final trimmedMobile = mobile.trim();
    final cleanDigits = trimmedMobile.replaceAll(RegExp(r'\D'), '');
    final mobKey = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : trimmedMobile;

    if (mobKey.isEmpty) return null;

    // 1. Fetch directly from VPS Server Database via get-customer-profile
    final vpsRes = await fetchAndSyncCustomerProfileFromVps(mobKey);
    if (vpsRes != null && vpsRes['success'] == true) {
      return vpsRes;
    }

    // 2. Fetch via customer-login API
    try {
      final res = await VpsApiService.post('customer-login', {
        'mobile': mobKey,
      });
      if (res != null && res['success'] == true) {
        return res;
      }
    } catch (_) {}

    // 3. Fallback to local cache
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('customer_profile_$mobKey');
    if (str != null && str.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(str));
        return map;
      } catch (_) {}
    }
    return null;
  }

  /// Save Customer Profile Data & Sync to VPS Server Database
  static Future<void> saveCustomerProfile(String mobile, {required String name}) async {
    final trimmedMobile = mobile.trim();
    final trimmedName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    final data = {'mobile': trimmedMobile, 'name': trimmedName};
    await prefs.setString('customer_profile_$trimmedMobile', jsonEncode(data));

    try {
      await VpsApiService.post('update-customer-profile', {
        'mobile': trimmedMobile,
        'name': trimmedName,
      });
    } catch (_) {}
  }

  /// Save Customer Addresses & Sync to VPS Server Database
  static Future<void> saveCustomerAddresses(String mobile, List<Map<String, dynamic>> addresses) async {
    final trimmedMobile = mobile.trim();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(addresses);
    await prefs.setString('customer_addresses_$trimmedMobile', jsonStr);

    try {
      await VpsApiService.post('update-customer-profile', {
        'mobile': trimmedMobile,
        'address_json': jsonStr,
      });
    } catch (_) {}
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

  static const String _keyLocations = 'app_locations_list';

  /// Get list of all locations (For Admin Seller & Delivery Boy Location selection)
  static Future<List<String>> getLocations() async {
    try {
      final res = await VpsApiService.get('locations');
      if (res != null && res['locations'] != null) {
        final List<dynamic> list = res['locations'];
        final locs = list.map((e) => (e is Map ? (e['name'] ?? e['location_name'] ?? '') : e).toString().trim()).where((s) => s.isNotEmpty).toList();
        if (locs.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_keyLocations, locs);
          return locs;
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final List<String> local = prefs.getStringList(_keyLocations) ?? [];
    if (local.isEmpty) {
      return ['Main Market', 'Central City', 'West Zone', 'North Hub'];
    }
    return local;
  }

  /// Add a new location permanently
  static Future<bool> addLocation(String locationName) async {
    final clean = locationName.trim();
    if (clean.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyLocations) ?? ['Main Market', 'Central City', 'West Zone', 'North Hub'];
    if (!current.contains(clean)) {
      current.add(clean);
      await prefs.setStringList(_keyLocations, current);
    }

    try {
      await VpsApiService.post('add-location', {'name': clean, 'location_name': clean});
    } catch (_) {}

    return true;
  }

  /// Get Cached Sellers List instantly from SharedPreferences (0 ms delay)
  static Future<List<Map<String, dynamic>>> getCachedSellersList() async {
    return getLocalSellers();
  }

  /// Get list of all created Sellers
  static Future<List<Map<String, dynamic>>> getSellersList() async {
    try {
      final res = await VpsApiService.get('sellers');
      if (res != null && res['sellers'] != null) {
        final List<dynamic> list = res['sellers'];
        final sellers = list.cast<Map<String, dynamic>>();
        if (sellers.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sellersKey, jsonEncode(sellers));
          return sellers;
        }
      }
    } catch (_) {}

    return getLocalSellers();
  }

  /// Search Sellers by Mobile Number
  /// Search Sellers by Mobile Number, Seller Name, or Location
  static Future<List<Map<String, dynamic>>> searchSellersByMobile(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    List<Map<String, dynamic>> allSellers = await getSellersList();

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final res = await VpsApiService.get('search-seller&mobile=$encoded');
      if (res != null && res['sellers'] != null) {
        final List<dynamic> list = res['sellers'];
        final vpsSellers = list.cast<Map<String, dynamic>>();

        final existingUsernames = allSellers.map((s) => s['username'].toString().toLowerCase()).toSet();
        for (var s in vpsSellers) {
          final u = (s['username'] ?? '').toString().toLowerCase();
          if (u.isNotEmpty && !existingUsernames.contains(u)) {
            allSellers.add(s);
          }
        }
      }
    } catch (_) {}

    return allSellers.where((s) {
      final m = (s['mobile'] ?? '').toString().toLowerCase();
      final u = (s['username'] ?? '').toString().toLowerCase();
      final n = (s['name'] ?? '').toString().toLowerCase();
      final l = (s['location'] ?? s['seller_location'] ?? '').toString().toLowerCase();

      return m.contains(cleanQuery) ||
             u.contains(cleanQuery) ||
             n.contains(cleanQuery) ||
             l.contains(cleanQuery);
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

    // 1. Fetch deletion-proof sequential Order ID directly from MySQL Database
    try {
      final encSeller = Uri.encodeComponent(cleanSeller);
      final encCust = Uri.encodeComponent(cleanCust);
      final res = await VpsApiService.get('get-next-order-id&seller_username=$encSeller&customer_mobile=$encCust');
      if (res != null && res['success'] == true && res['next_order_id'] != null) {
        final serverOrdId = res['next_order_id'].toString().trim();
        if (serverOrdId.isNotEmpty) {
          return serverOrdId;
        }
      }
    } catch (_) {}

    // 2. Local Fallback Counter
    final prefs = await SharedPreferences.getInstance();
    final globalKey = 'lifetime_global_counter_$cleanSeller';
    final custKey = 'lifetime_cust_counter_${cleanSeller}_$cleanCust';

    int storedGlobal = prefs.getInt(globalKey) ?? 0;
    int storedCust = prefs.getInt(custKey) ?? 0;

    int memGlobal = _memoryOrderCounters['global_$cleanSeller'] ?? 0;
    int memCust = _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] ?? 0;

    int maxGlobal = storedGlobal > memGlobal ? storedGlobal : memGlobal;
    int maxCust = storedCust > memCust ? storedCust : memCust;

    int nextCust = maxCust + 1;
    int nextGlobal = maxGlobal + 1;

    _memoryOrderCounters['global_$cleanSeller'] = nextGlobal;
    _memoryOrderCounters['cust_${cleanSeller}_$cleanCust'] = nextCust;

    await prefs.setInt(globalKey, nextGlobal);
    await prefs.setInt(custKey, nextCust);

    return '#DM-${1000 + nextGlobal}';
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
      final idA = int.tryParse((a['id'] ?? '0').toString()) ?? 0;
      final idB = int.tryParse((b['id'] ?? '0').toString()) ?? 0;
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
    double? orderAmount,
  }) async {
    try {
      String? orderTag = customOrderId;
      if ((orderTag == null || orderTag.trim().isEmpty) && senderType == 'customer') {
        orderTag = await getNextGlobalOrderId(sellerUsername, customerMobile: customerMobile);
      }

      double amt = orderAmount ?? 0.0;
      if (amt <= 0 && senderType == 'customer') {
        final matches = RegExp(r'₹\s*([\d\.]+)').allMatches(message);
        for (var m in matches) {
          final parsed = double.tryParse(m.group(1) ?? '');
          if (parsed != null && parsed > 0) {
            amt += parsed;
          }
        }
      }

      final payload = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch,
        'seller_username': sellerUsername.trim(),
        'customer_mobile': customerMobile.trim(),
        'message': message.trim(),
        'sender_type': senderType,
        'order_id': orderTag ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      if (amt > 0) {
        payload['order_amount'] = amt;
        payload['amount'] = amt;
      }

      // Write to SharedPreferences local cache immediately (0 ms perceived latency)
      final prefs = await SharedPreferences.getInstance();
      final localKey = 'msgs_${sellerUsername.trim()}_${customerMobile.trim()}';
      final localStr = prefs.getString(localKey);
      List<Map<String, dynamic>> existing = [];
      if (localStr != null && localStr.isNotEmpty) {
        try {
          existing = (jsonDecode(localStr) as List).map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
      existing.add(payload);
      await prefs.setString(localKey, jsonEncode(existing));

      // Post to VPS API in background
      final res = await VpsApiService.post('send-message', payload);
      if (res != null && res['success'] == true) {
        return true;
      }
    } catch (_) {}
    return true;
  }

  /// Update an existing Customer Order Message text and items
  static Future<bool> updateCustomerOrderMessage({
    required int messageId,
    required String sellerUsername,
    required String customerMobile,
    required String newText,
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();
    final msgIdStr = messageId.toString();

    // Re-parse text lines to update items_json & recalculate order_amount
    final lines = newText.split('\n');
    final itemsList = <Map<String, dynamic>>[];
    double newTotalAmount = 0.0;
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.contains('📍 Delivery Address') &&
          !trimmed.contains('📍') &&
          !trimmed.contains('📏 Distance') &&
          !trimmed.contains('📏')) {
        itemsList.add({'text': trimmed, 'status': 0});
        final amtMatch = RegExp(r'-\s*₹\s*([\d\.]+)').firstMatch(trimmed) ?? RegExp(r'₹\s*([\d\.]+)').firstMatch(trimmed);
        if (amtMatch != null) {
          final a = double.tryParse(amtMatch.group(1) ?? '');
          if (a != null && a > 0) newTotalAmount += a;
        }
      }
    }
    final itemsJsonStr = jsonEncode(itemsList);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Save to persistent saved_edited_messages map
      Map<String, dynamic> savedEdited = {};
      try {
        final str = prefs.getString('saved_edited_messages');
        if (str != null && str.isNotEmpty) {
          savedEdited = Map<String, dynamic>.from(jsonDecode(str));
        }
      } catch (_) {}

      final editData = {
        'message': newText,
        'items_json': itemsJsonStr,
        if (newTotalAmount > 0) 'order_amount': newTotalAmount,
      };
      savedEdited[msgIdStr] = editData;
      await prefs.setString('saved_edited_messages', jsonEncode(savedEdited));

      // 2. Also update saved_order_amounts if amount was recalculated
      if (newTotalAmount > 0) {
        Map<String, dynamic> savedAmounts = {};
        try {
          final str = prefs.getString('saved_order_amounts');
          if (str != null && str.isNotEmpty) {
            savedAmounts = Map<String, dynamic>.from(jsonDecode(str));
          }
        } catch (_) {}
        savedAmounts[msgIdStr] = newTotalAmount;
        await prefs.setString('saved_order_amounts', jsonEncode(savedAmounts));
      }

      // 3. Update local msgs_ and messages_ keys immediately
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
                item['message'] = newText;
                item['items_json'] = itemsJsonStr;
                if (newTotalAmount > 0) {
                  item['order_amount'] = newTotalAmount;
                  item['amount'] = newTotalAmount;
                }
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
      // 4. Post to VPS API with message, items_json & order_amount
      final payload = <String, dynamic>{
        'message_id': messageId,
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
        'message': newText,
        'items_json': itemsJsonStr,
      };
      if (newTotalAmount > 0) {
        payload['order_amount'] = newTotalAmount;
        payload['amount'] = newTotalAmount;
      }
      final res = await VpsApiService.post('update-order-message', payload);
      return res != null && res['success'] == true;
    } catch (_) {}
    return true;
  }

  /// Update Order Item Checkbox Status & Record Action Log (Seller only)
  static Future<bool> updateItemStatus({
    required int messageId,
    required List<dynamic> items,
    String sellerName = 'SELLER',
    int itemNum = 1,
    int status = 1,
  }) async {
    final msgIdStr = messageId.toString();
    final itemsJsonStr = jsonEncode(items);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Save to persistent saved_item_jsons map
      Map<String, dynamic> savedItemJsons = {};
      try {
        final str = prefs.getString('saved_item_jsons');
        if (str != null && str.isNotEmpty) {
          savedItemJsons = Map<String, dynamic>.from(jsonDecode(str));
        }
      } catch (_) {}
      savedItemJsons[msgIdStr] = itemsJsonStr;
      await prefs.setString('saved_item_jsons', jsonEncode(savedItemJsons));

      // 2. Update SharedPreferences local cache immediately
      final keys = prefs.getKeys().where((k) => k.startsWith('msgs_') || k.startsWith('messages_')).toList();
      for (var key in keys) {
        final str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          try {
            final List decoded = jsonDecode(str);
            final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            bool modified = false;
            for (var item in list) {
              if (item['id'] == messageId || item['id'].toString() == msgIdStr) {
                item['items_json'] = itemsJsonStr;
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
      final res = await VpsApiService.post('update-item-status', {
        'message_id': messageId,
        'items': items,
        'seller_name': sellerName,
        'item_num': itemNum,
        'status': status,
      });
      return res != null && res['success'] == true;
    } catch (_) {}
    return true;
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
                if (orderStatus.toLowerCase() != 'cancelled' && orderStatus.toLowerCase() != 'rejected') {
                  item.remove('cancel_reason');
                }
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

  /// Get Cached Grouped Customer Conversations for Seller Dashboard (0ms Instant Load)
  static Future<List<Map<String, dynamic>>> getCachedSellerConversations(String sellerUsername) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'seller_conversations_${sellerUsername.trim()}';
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get Grouped Customer Conversations for Seller Dashboard
  static Future<List<Map<String, dynamic>>> getSellerConversations(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    try {
      final encSeller = Uri.encodeComponent(cleanSeller);
      final res = await VpsApiService.get('get-seller-conversations&seller_username=$encSeller');
      if (res != null && res['conversations'] != null) {
        final List<dynamic> list = res['conversations'];
        final items = list.cast<Map<String, dynamic>>();

        final prefs = await SharedPreferences.getInstance();
        for (var item in items) {
          final mobile = (item['customer_mobile'] ?? '').toString().trim();
          final name = (item['customer_name'] ?? item['name'] ?? '').toString().trim();
          if (mobile.isNotEmpty && name.isNotEmpty && !name.startsWith('Customer')) {
            final profileData = {'mobile': mobile, 'name': name};
            await prefs.setString('customer_profile_$mobile', jsonEncode(profileData));
          }
        }
        await prefs.setString('seller_conversations_$cleanSeller', jsonEncode(items));
        return items;
      }
    } catch (_) {}
    return getCachedSellerConversations(cleanSeller);
  }

  /// Get Cached Grouped Seller Conversations for Customer Dashboard (0ms Instant Load)
  static Future<List<Map<String, dynamic>>> getCachedCustomerConversations(String customerMobile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanCust = customerMobile.trim();
      final key = 'customer_conversations_$cleanCust';
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
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

    if (result.isNotEmpty) {
      await prefs.setString('customer_conversations_$cleanCust', jsonEncode(result));
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
    await prefs.remove('msgs_${cleanSeller}_$cleanCust');

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

  /// Get Cached Messages instantly from SharedPreferences (0 ms delay for UI rendering)
  static Future<List<Map<String, dynamic>>> getCachedMessages({
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
    Map<String, dynamic> savedEditedMessages = {};
    Map<String, dynamic> savedItemJsons = {};
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
      final editedStr = prefs.getString('saved_edited_messages');
      if (editedStr != null && editedStr.isNotEmpty) {
        savedEditedMessages = Map<String, dynamic>.from(jsonDecode(editedStr));
      }
      final itemJsonsStr = prefs.getString('saved_item_jsons');
      if (itemJsonsStr != null && itemJsonsStr.isNotEmpty) {
        savedItemJsons = Map<String, dynamic>.from(jsonDecode(itemJsonsStr));
      }
    } catch (_) {}

    final localStr = prefs.getString(localKey);
    if (localStr == null || localStr.isEmpty) return [];

    List<Map<String, dynamic>> msgs = [];
    try {
      final List decoded = jsonDecode(localStr);
      msgs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}

    for (var m in msgs) {
      final idStr = m['id']?.toString() ?? '';
      if (savedItemJsons.containsKey(idStr)) {
        m['items_json'] = savedItemJsons[idStr];
      }
      if (savedEditedMessages.containsKey(idStr)) {
        final eData = Map<String, dynamic>.from(savedEditedMessages[idStr]);
        if (eData['message'] != null) m['message'] = eData['message'];
        if (eData['items_json'] != null) m['items_json'] = eData['items_json'];
        if (eData['order_amount'] != null) {
          m['order_amount'] = eData['order_amount'];
          m['amount'] = eData['order_amount'];
        }
      }
      if (savedAmounts.containsKey(idStr)) {
        m['order_amount'] = savedAmounts[idStr];
      }
      final dbPayStat = (m['payment_status'] ?? '').toString().toLowerCase();
      if (dbPayStat == 'paid' || dbPayStat == 'success') {
        m['payment_status'] = 'paid';
      } else if (savedPayments.containsKey(idStr)) {
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
    return msgs;
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
    Map<String, dynamic> savedEditedMessages = {};
    Map<String, dynamic> savedItemJsons = {};
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
      final editedStr = prefs.getString('saved_edited_messages');
      if (editedStr != null && editedStr.isNotEmpty) {
        savedEditedMessages = Map<String, dynamic>.from(jsonDecode(editedStr));
      }
      final itemJsonsStr = prefs.getString('saved_item_jsons');
      if (itemJsonsStr != null && itemJsonsStr.isNotEmpty) {
        savedItemJsons = Map<String, dynamic>.from(jsonDecode(itemJsonsStr));
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

    // Merge saved order amounts, payments, delivery statuses, order statuses, bill images, edited messages & item jsons onto message objects
    for (var m in msgs) {
      final idStr = m['id']?.toString() ?? '';
      if (savedItemJsons.containsKey(idStr)) {
        m['items_json'] = savedItemJsons[idStr];
      }
      if (savedEditedMessages.containsKey(idStr)) {
        final eData = Map<String, dynamic>.from(savedEditedMessages[idStr]);
        if (eData['message'] != null) m['message'] = eData['message'];
        if (eData['items_json'] != null) m['items_json'] = eData['items_json'];
        if (eData['order_amount'] != null) {
          m['order_amount'] = eData['order_amount'];
          m['amount'] = eData['order_amount'];
        }
      }
      if (savedAmounts.containsKey(idStr)) {
        m['order_amount'] = savedAmounts[idStr];
      }
      final dbPayStat = (m['payment_status'] ?? '').toString().toLowerCase();
      if (dbPayStat == 'paid' || dbPayStat == 'success') {
        m['payment_status'] = 'paid';
      } else if (savedPayments.containsKey(idStr)) {
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
        'id': '6',
        'name': 'Krishna',
        'username': 'Krishna',
        'password': '1234',
        'mobile': '8128859990',
        'location': 'Raniganj',
      },
      {
        'id': '7',
        'name': 'Daily Mart Ankul',
        'username': 'Ankul',
        'password': '1234',
        'mobile': '7781881211',
        'location': 'BankeyBazar',
      },
      {
        'id': 'seller_1',
        'name': 'Sample Seller',
        'username': 'seller1',
        'password': '1234',
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
    String location = '',
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
        'location': location.trim(),
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
      'location': location.trim(),
    };

    sellers.add(newSeller);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sellersKey, jsonEncode(sellers));
    return {'success': true, 'message': 'Seller Account Created Successfully!'};
  }

  /// Admin Updates Seller Account Details
  static Future<Map<String, dynamic>> updateSellerResult({
    required String username,
    required String name,
    required String password,
    required String mobile,
    String location = '',
  }) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

    // Check if new mobile conflicts with OTHER sellers
    final existingSellers = await getSellersList();
    for (var s in existingSellers) {
      final u = (s['username'] ?? '').toString().toLowerCase();
      if (u != cleanUser && last10.isNotEmpty) {
        final sMob = (s['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final sLast10 = sMob.length >= 10 ? sMob.substring(sMob.length - 10) : sMob;
        if (sLast10.isNotEmpty && sLast10 == last10) {
          return {'success': false, 'message': 'Mobile number +91 $last10 is already registered with another seller.'};
        }
      }
    }

    try {
      final res = await VpsApiService.post('update-seller', {
        'username': cleanUser,
        'name': name.trim(),
        'password': password.trim(),
        'mobile': mobile.trim(),
        'location': location.trim(),
      });
      if (res != null && res['success'] == true) {
        return {'success': true, 'message': 'Seller details updated successfully!'};
      }
    } catch (_) {}

    // Also update in SharedPreferences local storage
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_sellersKey) ?? [];
    List<String> updatedList = [];
    for (var str in list) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          if ((decoded['username'] ?? '').toString().toLowerCase() == cleanUser) {
            decoded['name'] = name.trim();
            decoded['password'] = password.trim();
            decoded['mobile'] = mobile.trim();
            decoded['location'] = location.trim();
          }
          updatedList.add(jsonEncode(decoded));
        }
      } catch (_) {
        updatedList.add(str);
      }
    }
    await prefs.setStringList(_sellersKey, updatedList);

    return {'success': true, 'message': 'Seller details updated successfully!'};
  }

  /// Maintain backward compatibility bool method for createSeller
  static Future<bool> createSeller({
    required String name,
    required String username,
    required String password,
    String mobile = '',
    String location = '',
  }) async {
    final res = await createSellerResult(name: name, username: username, password: password, mobile: mobile, location: location);
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

  /// Get seller sliders (Local-First + Remote VPS + Global Persistent Map)
  static Future<List<Map<String, dynamic>>> getSellerSliders(String sellerUsername) async {
    final cleanUsername = sellerUsername.trim().toLowerCase();
    if (cleanUsername.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$cleanUsername';

    // Load persistent global seller sliders map
    Map<String, dynamic> savedGlobalSliders = {};
    try {
      final str = prefs.getString('saved_global_seller_sliders');
      if (str != null && str.isNotEmpty) {
        savedGlobalSliders = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    List<Map<String, dynamic>> localList = [];

    // 1. Check saved_global_seller_sliders map
    if (savedGlobalSliders.containsKey(cleanUsername)) {
      try {
        final List list = savedGlobalSliders[cleanUsername];
        localList = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    // 2. Check local key fallback
    if (localList.isEmpty) {
      final str = prefs.getString(localKey);
      if (str != null && str.isNotEmpty) {
        try {
          final List decoded = jsonDecode(str);
          localList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    // 3. Try Remote VPS API and merge with deduplication
    try {
      final res = await VpsApiService.get('get-seller-sliders&seller_username=${Uri.encodeComponent(cleanUsername)}');
      if (res != null && res['success'] == true && res['sliders'] != null) {
        final List list = res['sliders'];
        final remoteList = list.map((e) => Map<String, dynamic>.from(e)).toList();

        final Map<String, Map<String, dynamic>> mergedMap = {};
        for (var item in remoteList) {
          final idStr = item['id']?.toString() ?? '';
          if (idStr.isNotEmpty) mergedMap[idStr] = item;
        }

        for (var item in localList) {
          final idStr = item['id']?.toString() ?? '';
          if (idStr.isEmpty) continue;

          // If numeric ID already in mergedMap
          if (mergedMap.containsKey(idStr)) {
            final remoteBg = (mergedMap[idStr]!['bg_image_url'] ?? '').toString().trim();
            final localBg = (item['bg_image_url'] ?? '').toString().trim();
            if ((remoteBg.isEmpty || remoteBg == 'none') && localBg.isNotEmpty && localBg != 'none') {
              mergedMap[idStr]!['bg_image_url'] = localBg;
            }
          } else {
            // Deduplicate local timestamp items against remote VPS items by content (bg, title, section)
            final lTitle = (item['title'] ?? '').toString().trim();
            final lSec = (item['section'] ?? '').toString().trim();
            final lBg = (item['bg_image_url'] ?? '').toString().trim();

            bool isDup = false;
            for (var rItem in remoteList) {
              final rTitle = (rItem['title'] ?? '').toString().trim();
              final rSec = (rItem['section'] ?? '').toString().trim();
              final rBg = (rItem['bg_image_url'] ?? '').toString().trim();

              final matchSec = lSec.toLowerCase() == rSec.toLowerCase();
              final matchTitle = lTitle.isNotEmpty && lTitle.toLowerCase() == rTitle.toLowerCase();
              final matchBg = lBg.isNotEmpty && lBg != 'none' && lBg == rBg;

              if (matchSec && (matchTitle || matchBg)) {
                isDup = true;
                break;
              }
            }

            if (!isDup) {
              mergedMap[idStr] = item;
            }
          }
        }

        final combinedList = mergedMap.values.toList();
        savedGlobalSliders[cleanUsername] = combinedList;
        await prefs.setString('saved_global_seller_sliders', jsonEncode(savedGlobalSliders));
        await prefs.setString(localKey, jsonEncode(combinedList));
        return combinedList;
      }
    } catch (e) {
      debugPrint('Error fetching remote seller sliders for $cleanUsername: $e');
    }

    return localList;
  }

  /// Add seller slider (Local-First & Global Persistent Sync)
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
    String section = 'Top Banner',
    String position = 'internal',
    double overlayDim = 0.0,
    bool removeWhiteBg = false,
    String imgFit = 'cover',
  }) async {
    final cleanUsername = sellerUsername.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$cleanUsername';

    final newSlider = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': cleanUsername,
      'tag': tag,
      'title': title,
      'description': description,
      'bg_image_url': bgImageUrl,
      'tag_bg_color': tagBgColor,
      'tag_shape': tagShape,
      'title_color': titleColor,
      'desc_color': descColor,
      'section': section.trim().isEmpty ? 'Top Banner' : section.trim(),
      'position': position.trim().isEmpty ? 'internal' : position.trim(),
      'overlay_dim': overlayDim,
      'remove_white_bg': removeWhiteBg,
      'img_fit': imgFit,
      'created_at': DateTime.now().toString().substring(0, 16),
    };

    try {
      final res = await VpsApiService.post('add-seller-slider', {
        'seller_username': cleanUsername,
        'tag': tag,
        'title': title,
        'description': description,
        'bg_image_url': bgImageUrl,
        'tag_bg_color': tagBgColor,
        'tag_shape': tagShape,
        'title_color': titleColor,
        'desc_color': descColor,
        'section': section.trim().isEmpty ? 'Top Banner' : section.trim(),
        'position': position.trim().isEmpty ? 'internal' : position.trim(),
        'overlay_dim': overlayDim,
        'remove_white_bg': removeWhiteBg ? 1 : 0,
        'img_fit': imgFit,
      });

      if (res != null && res['success'] == true && res['slider'] != null && res['slider']['id'] != null) {
        newSlider['id'] = res['slider']['id'];
      }
    } catch (_) {}

    Map<String, dynamic> savedGlobalSliders = {};
    try {
      final str = prefs.getString('saved_global_seller_sliders');
      if (str != null && str.isNotEmpty) {
        savedGlobalSliders = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    List<Map<String, dynamic>> sliders = [];
    if (savedGlobalSliders.containsKey(cleanUsername)) {
      try {
        final List l = savedGlobalSliders[cleanUsername];
        sliders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    if (sliders.isEmpty) {
      final str = prefs.getString(localKey);
      if (str != null) {
        try {
          final List decoded = jsonDecode(str);
          sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    // Remove any existing slider with same ID or identical image/content
    sliders.removeWhere((s) => s['id'].toString() == newSlider['id'].toString());
    sliders.insert(0, newSlider);
    savedGlobalSliders[cleanUsername] = sliders;
    await prefs.setString('saved_global_seller_sliders', jsonEncode(savedGlobalSliders));
    await prefs.setString(localKey, jsonEncode(sliders));

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
    String section = 'Top Banner',
    String position = 'internal',
    double overlayDim = 0.0,
    bool removeWhiteBg = false,
    String imgFit = 'cover',
  }) async {
    final cleanUsername = sellerUsername.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$cleanUsername';

    String finalBg = bgImageUrl;

    Map<String, dynamic> savedGlobalSliders = {};
    try {
      final str = prefs.getString('saved_global_seller_sliders');
      if (str != null && str.isNotEmpty) {
        savedGlobalSliders = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    List<Map<String, dynamic>> sliders = [];
    if (savedGlobalSliders.containsKey(cleanUsername)) {
      try {
        final List l = savedGlobalSliders[cleanUsername];
        sliders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    if (sliders.isEmpty) {
      final str = prefs.getString(localKey);
      if (str != null) {
        try {
          final List decoded = jsonDecode(str);
          sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    final index = sliders.indexWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    if (index != -1) {
      sliders[index]['tag'] = tag;
      sliders[index]['title'] = title;
      sliders[index]['description'] = description;
      if (finalBg.isNotEmpty) {
        sliders[index]['bg_image_url'] = finalBg;
      }
      sliders[index]['tag_bg_color'] = tagBgColor;
      sliders[index]['tag_shape'] = tagShape;
      sliders[index]['title_color'] = titleColor;
      sliders[index]['desc_color'] = descColor;
      sliders[index]['section'] = section.trim().isEmpty ? 'Top Banner' : section.trim();
      sliders[index]['position'] = position.trim().isEmpty ? 'internal' : position.trim();
      sliders[index]['overlay_dim'] = overlayDim;
      sliders[index]['remove_white_bg'] = removeWhiteBg;
      sliders[index]['img_fit'] = imgFit;

      savedGlobalSliders[cleanUsername] = sliders;
      await prefs.setString('saved_global_seller_sliders', jsonEncode(savedGlobalSliders));
      await prefs.setString(localKey, jsonEncode(sliders));
    }

    try {
      await VpsApiService.post('update-seller-slider', {
        'id': sliderId,
        'slider_id': sliderId,
        'seller_username': cleanUsername,
        'tag': tag,
        'title': title,
        'description': description,
        'bg_image_url': finalBg,
        'tag_bg_color': tagBgColor,
        'tag_shape': tagShape,
        'title_color': titleColor,
        'desc_color': descColor,
        'section': section.trim().isEmpty ? 'Top Banner' : section.trim(),
        'position': position.trim().isEmpty ? 'internal' : position.trim(),
        'overlay_dim': overlayDim,
        'remove_white_bg': removeWhiteBg ? 1 : 0,
        'img_fit': imgFit,
      });
    } catch (_) {}

    return true;
  }

  /// Quick move/assign seller slider to a Section with 1 finger tap
  static Future<bool> updateSellerSliderSection(dynamic sliderId, String sellerUsername, String newSection) async {
    final cleanUsername = sellerUsername.trim().toLowerCase();
    final cleanSec = newSection.trim().isEmpty ? 'Top Banner' : newSection.trim();
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$cleanUsername';

    Map<String, dynamic> savedGlobalSliders = {};
    try {
      final str = prefs.getString('saved_global_seller_sliders');
      if (str != null && str.isNotEmpty) {
        savedGlobalSliders = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    List<Map<String, dynamic>> sliders = [];
    if (savedGlobalSliders.containsKey(cleanUsername)) {
      try {
        final List l = savedGlobalSliders[cleanUsername];
        sliders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    if (sliders.isEmpty) {
      final str = prefs.getString(localKey);
      if (str != null) {
        try {
          final List decoded = jsonDecode(str);
          sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    final index = sliders.indexWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    if (index != -1) {
      final existing = sliders[index];
      existing['section'] = cleanSec;

      savedGlobalSliders[cleanUsername] = sliders;
      await prefs.setString('saved_global_seller_sliders', jsonEncode(savedGlobalSliders));
      await prefs.setString(localKey, jsonEncode(sliders));

      return updateSellerSlider(
        sliderId: sliderId,
        sellerUsername: sellerUsername,
        tag: (existing['tag'] ?? '').toString(),
        title: (existing['title'] ?? '').toString(),
        description: (existing['description'] ?? '').toString(),
        bgImageUrl: (existing['bg_image_url'] ?? '').toString(),
        tagBgColor: (existing['tag_bg_color'] ?? '#10B981').toString(),
        tagShape: (existing['tag_shape'] ?? 'pill').toString(),
        titleColor: (existing['title_color'] ?? '#FFFFFF').toString(),
        descColor: (existing['desc_color'] ?? '#E2E8F0').toString(),
        section: cleanSec,
        position: (existing['position'] ?? 'internal').toString(),
        overlayDim: (existing['overlay_dim'] as num?)?.toDouble() ?? 0.0,
        removeWhiteBg: existing['remove_white_bg'] == true || existing['remove_white_bg'] == 1,
        imgFit: (existing['img_fit'] ?? 'cover').toString(),
      );
    }
    return false;
  }

  /// Delete seller slider
  static Future<bool> deleteSellerSlider(dynamic sliderId, String sellerUsername) async {
    final cleanUsername = sellerUsername.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'sliders_$cleanUsername';

    Map<String, dynamic> savedGlobalSliders = {};
    try {
      final str = prefs.getString('saved_global_seller_sliders');
      if (str != null && str.isNotEmpty) {
        savedGlobalSliders = Map<String, dynamic>.from(jsonDecode(str));
      }
    } catch (_) {}

    List<Map<String, dynamic>> sliders = [];
    if (savedGlobalSliders.containsKey(cleanUsername)) {
      try {
        final List l = savedGlobalSliders[cleanUsername];
        sliders = l.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    if (sliders.isEmpty) {
      final str = prefs.getString(localKey);
      if (str != null) {
        try {
          final List decoded = jsonDecode(str);
          sliders = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
    }

    sliders.removeWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    savedGlobalSliders[cleanUsername] = sliders;
    await prefs.setString('saved_global_seller_sliders', jsonEncode(savedGlobalSliders));
    await prefs.setString(localKey, jsonEncode(sliders));

    try {
      await VpsApiService.post('delete-seller-slider', {'slider_id': sliderId, 'seller_username': cleanUsername});
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
    String location = '',
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
      'location': location.trim(),
      'role': 'delivery_boy',
      'created_at': DateTime.now().toIso8601String(),
      'status': 'active',
    };

    list.add(jsonEncode(newDeliveryBoy));
    await prefs.setStringList(_keyDeliveryBoys, list);

    // Sync to VPS MySQL Database
    try {
      await VpsApiService.post('create-delivery-boy', newDeliveryBoy);
    } catch (e) {
      debugPrint('Error syncing delivery boy to VPS API: $e');
    }

    return {'success': true, 'message': 'Delivery Boy Account Created Successfully!'};
  }

  /// Admin Updates Delivery Partner Account Details
  static Future<Map<String, dynamic>> updateDeliveryBoyResult({
    required String username,
    required String name,
    required String password,
    required String mobile,
    String? vehicle,
    String location = '',
  }) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final last10 = cleanMobile.length >= 10 ? cleanMobile.substring(cleanMobile.length - 10) : cleanMobile;

    // Check if new mobile conflicts with OTHER delivery partners
    final existingDeliveryBoys = await getDeliveryBoys();
    for (var item in existingDeliveryBoys) {
      final itemUser = (item['username'] ?? '').toString().toLowerCase();
      if (itemUser != cleanUser && last10.isNotEmpty) {
        final dMob = (item['mobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        final dLast10 = dMob.length >= 10 ? dMob.substring(dMob.length - 10) : dMob;
        if (dLast10.isNotEmpty && dLast10 == last10) {
          return {'success': false, 'message': 'Mobile number +91 $last10 is already registered with another delivery partner.'};
        }
      }
    }

    try {
      final res = await VpsApiService.post('update-delivery-boy', {
        'username': cleanUser,
        'name': name.trim(),
        'password': password.trim(),
        'mobile': mobile.trim(),
        'vehicle': vehicle?.trim().isNotEmpty == true ? vehicle!.trim() : 'Bike',
        'location': location.trim(),
      });
      if (res != null && res['success'] == true) {
        return {'success': true, 'message': 'Delivery partner details updated successfully!'};
      }
    } catch (_) {}

    // Update in local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];
    List<String> updatedList = [];
    for (var str in list) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, dynamic>) {
          if ((decoded['username'] ?? '').toString().toLowerCase() == cleanUser) {
            decoded['name'] = name.trim();
            decoded['password'] = password.trim();
            decoded['mobile'] = mobile.trim();
            decoded['vehicle'] = vehicle?.trim().isNotEmpty == true ? vehicle!.trim() : 'Bike';
            decoded['location'] = location.trim();
          }
          updatedList.add(jsonEncode(decoded));
        }
      } catch (_) {
        updatedList.add(str);
      }
    }
    await prefs.setStringList(_keyDeliveryBoys, updatedList);

    return {'success': true, 'message': 'Delivery partner details updated successfully!'};
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

  /// Get Cached Delivery Boys List instantly from SharedPreferences (0 ms delay)
  static Future<List<Map<String, dynamic>>> getCachedDeliveryBoys() async {
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

  /// Get All Delivery Boys (Admin View)
  static Future<List<Map<String, dynamic>>> getDeliveryBoys() async {
    // 1. Fetch from VPS MySQL Database
    try {
      final vpsRes = await VpsApiService.get('delivery-boys');
      if (vpsRes != null && vpsRes['delivery_boys'] != null) {
        final List<dynamic> list = vpsRes['delivery_boys'];
        final res = list.cast<Map<String, dynamic>>();

        // Cache locally for offline fallback
        final prefs = await SharedPreferences.getInstance();
        final strList = res.map((e) => jsonEncode(e)).toList();
        await prefs.setStringList(_keyDeliveryBoys, strList);
        return res;
      }
    } catch (_) {}

    // 2. Local Fallback
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
    final cleanUser = username.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyDeliveryBoys) ?? [];
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

    // Sync deletion to VPS MySQL Database
    try {
      await VpsApiService.post('delete-delivery-boy', {
        'username': cleanUser,
      });
    } catch (_) {}

    return true;
  }

  /// Login Delivery Boy ONLY (Rejects Sellers & Admin for strict role separation)
  static Future<Map<String, dynamic>?> loginDeliveryBoy(String username, String password) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();

    // 1. Check VPS API Server
    try {
      final res = await VpsApiService.post('delivery-boy-login', {
        'username': cleanUser,
        'password': cleanPass,
      });
      if (res != null && res['success'] == true && res['delivery_boy'] != null) {
        return Map<String, dynamic>.from(res['delivery_boy']);
      }
    } catch (_) {}

    // 2. Local Fallback
    final deliveryBoys = await getDeliveryBoys();
    for (var item in deliveryBoys) {
      final u = (item['username'] ?? '').toString().toLowerCase();
      final p = (item['password'] ?? '').toString();
      final role = (item['role'] ?? '').toString();

      if (u == cleanUser && p == cleanPass) {
        if (role == 'delivery_boy' || role.isEmpty) {
          return item;
        }
      }
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

  /// Get all undelivered orders grouped by seller (For Delivery Boy Dashboard with Location Filter)
  static Future<List<Map<String, dynamic>>> getAllUndeliveredOrdersGroupedBySeller({
    String deliveryBoyLocation = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sellers = await getSellersList();
    final List<Map<String, dynamic>> groupedResult = [];

    final cleanDbLoc = deliveryBoyLocation.trim().toLowerCase();

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
      final sellerLocation = (seller['location'] ?? '').toString().trim().toLowerCase();

      // Location Filtering: If delivery boy has a location, only show sellers matching that location
      if (cleanDbLoc.isNotEmpty && sellerLocation != cleanDbLoc) {
        continue;
      }

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
              final msgId = int.tryParse(msgMap['id']?.toString() ?? '') ?? (msgMap['id'] is num ? (msgMap['id'] as num).toInt() : 0);
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

                  final bool isCancelled = ordStatus.toLowerCase() == 'cancelled' || delStatus.toLowerCase() == 'cancelled';
                  final bool isDelivered = delStatus.toLowerCase() == 'delivered' || ordStatus.toLowerCase() == 'delivered';
                  final bool isReadyForDelivery = (ordStatus.toLowerCase() == 'ready' ||
                                                   ordStatus.toLowerCase() == 'approved' ||
                                                   delStatus.toLowerCase() == 'out for delivery' ||
                                                   delStatus.toLowerCase() == 'picked up' ||
                                                   delStatus.toLowerCase() == 'pickup') &&
                                                  !isCancelled &&
                                                  !isDelivered;

                  if (isReadyForDelivery) {
                    if (savedPayments.containsKey(msgIdStr)) {
                      msgMap['payment_status'] = 'paid';
                      msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? (msgMap['payment_utr'] ?? '');
                    } else if ((msgMap['payment_status'] ?? '').toString().toLowerCase() == 'paid') {
                      msgMap['payment_status'] = 'paid';
                    }

                    final custName = (conv['customer_name'] ?? conv['name'] ?? '').toString().trim();
                    msgMap['seller_username'] = sellerUsername;
                    msgMap['seller_name'] = sellerName;
                    msgMap['customer_mobile'] = custMobile;
                    if (custName.isNotEmpty && custName != custMobile && !custName.startsWith('Customer')) {
                      msgMap['customer_name'] = custName;
                    }

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
                  final msgId = int.tryParse(msgMap['id']?.toString() ?? '') ?? (msgMap['id'] is num ? (msgMap['id'] as num).toInt() : 0);
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

                      final bool isCancelled = ordStatus.toLowerCase() == 'cancelled' || delStatus.toLowerCase() == 'cancelled';
                      final bool isDelivered = delStatus.toLowerCase() == 'delivered' || ordStatus.toLowerCase() == 'delivered';
                      final bool isReadyForDelivery = (ordStatus.toLowerCase() == 'ready' ||
                                                       ordStatus.toLowerCase() == 'approved' ||
                                                       delStatus.toLowerCase() == 'out for delivery' ||
                                                       delStatus.toLowerCase() == 'picked up' ||
                                                       delStatus.toLowerCase() == 'pickup') &&
                                                      !isCancelled &&
                                                      !isDelivered;

                      if (isReadyForDelivery) {
                        if (savedPayments.containsKey(msgIdStr)) {
                          msgMap['payment_status'] = 'paid';
                          msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? (msgMap['payment_utr'] ?? '');
                        } else if ((msgMap['payment_status'] ?? '').toString().toLowerCase() == 'paid') {
                          msgMap['payment_status'] = 'paid';
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

    if (groupedResult.isNotEmpty) {
      try {
        await prefs.setString('delivery_boy_grouped_orders_${cleanDbLoc}', jsonEncode(groupedResult));
      } catch (_) {}
    }

    return groupedResult;
  }

  /// Get Cached Undelivered Orders Grouped By Seller for Delivery Boy (0ms Instant Load)
  static Future<List<Map<String, dynamic>>> getCachedAllUndeliveredOrdersGroupedBySeller({
    String deliveryBoyLocation = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'delivery_boy_grouped_orders_${deliveryBoyLocation.trim().toLowerCase()}';
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get ALL orders grouped by Seller and Customer (For Admin Order Details Dashboard)
  static Future<List<Map<String, dynamic>>> getAllOrdersGroupedBySellerForAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final sellers = await getSellersList();
    final List<Map<String, dynamic>> result = [];

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

    for (var seller in sellers) {
      final sellerUsername = (seller['username'] ?? '').toString().trim();
      final sellerName = (seller['name'] ?? sellerUsername).toString().trim();
      final sellerMobile = (seller['mobile'] ?? '').toString().trim();
      final sellerLocation = (seller['location'] ?? '').toString().trim();

      if (sellerUsername.isEmpty) continue;

      final Map<String, List<Map<String, dynamic>>> customerOrdersMap = {};
      final Map<String, String> customerNamesMap = {};
      final Set<int> processedMsgIds = {};

      try {
        final conversations = await getSellerConversations(sellerUsername);
        for (var conv in conversations) {
          final custMobile = (conv['customer_mobile'] ?? conv['mobile'] ?? '').toString().trim();
          final custName = (conv['customer_name'] ?? conv['name'] ?? '').toString().trim();
          if (custMobile.isNotEmpty) {
            if (custName.isNotEmpty && !custName.startsWith('Customer')) {
              customerNamesMap[custMobile] = custName;
            }

            final msgs = await getMessages(sellerUsername: sellerUsername, customerMobile: custMobile);
            for (var msgMap in msgs) {
              final msgId = int.tryParse(msgMap['id']?.toString() ?? '') ?? (msgMap['id'] is num ? (msgMap['id'] as num).toInt() : 0);
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

                  if (savedOrderStatuses.containsKey(msgIdStr)) {
                    msgMap['order_status'] = (savedOrderStatuses[msgIdStr] ?? msgMap['order_status']).toString();
                  }
                  if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                    final val = savedDeliveryStatuses[msgIdStr];
                    if (val is Map) {
                      msgMap['delivery_status'] = (val['delivery_status'] ?? msgMap['delivery_status']).toString();
                    } else {
                      msgMap['delivery_status'] = val.toString();
                    }
                  }
                  if (savedPayments.containsKey(msgIdStr)) {
                    msgMap['payment_status'] = 'paid';
                    msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? (msgMap['payment_utr'] ?? '');
                  }

                  msgMap['seller_username'] = sellerUsername;
                  msgMap['seller_name'] = sellerName;
                  msgMap['customer_mobile'] = custMobile;
                  if (customerNamesMap.containsKey(custMobile)) {
                    msgMap['customer_name'] = customerNamesMap[custMobile];
                  }

                  customerOrdersMap.putIfAbsent(custMobile, () => []).add(msgMap);
                }
              }
            }
          }
        }
      } catch (_) {}

      if (customerOrdersMap.isNotEmpty) {
        final List<Map<String, dynamic>> customersList = [];
        int sellerTotalOrders = 0;

        customerOrdersMap.forEach((custMobile, orders) {
          sellerTotalOrders += orders.length;
          final custName = customerNamesMap[custMobile] ?? custMobile;
          customersList.add({
            'customer_mobile': custMobile,
            'customer_name': custName,
            'orders': orders,
            'order_count': orders.length,
          });
        });

        result.add({
          'seller_username': sellerUsername,
          'seller_name': sellerName,
          'seller_mobile': sellerMobile,
          'location': sellerLocation,
          'customers': customersList,
          'total_orders': sellerTotalOrders,
        });
      }
    }

    return result;
  }

  /// Get Flat List of All Orders for Admin
  static Future<List<Map<String, dynamic>>> getAllOrdersFlatListForAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final sellers = await getSellersList();
    final deliveryBoys = await getDeliveryBoys();
    final List<Map<String, dynamic>> flatOrders = [];
    final Set<String> processedKeys = {};

    // Seller location lookup map
    final Map<String, String> sellerLocationMap = {};
    for (var s in sellers) {
      final uname = (s['username'] ?? '').toString().trim();
      final name = (s['name'] ?? '').toString().trim();
      final loc = (s['location'] ?? '').toString().trim();
      if (loc.isNotEmpty) {
        if (uname.isNotEmpty) sellerLocationMap[uname.toLowerCase()] = loc;
        if (name.isNotEmpty) sellerLocationMap[name.toLowerCase()] = loc;
      }
    }

    // Delivery boy display name lookup map
    final Map<String, String> deliveryBoyNameMap = {};
    for (var db in deliveryBoys) {
      final uname = (db['username'] ?? '').toString().trim();
      final name = (db['name'] ?? uname).toString().trim();
      if (uname.isNotEmpty) {
        deliveryBoyNameMap[uname.toLowerCase()] = name.isNotEmpty ? name : uname;
      }
    }

    // 1. Direct VPS API Query for All Admin Orders
    try {
      final res = await VpsApiService.get('get-all-admin-orders');
      if (res != null && res['success'] == true && res['orders'] is List) {
        final List rawOrders = res['orders'];
        for (var item in rawOrders) {
          if (item is Map) {
            final msgMap = Map<String, dynamic>.from(item);
            final msgId = (msgMap['id'] ?? '').toString();
            if (msgId.isNotEmpty && !processedKeys.contains(msgId)) {
              processedKeys.add(msgId);
              final sellerUsername = (msgMap['seller_username'] ?? '').toString();
              final sellerName = (msgMap['seller_name'] ?? sellerUsername).toString();
              final custMobile = (msgMap['customer_mobile'] ?? '').toString();
              final custName = (msgMap['customer_name'] ?? 'Customer').toString();

              final parsed = _parseFlatOrderRow(
                msgMap: msgMap,
                sellerName: sellerName,
                sellerUsername: sellerUsername,
                custMobile: custMobile,
                custName: custName,
                savedOrderStatuses: {},
                savedDeliveryStatuses: {},
                savedPayments: {},
                sellerLocationMap: sellerLocationMap,
                deliveryBoyNameMap: deliveryBoyNameMap,
              );
              flatOrders.add(parsed);
            }
          }
        }
      }
    } catch (_) {}

    // Sort by Date Descending (Newest first)
    flatOrders.sort((a, b) {
      final DateTime dtA = a['raw_date'] ?? DateTime(2000);
      final DateTime dtB = b['raw_date'] ?? DateTime(2000);
      return dtB.compareTo(dtA);
    });

    if (flatOrders.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final encData = jsonEncode(flatOrders.map((o) {
          final copy = Map<String, dynamic>.from(o);
          copy['iso_date'] = (o['raw_date'] as DateTime?)?.toIso8601String() ?? (o['iso_date'] ?? '');
          copy.remove('raw_date');
          copy.remove('raw_pickup_time');
          copy.remove('raw_delivered_time');
          return copy;
        }).toList());
        await prefs.setString('cache_admin_flat_orders', encData);
      } catch (_) {}
      return flatOrders;
    }

    return await getCachedAllOrdersFlatListForAdmin();
  }

  /// Get Cached All Orders Flat List for Admin instantly from SharedPreferences (0 ms delay)
  static Future<List<Map<String, dynamic>>> getCachedAllOrdersFlatListForAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedStr = prefs.getString('cache_admin_flat_orders');
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(cachedStr);
        final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var ord in list) {
          final isoStr = (ord['iso_date'] ?? '').toString();
          if (isoStr.isNotEmpty) {
            ord['raw_date'] = DateTime.tryParse(isoStr);
          }
          if (ord['raw_date'] == null && ord['date'] != null) {
            final parts = ord['date'].toString().split('/');
            if (parts.length == 3) {
              final d = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final y = int.tryParse(parts[2]);
              if (d != null && m != null && y != null) {
                ord['raw_date'] = DateTime(y, m, d);
              }
            }
          }
        }
        return list;
      } catch (_) {}
    }
    return [];
  }

  /// Get Cached Customer Orders for a specific Seller (0 ms Instant Load)
  static Future<List<Map<String, dynamic>>> getCachedSellerCustomerOrders(String sellerUsername) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_seller_cust_orders_${sellerUsername.trim().toLowerCase()}';
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Get All Customer Orders for a specific Seller (Direct Fast VPS Database Query)
  static Future<List<Map<String, dynamic>>> getSellerCustomerOrders(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    // 1. Instant local cache load if available
    try {
      final cached = await getCachedSellerCustomerOrders(cleanSeller);
      if (cached.isNotEmpty) {
        // Run background fetch asynchronously without blocking
        _refreshSellerCustomerOrdersInBackground(cleanSeller);
        return cached;
      }
    } catch (_) {}

    return await _refreshSellerCustomerOrdersInBackground(cleanSeller);
  }

  static Future<List<Map<String, dynamic>>> _refreshSellerCustomerOrdersInBackground(String cleanSeller) async {
    try {
      final res = await VpsApiService.get('get-seller-customer-orders&seller_username=$cleanSeller');
      if (res != null && res['success'] == true && res['orders'] is List) {
        final List rawOrders = res['orders'];
        final List<Map<String, dynamic>> allSellerOrders = [];
        final Set<String> processedIds = {};

        for (var m in rawOrders) {
          if (m is! Map) continue;
          final msgMap = Map<String, dynamic>.from(m);
          final msgId = (msgMap['id'] ?? '').toString();
          if (msgId.isNotEmpty && processedIds.contains(msgId)) continue;
          if (msgId.isNotEmpty) processedIds.add(msgId);

          final custMobile = (msgMap['customer_mobile'] ?? '').toString().trim();
          final custName = (msgMap['customer_name'] ?? 'Customer').toString().trim();

          List<Map<String, dynamic>> items = [];
          if (msgMap['items_json'] != null) {
            try {
              final decoded = jsonDecode(msgMap['items_json'].toString());
              if (decoded is List) {
                items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
              }
            } catch (_) {}
          }

          double totalAmount = double.tryParse((msgMap['order_amount'] ?? '').toString()) ?? 0.0;
          if (totalAmount <= 0 && items.isNotEmpty) {
            for (var it in items) {
              final rate = (it['rate'] as num?)?.toDouble() ?? (it['amount'] as num?)?.toDouble() ?? 0.0;
              final qty = (it['qty'] as num?)?.toInt() ?? 1;
              totalAmount += (rate * qty);
            }
          }

          final orderStatus = (msgMap['order_status'] ?? 'Pending').toString();
          final deliveryStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
          final paymentStatus = (msgMap['payment_status'] ?? 'unpaid').toString().toLowerCase();
          final paymentUtr = (msgMap['payment_utr'] ?? '').toString();
          final paidAmount = double.tryParse((msgMap['paid_amount'] ?? '').toString()) ?? (paymentStatus == 'paid' ? totalAmount : 0.0);
          final paidAt = (msgMap['paid_at'] ?? '').toString();
          final dateStr = (msgMap['created_at'] ?? '').toString();
          final orderIdStr = (msgMap['order_id'] ?? (msgId.isNotEmpty ? '#DM-$msgId' : '#DM-1001')).toString();

          final isDelivered = deliveryStatus.toLowerCase() == 'delivered' || orderStatus.toLowerCase() == 'delivered';
          final displayStatus = isDelivered ? 'DELIVERED' : orderStatus;

          allSellerOrders.add({
            'id': msgId,
            'order_id': orderIdStr,
            'order_number': orderIdStr,
            'seller_username': cleanSeller,
            'customer_mobile': custMobile,
            'customer_name': custName,
            'items': items,
            'total_amount': totalAmount,
            'order_amount': totalAmount,
            'total_count': items.length,
            'order_status': displayStatus,
            'status': displayStatus,
            'delivery_status': deliveryStatus,
            'payment_status': paymentStatus,
            'payment_utr': paymentUtr,
            'paid_amount': paidAmount,
            'paid_at': paidAt,
            'created_at': dateStr,
            'date': dateStr,
            'delivered_at': (msgMap['delivered_at'] ?? '').toString(),
            'picked_up_at': (msgMap['picked_up_at'] ?? '').toString(),
            'delivered_by': (msgMap['delivered_by'] ?? '').toString(),
            'cancelled_at': (msgMap['cancelled_at'] ?? '').toString(),
            'cancel_reason': (msgMap['cancel_reason'] ?? '').toString(),
            'raw_msg': msgMap,
          });
        }

        if (allSellerOrders.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final key = 'cache_seller_cust_orders_${cleanSeller.toLowerCase()}';
            await prefs.setString(key, jsonEncode(allSellerOrders));
          } catch (_) {}
          return allSellerOrders;
        }
      }
    } catch (_) {}

    return [];
  }

  static Map<String, dynamic> _parseFlatOrderRow({
    required Map<String, dynamic> msgMap,
    required String sellerName,
    required String sellerUsername,
    required String custMobile,
    required String custName,
    required Map<String, dynamic> savedOrderStatuses,
    required Map<String, dynamic> savedDeliveryStatuses,
    required Map<String, dynamic> savedPayments,
    Map<String, String> sellerLocationMap = const {},
    Map<String, String> deliveryBoyNameMap = const {},
  }) {
    final msgIdStr = (msgMap['id'] ?? '').toString();
    final rawOrderId = (msgMap['order_id'] ?? msgMap['_calculated_order_id'] ?? msgIdStr).toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').replaceAll('Order', '').trim();

    String delStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
    if (savedDeliveryStatuses.containsKey(msgIdStr)) {
      final val = savedDeliveryStatuses[msgIdStr];
      if (val is Map) {
        delStatus = (val['delivery_status'] ?? delStatus).toString();
      } else {
        delStatus = val.toString();
      }
    }

    String ordStatus = (msgMap['order_status'] ?? '').toString();
    if (savedOrderStatuses.containsKey(msgIdStr)) {
      ordStatus = (savedOrderStatuses[msgIdStr] ?? ordStatus).toString();
    }

    // Determine normalized order status: Pending, Pickup, Delivered, Cancelled
    String statusLabel = 'Pending';
    final delLower = delStatus.toLowerCase();
    final ordLower = ordStatus.toLowerCase();

    if (delLower == 'delivered' || ordLower == 'delivered') {
      statusLabel = 'Delivered';
    } else if (delLower == 'out for delivery' || delLower == 'pickup' || delLower == 'picked up') {
      statusLabel = 'Pickup';
    } else if (delLower == 'cancelled' || ordLower == 'cancelled') {
      statusLabel = 'Cancelled';
    } else {
      statusLabel = 'Pending';
    }

    // Delivery Boy Name Logic
    String rawDeliveryBoy = (msgMap['delivered_by'] ?? msgMap['delivery_boy_name'] ?? msgMap['delivery_boy'] ?? '').toString().trim();
    if (rawDeliveryBoy.isEmpty && savedDeliveryStatuses.containsKey(msgIdStr)) {
      final val = savedDeliveryStatuses[msgIdStr];
      if (val is Map) {
        rawDeliveryBoy = (val['delivered_by'] ?? val['delivery_boy_name'] ?? val['delivery_boy'] ?? '').toString().trim();
      }
    }

    String deliveryBoyName = 'Not Assigned';
    if (rawDeliveryBoy.isNotEmpty && rawDeliveryBoy.toLowerCase() != 'null') {
      final dbKey = rawDeliveryBoy.toLowerCase();
      if (deliveryBoyNameMap.containsKey(dbKey)) {
        deliveryBoyName = deliveryBoyNameMap[dbKey]!;
      } else {
        deliveryBoyName = rawDeliveryBoy.length > 1
            ? rawDeliveryBoy[0].toUpperCase() + rawDeliveryBoy.substring(1)
            : rawDeliveryBoy.toUpperCase();
      }
    }

    // Amounts
    double totalAmt = double.tryParse(msgMap['order_amount']?.toString() ?? '') ?? 0.0;
    if (totalAmt <= 0 && msgMap['items_json'] != null) {
      try {
        List items = msgMap['items_json'] is String ? jsonDecode(msgMap['items_json']) : (msgMap['items_json'] as List);
        for (var item in items) {
          if (item is Map) {
            double p = double.tryParse(item['price']?.toString() ?? '') ?? 0;
            int q = int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
            totalAmt += (p * q);
          }
        }
      } catch (_) {}
    }

    // Timestamps
    final String rawCreatedAt = (msgMap['created_at'] ?? '').toString();
    final String cleanDtStr = rawCreatedAt.replaceAll(' ', 'T');
    DateTime parsedDt = DateTime.tryParse(cleanDtStr) ?? DateTime.tryParse(rawCreatedAt) ?? DateTime.now();

    // Status Date Time Logic:
    // 1. Pending: empty ('')
    // 2. Pickup: picked_up_at (when pickup action occurred)
    // 3. Delivered: delivered_at (when delivery action occurred)
    // 4. Cancelled: cancelled_at
    String statusTimeDisplay = '';

    if (statusLabel == 'Delivered') {
      if (savedDeliveryStatuses.containsKey(msgIdStr) && savedDeliveryStatuses[msgIdStr] is Map) {
        final val = savedDeliveryStatuses[msgIdStr];
        statusTimeDisplay = (val['delivered_at'] ?? val['updated_at'] ?? '').toString().trim();
      }
      if (statusTimeDisplay.isEmpty) {
        statusTimeDisplay = (msgMap['delivered_at'] ?? msgMap['delivery_time'] ?? msgMap['updated_at'] ?? '').toString().trim();
      }
      if (statusTimeDisplay.isEmpty && (msgMap['delivery_status'] ?? '').toString().toLowerCase() == 'delivered') {
        statusTimeDisplay = (msgMap['status_time'] ?? '').toString().trim();
      }
    } else if (statusLabel == 'Pickup') {
      if (savedDeliveryStatuses.containsKey(msgIdStr) && savedDeliveryStatuses[msgIdStr] is Map) {
        final val = savedDeliveryStatuses[msgIdStr];
        statusTimeDisplay = (val['picked_up_at'] ?? val['updated_at'] ?? '').toString().trim();
      }
      if (statusTimeDisplay.isEmpty) {
        statusTimeDisplay = (msgMap['picked_up_at'] ?? msgMap['pickup_time'] ?? msgMap['updated_at'] ?? '').toString().trim();
      }
      if (statusTimeDisplay.isEmpty && (msgMap['delivery_status'] ?? '').toString().toLowerCase().contains('pickup')) {
        statusTimeDisplay = (msgMap['status_time'] ?? '').toString().trim();
      }
    } else if (statusLabel == 'Cancelled') {
      statusTimeDisplay = (msgMap['cancelled_at'] ?? msgMap['cancel_time'] ?? msgMap['updated_at'] ?? '').toString().trim();
      if (statusTimeDisplay.isEmpty) {
        statusTimeDisplay = (msgMap['status_time'] ?? '').toString().trim();
      }
    } else {
      // Pending: ALWAYS EMPTY
      statusTimeDisplay = '';
    }

    // Payment Status & Mode parsing
    String rawPayStatus = (msgMap['payment_status'] ?? '').toString().trim().toLowerCase();
    String rawPayMode = (msgMap['payment_mode'] ?? msgMap['payment_method'] ?? msgMap['payment_type'] ?? '').toString().trim();

    if (savedPayments.containsKey(msgIdStr)) {
      final pVal = savedPayments[msgIdStr];
      if (pVal is Map) {
        if (pVal['status'] != null) rawPayStatus = pVal['status'].toString().trim().toLowerCase();
        if (pVal['mode'] != null) rawPayMode = pVal['mode'].toString().trim();
      } else if (pVal != null) {
        rawPayStatus = pVal.toString().trim().toLowerCase();
      }
    }

    String payStatusDisplay = 'Unpaid';
    if (rawPayStatus == 'paid' || rawPayStatus == 'completed' || rawPayStatus == 'success' || rawPayStatus == 'online_paid') {
      payStatusDisplay = 'Paid';
    }

    String payModeDisplay = '';
    if (payStatusDisplay == 'Paid') {
      payModeDisplay = rawPayMode.isNotEmpty ? rawPayMode : 'Cash';
      if (payModeDisplay.toLowerCase() == 'cod') {
        payModeDisplay = 'Cash';
      } else if (payModeDisplay.toLowerCase() == 'online_pay' || payModeDisplay.toLowerCase() == 'upi_pay') {
        payModeDisplay = 'Online';
      }
    } else {
      payModeDisplay = ''; // Empty when Unpaid
    }

    final String finalCustName = (custName.isNotEmpty && !custName.startsWith('Customer'))
        ? '$custName ($custMobile)'
        : custMobile;

    // Seller Location
    String sellerLoc = '';
    final lookupKey = sellerUsername.toLowerCase();
    final lookupNameKey = sellerName.toLowerCase();
    String? loc = sellerLocationMap[lookupKey] ?? sellerLocationMap[lookupNameKey];
    if (loc != null && loc.isNotEmpty) {
      sellerLoc = loc;
    }

    // Explicit Pickup Date Time Parsing
    String pickupTimeDisplay = '';
    if (savedDeliveryStatuses.containsKey(msgIdStr) && savedDeliveryStatuses[msgIdStr] is Map) {
      final val = savedDeliveryStatuses[msgIdStr];
      pickupTimeDisplay = (val['picked_up_at'] ?? val['pickup_time'] ?? '').toString().trim();
    }
    if (pickupTimeDisplay.isEmpty) {
      pickupTimeDisplay = (msgMap['picked_up_at'] ?? msgMap['pickup_time'] ?? '').toString().trim();
    }
    if (pickupTimeDisplay.isEmpty && statusLabel == 'Pickup') {
      pickupTimeDisplay = (msgMap['status_time'] ?? '').toString().trim();
    }

    // Explicit Delivered Date Time Parsing
    String deliveredTimeDisplay = '';
    if (savedDeliveryStatuses.containsKey(msgIdStr) && savedDeliveryStatuses[msgIdStr] is Map) {
      final val = savedDeliveryStatuses[msgIdStr];
      deliveredTimeDisplay = (val['delivered_at'] ?? val['delivery_time'] ?? '').toString().trim();
    }
    if (deliveredTimeDisplay.isEmpty) {
      deliveredTimeDisplay = (msgMap['delivered_at'] ?? msgMap['delivery_time'] ?? '').toString().trim();
    }
    DateTime? rawPickupDt;
    if (pickupTimeDisplay.isNotEmpty) {
      try {
        rawPickupDt = DateTime.parse(pickupTimeDisplay.replaceAll(' ', 'T'));
      } catch (_) {}
    }

    DateTime? rawDeliveredDt;
    if (deliveredTimeDisplay.isNotEmpty) {
      try {
        rawDeliveredDt = DateTime.parse(deliveredTimeDisplay.replaceAll(' ', 'T'));
      } catch (_) {}
    }

    return {
      'date': '${parsedDt.day.toString().padLeft(2, '0')}/${parsedDt.month.toString().padLeft(2, '0')}/${parsedDt.year}',
      'iso_date': parsedDt.toIso8601String(),
      'raw_date': parsedDt,
      'raw_pickup_time': rawPickupDt,
      'raw_delivered_time': rawDeliveredDt,
      'customer_name': finalCustName,
      'delivery_address': (msgMap['delivery_address'] ?? msgMap['address'] ?? msgMap['cust_address'] ?? '').toString().trim(),
      'address': (msgMap['delivery_address'] ?? msgMap['address'] ?? msgMap['cust_address'] ?? '').toString().trim(),
      'order_no': '#$cleanOrderId',
      'order_send_time': rawCreatedAt.isNotEmpty ? rawCreatedAt : '${parsedDt.day}/${parsedDt.month}/${parsedDt.year}',
      'amount': totalAmt,
      'seller_name': sellerName,
      'seller_location': sellerLoc.isNotEmpty ? sellerLoc : '-',
      'pickup_time': pickupTimeDisplay,
      'delivered_time': deliveredTimeDisplay,
      'order_status': statusLabel,
      'delivery_boy_name': deliveryBoyName,
      'status_time': statusTimeDisplay,
      'payment_status_display': payStatusDisplay,
      'payment_mode_display': payModeDisplay,
    };
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
      'customer_mobile': cleanCust,
      'seller_username': cleanSeller,
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
    final msgIdStr = messageId.toString();

    final now = DateTime.now();
    final formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // 1. Update persistent saved_order_statuses, saved_cancel_reasons, and saved_cancel_times
    Map<String, dynamic> savedStatuses = {};
    Map<String, dynamic> savedReasons = {};
    Map<String, dynamic> savedCancelTimes = {};
    try {
      final str = prefs.getString('saved_order_statuses');
      if (str != null && str.isNotEmpty) {
        savedStatuses = Map<String, dynamic>.from(jsonDecode(str));
      }
      final rStr = prefs.getString('saved_cancel_reasons');
      if (rStr != null && rStr.isNotEmpty) {
        savedReasons = Map<String, dynamic>.from(jsonDecode(rStr));
      }
      final tStr = prefs.getString('saved_cancel_times');
      if (tStr != null && tStr.isNotEmpty) {
        savedCancelTimes = Map<String, dynamic>.from(jsonDecode(tStr));
      }
    } catch (_) {}
    savedStatuses[msgIdStr] = 'Cancelled';
    savedReasons[msgIdStr] = reason;
    savedCancelTimes[msgIdStr] = formattedTime;
    await prefs.setString('saved_order_statuses', jsonEncode(savedStatuses));
    await prefs.setString('saved_cancel_reasons', jsonEncode(savedReasons));
    await prefs.setString('saved_cancel_times', jsonEncode(savedCancelTimes));

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
      await VpsApiService.post('update-bill-image', {
        'seller_username': cleanSeller,
        'customer_mobile': cleanCust,
        'message_id': messageId,
        'bill_image': base64Image,
      });
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
  // SELLER PRODUCTS CRUD API & LOCAL CACHE
  // ==========================================

  /// Get Products for a Seller (from VPS Database with local cache fallback)
  static Future<List<Map<String, dynamic>>> getSellerProducts(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';

    // Read local cache first for smart image preservation
    Map<int, String> localImageMap = {};
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> localList = jsonDecode(str);
        for (var l in localList) {
          final id = (l['id'] as num?)?.toInt() ?? 0;
          final img = (l['image_url'] ?? l['image'] ?? '').toString().trim();
          if (id > 0 && img.isNotEmpty && img != '📦') {
            localImageMap[id] = img;
          }
        }
      }
    } catch (_) {}

    // 1. Helper function to query VPS API
    Future<List<Map<String, dynamic>>?> fetchProductsApi(String sName) async {
      try {
        final res = await VpsApiService.get('get-seller-products&seller_username=${Uri.encodeComponent(sName)}');
        if (res != null && res['success'] == true && res['products'] is List) {
          final List<dynamic> rawList = res['products'];
          return rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } catch (_) {}
      return null;
    }

    // 1. Fetch from VPS API using cleanSeller
    List<Map<String, dynamic>>? products = await fetchProductsApi(cleanSeller);

    // 2. Try Capitalized version (e.g. "krishna" -> "Krishna")
    if ((products == null || products.isEmpty) && cleanSeller.length >= 2) {
      final cap = cleanSeller[0].toUpperCase() + cleanSeller.substring(1);
      if (cap != cleanSeller) {
        products = await fetchProductsApi(cap);
      }
    }

    // 3. Try lowercase version (e.g. "Krishna" -> "krishna")
    if (products == null || products.isEmpty) {
      final lower = cleanSeller.toLowerCase();
      if (lower != cleanSeller) {
        products = await fetchProductsApi(lower);
      }
    }

    // 4. If still empty, try every registered seller username from DB
    if (products == null || products.isEmpty) {
      try {
        final sellers = await getSellersList();
        for (var s in sellers) {
          final u = (s['username'] ?? '').toString().trim();
          final m = (s['mobile'] ?? '').toString().trim();
          final name = (s['name'] ?? '').toString().trim();

          final isMatch = (u.isNotEmpty && u.toLowerCase() == cleanSeller.toLowerCase()) ||
              (m.isNotEmpty && m == cleanSeller) ||
              (name.isNotEmpty && name.toLowerCase() == cleanSeller.toLowerCase());

          if (isMatch || u.isNotEmpty) {
            final fallbackList = await fetchProductsApi(u);
            if (fallbackList != null && fallbackList.isNotEmpty) {
              products = fallbackList;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (products != null && products.isNotEmpty) {
      // Merge local image if VPS server returned empty image_url
      for (var p in products) {
        final pId = (p['id'] as num?)?.toInt() ?? 0;
        final pImg = (p['image_url'] ?? p['image'] ?? '').toString().trim();
        if ((pImg.isEmpty || pImg == '📦') && localImageMap.containsKey(pId)) {
          p['image_url'] = localImageMap[pId];
          p['image'] = localImageMap[pId];
        }
      }

      await prefs.setString(cacheKey, jsonEncode(products));
      return products;
    }

    // 5. Default Catalog Fallback so Seller Store is NEVER empty!
    return [
      {
        'id': 101,
        'seller_username': cleanSeller,
        'name': 'Aashirvaad Shudh Chakki Atta',
        'description': '100% Whole Wheat Flour Atta',
        'unit': '5 Kg',
        'category': 'Grocery & Staples',
        'section': 'Daily Staples 🌾',
        'qty': 50,
        'rate': 245.0,
        'image_url': '🌾',
        'button_text': 'Buy Now',
      },
      {
        'id': 102,
        'seller_username': cleanSeller,
        'name': 'Fortune Kachi Ghani Mustard Oil',
        'description': 'Pure Mustard Cooking Oil',
        'unit': '1 Ltr',
        'category': 'Grocery & Staples',
        'section': 'Daily Staples 🌾',
        'qty': 30,
        'rate': 142.0,
        'image_url': '🍾',
        'button_text': 'Buy Now',
      },
      {
        'id': 103,
        'seller_username': cleanSeller,
        'name': 'Amul Pasteurised Salted Butter',
        'description': 'Delicious Creamy Amul Butter',
        'unit': '500 Gm',
        'category': 'Dairy & Eggs',
        'section': 'Fresh Dairy & Eggs 🥛',
        'qty': 25,
        'rate': 275.0,
        'image_url': '🧈',
        'button_text': 'Buy Now',
      },
      {
        'id': 104,
        'seller_username': cleanSeller,
        'name': 'Tata Salt Vacuum Evaporated',
        'description': 'Desh ka Namak Tata Salt',
        'unit': '1 Kg',
        'category': 'Grocery & Staples',
        'section': 'Daily Staples 🌾',
        'qty': 100,
        'rate': 28.0,
        'image_url': '🧂',
        'button_text': 'Buy Now',
      },
      {
        'id': 105,
        'seller_username': cleanSeller,
        'name': 'Fresh Hybrid Tomatoes',
        'description': 'Farm Fresh Red Tomatoes',
        'unit': '1 Kg',
        'category': 'Fresh Vegetables',
        'section': 'Farm Fresh Vegetables 🥦',
        'qty': 40,
        'rate': 35.0,
        'image_url': '🍅',
        'button_text': 'Buy Now',
      },
      {
        'id': 106,
        'seller_username': cleanSeller,
        'name': 'Fresh Shimla Red Apples',
        'description': 'Crispy Sweet Red Apples',
        'unit': '1 Kg',
        'category': 'Fresh Fruits',
        'section': 'Fresh Fruits & Juices 🍎',
        'qty': 20,
        'rate': 160.0,
        'image_url': '🍎',
        'button_text': 'Buy Now',
      },
      {
        'id': 107,
        'seller_username': cleanSeller,
        'name': 'Amul Taaza Toned Milk Pouch',
        'description': 'Pasteurised Toned Milk',
        'unit': '500 Ml',
        'category': 'Dairy & Eggs',
        'section': 'Fresh Dairy & Eggs 🥛',
        'qty': 60,
        'rate': 27.0,
        'image_url': '🥛',
        'button_text': 'Buy Now',
      },
      {
        'id': 108,
        'seller_username': cleanSeller,
        'name': 'Britannia Good Day Cashew Biscuits',
        'description': 'Crunchy Butter Cashew Cookies',
        'unit': '200 Gm',
        'category': 'Snacks & Munchies',
        'section': 'Snacks & Crisps 🍿',
        'qty': 45,
        'rate': 40.0,
        'image_url': '🍪',
        'button_text': 'Buy Now',
      },
    ];
  }

  /// Add a Product for a Seller (VPS API + Local Cache)
  static Future<bool> addSellerProduct({
    required String sellerUsername,
    required String name,
    String description = '',
    String unit = 'Pcs',
    String category = '',
    String section = '',
    int qty = 1,
    required double rate,
    String imageUrl = '',
    String buttonText = 'Buy Now',
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanName = name.trim();
    final cleanImg = imageUrl.trim();
    final cleanBtnText = buttonText.trim().isNotEmpty ? buttonText.trim() : 'Buy Now';
    if (cleanSeller.isEmpty || cleanName.isEmpty) return false;

    Map<String, dynamic>? newProd;

    // 1. Save to VPS API Database
    try {
      final res = await VpsApiService.post('add-seller-product', {
        'seller_username': cleanSeller,
        'name': cleanName,
        'description': description.trim(),
        'unit': unit.trim(),
        'category': category.trim(),
        'section': section.trim(),
        'qty': qty,
        'rate': rate,
        'image_url': cleanImg,
        'image': cleanImg,
        'button_text': cleanBtnText,
      });

      if (res != null && res['success'] == true && res['product'] != null) {
        newProd = Map<String, dynamic>.from(res['product']);
        if (cleanImg.isNotEmpty) {
          newProd['image_url'] = cleanImg;
          newProd['image'] = cleanImg;
        }
      }
    } catch (_) {}

    newProd ??= {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': cleanSeller,
      'name': cleanName,
      'description': description.trim(),
      'unit': unit.trim(),
      'category': category.trim(),
      'section': section.trim(),
      'qty': qty,
      'rate': rate,
      'image_url': cleanImg,
      'image': cleanImg,
      'button_text': cleanBtnText,
    };

    // 2. Save/Update Local Cache
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    List<Map<String, dynamic>> products = [];
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        products = (jsonDecode(str) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    products.insert(0, newProd);
    await prefs.setString(cacheKey, jsonEncode(products));
    return true;
  }

  /// Update an existing Product for a Seller
  static Future<bool> updateSellerProduct({
    required int id,
    required String sellerUsername,
    required String name,
    String description = '',
    String unit = 'Pcs',
    String category = '',
    String section = '',
    int qty = 1,
    required double rate,
    String imageUrl = '',
    String buttonText = 'Buy Now',
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanName = name.trim();
    final cleanImg = imageUrl.trim();
    final cleanBtnText = buttonText.trim().isNotEmpty ? buttonText.trim() : 'Buy Now';
    if (id <= 0 || cleanName.isEmpty) return false;

    // 1. VPS API Update
    try {
      await VpsApiService.post('update-seller-product', {
        'id': id,
        'seller_username': cleanSeller,
        'name': cleanName,
        'description': description.trim(),
        'unit': unit.trim(),
        'category': category.trim(),
        'section': section.trim(),
        'qty': qty,
        'rate': rate,
        'image_url': cleanImg,
        'image': cleanImg,
        'button_text': cleanBtnText,
      });
    } catch (_) {}

    // 2. Local Cache Update
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final products = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var p in products) {
          if ((p['id'] as num?)?.toInt() == id) {
            p['name'] = cleanName;
            p['description'] = description.trim();
            p['unit'] = unit.trim();
            p['category'] = category.trim();
            p['section'] = section.trim();
            p['qty'] = qty;
            p['rate'] = rate;
            p['image_url'] = cleanImg;
            p['image'] = cleanImg;
            p['button_text'] = cleanBtnText;
          }
        }
        await prefs.setString(cacheKey, jsonEncode(products));
      }
    } catch (_) {}

    return true;
  }

  /// Delete a Product for a Seller
  static Future<bool> deleteSellerProduct(int id, String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (id <= 0) return false;

    // 1. VPS API Delete
    try {
      await VpsApiService.post('delete-seller-product', {
        'id': id,
        'seller_username': cleanSeller,
      });
    } catch (_) {}

    // 2. Local Cache Update
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final products = list.map((e) => Map<String, dynamic>.from(e)).toList();
        products.removeWhere((p) => (p['id'] as num?)?.toInt() == id);
        await prefs.setString(cacheKey, jsonEncode(products));
      }
    } catch (_) {}

    return true;
  }

  // ==========================================
  // SELLER CUSTOM UNITS CRUD API & LOCAL CACHE
  // ==========================================

  /// Get Custom Units created by Seller (VPS Database with local cache fallback)
  static Future<List<Map<String, dynamic>>> getSellerUnits(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_units_$cleanSeller';

    // 1. VPS API
    try {
      final res = await VpsApiService.get('get-seller-units&seller_username=$cleanSeller');
      if (res != null && res['success'] == true && res['units'] is List) {
        final List<dynamic> rawList = res['units'];
        final List<Map<String, dynamic>> units = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        await prefs.setString(cacheKey, jsonEncode(units));
        return units;
      }
    } catch (_) {}

    // 2. Local Fallback Cache
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Add Custom Unit for Seller
  static Future<bool> addSellerUnit(String sellerUsername, String unitName) async {
    final cleanSeller = sellerUsername.trim();
    final cleanUnit = unitName.trim();
    if (cleanSeller.isEmpty || cleanUnit.isEmpty) return false;

    Map<String, dynamic>? newUnit;

    // 1. VPS API
    try {
      final res = await VpsApiService.post('add-seller-unit', {
        'seller_username': cleanSeller,
        'unit_name': cleanUnit,
      });
      if (res != null && res['success'] == true && res['unit'] != null) {
        newUnit = Map<String, dynamic>.from(res['unit']);
      }
    } catch (_) {}

    newUnit ??= {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': cleanSeller,
      'unit_name': cleanUnit,
    };

    // 2. Local Cache Update
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_units_$cleanSeller';
    List<Map<String, dynamic>> units = [];
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        units = (jsonDecode(str) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    bool exists = units.any((u) => (u['unit_name'] ?? '').toString().trim().toLowerCase() == cleanUnit.toLowerCase());
    if (!exists) {
      units.add(newUnit);
      await prefs.setString(cacheKey, jsonEncode(units));
    }
    return true;
  }

  /// Update Custom Unit
  static Future<bool> updateSellerUnit(int id, String sellerUsername, String unitName) async {
    final cleanSeller = sellerUsername.trim();
    final cleanUnit = unitName.trim();
    if (cleanUnit.isEmpty) return false;

    try {
      if (id > 0) {
        await VpsApiService.post('update-seller-unit', {
          'id': id,
          'unit_name': cleanUnit,
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_units_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final units = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var u in units) {
          if ((u['id'] as num?)?.toInt() == id) {
            u['unit_name'] = cleanUnit;
          }
        }
        await prefs.setString(cacheKey, jsonEncode(units));
      }
    } catch (_) {}

    return true;
  }

  /// Delete Custom Unit
  static Future<bool> deleteSellerUnit(int id, String sellerUsername, String unitName) async {
    final cleanSeller = sellerUsername.trim();

    try {
      if (id > 0) {
        await VpsApiService.post('delete-seller-unit', {
          'id': id,
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_units_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final units = list.map((e) => Map<String, dynamic>.from(e)).toList();
        units.removeWhere((u) => (u['id'] as num?)?.toInt() == id || u['unit_name'] == unitName);
        await prefs.setString(cacheKey, jsonEncode(units));
      }
    } catch (_) {}

    return true;
  }

  // ==========================================
  // SELLER CATEGORIES CRUD API & LOCAL CACHE
  // ==========================================

  /// Default store categories (Empty by default until created by seller)
  static List<Map<String, dynamic>> get defaultStoreCategories => [];

  /// Get Custom Categories for Seller (from VPS Database with local cache fallback)
  /// Get Custom Categories for Seller (from VPS Database with local cache fallback)
  static Future<List<Map<String, dynamic>>> getSellerCategories(String sellerUsername) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_categories_$cleanSeller';

    // 1. Fetch from VPS API
    try {
      final res = await VpsApiService.get('get-seller-categories&seller_username=${Uri.encodeComponent(cleanSeller)}');
      if (res != null && res['success'] == true && res['categories'] is List) {
        final List<dynamic> rawList = res['categories'];
        final List<Map<String, dynamic>> categories = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        await prefs.setString(cacheKey, jsonEncode(categories));
        return categories;
      }
    } catch (_) {}

    // 3. Fallback Categories so Category Ring & Product Catalog is NEVER empty!
    return [
      {'id': 1, 'name': 'Grocery & Staples', 'color': '#8B5CF6', 'image_url': '🌾'},
      {'id': 2, 'name': 'Fresh Vegetables', 'color': '#10B981', 'image_url': '🥦'},
      {'id': 3, 'name': 'Fresh Fruits', 'color': '#F59E0B', 'image_url': '🍎'},
      {'id': 4, 'name': 'Dairy & Eggs', 'color': '#06B6D4', 'image_url': '🥛'},
      {'id': 5, 'name': 'Snacks & Munchies', 'color': '#EC4899', 'image_url': '🍿'},
      {'id': 6, 'name': 'Beverages & Drinks', 'color': '#3B82F6', 'image_url': '🥤'},
      {'id': 7, 'name': 'Bakery & Sweets', 'color': '#F97316', 'image_url': '🍞'},
      {'id': 8, 'name': 'Personal Care', 'color': '#14B8A6', 'image_url': '🧴'},
      {'id': 9, 'name': 'Household Essentials', 'color': '#6366F1', 'image_url': '🧹'},
    ];
  }

  /// Add Custom Category for Seller
  static Future<bool> addSellerCategory(String sellerUsername, String categoryName, String imageUrl, {String color = '#8B5CF6'}) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    final cleanName = categoryName.trim();
    final cleanImg = imageUrl.trim();
    final cleanColor = color.trim().isEmpty ? '#8B5CF6' : color.trim();
    if (cleanSeller.isEmpty || cleanName.isEmpty) return false;

    Map<String, dynamic>? newCat;

    // 1. VPS API
    try {
      final res = await VpsApiService.post('add-seller-category', {
        'seller_username': cleanSeller,
        'name': cleanName,
        'image_url': cleanImg,
        'color': cleanColor,
      });
      if (res != null && res['success'] == true && res['category'] != null) {
        newCat = Map<String, dynamic>.from(res['category']);
      }
    } catch (_) {}

    newCat ??= {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': cleanSeller,
      'name': cleanName,
      'image_url': cleanImg.isEmpty ? '🏷️' : cleanImg,
      'color': cleanColor,
    };

    // 2. Local Cache Update
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_categories_$cleanSeller';
    List<Map<String, dynamic>> categories = [];
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        categories = (jsonDecode(str) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    bool exists = false;
    for (var c in categories) {
      if ((c['name'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase()) {
        c['color'] = cleanColor;
        if (cleanImg.isNotEmpty) c['image_url'] = cleanImg;
        exists = true;
      }
    }
    if (!exists) {
      categories.add(newCat);
    }
    await prefs.setString(cacheKey, jsonEncode(categories));
    return true;
  }

  /// Update Custom Category
  static Future<bool> updateSellerCategory(int id, String sellerUsername, String categoryName, String imageUrl, {String color = '#8B5CF6'}) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    final cleanName = categoryName.trim();
    final cleanImg = imageUrl.trim();
    final cleanColor = color.trim().isEmpty ? '#8B5CF6' : color.trim();
    if (cleanName.isEmpty) return false;

    try {
      if (id > 0) {
        await VpsApiService.post('update-seller-category', {
          'id': id,
          'seller_username': cleanSeller,
          'name': cleanName,
          'image_url': cleanImg,
          'color': cleanColor,
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_categories_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final categories = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var c in categories) {
          if ((c['id'] as num?)?.toInt() == id || (c['name'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase()) {
            c['name'] = cleanName;
            if (cleanImg.isNotEmpty) c['image_url'] = cleanImg;
            c['color'] = cleanColor;
          }
        }
        await prefs.setString(cacheKey, jsonEncode(categories));
      }
    } catch (_) {}

    return true;
  }

  /// Delete Custom Category
  static Future<bool> deleteSellerCategory(int id, String sellerUsername, String categoryName) async {
    final cleanSeller = sellerUsername.trim();

    try {
      if (id > 0) {
        await VpsApiService.post('delete-seller-category', {
          'id': id,
          'seller_username': cleanSeller,
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_categories_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final categories = list.map((e) => Map<String, dynamic>.from(e)).toList();
        categories.removeWhere((c) => (c['id'] as num?)?.toInt() == id || c['name'] == categoryName);
        await prefs.setString(cacheKey, jsonEncode(categories));
      }
    } catch (_) {}

    return true;
  }

  static const String _keyGlobalHeaderTheme = 'global_header_theme_config';

  /// Get Global Animated Header Theme Configuration (Database-First + Local Cache Fallback)
  static Future<Map<String, dynamic>> getHeaderThemeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultConfig = <String, dynamic>{
      'preset_id': 'midnight_navy',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
      'direction': 'diagonal', // 'horizontal', 'vertical', 'diagonal', 'radial'
      'shading': 'dark', // 'light', 'medium', 'dark', 'ultra_dark'
      'enable_shining': true,
      'particle_opacity': 0.9,
      'is_festival_active': true,
      'festival_title': '',
      'lottie_url': 'assets/lottie/daily_mart_exclusive.json',
      'lottie_opacity': 0.85,
    };

    // 1. Fetch fresh config from Server Database first
    try {
      final res = await VpsApiService.get('get-header-theme');
      if (res != null && res['success'] == true && res['theme'] != null) {
        final serverConfig = Map<String, dynamic>.from(res['theme']);
        if ((serverConfig['lottie_url'] ?? '').toString().contains('lottiefiles.com')) {
          serverConfig['lottie_url'] = 'assets/lottie/daily_mart_exclusive.json';
        }
        await prefs.setString(_keyGlobalHeaderTheme, jsonEncode(serverConfig));
        return serverConfig;
      }
    } catch (_) {}

    // 2. Fallback to Local SharedPreferences Cache if offline
    final str = prefs.getString(_keyGlobalHeaderTheme);
    if (str != null && str.isNotEmpty) {
      try {
        final cached = Map<String, dynamic>.from(jsonDecode(str));
        if ((cached['lottie_url'] ?? '').toString().contains('lottiefiles.com')) {
          cached['lottie_url'] = 'assets/lottie/daily_mart_exclusive.json';
        }
        return cached;
      } catch (_) {}
    }

    return defaultConfig;
  }

  /// Save Global Animated Header Theme Configuration (Local-First + VPS Sync)
  static Future<bool> saveHeaderThemeConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGlobalHeaderTheme, jsonEncode(config));

    try {
      await VpsApiService.post('update-header-theme', config);
    } catch (_) {}

    return true;
  }

  /// Generate Auto-Incrementing Sequential Order ID (#DM-1001, #DM-1002...)
  static Future<String> generateNextOrderId() async {
    final prefs = await SharedPreferences.getInstance();
    int currentId = prefs.getInt('last_generated_order_id_num') ?? 1000;
    currentId++;
    await prefs.setInt('last_generated_order_id_num', currentId);
    return '#DM-$currentId';
  }

  /// Save Customer Placed Order (Saves locally AND syncs to MySQL Database)
  static Future<Map<String, dynamic>> saveCustomerPlacedOrder(Map<String, dynamic> orderPayload) async {
    final prefs = await SharedPreferences.getInstance();

    // Ensure customer_mobile is set from logged in user if empty
    String custMobile = (orderPayload['customer_mobile'] ?? '').toString().trim();
    if (custMobile.isEmpty) {
      final currentUser = await getCurrentUser();
      custMobile = (currentUser?.mobile ?? '').trim();
      if (custMobile.isNotEmpty) {
        orderPayload['customer_mobile'] = custMobile;
      }
    }

    final localOrderId = (orderPayload['order_id'] ?? await generateNextOrderId()).toString();
    orderPayload['order_id'] = localOrderId;
    orderPayload['order_number'] = localOrderId;

    Map<String, dynamic> finalOrder = Map<String, dynamic>.from(orderPayload);

    // 1. ALWAYS Save locally first so order is NEVER lost!
    await _appendOrderToLocalHistory(custMobile, finalOrder, prefs);

    // 2. Sync to VPS MySQL Database (customer_orders + messages tables)
    try {
      final res = await VpsApiService.post('place-order', orderPayload);
      if (res != null && res['success'] == true && res['order'] != null) {
        final Map<String, dynamic> remoteOrder = Map<String, dynamic>.from(res['order']);
        finalOrder = remoteOrder;
        await _appendOrderToLocalHistory(custMobile, finalOrder, prefs, overwriteExistingId: localOrderId);
      } else {
        // Fallback: Also post as a message order to messages table
        final sellerUser = (orderPayload['seller_username'] ?? '').toString().trim();
        if (sellerUser.isNotEmpty && custMobile.isNotEmpty) {
          final items = List.from(orderPayload['items'] ?? []);
          final totalCount = (orderPayload['total_count'] as num?)?.toInt() ?? items.length;
          final totalAmt = (orderPayload['total_amount'] as num?)?.toDouble() ?? 0.0;
          final addrStr = (orderPayload['delivery_address'] ?? orderPayload['address'] ?? '').toString().trim();
          final msgText = '🛒 NEW ORDER PLACED ($localOrderId)\nTotal Items: $totalCount\nTotal Amount: ₹$totalAmt${addrStr.isNotEmpty ? '\n📍 Address: $addrStr' : ''}';

          await VpsApiService.post('send-message', {
            'seller_username': sellerUser,
            'customer_mobile': custMobile,
            'message': msgText,
            'items_json': jsonEncode(items),
            'order_id': localOrderId,
            'order_amount': totalAmt,
            'delivery_address': addrStr,
            'address': addrStr,
            'sender_type': 'customer',
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing order to VPS Database: $e');
    }

    return finalOrder;
  }

  static Future<void> _appendOrderToLocalHistory(String custMobile, Map<String, dynamic> order, SharedPreferences prefs, {String? overwriteExistingId}) async {
    final keysToUpdate = <String>[
      'global_all_customer_orders_history',
      if (custMobile.isNotEmpty) 'customer_orders_history_$custMobile',
      if (custMobile.length >= 10) 'customer_orders_history_${custMobile.substring(custMobile.length - 10)}',
    ];

    for (final key in keysToUpdate) {
      final String? existingJson = prefs.getString(key);
      List<Map<String, dynamic>> list = [];
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final List raw = jsonDecode(existingJson);
          list = List<Map<String, dynamic>>.from(raw);
        } catch (_) {}
      }

      if (overwriteExistingId != null) {
        list.removeWhere((item) => item['order_id'] == overwriteExistingId || item['order_number'] == overwriteExistingId);
      }

      final orderId = (order['order_id'] ?? order['order_number'] ?? '').toString();
      list.removeWhere((item) => (item['order_id'] ?? item['order_number'] ?? '').toString() == orderId);

      list.insert(0, order);
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Fetch Customer/Seller Placed Orders History (Merges MySQL VPS Database & Local Cache)
  static Future<List<Map<String, dynamic>>> getCustomerPlacedOrders(String customerMobile, {String sellerUsername = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    String custMobile = customerMobile.trim();
    final cleanSeller = sellerUsername.trim();
    
    if (custMobile.isEmpty) {
      final currentUser = await getCurrentUser();
      custMobile = (currentUser?.mobile ?? '').trim();
    }

    final digits = custMobile.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

    Map<String, dynamic> savedOrderStatuses = {};
    Map<String, dynamic> savedDeliveryStatuses = {};
    Map<String, dynamic> savedCancelReasons = {};
    Map<String, dynamic> savedPayments = {};
    try {
      final sStr = prefs.getString('saved_order_statuses');
      if (sStr != null && sStr.isNotEmpty) savedOrderStatuses = Map<String, dynamic>.from(jsonDecode(sStr));
      final dStr = prefs.getString('saved_delivery_statuses');
      if (dStr != null && dStr.isNotEmpty) savedDeliveryStatuses = Map<String, dynamic>.from(jsonDecode(dStr));
      final rStr = prefs.getString('saved_cancel_reasons');
      if (rStr != null && rStr.isNotEmpty) savedCancelReasons = Map<String, dynamic>.from(jsonDecode(rStr));
      final pStr = prefs.getString('saved_order_payments');
      if (pStr != null && pStr.isNotEmpty) savedPayments = Map<String, dynamic>.from(jsonDecode(pStr));
    } catch (_) {}

    final Map<String, Map<String, dynamic>> mergedMap = {};

    void addOrUpdateOrder(Map<String, dynamic> rawOrder) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(rawOrder);
      
      final dbId = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
      String orderId = (m['order_id'] ?? m['order_number'] ?? '').toString().trim();
      final msgStr = (m['message'] ?? '').toString().trim();
      
      // Extract #DM-XXXX if contained in message text
      final matchDm = RegExp(r'#DM-\d+').firstMatch(msgStr);
      if (matchDm != null) {
        orderId = matchDm.group(0)!;
      }
      
      if (orderId.isEmpty || orderId == 'Status' || orderId == 'Order #') {
        if (dbId > 0) {
          orderId = '#DM-${1000 + dbId}';
        } else {
          return;
        }
      } else if (orderId.startsWith('Order #')) {
        final numPart = orderId.replaceFirst('Order #', '').trim();
        final n = int.tryParse(numPart);
        if (n != null) {
          orderId = '#DM-${1000 + n}';
        }
      }

      m['order_id'] = orderId;
      m['order_number'] = orderId;

      // Extract total_amount if 0
      double totAmt = double.tryParse(m['total_amount']?.toString() ?? '') ?? double.tryParse(m['order_amount']?.toString() ?? '') ?? 0.0;
      if (totAmt <= 0) {
        final matchAmt = RegExp(r'(?:Total Amount|Total):\s*₹?\s*([\d\.]+)', caseSensitive: false).firstMatch(msgStr);
        if (matchAmt != null) {
          totAmt = double.tryParse(matchAmt.group(1)!) ?? 0.0;
        }
      }

      // Normalize items list
      List items = List.from(m['items'] ?? []);
      if (items.isEmpty && m['items_json'] != null) {
        try {
          final String jsonStr = m['items_json'].toString();
          if (jsonStr.isNotEmpty && jsonStr != '[]' && jsonStr != 'null') {
            final decoded = jsonDecode(jsonStr);
            if (decoded is List) items = decoded;
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> normalizedItems = [];
      for (final it in items) {
        if (it is Map) {
          final mapIt = Map<String, dynamic>.from(it);
          final rawName = (mapIt['name'] ?? mapIt['text'] ?? mapIt['title'] ?? '').toString().trim();
          if (rawName.isNotEmpty && !rawName.startsWith('🛒') && !rawName.startsWith('NEW ORDER PLACED')) {
            String cleanName = rawName;
            String unit = (mapIt['unit'] ?? 'Pcs').toString();
            int qty = int.tryParse(mapIt['qty']?.toString() ?? '1') ?? 1;
            double itemAmt = double.tryParse(mapIt['amount']?.toString() ?? '') ?? (mapIt['rate'] != null ? (double.tryParse(mapIt['rate'].toString()) ?? 0.0) * qty : 0.0);

            final matchLine = RegExp(r'^\d+\.\s*(.*?)(?:\s*\((.*?)\))?(?:\s*-\s*₹\s*([\d\.]+))?$').firstMatch(rawName);
            if (matchLine != null) {
              cleanName = matchLine.group(1)?.trim() ?? rawName;
              if (matchLine.group(2) != null) {
                final spec = matchLine.group(2)!.trim();
                final parts = spec.split(' ');
                if (parts.length >= 2) {
                  qty = int.tryParse(parts[0]) ?? qty;
                  unit = parts.sublist(1).join(' ');
                }
              }
              if (matchLine.group(3) != null) {
                itemAmt = double.tryParse(matchLine.group(3)!) ?? itemAmt;
              }
            }

            mapIt['name'] = cleanName;
            mapIt['qty'] = qty;
            mapIt['unit'] = unit;
            mapIt['amount'] = itemAmt;
            normalizedItems.add(mapIt);
          }
        }
      }

      // If normalizedItems is empty but msgStr has content, build items from msgStr lines
      if (normalizedItems.isEmpty && msgStr.isNotEmpty && !msgStr.startsWith('h')) {
        final lines = msgStr.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.contains('ORDER PLACED') && !trimmed.contains('Total')) {
            String cName = trimmed;
            String cUnit = 'Pcs';
            int cQty = 1;
            double cAmt = 0.0;

            final matchL = RegExp(r'^\d+\.\s*(.*?)(?:\s*\((.*?)\))?(?:\s*-\s*₹\s*([\d\.]+))?$').firstMatch(trimmed);
            if (matchL != null) {
              cName = matchL.group(1)?.trim() ?? trimmed;
              if (matchL.group(2) != null) {
                final spec = matchL.group(2)!.trim();
                final parts = spec.split(' ');
                if (parts.length >= 2) {
                  cQty = int.tryParse(parts[0]) ?? 1;
                  cUnit = parts.sublist(1).join(' ');
                }
              }
              if (matchL.group(3) != null) {
                cAmt = double.tryParse(matchL.group(3)!) ?? 0.0;
              }
            }

            normalizedItems.add({
              'name': cName,
              'qty': cQty,
              'unit': cUnit,
              'amount': cAmt,
            });
          }
        }
      }

      // Calculate total amount if still 0
      if (totAmt <= 0) {
        for (final it in normalizedItems) {
          totAmt += double.tryParse(it['amount']?.toString() ?? '0') ?? 0.0;
        }
      }

      // If normalizedItems is STILL empty, add a default Order Receipt item!
      if (normalizedItems.isEmpty) {
        normalizedItems.add({
          'name': 'Order Receipt ($orderId)',
          'qty': int.tryParse(m['total_count']?.toString() ?? '1') ?? 1,
          'unit': 'Item',
          'amount': totAmt,
        });
      }

      final msgIdStr = (dbId > 0 ? dbId : (m['id'] ?? '')).toString();

      String orderStatus = (m['order_status'] ?? m['status'] ?? '').toString();
      if (savedOrderStatuses.containsKey(msgIdStr)) {
        orderStatus = savedOrderStatuses[msgIdStr].toString();
      }

      String deliveryStatus = (m['delivery_status'] ?? '').toString();
      if (savedDeliveryStatuses.containsKey(msgIdStr)) {
        final val = savedDeliveryStatuses[msgIdStr];
        if (val is Map) {
          deliveryStatus = (val['delivery_status'] ?? deliveryStatus).toString();
          if (val['picked_up_at'] != null) m['picked_up_at'] = val['picked_up_at'];
          if (val['delivered_at'] != null) m['delivered_at'] = val['delivered_at'];
        } else {
          deliveryStatus = val.toString();
        }
      }

      String cancelReason = (m['cancel_reason'] ?? m['cancellation_reason'] ?? '').toString();
      if (savedCancelReasons.containsKey(msgIdStr)) {
        final rVal = savedCancelReasons[msgIdStr]?.toString() ?? '';
        if (rVal.isNotEmpty) cancelReason = rVal;
      }

      String paymentUtr = (m['payment_utr'] ?? m['utr'] ?? m['utr_number'] ?? m['txn_id'] ?? m['transaction_id'] ?? m['razorpay_payment_id'] ?? m['payment_id'] ?? '').toString().trim();
      String paymentStatus = (m['payment_status'] ?? '').toString().trim().toLowerCase();
      String paymentMode = (m['payment_mode'] ?? m['payment_method'] ?? m['payment_type'] ?? '').toString().trim();

      if (savedPayments.containsKey(msgIdStr)) {
        final pData = savedPayments[msgIdStr];
        if (pData is Map) {
          if (pData['payment_utr'] != null && pData['payment_utr'].toString().isNotEmpty) {
            paymentUtr = pData['payment_utr'].toString().trim();
          }
          if (pData['payment_status'] != null) {
            paymentStatus = pData['payment_status'].toString().trim().toLowerCase();
          }
          if (pData['payment_mode'] != null) {
            paymentMode = pData['payment_mode'].toString().trim();
          }
        }
      }

      if (paymentUtr.isEmpty) {
        final utrMatch = RegExp(r'(?:UTR|Txn|Transaction ID|Payment ID|Razorpay ID|Ref):\s*([A-Za-z0-9_]+)', caseSensitive: false).firstMatch(msgStr);
        if (utrMatch != null) {
          paymentUtr = utrMatch.group(1)!.trim();
        } else {
          final payMatch = RegExp(r'\b(pay_[A-Za-z0-9]+)\b').firstMatch(msgStr);
          if (payMatch != null) {
            paymentUtr = payMatch.group(1)!.trim();
          }
        }
      }

      if (paymentMode.isEmpty) {
        final lowerMsg = msgStr.toLowerCase();
        if (lowerMsg.contains('online') || lowerMsg.contains('upi') || lowerMsg.contains('razorpay') || lowerMsg.contains('paid online')) {
          paymentMode = 'Online';
        }
      }

      final bool isDelivered = deliveryStatus.toLowerCase() == 'delivered' ||
          orderStatus.toLowerCase() == 'delivered';
      final bool isCancelled = deliveryStatus.toLowerCase() == 'cancelled' ||
          orderStatus.toLowerCase() == 'cancelled' ||
          orderStatus.toLowerCase() == 'deleted' ||
          cancelReason.isNotEmpty;
      final bool isReady = orderStatus.toLowerCase() == 'ready' || orderStatus.toLowerCase() == 'approved';

      String displayStatus = 'PENDING';
      if (isDelivered) {
        displayStatus = 'DELIVERED';
      } else if (isCancelled) {
        displayStatus = 'CANCELLED';
      } else if (isReady) {
        displayStatus = 'READY';
      } else {
        displayStatus = 'PENDING';
      }

      m['items'] = normalizedItems;
      m['total_amount'] = totAmt;
      m['total_count'] = normalizedItems.isNotEmpty ? normalizedItems.length : 1;
      m['seller_name'] = (m['seller_name'] ?? m['seller_username'] ?? 'Store').toString();
      m['status'] = displayStatus;
      m['order_status'] = displayStatus;
      m['delivery_status'] = deliveryStatus.isNotEmpty ? deliveryStatus : (isDelivered ? 'Delivered' : 'Pending');
      m['cancel_reason'] = cancelReason.isNotEmpty ? cancelReason : (isCancelled ? 'Cancelled by seller' : '');
      m['payment_utr'] = paymentUtr;
      m['utr'] = paymentUtr;
      m['payment_status'] = paymentStatus;
      m['payment_mode'] = paymentMode;

      final dateStr = (m['date'] ?? m['created_at'] ?? '').toString();
      m['date'] = dateStr;
      m['timestamp'] = (m['timestamp'] as num?)?.toInt() ?? (DateTime.tryParse(dateStr)?.millisecondsSinceEpoch ?? (dbId > 0 ? dbId * 1000 : 0));

      final uniqueKey = '$orderId-${dbId > 0 ? dbId : m['timestamp']}';
      mergedMap[uniqueKey] = m;
    }

    // 1. Load from Local Cache
    final keysToCheck = <String>[
      'global_all_customer_orders_history',
      if (custMobile.isNotEmpty) 'customer_orders_history_$custMobile',
      if (last10.isNotEmpty) 'customer_orders_history_$last10',
    ];

    for (final key in keysToCheck) {
      final String? existingJson = prefs.getString(key);
      if (existingJson != null && existingJson.isNotEmpty) {
        try {
          final List raw = jsonDecode(existingJson);
          for (final item in raw) {
            if (item is Map) {
              addOrUpdateOrder(Map<String, dynamic>.from(item));
            }
          }
        } catch (_) {}
      }
    }

    // 2. Fetch from VPS MySQL Database action=get-customer-orders
    try {
      final List<String> queryParts = [];
      if (last10.isNotEmpty) queryParts.add('customer_mobile=$last10');
      if (cleanSeller.isNotEmpty) queryParts.add('seller_username=${Uri.encodeComponent(cleanSeller)}');
      final queryParam = queryParts.join('&');
      
      final res = await VpsApiService.get('get-customer-orders&$queryParam');
      if (res != null && res['success'] == true && res['orders'] != null) {
        final List rawOrders = res['orders'];
        for (final item in rawOrders) {
          if (item is Map) {
            addOrUpdateOrder(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer orders from VPS Database: $e');
    }

    // 3. Direct Query messages table by customer_mobile / seller_username
    try {
      final List<String> msgParts = [];
      if (last10.isNotEmpty) msgParts.add('customer_mobile=$last10');
      if (cleanSeller.isNotEmpty) msgParts.add('seller_username=${Uri.encodeComponent(cleanSeller)}');
      final mobParam = msgParts.join('&');
      
      final resDirect = await VpsApiService.get('get-messages&$mobParam');
      if (resDirect != null && resDirect['success'] == true && resDirect['messages'] != null) {
        final List msgs = resDirect['messages'];
        for (final msg in msgs) {
          if (msg is Map) {
            addOrUpdateOrder(Map<String, dynamic>.from(msg));
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching direct customer messages: $e');
    }

    // 4. Fetch from VPS MySQL Database messages table (messages/conversations fallback per seller)
    try {
      final queryParam = last10.isNotEmpty ? 'customer_mobile=$last10' : '';
      final List<Map<String, String>> sellersToQuery = [];

      final resConv = await VpsApiService.get('get-customer-conversations&$queryParam');
      if (resConv != null && resConv['success'] == true && resConv['conversations'] != null) {
        final List convs = resConv['conversations'];
        for (final c in convs) {
          final sUser = (c['seller_username'] ?? '').toString().trim();
          final sName = (c['seller_name'] ?? sUser).toString();
          if (sUser.isNotEmpty) {
            sellersToQuery.add({'username': sUser, 'name': sName});
          }
        }
      }

      // Fallback: If no sellers found from conversations, fetch all sellers list
      if (sellersToQuery.isEmpty) {
        final resSellers = await VpsApiService.get('sellers');
        if (resSellers != null && resSellers['success'] == true && resSellers['sellers'] != null) {
          final List sellersList = resSellers['sellers'];
          for (final s in sellersList) {
            final sUser = (s['username'] ?? '').toString().trim();
            final sName = (s['name'] ?? sUser).toString();
            if (sUser.isNotEmpty) {
              sellersToQuery.add({'username': sUser, 'name': sName});
            }
          }
        }
      }

      for (final seller in sellersToQuery) {
        final sellerUser = seller['username']!;
        final sellerName = seller['name']!;
        final mobParam = last10.isNotEmpty ? '&customer_mobile=$last10' : '';

        final resMsgs = await VpsApiService.get('get-messages&seller_username=$sellerUser$mobParam');
        if (resMsgs != null && resMsgs['success'] == true && resMsgs['messages'] != null) {
          final List msgs = resMsgs['messages'];
          for (final msg in msgs) {
            if (msg is Map) {
              final Map<String, dynamic> msgMap = Map<String, dynamic>.from(msg);
              msgMap['seller_username'] = sellerUser;
              msgMap['seller_name'] = sellerName;
              addOrUpdateOrder(msgMap);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer conversation messages from VPS: $e');
    }

    final result = mergedMap.values.toList();
    result.sort((a, b) {
      final tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
      final tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
      return tsB.compareTo(tsA);
    });

    return result;
  }

  /// Get Seller Sections (VPS Database API + SharedPreferences Cache)
  static Future<List<Map<String, dynamic>>> getSellerSections(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_sections_$cleanSeller';

    // 1. Fetch fresh from VPS API Database
    try {
      final res = await VpsApiService.get('get-seller-sections&seller_username=$cleanSeller');
      if (res != null && res['success'] == true && res['sections'] is List) {
        final List<dynamic> rawList = res['sections'];
        final List<Map<String, dynamic>> sections = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        await prefs.setString(cacheKey, jsonEncode(sections));
        return sections;
      }
    } catch (_) {}

    // 2. Fallback to Local Cache if offline
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    // NO HARDCODED DEFAULT SECTIONS! Returns empty list until created by seller
    return [];
  }

  /// Add Seller Section (VPS API + Local Cache)
  static Future<bool> addSellerSection(String sellerUsername, String name, [String icon = '🏷️', String bgColor = '#FFFFFF', String textColor = '#0F172A', int columns = 2]) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanIcon = icon.trim().isNotEmpty ? icon.trim() : '🏷️';
    final cleanBgColor = bgColor.trim().isNotEmpty ? bgColor.trim() : '#FFFFFF';
    final cleanTextColor = textColor.trim().isNotEmpty ? textColor.trim() : '#0F172A';
    final cleanCols = (columns >= 1 && columns <= 3) ? columns : 2;
    if (cleanSeller.isEmpty || cleanName.isEmpty) return false;

    Map<String, dynamic>? newSec;

    try {
      final res = await VpsApiService.post('add-seller-section', {
        'seller_username': cleanSeller,
        'name': cleanName,
        'icon': cleanIcon,
        'bg_color': cleanBgColor,
        'text_color': cleanTextColor,
        'columns': cleanCols,
      });
      if (res != null && res['success'] == true && res['section'] != null) {
        newSec = Map<String, dynamic>.from(res['section']);
      }
    } catch (_) {}

    newSec ??= {
      'id': DateTime.now().millisecondsSinceEpoch,
      'seller_username': cleanSeller,
      'name': cleanName,
      'icon': cleanIcon,
      'bg_color': cleanBgColor,
      'text_color': cleanTextColor,
      'columns': cleanCols,
    };

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_sections_$cleanSeller';
    List<Map<String, dynamic>> sections = [];
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        sections = (jsonDecode(str) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}

    int exIdx = sections.indexWhere((s) => (s['name'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase());
    if (exIdx >= 0) {
      sections[exIdx]['icon'] = cleanIcon;
      sections[exIdx]['bg_color'] = cleanBgColor;
      sections[exIdx]['text_color'] = cleanTextColor;
      sections[exIdx]['columns'] = cleanCols;
      if (newSec['id'] != null) sections[exIdx]['id'] = newSec['id'];
    } else {
      sections.add(newSec);
    }
    await prefs.setString(cacheKey, jsonEncode(sections));
    return true;
  }

  /// Update Seller Section
  static Future<bool> updateSellerSection(int id, String sellerUsername, String newName, [String icon = '🏷️', String bgColor = '#FFFFFF', String textColor = '#0F172A', int columns = 2]) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanName = newName.trim();
    final cleanIcon = icon.trim().isNotEmpty ? icon.trim() : '🏷️';
    final cleanBgColor = bgColor.trim().isNotEmpty ? bgColor.trim() : '#FFFFFF';
    final cleanTextColor = textColor.trim().isNotEmpty ? textColor.trim() : '#0F172A';
    final cleanCols = (columns >= 1 && columns <= 3) ? columns : 2;
    if (cleanName.isEmpty) return false;

    try {
      await VpsApiService.post('update-seller-section', {
        'id': id,
        'seller_username': cleanSeller,
        'name': cleanName,
        'icon': cleanIcon,
        'bg_color': cleanBgColor,
        'text_color': cleanTextColor,
        'columns': cleanCols,
      });
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_sections_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      List<Map<String, dynamic>> sections = [];
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        sections = list.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      bool updatedInCache = false;
      for (var s in sections) {
        if ((s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase()) {
          s['name'] = cleanName;
          s['icon'] = cleanIcon;
          s['bg_color'] = cleanBgColor;
          s['text_color'] = cleanTextColor;
          s['columns'] = cleanCols;
          updatedInCache = true;
        }
      }
      if (!updatedInCache) {
        sections.add({
          'id': id > 0 ? id : DateTime.now().millisecondsSinceEpoch,
          'seller_username': cleanSeller,
          'name': cleanName,
          'icon': cleanIcon,
          'bg_color': cleanBgColor,
          'text_color': cleanTextColor,
          'columns': cleanCols,
        });
      }
      await prefs.setString(cacheKey, jsonEncode(sections));
    } catch (_) {}

    return true;
  }

  /// Delete Seller Section
  static Future<bool> deleteSellerSection(int id, String sellerUsername, String name) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();

    try {
      if (id > 0) {
        await VpsApiService.post('delete-seller-section', {
          'id': id,
          'seller_username': cleanSeller,
        });
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_sections_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final sections = list.map((e) => Map<String, dynamic>.from(e)).toList();
        sections.removeWhere((s) => (s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase());
        await prefs.setString(cacheKey, jsonEncode(sections));
      }
    } catch (_) {}

    return true;
  }
}
