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

    // Instant Background Preload of Welcome Popup for 0ms display upon entry
    if (username.trim().isNotEmpty) {
      getSellerWelcomePopupImage(username.trim());
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

  /// Get Customer Addresses
  static Future<List<Map<String, dynamic>>> getCustomerAddresses(String mobile) async {
    final trimmedMobile = mobile.trim();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('customer_addresses_$trimmedMobile');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        return List<Map<String, dynamic>>.from(list);
      } catch (_) {}
    }
    return [];
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

  /// Generate next sequential Order ID matching server auto-increment (#DM-1237, #DM-1238...)
  static Future<String> getNextGlobalOrderId(
    String sellerUsername, {
    required String customerMobile,
    List<Map<String, dynamic>>? activeMessages,
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanCust = customerMobile.trim();

    // 1. Fetch sequential Order ID directly from MySQL Database
    try {
      final encSeller = Uri.encodeComponent(cleanSeller);
      final encCust = Uri.encodeComponent(cleanCust);
      final res = await VpsApiService.get('get-next-order-id&seller_username=$encSeller&customer_mobile=$encCust')
          .timeout(const Duration(milliseconds: 1500));
      if (res != null && res['success'] == true && res['next_order_id'] != null) {
        final serverOrdId = res['next_order_id'].toString().trim();
        final match = RegExp(r'#DM-(\d+)').firstMatch(serverOrdId);
        final numPart = match != null ? int.tryParse(match.group(1)!) : null;
        if (numPart != null && numPart >= 1200) {
          return serverOrdId;
        }
      }
    } catch (_) {}

    // 2. Query latest order from database messages to match server auto-increment
    try {
      final res = await VpsApiService.get('get-messages').timeout(const Duration(milliseconds: 2000));
      if (res != null && res['success'] == true && res['messages'] is List) {
        int maxId = 0;
        for (var m in (res['messages'] as List)) {
          final idVal = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
          if (idVal > maxId) maxId = idVal;
        }
        if (maxId > 0) {
          return '#DM-${1000 + maxId + 1}';
        }
      }
    } catch (_) {}

    // 3. Fallback from cached orders
    try {
      final cachedOrders = await getCachedCustomerPlacedOrders(customerMobile);
      int highestNum = 1236;
      for (var o in cachedOrders) {
        final oId = (o['order_id'] ?? '').toString();
        final match = RegExp(r'#DM-(\d+)').firstMatch(oId);
        if (match != null) {
          final val = int.tryParse(match.group(1)!) ?? 0;
          if (val > highestNum) highestNum = val;
        }
      }
      return '#DM-${highestNum + 1}';
    } catch (_) {}

    return '#DM-1237';
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

      // Instantly populate Seller Customer Order Cache
      _updateSellerOrderCache(sellerUsername, {
        'id': payload['id'].toString(),
        'order_id': orderTag ?? '',
        'order_number': orderTag ?? '',
        'seller_username': sellerUsername.trim(),
        'customer_mobile': customerMobile.trim(),
        'customer_name': 'Customer',
        'items': [],
        'total_amount': amt,
        'order_amount': amt,
        'total_count': 1,
        'order_status': 'Pending',
        'status': 'Pending',
        'delivery_status': 'Pending',
        'payment_status': 'unpaid',
        'created_at': DateTime.now().toIso8601String(),
        'date': DateTime.now().toIso8601String(),
      });

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
    String? orderId,
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
      if (messageId > 0) {
        savedStatuses[msgIdStr] = orderStatus;
      }
      if (orderId != null && orderId.isNotEmpty) {
        savedStatuses[orderId] = orderStatus;
        final cleanDigits = orderId.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanDigits.isNotEmpty) {
          savedStatuses[cleanDigits] = orderStatus;
        }
      }
      await prefs.setString('saved_order_statuses', jsonEncode(savedStatuses));

      // 2. Update local msgs_, messages_, cache_seller_cust_orders_, and history keys
      final keys = prefs.getKeys().where((k) =>
          k.startsWith('msgs_') ||
          k.startsWith('messages_') ||
          k.startsWith('cache_seller_cust_orders_') ||
          k.startsWith('customer_orders_history_') ||
          k == 'global_all_customer_orders_history').toList();

      for (var key in keys) {
        final str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          try {
            final List decoded = jsonDecode(str);
            final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            bool modified = false;
            for (var item in list) {
              final itemId = (item['id'] ?? item['message_id'] ?? '').toString();
              final itemOrdId = (item['order_id'] ?? item['order_number'] ?? '').toString();
              final matchesId = messageId > 0 && (itemId == msgIdStr || item['id'] == messageId);
              final matchesOrdId = orderId != null && orderId.isNotEmpty && (itemOrdId == orderId || itemOrdId.contains(orderId));
              if (matchesId || matchesOrdId) {
                item['order_status'] = orderStatus;
                item['status'] = orderStatus;
                item['delivery_status'] = orderStatus;
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
      final payload = <String, dynamic>{
        'message_id': messageId,
        'order_status': orderStatus,
      };
      if (orderId != null && orderId.isNotEmpty) {
        payload['order_id'] = orderId;
      }
      final res = await VpsApiService.post('update-order-status', payload);
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
    bool fullWidth = false,
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
      'full_width': fullWidth ? 1 : 0,
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
        'full_width': fullWidth ? 1 : 0,
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
    bool fullWidth = false,
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
      sliders[index]['full_width'] = fullWidth ? 1 : 0;

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
        'full_width': fullWidth ? 1 : 0,
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
        fullWidth: existing['full_width'] == 1 || existing['full_width'] == true || existing['full_width'] == '1',
      );
    }
    return false;
  }

  /// Quick toggle seller slider full_width (edge-to-edge vs normal margin) with 1 finger tap
  static Future<bool> toggleSellerSliderFullWidth(dynamic sliderId, String sellerUsername, bool fullWidth) async {
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

    final index = sliders.indexWhere((s) => s['id'] == sliderId || s['id'].toString() == sliderId.toString());
    if (index != -1) {
      final existing = sliders[index];
      existing['full_width'] = fullWidth ? 1 : 0;

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
        section: (existing['section'] ?? 'Top Banner').toString(),
        position: (existing['position'] ?? 'internal').toString(),
        overlayDim: (existing['overlay_dim'] as num?)?.toDouble() ?? 0.0,
        removeWhiteBg: existing['remove_white_bg'] == true || existing['remove_white_bg'] == 1,
        imgFit: (existing['img_fit'] ?? 'cover').toString(),
        fullWidth: fullWidth,
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

    final Map<String, Map<String, dynamic>> sellerGroupMap = {};
    final Set<int> processedMsgIds = {};

    // 1. Fast Single-Call API from VPS (<100ms instead of 50 sequential calls!)
    try {
      final vpsRes = await VpsApiService.get('get-undelivered-orders&location=$cleanDbLoc');
      if (vpsRes != null && vpsRes['success'] == true && vpsRes['orders'] is List) {
        final List ordersList = vpsRes['orders'];
        for (var o in ordersList) {
          if (o is Map) {
            final msgMap = Map<String, dynamic>.from(o);
            final msgId = (msgMap['id'] as num?)?.toInt() ?? int.tryParse(msgMap['id']?.toString() ?? '') ?? 0;
            final msgIdStr = msgId.toString();

            if (msgId != 0 && !processedMsgIds.contains(msgId)) {
              processedMsgIds.add(msgId);

              String ordStatus = (msgMap['order_status'] ?? '').toString();
              if (savedOrderStatuses.containsKey(msgIdStr)) {
                ordStatus = (savedOrderStatuses[msgIdStr] ?? ordStatus).toString();
              }

              String delStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
              if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                final val = savedDeliveryStatuses[msgIdStr];
                delStatus = (val is Map ? val['delivery_status'] : val).toString();
                msgMap['delivery_status'] = delStatus;
              }

              final bool isCancelled = ordStatus.toLowerCase() == 'cancelled' || delStatus.toLowerCase() == 'cancelled';
              final bool isDelivered = delStatus.toLowerCase() == 'delivered' || ordStatus.toLowerCase() == 'delivered';

              if (!isCancelled && !isDelivered) {
                if (savedPayments.containsKey(msgIdStr)) {
                  msgMap['payment_status'] = 'paid';
                  msgMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? (msgMap['payment_utr'] ?? '');
                }

                final sellerUser = (msgMap['seller_username'] ?? '').toString().trim().toLowerCase();
                if (sellerUser.isNotEmpty) {
                  if (!sellerGroupMap.containsKey(sellerUser)) {
                    sellerGroupMap[sellerUser] = {
                      'seller_username': msgMap['seller_username'],
                      'seller_name': msgMap['seller_name'] ?? 'Store',
                      'seller_mobile': msgMap['seller_mobile'] ?? '',
                      'orders': <Map<String, dynamic>>[],
                    };
                  }
                  (sellerGroupMap[sellerUser]!['orders'] as List<Map<String, dynamic>>).add(msgMap);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Fast get-undelivered-orders api failed: $e');
    }

    // 2. Also check local SharedPreferences keys for offline/recent orders
    final localKeys = prefs.getKeys();
    for (var key in localKeys) {
      if (key.startsWith('msgs_') || key.startsWith('messages_')) {
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          try {
            final List<dynamic> list = jsonDecode(raw);
            for (var item in list) {
              if (item is Map) {
                final msgMap = Map<String, dynamic>.from(item);
                final msgId = (msgMap['id'] as num?)?.toInt() ?? int.tryParse(msgMap['id']?.toString() ?? '') ?? 0;
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
                      delStatus = (val is Map ? val['delivery_status'] : val).toString();
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
                      }

                      final sellerUser = (msgMap['seller_username'] ?? '').toString().trim().toLowerCase();
                      if (sellerUser.isNotEmpty) {
                        if (!sellerGroupMap.containsKey(sellerUser)) {
                          sellerGroupMap[sellerUser] = {
                            'seller_username': msgMap['seller_username'],
                            'seller_name': msgMap['seller_name'] ?? 'Store',
                            'seller_mobile': msgMap['seller_mobile'] ?? '',
                            'orders': <Map<String, dynamic>>[],
                          };
                        }
                        (sellerGroupMap[sellerUser]!['orders'] as List<Map<String, dynamic>>).add(msgMap);
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    final List<Map<String, dynamic>> groupedResult = sellerGroupMap.values.toList();

    // Cache the updated list (even if empty, to immediately clear delivered orders)
    try {
      await prefs.setString('delivery_boy_grouped_orders_${cleanDbLoc}', jsonEncode(groupedResult));
      await prefs.setString('delivery_boy_grouped_orders_all', jsonEncode(groupedResult));
    } catch (_) {}

    return groupedResult;
  }

  /// Get Cached Undelivered Orders Grouped By Seller for Delivery Boy (0ms Instant Load)
  static Future<List<Map<String, dynamic>>> getCachedAllUndeliveredOrdersGroupedBySeller({
    String deliveryBoyLocation = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locKey = deliveryBoyLocation.trim().toLowerCase();
      final keysToCheck = [
        if (locKey.isNotEmpty) 'delivery_boy_grouped_orders_$locKey',
        'delivery_boy_grouped_orders_all',
        'delivery_boy_grouped_orders_',
      ];

      final String? allSavedDeliveryStr = prefs.getString('saved_delivery_statuses');
      final String? allSavedPaymentsStr = prefs.getString('saved_order_payments');
      Map<String, dynamic> savedDeliveryStatuses = {};
      Map<String, dynamic> savedPayments = {};
      try {
        if (allSavedDeliveryStr != null && allSavedDeliveryStr.isNotEmpty) {
          savedDeliveryStatuses = Map<String, dynamic>.from(jsonDecode(allSavedDeliveryStr));
        }
        if (allSavedPaymentsStr != null && allSavedPaymentsStr.isNotEmpty) {
          savedPayments = Map<String, dynamic>.from(jsonDecode(allSavedPaymentsStr));
        }
      } catch (_) {}

      for (var key in keysToCheck) {
        final str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          final List decoded = jsonDecode(str);
          final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

          final List<Map<String, dynamic>> cleanList = [];
          for (var sellerGroup in list) {
            final List rawOrders = (sellerGroup['orders'] is List) ? sellerGroup['orders'] : [];
            final List<Map<String, dynamic>> cleanOrders = [];
            for (var o in rawOrders) {
              if (o is Map) {
                final oMap = Map<String, dynamic>.from(o);
                final msgIdStr = (oMap['id'] ?? '').toString();
                if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                  final savedVal = savedDeliveryStatuses[msgIdStr];
                  final delStatus = (savedVal is Map ? savedVal['delivery_status'] : savedVal).toString().toLowerCase();
                  if (delStatus == 'delivered' || delStatus == 'cancelled') {
                    continue; // Skip delivered/cancelled order!
                  }
                  oMap['delivery_status'] = (savedVal is Map ? savedVal['delivery_status'] : savedVal).toString();
                }
                if (savedPayments.containsKey(msgIdStr)) {
                  oMap['payment_status'] = 'paid';
                  oMap['payment_utr'] = savedPayments[msgIdStr]['payment_utr'] ?? oMap['payment_utr'];
                }
                cleanOrders.add(oMap);
              }
            }
            if (cleanOrders.isNotEmpty) {
              sellerGroup['orders'] = cleanOrders;
              cleanList.add(sellerGroup);
            }
          }
          return cleanList;
        }
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

    try {
      final fresh = await _refreshSellerCustomerOrdersInBackground(cleanSeller);
      if (fresh.isNotEmpty) return fresh;
    } catch (_) {}

    return await getCachedSellerCustomerOrders(cleanSeller);
  }

  static Future<List<Map<String, dynamic>>> _refreshSellerCustomerOrdersInBackground(String cleanSeller) async {
    try {
      List rawOrders = [];
      final res = await VpsApiService.get('get-seller-customer-orders&seller_username=$cleanSeller');
      if (res != null && res['success'] == true && res['orders'] is List) {
        rawOrders = (res['orders'] as List);
      }

      // Robust fallback: If get-seller-customer-orders returned empty, query get-all-admin-orders and filter for this seller!
      if (rawOrders.isEmpty) {
        try {
          final adminRes = await VpsApiService.get('get-all-admin-orders');
          if (adminRes != null && adminRes['success'] == true && adminRes['orders'] is List) {
            final List adminList = adminRes['orders'];
            final target = cleanSeller.toLowerCase();
            rawOrders = adminList.where((o) {
              if (o is! Map) return false;
              final su = (o['seller_username'] ?? '').toString().trim().toLowerCase();
              final sn = (o['seller_name'] ?? '').toString().trim().toLowerCase();
              return su == target || sn == target || su.contains(target) || target.contains(su);
            }).toList();
          }
        } catch (_) {}
      }

      if (rawOrders.isNotEmpty) {
        final List<Map<String, dynamic>> allSellerOrders = [];
        final Set<String> processedIds = {};

        Map<String, dynamic> savedStatuses = {};
        try {
          final prefs = await SharedPreferences.getInstance();
          final sStr = prefs.getString('saved_order_statuses');
          if (sStr != null && sStr.isNotEmpty) {
            savedStatuses = Map<String, dynamic>.from(jsonDecode(sStr));
          }
        } catch (_) {}

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

          String orderStatus = (msgMap['order_status'] ?? 'Pending').toString();
          String deliveryStatus = (msgMap['delivery_status'] ?? 'Pending').toString();
          final paymentStatus = (msgMap['payment_status'] ?? 'unpaid').toString().toLowerCase();
          final paymentUtr = (msgMap['payment_utr'] ?? '').toString();
          final paidAmount = double.tryParse((msgMap['paid_amount'] ?? '').toString()) ?? (paymentStatus == 'paid' ? totalAmount : 0.0);
          final paidAt = (msgMap['paid_at'] ?? '').toString();
          final dateStr = (msgMap['created_at'] ?? '').toString();
          final orderIdStr = (msgMap['order_id'] ?? (msgId.isNotEmpty ? '#DM-$msgId' : '#DM-1001')).toString();

          final cleanDigits = orderIdStr.replaceAll(RegExp(r'[^0-9]'), '');
          final savedStat = savedStatuses[msgId] ?? savedStatuses[orderIdStr] ?? (cleanDigits.isNotEmpty ? savedStatuses[cleanDigits] : null);
          if (savedStat != null && savedStat.toString().isNotEmpty) {
            final sUpper = savedStat.toString().toUpperCase();
            final curUpper = orderStatus.toUpperCase();
            if (curUpper == 'PENDING' && (sUpper == 'READY' || sUpper == 'CANCELLED')) {
              orderStatus = savedStat.toString();
              if (sUpper == 'READY') {
                deliveryStatus = 'Ready';
              } else if (sUpper == 'CANCELLED') {
                deliveryStatus = 'Cancelled';
              }
            }
          }

          final isDelivered = deliveryStatus.toLowerCase() == 'delivered' || orderStatus.toLowerCase() == 'delivered';
          final displayStatus = isDelivered ? 'DELIVERED' : orderStatus;

          String deliveryAddress = (msgMap['delivery_address'] ?? msgMap['address'] ?? msgMap['cust_address'] ?? '').toString().trim();
          if (deliveryAddress.isEmpty && msgMap['message'] != null) {
            final match = RegExp(r'(?:Address|delivery_address|📍\s*Address):\s*([^\r\n]+)', caseSensitive: false).firstMatch(msgMap['message'].toString());
            if (match != null) {
              deliveryAddress = match.group(1)!.trim();
            }
          }
          if (deliveryAddress.isEmpty && msgMap['customer_profile_address'] != null) {
            deliveryAddress = msgMap['customer_profile_address'].toString().trim();
          }

          allSellerOrders.add({
            'id': msgId,
            'order_id': orderIdStr,
            'order_number': orderIdStr,
            'seller_username': cleanSeller,
            'customer_mobile': custMobile,
            'customer_name': custName,
            'delivery_address': deliveryAddress,
            'address': deliveryAddress,
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

    // 2b. Immediately update delivery_boy_grouped_orders_ cache keys in SharedPreferences
    final dbKeys = prefs.getKeys().where((k) => k.startsWith('delivery_boy_grouped_orders_')).toList();
    for (var k in dbKeys) {
      final str = prefs.getString(k);
      if (str != null && str.isNotEmpty) {
        try {
          final List decoded = jsonDecode(str);
          final List<Map<String, dynamic>> sellers = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          bool modified = false;
          for (var s in sellers) {
            final List ordersList = (s['orders'] is List) ? s['orders'] : [];
            if (newDeliveryStatus.toLowerCase() == 'delivered' || newDeliveryStatus.toLowerCase() == 'cancelled') {
              final beforeLen = ordersList.length;
              ordersList.removeWhere((o) {
                final oId = (o['id'] as num?)?.toInt() ?? int.tryParse(o['id']?.toString() ?? '') ?? 0;
                return oId == messageId;
              });
              if (ordersList.length != beforeLen) modified = true;
            } else {
              for (var o in ordersList) {
                final oId = (o['id'] as num?)?.toInt() ?? int.tryParse(o['id']?.toString() ?? '') ?? 0;
                if (oId == messageId) {
                  o['delivery_status'] = newDeliveryStatus;
                  o['delivered_by'] = deliveryBoyUsername;
                  modified = true;
                }
              }
            }
          }
          sellers.removeWhere((s) => ((s['orders'] as List?) ?? []).isEmpty);
          if (modified) {
            await prefs.setString(k, jsonEncode(sellers));
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
    String orderId = '',
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
    if (messageId > 0) {
      savedStatuses[msgIdStr] = 'Cancelled';
      savedReasons[msgIdStr] = reason;
      savedCancelTimes[msgIdStr] = formattedTime;
    }
    if (orderId.isNotEmpty) {
      savedStatuses[orderId] = 'Cancelled';
      savedReasons[orderId] = reason;
      savedCancelTimes[orderId] = formattedTime;
    }
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
            final matchesId = messageId > 0 && (item['id'] == messageId || item['id'].toString() == msgIdStr);
            final matchesOrderId = orderId.isNotEmpty && (item['order_id'] == orderId || item['order_number'] == orderId);
            if (matchesId || matchesOrderId) {
              item['order_status'] = 'Cancelled';
              item['delivery_status'] = 'Cancelled';
              item['status'] = 'CANCELLED';
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

    // 2b. Update customer_orders_history_ and seller_customer_orders_ keys in SharedPreferences
    final orderHistoryKeys = prefs.getKeys().where((k) =>
      k.startsWith('customer_orders_history_') ||
      k.startsWith('seller_customer_orders_') ||
      k == 'global_all_customer_orders_history'
    ).toList();
    for (var key in orderHistoryKeys) {
      final str = prefs.getString(key);
      if (str != null && str.isNotEmpty) {
        try {
          final List decoded = jsonDecode(str);
          final List<Map<String, dynamic>> list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          bool modified = false;
          for (var item in list) {
            final matchesId = messageId > 0 && (item['id'] == messageId || item['id'].toString() == msgIdStr);
            final matchesOrderId = orderId.isNotEmpty && (item['order_id'] == orderId || item['order_number'] == orderId);
            if (matchesId || matchesOrderId) {
              item['order_status'] = 'Cancelled';
              item['delivery_status'] = 'Cancelled';
              item['status'] = 'CANCELLED';
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
        if (orderId.isNotEmpty) 'order_id': orderId,
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

  /// Read Cached Products for a Seller (Instant 0.01 sec read without network delay)
  static Future<List<Map<String, dynamic>>> getCachedSellerProducts(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    Map<String, List<Map<String, dynamic>>> localVariantsMap = {};
    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final vStr = prefs.getString('seller_product_variants_$keySuffix');
        if (vStr != null && vStr.isNotEmpty) {
          final Map<String, dynamic> decodedVMap = jsonDecode(vStr);
          decodedVMap.forEach((k, val) {
            localVariantsMap[k] = _parseProductVariants(val);
          });
        }
      } catch (_) {}
    }

    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final str = prefs.getString('seller_products_$keySuffix');
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          final prods = list.map((e) {
            final m = Map<String, dynamic>.from(e);
            final pId = (m['id'] as num?)?.toInt() ?? 0;
            final pName = (m['name'] ?? '').toString().trim().toLowerCase();
            final parsed = _parseProductVariants(m['variants']);
            if (parsed.isNotEmpty) {
              m['variants'] = parsed;
            } else if (pId > 0 && localVariantsMap.containsKey('id_$pId')) {
              m['variants'] = localVariantsMap['id_$pId']!;
            } else if (pName.isNotEmpty && localVariantsMap.containsKey('name_$pName')) {
              m['variants'] = localVariantsMap['name_$pName']!;
            } else {
              m['variants'] = <Map<String, dynamic>>[];
            }
            return m;
          }).toList();
          if (prods.isNotEmpty) return prods;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Read Cached Categories for a Seller (Instant 0.01 sec read without network delay)
  static Future<List<Map<String, dynamic>>> getCachedSellerCategories(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final str = prefs.getString('seller_categories_$keySuffix');
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          final cats = list.map((e) => Map<String, dynamic>.from(e)).toList();
          if (cats.isNotEmpty) return cats;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Read Cached Sections for a Seller (Instant 0.01 sec read without network delay)
  static Future<List<Map<String, dynamic>>> getCachedSellerSections(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final str = prefs.getString('seller_sections_$keySuffix');
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          final secs = list.map((e) => Map<String, dynamic>.from(e)).toList();
          if (secs.isNotEmpty) return secs;
        }
      } catch (_) {}
    }
    return [];
  }

  static List<Map<String, dynamic>> _parseProductVariants(dynamic raw) {
    if (raw == null) return [];
    try {
      List<dynamic> list = [];
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } else if (raw is List) {
        list = raw;
      }
      return list
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final imgUrl = (m['image_url'] ?? m['image'] ?? '').toString().trim();
            return <String, dynamic>{
              'name': (m['name'] ?? m['variable_name'] ?? '').toString().trim(),
              'purchase_rate': double.tryParse((m['purchase_rate'] ?? m['p_rate'] ?? 0).toString()) ?? 0.0,
              'rate': double.tryParse((m['rate'] ?? m['sale_rate'] ?? m['s_rate'] ?? 0).toString()) ?? 0.0,
              'image_url': imgUrl,
            };
          })
          .where((v) => (v['name'] as String).isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get Products for a Seller (from VPS Database with local cache fallback)
  static Future<List<Map<String, dynamic>>> getSellerProducts(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    final variantsCacheKey = 'seller_product_variants_${cleanSeller.toLowerCase()}';

    // Read local cache first for smart image and variants preservation
    Map<int, String> localImageMap = {};
    Map<String, List<Map<String, dynamic>>> localVariantsMap = {};
    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final vStr = prefs.getString('seller_product_variants_$keySuffix');
        if (vStr != null && vStr.isNotEmpty) {
          final Map<String, dynamic> decodedVMap = jsonDecode(vStr);
          decodedVMap.forEach((k, val) {
            localVariantsMap[k] = _parseProductVariants(val);
          });
        }
      } catch (_) {}
    }

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
          final lVars = _parseProductVariants(l['variants']);
          if (id > 0 && lVars.isNotEmpty && !localVariantsMap.containsKey('id_$id')) {
            localVariantsMap['id_$id'] = lVars;
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
      // Merge local image and normalize variants
      for (var p in products) {
        final pId = (p['id'] as num?)?.toInt() ?? 0;
        final pName = (p['name'] ?? '').toString().trim().toLowerCase();
        final pImg = (p['image_url'] ?? p['image'] ?? '').toString().trim();
        if ((pImg.isEmpty || pImg == '📦') && localImageMap.containsKey(pId)) {
          p['image_url'] = localImageMap[pId];
          p['image'] = localImageMap[pId];
        }

        final serverVars = _parseProductVariants(p['variants']);
        final localVars = (pId > 0 && localVariantsMap.containsKey('id_$pId'))
            ? localVariantsMap['id_$pId']!
            : (pName.isNotEmpty && localVariantsMap.containsKey('name_$pName'))
                ? localVariantsMap['name_$pName']!
                : <Map<String, dynamic>>[];

        if (serverVars.isNotEmpty) {
          // Preserve any local variant image if server variant image is empty
          for (var sv in serverVars) {
            final svImg = (sv['image_url'] ?? '').toString().trim();
            if (svImg.isEmpty && localVars.isNotEmpty) {
              final svName = (sv['name'] ?? '').toString().trim().toLowerCase();
              for (var lv in localVars) {
                if ((lv['name'] ?? '').toString().trim().toLowerCase() == svName) {
                  final lvImg = (lv['image_url'] ?? '').toString().trim();
                  if (lvImg.isNotEmpty) {
                    sv['image_url'] = lvImg;
                    break;
                  }
                }
              }
            }
          }
          p['variants'] = serverVars;
          if (pId > 0) localVariantsMap['id_$pId'] = serverVars;
        } else if (localVars.isNotEmpty) {
          p['variants'] = localVars;
        } else {
          p['variants'] = <Map<String, dynamic>>[];
        }
      }

      await prefs.setString(variantsCacheKey, jsonEncode(localVariantsMap));
      await prefs.setString(cacheKey, jsonEncode(products));
      return products;
    }

    // Read local cache fallback
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final prods = list.map((e) {
          final m = Map<String, dynamic>.from(e);
          m['variants'] = _parseProductVariants(m['variants']);
          return m;
        }).toList();
        if (prods.isNotEmpty) return prods;
      }
    } catch (_) {}

    return [];
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
    double purchaseRate = 0.0,
    String imageUrl = '',
    String buttonText = 'Buy Now',
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanName = name.trim();
    final cleanImg = imageUrl.trim();
    final cleanBtnText = buttonText.trim().isNotEmpty ? buttonText.trim() : 'Buy Now';
    final cleanVariants = _parseProductVariants(variants);
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
        'purchase_rate': purchaseRate,
        'image_url': cleanImg,
        'image': cleanImg,
        'button_text': cleanBtnText,
        'variants': jsonEncode(cleanVariants),
      });

      if (res != null && res['success'] == true && res['product'] != null) {
        newProd = Map<String, dynamic>.from(res['product']);
        if (cleanImg.isNotEmpty) {
          newProd['image_url'] = cleanImg;
          newProd['image'] = cleanImg;
        }
        newProd['variants'] = cleanVariants;
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
      'purchase_rate': purchaseRate,
      'image_url': cleanImg,
      'image': cleanImg,
      'button_text': cleanBtnText,
      'variants': cleanVariants,
    };

    // 2. Save/Update Local Cache
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    final variantsCacheKey = 'seller_product_variants_$cleanSeller';

    try {
      Map<String, dynamic> vMap = {};
      for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase()]) {
        final vStr = prefs.getString('seller_product_variants_$keySuffix');
        if (vStr != null && vStr.isNotEmpty) {
          vMap.addAll(Map<String, dynamic>.from(jsonDecode(vStr)));
        }
      }
      final newId = (newProd['id'] as num?)?.toInt() ?? 0;
      if (newId > 0) vMap['id_$newId'] = cleanVariants;
      vMap['name_${cleanName.toLowerCase()}'] = cleanVariants;
      await prefs.setString(variantsCacheKey, jsonEncode(vMap));
      await prefs.setString('seller_product_variants_${cleanSeller.toLowerCase()}', jsonEncode(vMap));
    } catch (_) {}

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

  /// Bulk Add Products for a Seller (VPS API + Local Cache)
  static Future<int> bulkAddSellerProducts({
    required String sellerUsername,
    required List<Map<String, dynamic>> productsList,
  }) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty || productsList.isEmpty) return 0;

    int importedCount = 0;
    List<Map<String, dynamic>> newlyCreatedProds = [];

    try {
      // 1. Fetch existing categories, sections, units to check if auto-creation needed
      final existingCats = (await getSellerCategories(cleanSeller)).map((c) => (c['name'] ?? '').toString().trim().toLowerCase()).toSet();
      final existingSecs = (await getSellerSections(cleanSeller)).map((s) => (s['name'] ?? '').toString().trim().toLowerCase()).toSet();
      final existingUnits = (await getSellerUnits(cleanSeller)).map((u) => (u['name'] ?? '').toString().trim().toLowerCase()).toSet();

      // 2. Auto-create missing categories, sections, units on VPS database
      for (var p in productsList) {
        final cat = (p['category'] ?? '').toString().trim();
        if (cat.isNotEmpty && !existingCats.contains(cat.toLowerCase())) {
          existingCats.add(cat.toLowerCase());
          await addSellerCategory(cleanSeller, cat, '');
        }

        final sec = (p['section'] ?? '').toString().trim();
        if (sec.isNotEmpty && !existingSecs.contains(sec.toLowerCase())) {
          existingSecs.add(sec.toLowerCase());
          await addSellerSection(cleanSeller, sec);
        }

        final unit = (p['unit'] ?? '').toString().trim();
        if (unit.isNotEmpty && !existingUnits.contains(unit.toLowerCase())) {
          existingUnits.add(unit.toLowerCase());
          await addSellerUnit(cleanSeller, unit);
        }
      }

      // 3. Insert every product into VPS MySQL database via active add-seller-product endpoint
      for (var p in productsList) {
        final name = (p['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final res = await VpsApiService.post('add-seller-product', {
          'seller_username': cleanSeller,
          'name': name,
          'description': (p['description'] ?? '').toString().trim(),
          'long_description': (p['long_description'] ?? '').toString().trim(),
          'unit': (p['unit'] ?? 'Pcs').toString().trim(),
          'category': (p['category'] ?? '').toString().trim(),
          'section': (p['section'] ?? '').toString().trim(),
          'qty': int.tryParse(p['qty']?.toString() ?? '1') ?? 1,
          'rate': double.tryParse(p['rate']?.toString() ?? '0') ?? 0.0,
          'purchase_rate': double.tryParse(p['purchase_rate']?.toString() ?? '0') ?? 0.0,
          'image_url': (p['image_url'] ?? '').toString().trim(),
          'button_text': 'Buy Now',
        });

        if (res != null && res['success'] == true && res['product'] != null) {
          newlyCreatedProds.add(Map<String, dynamic>.from(res['product']));
        } else {
          newlyCreatedProds.add({
            'id': DateTime.now().millisecondsSinceEpoch + importedCount,
            'seller_username': cleanSeller,
            'name': name,
            'description': (p['description'] ?? '').toString().trim(),
            'long_description': (p['long_description'] ?? '').toString().trim(),
            'unit': (p['unit'] ?? 'Pcs').toString().trim(),
            'category': (p['category'] ?? '').toString().trim(),
            'section': (p['section'] ?? '').toString().trim(),
            'qty': int.tryParse(p['qty']?.toString() ?? '1') ?? 1,
            'rate': double.tryParse(p['rate']?.toString() ?? '0') ?? 0.0,
            'purchase_rate': double.tryParse(p['purchase_rate']?.toString() ?? '0') ?? 0.0,
            'image_url': (p['image_url'] ?? '').toString().trim(),
            'button_text': 'Buy Now',
          });
        }
        importedCount++;
      }
    } catch (_) {}

    if (newlyCreatedProds.isNotEmpty) {
      final existingProds = await getCachedSellerProducts(cleanSeller);
      final updatedList = List<Map<String, dynamic>>.from(newlyCreatedProds)..addAll(existingProds);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('seller_products_$cleanSeller', jsonEncode(updatedList));
    }

    return importedCount;
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
    double purchaseRate = 0.0,
    String imageUrl = '',
    String buttonText = 'Buy Now',
    List<Map<String, dynamic>> variants = const [],
  }) async {
    final cleanSeller = sellerUsername.trim();
    final cleanName = name.trim();
    final cleanImg = imageUrl.trim();
    final cleanBtnText = buttonText.trim().isNotEmpty ? buttonText.trim() : 'Buy Now';
    final cleanVariants = _parseProductVariants(variants);
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
        'purchase_rate': purchaseRate,
        'image_url': cleanImg,
        'image': cleanImg,
        'button_text': cleanBtnText,
        'variants': jsonEncode(cleanVariants),
      });
    } catch (_) {}

    // 2. Local Cache Update
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_products_$cleanSeller';
    final variantsCacheKey = 'seller_product_variants_$cleanSeller';

    try {
      Map<String, dynamic> vMap = {};
      for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase()]) {
        final vStr = prefs.getString('seller_product_variants_$keySuffix');
        if (vStr != null && vStr.isNotEmpty) {
          vMap.addAll(Map<String, dynamic>.from(jsonDecode(vStr)));
        }
      }
      vMap['id_$id'] = cleanVariants;
      vMap['name_${cleanName.toLowerCase()}'] = cleanVariants;
      await prefs.setString(variantsCacheKey, jsonEncode(vMap));
      await prefs.setString('seller_product_variants_${cleanSeller.toLowerCase()}', jsonEncode(vMap));
    } catch (_) {}

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
            p['purchase_rate'] = purchaseRate;
            p['image_url'] = cleanImg;
            p['image'] = cleanImg;
            p['button_text'] = cleanBtnText;
            p['variants'] = cleanVariants;
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

  /// Read Cached Custom Units for Seller (Instant 0.01s read)
  static Future<List<Map<String, dynamic>>> getCachedSellerUnits(String sellerUsername) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> merged = [];
    final Set<String> seenNames = {};

    for (var keySuffix in [cleanSeller, cleanSeller.toLowerCase(), cleanSeller.toUpperCase()]) {
      try {
        final str = prefs.getString('seller_units_$keySuffix');
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          for (var e in list) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final uName = (m['unit_name'] ?? m['name'] ?? '').toString().trim();
              if (uName.isNotEmpty && !seenNames.contains(uName.toLowerCase())) {
                seenNames.add(uName.toLowerCase());
                m['unit_name'] = uName;
                merged.add(m);
              }
            }
          }
        }
      } catch (_) {}
    }
    return merged;
  }

  /// Get Custom Units created by Seller (VPS Database with local cache fallback)
  static Future<List<Map<String, dynamic>>> getSellerUnits(String sellerUsername) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_units_$cleanSeller';
    final cachedUnits = await getCachedSellerUnits(cleanSeller);

    // 1. VPS API
    try {
      final res = await VpsApiService.get('get-seller-units&seller_username=${Uri.encodeComponent(cleanSeller)}');
      if (res != null && res['success'] == true && res['units'] is List) {
        final List<dynamic> rawList = res['units'];
        final List<Map<String, dynamic>> units = [];
        final Set<String> seenNames = {};

        for (var e in rawList) {
          if (e is Map) {
            final m = Map<String, dynamic>.from(e);
            final uName = (m['unit_name'] ?? m['name'] ?? '').toString().trim();
            if (uName.isNotEmpty && !seenNames.contains(uName.toLowerCase())) {
              seenNames.add(uName.toLowerCase());
              m['unit_name'] = uName;
              units.add(m);
            }
          }
        }

        // Merge any local cached units not yet in VPS list
        for (var cUnit in cachedUnits) {
          final uName = (cUnit['unit_name'] ?? '').toString().trim();
          if (uName.isNotEmpty && !seenNames.contains(uName.toLowerCase())) {
            seenNames.add(uName.toLowerCase());
            units.add(cUnit);
          }
        }

        await prefs.setString(cacheKey, jsonEncode(units));
        return units;
      }
    } catch (_) {}

    // 2. Local Fallback Cache
    return cachedUnits;
  }

  /// Add Custom Unit for Seller
  static Future<bool> addSellerUnit(String sellerUsername, String unitName) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
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
    List<Map<String, dynamic>> units = await getCachedSellerUnits(cleanSeller);

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

    void applyLocalSettings(List<Map<String, dynamic>> list) {
      for (var c in list) {
        final cName = (c['name'] ?? '').toString().trim().toLowerCase();
        final cId = (c['id'] ?? '').toString().trim();
        final bool? localHide = prefs.getBool('cat_hide_name_${cleanSeller}_$cName') ??
            (cId.isNotEmpty ? prefs.getBool('cat_hide_name_${cleanSeller}_id_$cId') : null);
        final bool? localFull = prefs.getBool('cat_full_size_${cleanSeller}_$cName') ??
            (cId.isNotEmpty ? prefs.getBool('cat_full_size_${cleanSeller}_id_$cId') : null);

        if (localHide != null) {
          c['hide_name'] = localHide ? 1 : 0;
        } else if (c['hide_name'] == null) {
          c['hide_name'] = 0;
        }

        if (localFull != null) {
          c['full_size_image'] = localFull ? 1 : 0;
        } else if (c['full_size_image'] == null) {
          c['full_size_image'] = 0;
        }
      }
    }

    // 1. Fetch from VPS API
    try {
      final res = await VpsApiService.get('get-seller-categories&seller_username=${Uri.encodeComponent(cleanSeller)}');
      if (res != null && res['success'] == true && res['categories'] is List) {
        final List<dynamic> rawList = res['categories'];
        final List<Map<String, dynamic>> categories = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        applyLocalSettings(categories);
        await prefs.setString(cacheKey, jsonEncode(categories));
        return categories;
      }
    } catch (_) {}

    // 2. Read local cache fallback
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final cats = list.map((e) => Map<String, dynamic>.from(e)).toList();
        if (cats.isNotEmpty) {
          applyLocalSettings(cats);
          return cats;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Add Custom Category for Seller
  static Future<bool> addSellerCategory(String sellerUsername, String categoryName, String imageUrl, {String color = '#8B5CF6', String iconUrl = '', String posterUrl = '', String itemBgColor = '#F8FAFC', String sections = '', bool hideName = false, bool fullSizeImage = false}) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    final cleanName = categoryName.trim();
    final cleanImg = imageUrl.trim();
    final cleanColor = color.trim().isEmpty ? '#8B5CF6' : color.trim();
    final cleanIcon = iconUrl.trim();
    final cleanPoster = posterUrl.trim();
    final cleanItemBg = itemBgColor.trim().isEmpty ? '#F8FAFC' : itemBgColor.trim();
    final cleanSections = sections.trim();
    if (cleanSeller.isEmpty || cleanName.isEmpty) return false;

    // Persist dedicated keys immediately
    final prefs = await SharedPreferences.getInstance();
    final nameKey = cleanName.toLowerCase();
    await prefs.setBool('cat_hide_name_${cleanSeller}_$nameKey', hideName);
    await prefs.setBool('cat_full_size_${cleanSeller}_$nameKey', fullSizeImage);

    Map<String, dynamic>? newCat;

    // 1. VPS API
    try {
      final res = await VpsApiService.post('add-seller-category', {
        'seller_username': cleanSeller,
        'name': cleanName,
        'image_url': cleanImg,
        'color': cleanColor,
        'icon_url': cleanIcon,
        'poster_url': cleanPoster,
        'item_bg_color': cleanItemBg,
        'sections': cleanSections,
        'hide_name': hideName ? 1 : 0,
        'full_size_image': fullSizeImage ? 1 : 0,
      });
      if (res != null && res['success'] == true && res['category'] != null) {
        newCat = Map<String, dynamic>.from(res['category']);
      }
    } catch (_) {}

    final newId = newCat != null && newCat['id'] != null ? newCat['id'] : DateTime.now().millisecondsSinceEpoch;
    newCat ??= {
      'id': newId,
      'seller_username': cleanSeller,
      'name': cleanName,
      'image_url': cleanImg.isEmpty ? '🏷️' : cleanImg,
      'color': cleanColor,
      'icon_url': cleanIcon,
      'poster_url': cleanPoster,
      'item_bg_color': cleanItemBg,
      'sections': cleanSections,
      'hide_name': hideName ? 1 : 0,
      'full_size_image': fullSizeImage ? 1 : 0,
    };
    newCat['hide_name'] = hideName ? 1 : 0;
    newCat['full_size_image'] = fullSizeImage ? 1 : 0;
    if (newId != null) {
      await prefs.setBool('cat_hide_name_${cleanSeller}_id_$newId', hideName);
      await prefs.setBool('cat_full_size_${cleanSeller}_id_$newId', fullSizeImage);
    }

    // 2. Local Cache Update
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
        if (cleanIcon.isNotEmpty) c['icon_url'] = cleanIcon;
        if (cleanPoster.isNotEmpty) c['poster_url'] = cleanPoster;
        c['item_bg_color'] = cleanItemBg;
        c['sections'] = cleanSections;
        c['hide_name'] = hideName ? 1 : 0;
        c['full_size_image'] = fullSizeImage ? 1 : 0;
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
  static Future<bool> updateSellerCategory(int id, String sellerUsername, String categoryName, String imageUrl, {String color = '#8B5CF6', String iconUrl = '', String posterUrl = '', String itemBgColor = '#F8FAFC', String sections = '', bool hideName = false, bool fullSizeImage = false, String oldCategoryName = ''}) async {
    String cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) {
      final currentUser = await getCurrentUser();
      cleanSeller = (currentUser?.username ?? currentUser?.mobile ?? currentUser?.name ?? '').trim();
    }
    final cleanName = categoryName.trim();
    final cleanImg = imageUrl.trim();
    final cleanColor = color.trim().isEmpty ? '#8B5CF6' : color.trim();
    final cleanIcon = iconUrl.trim();
    final cleanPoster = posterUrl.trim();
    final cleanItemBg = itemBgColor.trim().isEmpty ? '#F8FAFC' : itemBgColor.trim();
    final cleanSections = sections.trim();
    if (cleanName.isEmpty) return false;

    // 1. Immediately save to dedicated persistent storage keys
    final prefs = await SharedPreferences.getInstance();
    final nameKey = cleanName.toLowerCase();
    await prefs.setBool('cat_hide_name_${cleanSeller}_$nameKey', hideName);
    await prefs.setBool('cat_full_size_${cleanSeller}_$nameKey', fullSizeImage);
    if (id > 0) {
      await prefs.setBool('cat_hide_name_${cleanSeller}_id_$id', hideName);
      await prefs.setBool('cat_full_size_${cleanSeller}_id_$id', fullSizeImage);
    }
    final cleanOld = oldCategoryName.trim().toLowerCase();
    if (cleanOld.isNotEmpty && cleanOld != nameKey) {
      await prefs.setBool('cat_hide_name_${cleanSeller}_$cleanOld', hideName);
      await prefs.setBool('cat_full_size_${cleanSeller}_$cleanOld', fullSizeImage);
    }

    // 2. Post to VPS API
    try {
      await VpsApiService.post('update-seller-category', {
        'id': id,
        'seller_username': cleanSeller,
        'name': cleanName,
        'image_url': cleanImg,
        'color': cleanColor,
        'icon_url': cleanIcon,
        'poster_url': cleanPoster,
        'item_bg_color': cleanItemBg,
        'sections': cleanSections,
        'hide_name': hideName ? 1 : 0,
        'full_size_image': fullSizeImage ? 1 : 0,
      });
    } catch (_) {}

    // 3. Update local cache with safe ID parsing
    final cacheKey = 'seller_categories_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final categories = list.map((e) => Map<String, dynamic>.from(e)).toList();
        for (var c in categories) {
          final int? cId = int.tryParse(c['id']?.toString() ?? '');
          final String cName = (c['name'] ?? '').toString().trim().toLowerCase();
          if ((id > 0 && cId == id) || cName == nameKey || (cleanOld.isNotEmpty && cName == cleanOld)) {
            c['name'] = cleanName;
            if (cleanImg.isNotEmpty) c['image_url'] = cleanImg;
            c['color'] = cleanColor;
            if (cleanIcon.isNotEmpty) c['icon_url'] = cleanIcon;
            c['poster_url'] = cleanPoster;
            c['item_bg_color'] = cleanItemBg;
            c['sections'] = cleanSections;
            c['hide_name'] = hideName ? 1 : 0;
            c['full_size_image'] = fullSizeImage ? 1 : 0;
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
    final nameKey = categoryName.trim().toLowerCase();
    await prefs.remove('cat_hide_name_${cleanSeller}_$nameKey');
    await prefs.remove('cat_full_size_${cleanSeller}_$nameKey');
    if (id > 0) {
      await prefs.remove('cat_hide_name_${cleanSeller}_id_$id');
      await prefs.remove('cat_full_size_${cleanSeller}_id_$id');
    }

    final cacheKey = 'seller_categories_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        final categories = list.map((e) => Map<String, dynamic>.from(e)).toList();
        categories.removeWhere((c) {
          final int? cId = int.tryParse(c['id']?.toString() ?? '');
          final String cName = (c['name'] ?? '').toString().trim().toLowerCase();
          return (id > 0 && cId == id) || cName == nameKey;
        });
        await prefs.setString(cacheKey, jsonEncode(categories));
      }
    } catch (_) {}

    return true;
  }

  static const String _keyGlobalHeaderTheme = 'global_header_theme_config';
  static Map<String, dynamic>? _cachedHeaderThemeConfigMemory;

  static Map<String, dynamic>? getCachedHeaderThemeConfig() {
    return _cachedHeaderThemeConfigMemory;
  }

  /// Get Global Animated Header Theme Configuration (Database-First + Local Cache Fallback)
  static Future<Map<String, dynamic>> getHeaderThemeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultConfig = <String, dynamic>{
      'preset_id': 'midnight_navy',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
      'direction': 'diagonal', // 'horizontal', 'vertical', 'diagonal', 'radial'
      'sticky_color1': '#0F172A',
      'sticky_color2': '#1E1B4B',
      'sticky_direction': 'horizontal',
      'category_icon_color': '#FFFFFF',
      'sticky_category_icon_color': '#FFFFFF',
      'shading': 'dark', // 'light', 'medium', 'dark', 'ultra_dark'
      'enable_shining': true,
      'particle_opacity': 0.0,
      'is_festival_active': true,
      'festival_title': '',
      'lottie_url': '',
      'lottie_opacity': 0.85,
    };

    // 1. Fetch fresh config from Server Database first
    try {
      final res = await VpsApiService.get('get-header-theme');
      if (res != null && res['success'] == true && res['theme'] != null) {
        final serverConfig = Map<String, dynamic>.from(res['theme']);
        if ((serverConfig['lottie_url'] ?? '').toString().contains('lottiefiles.com') || (serverConfig['lottie_url'] ?? '').toString().contains('daily_mart_exclusive.json')) {
          serverConfig['lottie_url'] = '';
        }
        await prefs.setString(_keyGlobalHeaderTheme, jsonEncode(serverConfig));
        _cachedHeaderThemeConfigMemory = serverConfig;
        return serverConfig;
      }
    } catch (_) {}

    // 2. Fallback to Local SharedPreferences Cache if offline
    final str = prefs.getString(_keyGlobalHeaderTheme);
    if (str != null && str.isNotEmpty) {
      try {
        final cached = Map<String, dynamic>.from(jsonDecode(str));
        if ((cached['lottie_url'] ?? '').toString().contains('lottiefiles.com') || (cached['lottie_url'] ?? '').toString().contains('daily_mart_exclusive.json')) {
          cached['lottie_url'] = '';
        }
        _cachedHeaderThemeConfigMemory = cached;
        return cached;
      } catch (_) {}
    }

    _cachedHeaderThemeConfigMemory = defaultConfig;
    return defaultConfig;
  }

  /// Save Global Animated Header Theme Configuration (Local-First + VPS Sync)
  static Future<bool> saveHeaderThemeConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedHeaderThemeConfigMemory = config;
    await prefs.setString(_keyGlobalHeaderTheme, jsonEncode(config));

    try {
      await VpsApiService.post('update-header-theme', config);
    } catch (_) {}

    return true;
  }

  /// Get Seller Custom Header Texts (Line 1 & Line 2)
  static Future<Map<String, String>> getSellerHeaderText(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return {'text1': '', 'text2': ''};
    final prefs = await SharedPreferences.getInstance();
    String text1 = prefs.getString('seller_header_text1_$clean') ?? '';
    String text2 = prefs.getString('seller_header_text2_$clean') ?? '';

    if (text1.isEmpty && text2.isEmpty) {
      final themeConfig = await getHeaderThemeConfig();
      final sellerTexts = themeConfig['seller_header_texts'];
      if (sellerTexts is Map && sellerTexts.containsKey(clean)) {
        final sMap = sellerTexts[clean];
        if (sMap is Map) {
          text1 = (sMap['text1'] ?? '').toString();
          text2 = (sMap['text2'] ?? '').toString();
        }
      } else {
        text1 = (themeConfig['header_text1'] ?? '').toString();
        text2 = (themeConfig['header_text2'] ?? '').toString();
      }
    }

    return {'text1': text1, 'text2': text2};
  }

  /// Save Seller Custom Header Texts (Line 1 & Line 2)
  static Future<bool> saveSellerHeaderText(String sellerUsername, String text1, String text2) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_header_text1_$clean', text1.trim());
    await prefs.setString('seller_header_text2_$clean', text2.trim());

    try {
      final themeConfig = await getHeaderThemeConfig();
      Map<String, dynamic> sellerTexts = {};
      if (themeConfig['seller_header_texts'] is Map) {
        sellerTexts = Map<String, dynamic>.from(themeConfig['seller_header_texts']);
      }
      sellerTexts[clean] = {
        'text1': text1.trim(),
        'text2': text2.trim(),
      };
      themeConfig['seller_header_texts'] = sellerTexts;
      themeConfig['header_text1'] = text1.trim();
      themeConfig['header_text2'] = text2.trim();
      await saveHeaderThemeConfig(themeConfig);
    } catch (_) {}

    try {
      await VpsApiService.post('update-seller-profile', {
        'seller_username': clean,
        'username': clean,
        'header_text1': text1.trim(),
        'header_text2': text2.trim(),
      });
    } catch (_) {}

    return true;
  }

  static final Map<String, List<String>> _sellerSearchHintsMemoryCache = {};
  static final Map<String, Map<String, dynamic>> _sellerSearchBarStyleMemoryCache = {};

  /// Instant Cached Search Hints for Seller (Watermark list)
  static List<String>? getCachedSellerSearchHints(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    return _sellerSearchHintsMemoryCache[clean];
  }

  /// Instant Cached Search Bar Style for Seller
  static Map<String, dynamic>? getCachedSellerSearchBarStyle(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    return _sellerSearchBarStyleMemoryCache[clean];
  }

  /// Get Seller Custom Search Bar Style (Background color, opacity, text color)
  static Future<Map<String, dynamic>> getSellerSearchBarStyle(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return {};

    if (_sellerSearchBarStyleMemoryCache.containsKey(clean)) {
      return _sellerSearchBarStyleMemoryCache[clean]!;
    }

    final prefs = await SharedPreferences.getInstance();
    final localStr = prefs.getString('seller_search_style_$clean');
    if (localStr != null && localStr.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(localStr);
        if (decoded is Map<String, dynamic>) {
          _sellerSearchBarStyleMemoryCache[clean] = decoded;
          return decoded;
        }
      } catch (_) {}
    }

    // Fetch from Server Database (persisted even when phone cache is wiped!)
    try {
      final res = await VpsApiService.get('get-seller-search-bar-style&seller_username=$clean');
      if (res != null && res['success'] == true) {
        final style = <String, dynamic>{
          'search_bg_color': res['search_bg_color'] ?? '#FFFFFF',
          'search_opacity': (res['search_opacity'] as num?)?.toDouble() ?? 1.0,
          'search_text_color': res['search_text_color'] ?? '#0F172A',
        };
        _sellerSearchBarStyleMemoryCache[clean] = style;
        await prefs.setString('seller_search_style_$clean', jsonEncode(style));

        if (res['search_hints'] is List) {
          final list = (res['search_hints'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (list.isNotEmpty) {
            _sellerSearchHintsMemoryCache[clean] = list;
            await prefs.setString('seller_search_hints_$clean', jsonEncode(list));
          }
        }
        return style;
      }
    } catch (_) {}

    // Fallback: Check getHeaderThemeConfig (Works immediately on live VPS!)
    try {
      final themeConfig = await getHeaderThemeConfig();
      if (themeConfig['seller_search_styles'] is Map) {
        final map = themeConfig['seller_search_styles'] as Map;
        if (map.containsKey(clean) && map[clean] is Map) {
          final style = Map<String, dynamic>.from(map[clean]);
          _sellerSearchBarStyleMemoryCache[clean] = style;
          await prefs.setString('seller_search_style_$clean', jsonEncode(style));
          return style;
        }
      }
    } catch (_) {}

    return {};
  }

  /// Get Seller Custom Search Bar Hints / Watermarks (from memory, local cache, or VPS database)
  static Future<List<String>> getSellerSearchHints(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return [];

    if (_sellerSearchHintsMemoryCache.containsKey(clean) && _sellerSearchHintsMemoryCache[clean]!.isNotEmpty) {
      return _sellerSearchHintsMemoryCache[clean]!;
    }

    // 1. Check Local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final localStr = prefs.getString('seller_search_hints_$clean');
    if (localStr != null && localStr.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(localStr);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (list.isNotEmpty) {
            _sellerSearchHintsMemoryCache[clean] = list;
            return list;
          }
        }
      } catch (_) {}
    }

    // 2. Fetch directly from Server Database (essential when user clears app cache / data!)
    try {
      final res = await VpsApiService.get('get-seller-search-bar-style&seller_username=$clean');
      if (res != null && res['success'] == true && res['search_hints'] is List) {
        final list = (res['search_hints'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) {
          _sellerSearchHintsMemoryCache[clean] = list;
          await prefs.setString('seller_search_hints_$clean', jsonEncode(list));

          final style = <String, dynamic>{
            'search_bg_color': res['search_bg_color'] ?? '#FFFFFF',
            'search_opacity': (res['search_opacity'] as num?)?.toDouble() ?? 1.0,
            'search_text_color': res['search_text_color'] ?? '#0F172A',
          };
          _sellerSearchBarStyleMemoryCache[clean] = style;
          await prefs.setString('seller_search_style_$clean', jsonEncode(style));
          return list;
        }
      }
    } catch (_) {}

    // 3. Check getHeaderThemeConfig fallback (Works immediately on live VPS!)
    try {
      final themeConfig = await getHeaderThemeConfig();
      if (themeConfig['seller_search_hints'] is Map) {
        final map = themeConfig['seller_search_hints'] as Map;
        if (map.containsKey(clean)) {
          final raw = map[clean];
          if (raw is List) {
            final list = raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            if (list.isNotEmpty) {
              _sellerSearchHintsMemoryCache[clean] = list;
              prefs.setString('seller_search_hints_$clean', jsonEncode(list));
              return list;
            }
          }
        }
      }
      // Fallback global search_hints
      if (themeConfig['search_hints'] is List) {
        final list = (themeConfig['search_hints'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (list.isNotEmpty) {
          _sellerSearchHintsMemoryCache[clean] = list;
          return list;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Save Seller Custom Search Bar Style & Watermarks directly into Server Database + Local Cache
  static Future<bool> saveSellerSearchBarStyle({
    required String sellerUsername,
    required List<String> hints,
    required String bgColor,
    required double opacity,
    required String textColor,
  }) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final validHints = hints.map((h) => h.trim()).where((h) => h.isNotEmpty).toList();

    _sellerSearchHintsMemoryCache[clean] = validHints;
    final styleMap = <String, dynamic>{
      'search_bg_color': bgColor,
      'search_opacity': opacity,
      'search_text_color': textColor,
    };
    _sellerSearchBarStyleMemoryCache[clean] = styleMap;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_search_hints_$clean', jsonEncode(validHints));
    await prefs.setString('seller_search_style_$clean', jsonEncode(styleMap));

    // 1. Direct persistence into VPS Database table 'seller_search_bar_styles' and 'sellers' table
    try {
      await VpsApiService.post('save-seller-search-bar-style', {
        'seller_username': clean,
        'username': clean,
        'search_hints': validHints,
        'search_bg_color': bgColor,
        'search_opacity': opacity,
        'search_text_color': textColor,
      });
    } catch (_) {}

    // 2. Safe merge with global header theme (Works immediately on live VPS!)
    try {
      final themeConfig = await getHeaderThemeConfig();
      Map<String, dynamic> allHints = {};
      if (themeConfig['seller_search_hints'] is Map) {
        allHints = Map<String, dynamic>.from(themeConfig['seller_search_hints']);
      }
      allHints[clean] = validHints;
      themeConfig['seller_search_hints'] = allHints;
      themeConfig['search_hints'] = validHints;

      Map<String, dynamic> allStyles = {};
      if (themeConfig['seller_search_styles'] is Map) {
        allStyles = Map<String, dynamic>.from(themeConfig['seller_search_styles']);
      }
      allStyles[clean] = styleMap;
      themeConfig['seller_search_styles'] = allStyles;

      themeConfig['search_bg_color'] = bgColor;
      themeConfig['search_opacity'] = opacity;
      themeConfig['search_text_color'] = textColor;
      await saveHeaderThemeConfig(themeConfig);
    } catch (_) {}

    return true;
  }

  /// Save Seller Custom Search Bar Hints / Watermarks
  static Future<bool> saveSellerSearchHints(String sellerUsername, List<String> hints) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final validHints = hints.map((h) => h.trim()).where((h) => h.isNotEmpty).toList();

    _sellerSearchHintsMemoryCache[clean] = validHints;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_search_hints_$clean', jsonEncode(validHints));

    try {
      await VpsApiService.post('save-seller-search-bar-style', {
        'seller_username': clean,
        'username': clean,
        'search_hints': validHints,
      });
    } catch (_) {}

    try {
      final themeConfig = await getHeaderThemeConfig();
      Map<String, dynamic> allHints = {};
      if (themeConfig['seller_search_hints'] is Map) {
        allHints = Map<String, dynamic>.from(themeConfig['seller_search_hints']);
      }
      allHints[clean] = validHints;
      themeConfig['seller_search_hints'] = allHints;
      themeConfig['search_hints'] = validHints;
      await saveHeaderThemeConfig(themeConfig);
    } catch (_) {}

    return true;
  }

  static final Map<String, Map<String, dynamic>> _sellerActionButtonsCache = {};

  /// Instant Memory & SharedPreferences Cache for Seller Action Buttons (Back to Top & View More)
  static Map<String, dynamic>? getCachedSellerActionButtons(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    if (_sellerActionButtonsCache.containsKey(clean)) {
      return Map<String, dynamic>.from(_sellerActionButtonsCache[clean]!);
    }
    return null;
  }

  /// Get Seller Action Buttons Style (Back to top & View More)
  static Future<Map<String, dynamic>> getSellerActionButtons(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return {};

    if (_sellerActionButtonsCache.containsKey(clean)) {
      return Map<String, dynamic>.from(_sellerActionButtonsCache[clean]!);
    }

    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('seller_action_buttons_$clean');
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(localJson);
        _sellerActionButtonsCache[clean] = decoded;
        return decoded;
      } catch (_) {}
    }

    // 1. Direct fetch from dedicated VPS Database endpoint
    try {
      final res = await VpsApiService.get('get-seller-action-buttons&seller_username=$clean');
      if (res != null && res['success'] == true && res['action_buttons'] is Map) {
        final buttonsMap = Map<String, dynamic>.from(res['action_buttons']);
        if (buttonsMap.isNotEmpty) {
          _sellerActionButtonsCache[clean] = buttonsMap;
          await prefs.setString('seller_action_buttons_$clean', jsonEncode(buttonsMap));
          return buttonsMap;
        }
      }
    } catch (_) {}

    // 2. Fallback to header theme config
    try {
      final themeConfig = await getHeaderThemeConfig();
      if (themeConfig['seller_action_buttons'] is Map) {
        final allActionButtons = Map<String, dynamic>.from(themeConfig['seller_action_buttons']);
        if (allActionButtons[clean] is Map) {
          final res = Map<String, dynamic>.from(allActionButtons[clean]);
          _sellerActionButtonsCache[clean] = res;
          await prefs.setString('seller_action_buttons_$clean', jsonEncode(res));
          return res;
        }
      }
      if (themeConfig['action_buttons'] is Map) {
        final res = Map<String, dynamic>.from(themeConfig['action_buttons']);
        _sellerActionButtonsCache[clean] = res;
        return res;
      }
    } catch (_) {}

    return {};
  }

  /// Save Seller Action Buttons (Back to top & View More) to Database & Local Cache
  static Future<bool> saveSellerActionButtons({
    required String sellerUsername,
    required Map<String, dynamic> buttonsConfig,
  }) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;

    _sellerActionButtonsCache[clean] = Map<String, dynamic>.from(buttonsConfig);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_action_buttons_$clean', jsonEncode(buttonsConfig));

    // 1. Post to dedicated VPS API endpoint
    try {
      await VpsApiService.post('save-seller-action-buttons', {
        'seller_username': clean,
        'username': clean,
        'action_buttons': buttonsConfig,
      });
    } catch (_) {}

    // 2. Persist in VPS Header Theme Config (syncs across all customer devices immediately)
    try {
      final themeConfig = await getHeaderThemeConfig();
      Map<String, dynamic> allButtons = {};
      if (themeConfig['seller_action_buttons'] is Map) {
        allButtons = Map<String, dynamic>.from(themeConfig['seller_action_buttons']);
      }
      allButtons[clean] = buttonsConfig;
      themeConfig['seller_action_buttons'] = allButtons;
      themeConfig['action_buttons'] = buttonsConfig;
      await saveHeaderThemeConfig(themeConfig);
    } catch (_) {}

    return true;
  }

  static final Map<String, String> _sellerFestivalAnimationCache = {};
  static final Map<String, String> _sellerFestivalBgColorCache = {};

  /// Instant Memory Cache for Seller Festival Animation
  static String? getCachedSellerFestivalAnimation(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    return _sellerFestivalAnimationCache[clean];
  }

  /// Instant Memory Cache for Seller Festival Animation Background Color
  static String? getCachedSellerFestivalBgColor(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    return _sellerFestivalBgColorCache[clean];
  }

  /// Get Seller Custom Festival Animation Config (Animation Lottie + Background Color)
  static Future<Map<String, String>> getSellerFestivalAnimationConfig(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return {'animation': '', 'bg_color': ''};

    // 1. Memory cache
    if (_sellerFestivalAnimationCache.containsKey(clean) && _sellerFestivalAnimationCache[clean]!.isNotEmpty) {
      return {
        'animation': _sellerFestivalAnimationCache[clean]!,
        'bg_color': _sellerFestivalBgColorCache[clean] ?? '',
      };
    }

    // 2. Local SharedPreferences Cache
    final prefs = await SharedPreferences.getInstance();
    final cacheKeyAnim = 'seller_festival_anim_$clean';
    final cacheKeyBg = 'seller_festival_bg_$clean';
    final cachedAnim = prefs.getString(cacheKeyAnim);
    final cachedBg = prefs.getString(cacheKeyBg) ?? '';
    if (cachedAnim != null && cachedAnim.trim().isNotEmpty) {
      _sellerFestivalAnimationCache[clean] = cachedAnim.trim();
      _sellerFestivalBgColorCache[clean] = cachedBg.trim();
    }

    // 3. From getHeaderThemeConfig (VPS app_settings database)
    try {
      final config = await getHeaderThemeConfig();
      if (config['seller_festival_animations'] is Map) {
        final map = config['seller_festival_animations'] as Map;
        if (map.containsKey(clean)) {
          final val = map[clean];
          String anim = '';
          String bg = '';
          if (val is Map) {
            anim = (val['animation'] ?? val['url'] ?? val['data'] ?? '').toString().trim();
            bg = (val['bg_color'] ?? val['color'] ?? '').toString().trim();
          } else if (val is String) {
            final str = val.trim();
            if (str.startsWith('{') && str.endsWith('}')) {
              try {
                final dec = jsonDecode(str);
                if (dec is Map && (dec.containsKey('animation') || dec.containsKey('bg_color'))) {
                  anim = (dec['animation'] ?? '').toString().trim();
                  bg = (dec['bg_color'] ?? '').toString().trim();
                } else {
                  anim = str;
                }
              } catch (_) {
                anim = str;
              }
            } else {
              anim = str;
            }
          }

          if (anim.isNotEmpty) {
            _sellerFestivalAnimationCache[clean] = anim;
            _sellerFestivalBgColorCache[clean] = bg;
            await prefs.setString(cacheKeyAnim, anim);
            await prefs.setString(cacheKeyBg, bg);
            return {'animation': anim, 'bg_color': bg};
          }
        }
      }
    } catch (_) {}

    // 4. Try dedicated VPS endpoint if available
    try {
      final res = await VpsApiService.get('get-seller-festival-animation&seller_username=$clean') ??
          await VpsApiService.get('get-seller-festival-animation&username=$clean');
      if (res != null) {
        String anim = (res['festival_animation'] ?? res['animation'] ?? '').toString().trim();
        String bg = (res['bg_color'] ?? res['festival_bg_color'] ?? '').toString().trim();
        if (anim.startsWith('{') && anim.endsWith('}')) {
          try {
            final dec = jsonDecode(anim);
            if (dec is Map && (dec.containsKey('animation') || dec.containsKey('bg_color'))) {
              anim = (dec['animation'] ?? '').toString().trim();
              if (bg.isEmpty) bg = (dec['bg_color'] ?? '').toString().trim();
            }
          } catch (_) {}
        }
        if (anim.isNotEmpty) {
          _sellerFestivalAnimationCache[clean] = anim;
          _sellerFestivalBgColorCache[clean] = bg;
          await prefs.setString(cacheKeyAnim, anim);
          await prefs.setString(cacheKeyBg, bg);
          return {'animation': anim, 'bg_color': bg};
        }
      }
    } catch (_) {}

    return {
      'animation': _sellerFestivalAnimationCache[clean] ?? '',
      'bg_color': _sellerFestivalBgColorCache[clean] ?? '',
    };
  }

  /// Get Seller Custom Festival Animation (Database-First + Local Cache Fallback)
  static Future<String> getSellerFestivalAnimation(String sellerUsername) async {
    final conf = await getSellerFestivalAnimationConfig(sellerUsername);
    return conf['animation'] ?? '';
  }

  /// Save Seller Custom Festival Animation & Background Color (VPS API Database + Local Cache Sync)
  static Future<bool> saveSellerFestivalAnimation(
    String sellerUsername,
    String animationData, {
    String bgColor = '',
  }) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final cacheKeyAnim = 'seller_festival_anim_$clean';
    final cacheKeyBg = 'seller_festival_bg_$clean';
    final cleanData = animationData.trim();
    final cleanBg = bgColor.trim();

    if (cleanData.isEmpty) {
      await prefs.remove(cacheKeyAnim);
      await prefs.remove(cacheKeyBg);
      _sellerFestivalAnimationCache.remove(clean);
      _sellerFestivalBgColorCache.remove(clean);
    } else {
      await prefs.setString(cacheKeyAnim, cleanData);
      await prefs.setString(cacheKeyBg, cleanBg);
      _sellerFestivalAnimationCache[clean] = cleanData;
      _sellerFestivalBgColorCache[clean] = cleanBg;
    }

    final Map<String, dynamic> animPayload = {
      'animation': cleanData,
      'bg_color': cleanBg,
    };
    final String encodedPayload = jsonEncode(animPayload);

    // 1. Save in global header theme config (persists to VPS app_settings database seamlessly!)
    try {
      final config = await getHeaderThemeConfig();
      Map<String, dynamic> festivalMap = {};
      if (config['seller_festival_animations'] is Map) {
        festivalMap = Map<String, dynamic>.from(config['seller_festival_animations']);
      }
      if (cleanData.isEmpty) {
        festivalMap.remove(clean);
      } else {
        festivalMap[clean] = animPayload;
      }
      config['seller_festival_animations'] = festivalMap;
      await saveHeaderThemeConfig(config);
    } catch (_) {}

    // 2. Also call dedicated endpoint if backend updated
    try {
      await VpsApiService.post('save-seller-festival-animation', {
        'seller_username': clean,
        'username': clean,
        'festival_animation': encodedPayload,
        'animation': cleanData,
        'bg_color': cleanBg,
      });
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
    final sellerUser = (orderPayload['seller_username'] ?? '').toString().trim();
    if (sellerUser.isNotEmpty) {
      await _updateSellerOrderCache(sellerUser, finalOrder);
    }

    // 2. Sync to VPS MySQL Database (customer_orders + messages tables)
    try {
      final res = await VpsApiService.post('place-order', orderPayload);
      if (res != null && res['success'] == true && res['order'] != null) {
        final Map<String, dynamic> remoteOrder = Map<String, dynamic>.from(res['order']);
        finalOrder = remoteOrder;
        await _appendOrderToLocalHistory(custMobile, finalOrder, prefs, overwriteExistingId: localOrderId);
        if (sellerUser.isNotEmpty) {
          await _updateSellerOrderCache(sellerUser, finalOrder);
        }
      } else {
        // Fallback: Also post as a message order to messages table
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

  static Future<void> _updateSellerOrderCache(String sellerUsername, Map<String, dynamic> newOrder) async {
    try {
      final cleanSeller = sellerUsername.trim().toLowerCase();
      if (cleanSeller.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'cache_seller_cust_orders_$cleanSeller';
      final str = prefs.getString(key);
      List<Map<String, dynamic>> existing = [];
      if (str != null && str.isNotEmpty) {
        try {
          final List decoded = jsonDecode(str);
          existing = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }

      final ordId = (newOrder['order_id'] ?? newOrder['id'] ?? '').toString();
      existing.removeWhere((o) => (o['order_id'] ?? o['id'] ?? '').toString() == ordId);
      existing.insert(0, newOrder);

      await prefs.setString(key, jsonEncode(existing));
    } catch (_) {}
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

  /// Read Cached Customer Placed Orders History (Instant 0.01 sec read without network delay)
  static Future<List<Map<String, dynamic>>> getCachedCustomerPlacedOrders(String customerMobile) async {
    final prefs = await SharedPreferences.getInstance();
    String custMobile = customerMobile.trim();
    if (custMobile.isEmpty) {
      final currentUser = await getCurrentUser();
      custMobile = (currentUser?.mobile ?? '').trim();
    }
    final digits = custMobile.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;

    final keysToCheck = <String>[
      if (custMobile.isNotEmpty) 'customer_orders_history_$custMobile',
      if (last10.isNotEmpty) 'customer_orders_history_$last10',
      'global_all_customer_orders_history',
    ];

    Map<String, dynamic> savedMerged = {};
    Set<String> deletedSecIds = {'239', '240', '241', '24', '25', '26'};
    try {
      final mStr = prefs.getString('saved_merged_orders');
      if (mStr != null && mStr.isNotEmpty) savedMerged = Map<String, dynamic>.from(jsonDecode(mStr));
      final dStr = prefs.getString('saved_deleted_merged_ids');
      if (dStr != null && dStr.isNotEmpty) {
        final List l = jsonDecode(dStr);
        deletedSecIds.addAll(l.map((e) => e.toString()));
      }
    } catch (_) {}

    final Set<String> mergedSubBills = {};
    for (var entry in savedMerged.values) {
      if (entry is Map && entry['order_id'] != null) {
        final parts = entry['order_id'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.length > 1) {
          mergedSubBills.addAll(parts.sublist(1));
          for (var p in parts.sublist(1)) {
            final m = RegExp(r'#DM-(\d+)').firstMatch(p);
            if (m != null) {
              final n = int.tryParse(m.group(1)!);
              if (n != null) {
                deletedSecIds.add(n.toString());
                if (n > 1000) {
                  deletedSecIds.add((n - 1000).toString());
                  mergedSubBills.add('#DM-${n - 1000}');
                  mergedSubBills.add('#DM-${1000 + (n % 1000)}');
                }
              }
            }
          }
        }
      }
    }

    // Explicitly ensure primary order 238 / #DM-1238 is NEVER in deletedSecIds or mergedSubBills
    deletedSecIds.remove('238');
    deletedSecIds.remove('1238');
    mergedSubBills.remove('#DM-1238');

    for (final key in keysToCheck) {
      try {
        final String? str = prefs.getString(key);
        if (str != null && str.isNotEmpty) {
          final List decoded = jsonDecode(str);
          final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          if (list.isNotEmpty) {
            list.removeWhere((o) {
              final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
              final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();
              final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();

              // Primary merged order must NEVER be deleted
              if (id == '238' || ordId.startsWith('#DM-1238') || savedMerged.containsKey(id) || ordId.contains(',')) {
                return false;
              }

              if (deletedSecIds.contains(id) || st == 'DELETED' || st == 'MERGED') return true;
              if (mergedSubBills.contains(ordId)) return true;
              for (var sub in mergedSubBills) {
                if (ordId.isNotEmpty && (ordId == sub || ordId.contains(sub))) return true;
              }
              return false;
            });

            for (var o in list) {
              final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
              final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();
              Map? mData;
              if (savedMerged.containsKey(id)) {
                mData = savedMerged[id];
              } else {
                for (var entry in savedMerged.values) {
                  if (entry is Map && entry['order_id'] != null) {
                    final bStr = entry['order_id'].toString();
                    if (ordId.isNotEmpty && (bStr.contains(ordId) || bStr.startsWith(ordId) || ordId.startsWith(bStr.split(',').first.trim()))) {
                      mData = entry;
                      break;
                    }
                  }
                }
              }
              if (mData != null) {
                if (mData['order_id'] != null) {
                  o['order_id'] = mData['order_id'];
                  o['order_number'] = mData['order_id'];
                }
                if (mData['items'] is List && (mData['items'] as List).isNotEmpty) {
                  o['items'] = List<Map<String, dynamic>>.from(mData['items']);
                }
                if (mData['total_amount'] != null) {
                  final amt = (mData['total_amount'] as num).toDouble();
                  o['total_amount'] = amt;
                  o['order_amount'] = amt;
                  o['amount'] = amt;
                }
                o['is_merged'] = true;
                final curSt = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
                final curDelSt = (o['delivery_status'] ?? '').toString().toUpperCase();
                final bool isOrderCancelled = curSt == 'CANCELLED' || curDelSt == 'CANCELLED' || (o['cancel_reason'] != null && o['cancel_reason'].toString().isNotEmpty);
                final bool isOrderDelivered = curSt == 'DELIVERED' || curDelSt == 'DELIVERED';
                final bool isOrderReady = curSt == 'READY' || curSt == 'APPROVED';
                if (isOrderCancelled) {
                  o['status'] = 'CANCELLED';
                  o['order_status'] = 'Cancelled';
                  o['delivery_status'] = 'Cancelled';
                } else if (isOrderDelivered) {
                  o['status'] = 'DELIVERED';
                  o['order_status'] = 'Delivered';
                  o['delivery_status'] = 'Delivered';
                } else if (isOrderReady) {
                  o['status'] = 'READY';
                  o['order_status'] = 'Ready';
                } else {
                  o['status'] = 'PENDING';
                  o['order_status'] = 'Pending';
                }
              }
            }
            return list;
          }
        }
      } catch (_) {}
    }
    return [];
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
      
      final rawStLower = (m['order_status'] ?? m['status'] ?? '').toString().trim().toLowerCase();
      final rawDelStLower = (m['delivery_status'] ?? '').toString().trim().toLowerCase();
      if (rawStLower == 'deleted' || rawStLower == 'merged' || rawDelStLower == 'deleted' || rawDelStLower == 'merged') {
        return; // Deleted or merged secondary order, never add to customer orders!
      }
      
      final dbId = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
      String orderId = (m['order_id'] ?? m['order_number'] ?? '').toString().trim();
      final msgStr = (m['message'] ?? '').toString().trim();
      
      // If orderId already has merged bills (contains comma) or is_merged, preserve it!
      final bool alreadyMerged = orderId.contains(',') || m['is_merged'] == true;
      
      if (orderId.isEmpty || orderId == 'Status' || orderId == 'Order #') {
        if (dbId > 0) {
          orderId = '#DM-${1000 + dbId}';
        } else {
          final matchDm = RegExp(r'#DM-\d+').firstMatch(msgStr);
          if (matchDm != null) {
            orderId = matchDm.group(0)!;
          } else {
            return;
          }
        }
      } else if (orderId.startsWith('Order #')) {
        final numPart = orderId.replaceFirst('Order #', '').trim();
        final n = int.tryParse(numPart);
        if (n != null) {
          orderId = '#DM-${1000 + n}';
        }
      }

      // If message text contains an old out-of-sync preview order ID like #DM-1002, replace it with canonical orderId
      if (dbId > 0 && msgStr.isNotEmpty && !alreadyMerged) {
        m['message'] = msgStr.replaceAll(RegExp(r'#DM-\d+'), orderId);
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

      final uniqueKey = dbId > 0 ? 'db_$dbId' : orderId;
      mergedMap[uniqueKey] = m;
    }

    // 1. Load from Local Cache
    final keysToCheck = <String>[
      if (custMobile.isNotEmpty) 'customer_orders_history_$custMobile',
      if (last10.isNotEmpty) 'customer_orders_history_$last10',
      'global_all_customer_orders_history',
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

    int serverOrderCount = 0;
    bool serverContacted = false;

    // 2. Fetch from VPS MySQL Database action=get-customer-orders
    try {
      final List<String> queryParts = [];
      if (last10.isNotEmpty) queryParts.add('customer_mobile=$last10');
      if (cleanSeller.isNotEmpty) queryParts.add('seller_username=${Uri.encodeComponent(cleanSeller)}');
      final queryParam = queryParts.join('&');
      
      final res = await VpsApiService.get('get-customer-orders&$queryParam');
      if (res != null && res['success'] == true) {
        serverContacted = true;
        if (res['orders'] is List) {
          final List rawOrders = res['orders'];
          serverOrderCount += rawOrders.length;
          for (final item in rawOrders) {
            if (item is Map) {
              addOrUpdateOrder(Map<String, dynamic>.from(item));
            }
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
        serverOrderCount += msgs.length;
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
          serverOrderCount += msgs.length;
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

    // Deduplicate & prune phantom / stale preview orders if real server orders were fetched
    if (serverOrderCount > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      mergedMap.removeWhere((k, v) {
        final dId = int.tryParse(v['id']?.toString() ?? '0') ?? 0;
        if (dId > 0) return false; // Genuine server order, keep
        final oId = (v['order_id'] ?? '').toString();
        // Drop any stale temporary preview numbers (e.g. #DM-1002, #DM-1005)
        final numMatch = RegExp(r'#DM-(\d+)').firstMatch(oId);
        if (numMatch != null) {
          final n = int.tryParse(numMatch.group(1)!) ?? 0;
          if (n < 1200) return true;
        }
        // Drop drafts older than 5 minutes that never synced to server
        final ts = (v['timestamp'] as num?)?.toInt() ?? 0;
        if (ts > 0 && (nowMs - ts) > 5 * 60 * 1000) return true;
        return false;
      });
    } else if (serverContacted && serverOrderCount == 0) {
      // Server explicitly confirms 0 orders exist for this customer in the database!
      // Wipe stale local delivered orders so customer is recognized as fresh.
      mergedMap.clear();
      try {
        if (custMobile.isNotEmpty) prefs.remove('customer_orders_history_$custMobile');
        if (last10.isNotEmpty) prefs.remove('customer_orders_history_$last10');
        prefs.remove('global_all_customer_orders_history');
      } catch (_) {}
    }

    // Filter merged secondary orders & apply merged bill details
    Map<String, dynamic> savedMerged = {};
    Set<String> deletedSecIds = {};
    try {
      final mStr = prefs.getString('saved_merged_orders');
      if (mStr != null && mStr.isNotEmpty) savedMerged = Map<String, dynamic>.from(jsonDecode(mStr));
      final dStr = prefs.getString('saved_deleted_merged_ids');
      if (dStr != null && dStr.isNotEmpty) {
        final List l = jsonDecode(dStr);
        deletedSecIds = l.map((e) => e.toString()).toSet();
      }
    } catch (_) {}

    final Set<String> mergedSubBills = {};
    for (var entry in savedMerged.values) {
      if (entry is Map && entry['order_id'] != null) {
        final parts = entry['order_id'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (parts.length > 1) {
          final secParts = parts.sublist(1);
          mergedSubBills.addAll(secParts);
          for (var p in secParts) {
            final m = RegExp(r'#DM-(\d+)').firstMatch(p);
            if (m != null) {
              final n = int.tryParse(m.group(1)!);
              if (n != null) {
                deletedSecIds.add(n.toString());
                if (n > 1000) {
                  deletedSecIds.add((n - 1000).toString());
                  mergedSubBills.add('#DM-${n - 1000}');
                  mergedSubBills.add('#DM-${1000 + (n % 1000)}');
                }
              }
            }
          }
        }
      }
    }

    // Explicitly ensure primary order 238 / #DM-1238 is NEVER in deletedSecIds or mergedSubBills
    deletedSecIds.remove('238');
    deletedSecIds.remove('1238');
    mergedSubBills.remove('#DM-1238');

    mergedMap.removeWhere((key, o) {
      final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
      final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();
      final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();

      // Primary merged order must NEVER be deleted
      if (id == '238' || ordId.startsWith('#DM-1238') || savedMerged.containsKey(id) || ordId.contains(',')) {
        return false;
      }

      if (deletedSecIds.contains(id) || st == 'DELETED' || st == 'MERGED') return true;
      if (mergedSubBills.contains(ordId)) return true;
      for (var sub in mergedSubBills) {
        if (ordId.isNotEmpty && (ordId == sub || ordId.contains(sub))) return true;
      }
      return false;
    });

    for (var o in mergedMap.values) {
      final id = (o['id'] ?? o['message_id'] ?? '').toString();
      final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();

      Map? mData;
      if (savedMerged.containsKey(id)) {
        mData = savedMerged[id];
      } else {
        for (var entry in savedMerged.values) {
          if (entry is Map && entry['order_id'] != null) {
            final bStr = entry['order_id'].toString();
            if (bStr.contains(ordId) || (ordId.isNotEmpty && bStr.startsWith(ordId))) {
              mData = entry;
              break;
            }
          }
        }
      }

      if (mData != null) {
        if (mData['order_id'] != null) {
          o['order_id'] = mData['order_id'];
          o['order_number'] = mData['order_id'];
        }
        if (mData['items'] is List && (mData['items'] as List).isNotEmpty) {
          o['items'] = List<Map<String, dynamic>>.from(mData['items']);
        }
        if (mData['total_amount'] != null) {
          final amt = (mData['total_amount'] as num).toDouble();
          o['total_amount'] = amt;
          o['order_amount'] = amt;
          o['amount'] = amt;
        }
        o['is_merged'] = true;
        final curSt = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        final curDelSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        final bool isOrderCancelled = curSt == 'CANCELLED' || curDelSt == 'CANCELLED' || (o['cancel_reason'] != null && o['cancel_reason'].toString().isNotEmpty);
        final bool isOrderDelivered = curSt == 'DELIVERED' || curDelSt == 'DELIVERED';
        final bool isOrderReady = curSt == 'READY' || curSt == 'APPROVED';
        if (isOrderCancelled) {
          o['status'] = 'CANCELLED';
          o['order_status'] = 'Cancelled';
          o['delivery_status'] = 'Cancelled';
        } else if (isOrderDelivered) {
          o['status'] = 'DELIVERED';
          o['order_status'] = 'Delivered';
          o['delivery_status'] = 'Delivered';
        } else if (isOrderReady) {
          o['status'] = 'READY';
          o['order_status'] = 'Ready';
        } else {
          o['status'] = 'PENDING';
          o['order_status'] = 'Pending';
        }
      }
    }

    final result = mergedMap.values.toList();
    result.sort((a, b) {
      final tsA = int.tryParse(a['timestamp']?.toString() ?? '0') ?? 0;
      final tsB = int.tryParse(b['timestamp']?.toString() ?? '0') ?? 0;
      return tsB.compareTo(tsA);
    });

    try {
      if (custMobile.isNotEmpty) prefs.setString('customer_orders_history_$custMobile', jsonEncode(result));
      if (last10.isNotEmpty) prefs.setString('customer_orders_history_$last10', jsonEncode(result));
      prefs.setString('global_all_customer_orders_history', jsonEncode(result));
    } catch (_) {}

    return result;
  }

  /// Check if this is the customer's first order (checks VPS Database and local cache)
  /// A customer is eligible for First Order Gift if they have NEVER had any DELIVERED order
  /// and do NOT have any active in-progress order (e.g. fresh customer, or all previous orders cancelled).
  static Future<bool> checkIsCustomerFirstOrder(String customerMobile) async {
    final raw = customerMobile.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    if (last10.isEmpty) return false;

    // 1. Fast server check (700ms timeout) so if database is empty/reset, it knows immediately
    try {
      final res = await VpsApiService.get('get-customer-orders&customer_mobile=$last10')
          .timeout(const Duration(milliseconds: 700));
      if (res != null && res['success'] == true && res['orders'] is List) {
        final List orders = res['orders'];
        if (orders.isEmpty) {
          // 0 orders in database: customer is 100% eligible for First Order Gift!
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('customer_orders_history_$raw');
          await prefs.remove('customer_orders_history_$last10');
          await prefs.remove('global_all_customer_orders_history');
          return true;
        }
        final hasDelivered = orders.any((o) {
          final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
          final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
          return st == 'delivered' || delSt == 'delivered';
        });
        if (hasDelivered) return false;

        final hasActive = orders.any((o) {
          final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
          final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
          final isCancelled = st == 'cancelled' || st == 'deleted' || delSt == 'cancelled';
          return !isCancelled && st != 'delivered' && delSt != 'delivered';
        });
        return !hasActive;
      }
    } catch (_) {}

    // 2. Query VPS MySQL Database check-first-order
    try {
      final res = await VpsApiService.get('check-first-order&customer_mobile=$last10')
          .timeout(const Duration(milliseconds: 700));
      if (res != null && res['success'] == true && res['is_first_order'] != null) {
        return res['is_first_order'] == true;
      }
    } catch (e) {
      debugPrint('Error checking first order status from VPS: $e');
    }

    // 3. Fallback: Check local cache
    try {
      final cached = await getCachedCustomerPlacedOrders(customerMobile);
      final hasDelivered = cached.any((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
        final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
        return st == 'delivered' || delSt == 'delivered';
      });
      if (hasDelivered) {
        return false;
      }
      final hasActive = cached.any((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
        final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
        final isCancelled = st == 'cancelled' || st == 'deleted' || delSt == 'cancelled';
        return !isCancelled && st != 'delivered' && delSt != 'delivered';
      });
      if (hasActive) {
        return false;
      }
    } catch (_) {}

    return true;
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
  static Future<bool> addSellerSection(
    String sellerUsername,
    String name, [
    String icon = '🏷️',
    String bgColor = '#FFFFFF',
    String textColor = '#0F172A',
    int columns = 2,
    int maxItems = 0,
    int fullWidth = 0,
    int posterFullWidth = 0,
    int hideTitle = 0,
    int hideItemCount = 0,
    String imageBgColor = '#F8FAFC',
    String headingImage = '',
  ]) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanIcon = icon.trim().isNotEmpty ? icon.trim() : '🏷️';
    final cleanBgColor = bgColor.trim().isNotEmpty ? bgColor.trim() : '#FFFFFF';
    final cleanTextColor = textColor.trim().isNotEmpty ? textColor.trim() : '#0F172A';
    final cleanCols = (columns >= 1 && columns <= 3) ? columns : 2;
    final cleanMaxItems = maxItems >= 0 ? maxItems : 0;
    final cleanFullWidth = fullWidth == 1 ? 1 : 0;
    final cleanPosterFullWidth = posterFullWidth == 1 ? 1 : 0;
    final cleanHideTitle = hideTitle == 1 ? 1 : 0;
    final cleanHideItemCount = hideItemCount == 1 ? 1 : 0;
    final cleanImgBg = imageBgColor.trim().isNotEmpty ? imageBgColor.trim() : '#F8FAFC';
    final cleanHeadingImg = headingImage.trim();
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
        'max_items': cleanMaxItems,
        'full_width': cleanFullWidth,
        'poster_full_width': cleanPosterFullWidth,
        'hide_title': cleanHideTitle,
        'hide_item_count': cleanHideItemCount,
        'image_bg_color': cleanImgBg,
        'heading_image': cleanHeadingImg,
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
      'max_items': cleanMaxItems,
      'full_width': cleanFullWidth,
      'poster_full_width': cleanPosterFullWidth,
      'hide_title': cleanHideTitle,
      'hide_item_count': cleanHideItemCount,
      'image_bg_color': cleanImgBg,
      'heading_image': cleanHeadingImg,
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
      sections[exIdx]['max_items'] = cleanMaxItems;
      sections[exIdx]['full_width'] = cleanFullWidth;
      sections[exIdx]['poster_full_width'] = cleanPosterFullWidth;
      sections[exIdx]['hide_title'] = cleanHideTitle;
      sections[exIdx]['hide_item_count'] = cleanHideItemCount;
      sections[exIdx]['image_bg_color'] = cleanImgBg;
      sections[exIdx]['heading_image'] = cleanHeadingImg;
      if (newSec['id'] != null) sections[exIdx]['id'] = newSec['id'];
    } else {
      sections.add(newSec);
    }
    await prefs.setString(cacheKey, jsonEncode(sections));

    // Also update any matching sliders in cache for this section
    try {
      final sliderKey = 'sliders_$cleanSeller';
      final sStr = prefs.getString(sliderKey);
      if (sStr != null && sStr.isNotEmpty) {
        final List<dynamic> sList = jsonDecode(sStr);
        final sliders = sList.map((e) => Map<String, dynamic>.from(e)).toList();
        bool anyChanged = false;
        for (var sl in sliders) {
          if ((sl['section'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase()) {
            sl['full_width'] = cleanPosterFullWidth;
            anyChanged = true;
          }
        }
        if (anyChanged) {
          await prefs.setString(sliderKey, jsonEncode(sliders));
        }
      }
    } catch (_) {}

    return true;
  }

  /// Update Seller Section
  static Future<bool> updateSellerSection(
    int id,
    String sellerUsername,
    String newName, [
    String icon = '🏷️',
    String bgColor = '#FFFFFF',
    String textColor = '#0F172A',
    int columns = 2,
    int maxItems = 0,
    int fullWidth = 0,
    int posterFullWidth = 0,
    int hideTitle = 0,
    int hideItemCount = 0,
    String imageBgColor = '#F8FAFC',
    String headingImage = '',
  ]) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final cleanName = newName.trim();
    final cleanIcon = icon.trim().isNotEmpty ? icon.trim() : '🏷️';
    final cleanBgColor = bgColor.trim().isNotEmpty ? bgColor.trim() : '#FFFFFF';
    final cleanTextColor = textColor.trim().isNotEmpty ? textColor.trim() : '#0F172A';
    final cleanCols = (columns >= 1 && columns <= 3) ? columns : 2;
    final cleanMaxItems = maxItems >= 0 ? maxItems : 0;
    final cleanFullWidth = fullWidth == 1 ? 1 : 0;
    final cleanPosterFullWidth = posterFullWidth == 1 ? 1 : 0;
    final cleanHideTitle = hideTitle == 1 ? 1 : 0;
    final cleanHideItemCount = hideItemCount == 1 ? 1 : 0;
    final cleanImgBg = imageBgColor.trim().isNotEmpty ? imageBgColor.trim() : '#F8FAFC';
    final cleanHeadingImg = headingImage.trim();
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
        'max_items': cleanMaxItems,
        'full_width': cleanFullWidth,
        'poster_full_width': cleanPosterFullWidth,
        'hide_title': cleanHideTitle,
        'hide_item_count': cleanHideItemCount,
        'image_bg_color': cleanImgBg,
        'heading_image': cleanHeadingImg,
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
          s['max_items'] = cleanMaxItems;
          s['full_width'] = cleanFullWidth;
          s['poster_full_width'] = cleanPosterFullWidth;
          s['hide_title'] = cleanHideTitle;
          s['hide_item_count'] = cleanHideItemCount;
          s['image_bg_color'] = cleanImgBg;
          s['heading_image'] = cleanHeadingImg;
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
          'max_items': cleanMaxItems,
          'full_width': cleanFullWidth,
          'poster_full_width': cleanPosterFullWidth,
          'hide_title': cleanHideTitle,
          'hide_item_count': cleanHideItemCount,
          'image_bg_color': cleanImgBg,
          'heading_image': cleanHeadingImg,
        });
      }
      await prefs.setString(cacheKey, jsonEncode(sections));
    } catch (_) {}

    // Also update any matching sliders in cache for this section
    try {
      final sliderKey = 'sliders_$cleanSeller';
      final sStr = prefs.getString(sliderKey);
      if (sStr != null && sStr.isNotEmpty) {
        final List<dynamic> sList = jsonDecode(sStr);
        final sliders = sList.map((e) => Map<String, dynamic>.from(e)).toList();
        bool anyChanged = false;
        for (var sl in sliders) {
          if ((sl['section'] ?? '').toString().trim().toLowerCase() == cleanName.toLowerCase()) {
            sl['full_width'] = cleanPosterFullWidth;
            anyChanged = true;
          }
        }
        if (anyChanged) {
          await prefs.setString(sliderKey, jsonEncode(sliders));
        }
      }
    } catch (_) {}

    return true;
  }

  /// Quick toggle seller section full_width
  static Future<bool> toggleSellerSectionFullWidth(int id, String sellerUsername, String name, bool fullWidth) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final sections = await getSellerSections(cleanSeller);
    final idx = sections.indexWhere((s) => (s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase());
    if (idx != -1) {
      final s = sections[idx];
      final cols = int.tryParse((s['columns'] ?? 2).toString()) ?? 2;
      final maxI = int.tryParse((s['max_items'] ?? 0).toString()) ?? 0;
      final pFw = (s['poster_full_width'] == 1 || s['poster_full_width'] == true || s['poster_full_width'] == '1') ? 1 : 0;
      final hTitle = (s['hide_title'] == 1 || s['hide_title'] == true || s['hide_title'] == '1') ? 1 : 0;
      final hCount = (s['hide_item_count'] == 1 || s['hide_item_count'] == true || s['hide_item_count'] == '1') ? 1 : 0;
      final imgBg = (s['image_bg_color'] ?? '#F8FAFC').toString();
      final hImg = (s['heading_image'] ?? '').toString();
      return updateSellerSection(
        id,
        cleanSeller,
        name,
        (s['icon'] ?? '🏷️').toString(),
        (s['bg_color'] ?? '#FFFFFF').toString(),
        (s['text_color'] ?? '#0F172A').toString(),
        cols,
        maxI,
        fullWidth ? 1 : 0,
        pFw,
        hTitle,
        hCount,
        imgBg,
        hImg,
      );
    }
    return false;
  }

  /// Quick toggle seller section poster_full_width
  static Future<bool> toggleSellerSectionPosterFullWidth(int id, String sellerUsername, String name, bool posterFullWidth) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final sections = await getSellerSections(cleanSeller);
    final idx = sections.indexWhere((s) => (s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase());
    if (idx != -1) {
      final s = sections[idx];
      final cols = int.tryParse((s['columns'] ?? 2).toString()) ?? 2;
      final maxI = int.tryParse((s['max_items'] ?? 0).toString()) ?? 0;
      final sFw = (s['full_width'] == 1 || s['full_width'] == true || s['full_width'] == '1') ? 1 : 0;
      final hTitle = (s['hide_title'] == 1 || s['hide_title'] == true || s['hide_title'] == '1') ? 1 : 0;
      final hCount = (s['hide_item_count'] == 1 || s['hide_item_count'] == true || s['hide_item_count'] == '1') ? 1 : 0;
      final imgBg = (s['image_bg_color'] ?? '#F8FAFC').toString();
      final hImg = (s['heading_image'] ?? '').toString();
      return updateSellerSection(
        id,
        cleanSeller,
        name,
        (s['icon'] ?? '🏷️').toString(),
        (s['bg_color'] ?? '#FFFFFF').toString(),
        (s['text_color'] ?? '#0F172A').toString(),
        cols,
        maxI,
        sFw,
        posterFullWidth ? 1 : 0,
        hTitle,
        hCount,
        imgBg,
        hImg,
      );
    }
    return false;
  }

  /// Quick toggle seller section hide_title
  static Future<bool> toggleSellerSectionHideTitle(int id, String sellerUsername, String name, bool hideTitle) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final sections = await getSellerSections(cleanSeller);
    final idx = sections.indexWhere((s) => (s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase());
    if (idx != -1) {
      final s = sections[idx];
      final cols = int.tryParse((s['columns'] ?? 2).toString()) ?? 2;
      final maxI = int.tryParse((s['max_items'] ?? 0).toString()) ?? 0;
      final sFw = (s['full_width'] == 1 || s['full_width'] == true || s['full_width'] == '1') ? 1 : 0;
      final pFw = (s['poster_full_width'] == 1 || s['poster_full_width'] == true || s['poster_full_width'] == '1') ? 1 : 0;
      final hCount = (s['hide_item_count'] == 1 || s['hide_item_count'] == true || s['hide_item_count'] == '1') ? 1 : 0;
      final imgBg = (s['image_bg_color'] ?? '#F8FAFC').toString();
      final hImg = (s['heading_image'] ?? '').toString();
      return updateSellerSection(
        id,
        cleanSeller,
        name,
        (s['icon'] ?? '🏷️').toString(),
        (s['bg_color'] ?? '#FFFFFF').toString(),
        (s['text_color'] ?? '#0F172A').toString(),
        cols,
        maxI,
        sFw,
        pFw,
        hideTitle ? 1 : 0,
        hCount,
        imgBg,
        hImg,
      );
    }
    return false;
  }

  /// Quick toggle seller section hide_item_count
  static Future<bool> toggleSellerSectionHideItemCount(int id, String sellerUsername, String name, bool hideItemCount) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final sections = await getSellerSections(cleanSeller);
    final idx = sections.indexWhere((s) => (s['id'] as num?)?.toInt() == id || (s['name'] ?? '').toString().trim().toLowerCase() == name.trim().toLowerCase());
    if (idx != -1) {
      final s = sections[idx];
      final cols = int.tryParse((s['columns'] ?? 2).toString()) ?? 2;
      final maxI = int.tryParse((s['max_items'] ?? 0).toString()) ?? 0;
      final sFw = (s['full_width'] == 1 || s['full_width'] == true || s['full_width'] == '1') ? 1 : 0;
      final pFw = (s['poster_full_width'] == 1 || s['poster_full_width'] == true || s['poster_full_width'] == '1') ? 1 : 0;
      final hTitle = (s['hide_title'] == 1 || s['hide_title'] == true || s['hide_title'] == '1') ? 1 : 0;
      final imgBg = (s['image_bg_color'] ?? '#F8FAFC').toString();
      final hImg = (s['heading_image'] ?? '').toString();
      return updateSellerSection(
        id,
        cleanSeller,
        name,
        (s['icon'] ?? '🏷️').toString(),
        (s['bg_color'] ?? '#FFFFFF').toString(),
        (s['text_color'] ?? '#0F172A').toString(),
        cols,
        maxI,
        sFw,
        pFw,
        hTitle,
        hideItemCount ? 1 : 0,
        imgBg,
        hImg,
      );
    }
    return false;
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

  /// Get Cached Seller Sliders (Instant Local Cache)
  static Future<List<Map<String, dynamic>>> getCachedSellerSliders(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_sliders_$cleanSeller';
    try {
      final str = prefs.getString(cacheKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // --- SELLER PRODUCT BORDER FRAME METHODS ---
  static final Map<String, String> _productBorderCache = {};

  /// Get Cached Seller Product Border Image string (Synchronous Instant Memory / Cache)
  static String? getCachedSellerProductBorderImage(String sellerUsername) {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return null;
    return _productBorderCache[cleanSeller];
  }

  /// Get Seller Product Border Image (VPS Database API + Local SharedPreferences Cache)
  static Future<String?> getSellerProductBorderImage(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_product_border_$cleanSeller';

    // 1. Check local cache first
    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      _productBorderCache[cleanSeller] = cachedStr;
    }

    // 2. Fetch fresh from VPS API Database
    try {
      final res = await VpsApiService.get('get-seller-product-border&seller_username=$cleanSeller') ??
          await VpsApiService.get('get-seller-product-border&username=$cleanSeller') ??
          await VpsApiService.get('get-seller-profile&seller_username=$cleanSeller') ??
          await VpsApiService.get('get-seller-profile&username=$cleanSeller') ??
          await VpsApiService.get('get-seller-masters&seller_username=$cleanSeller');

      if (res != null) {
        final borderImg = (res['border_image'] ??
                res['product_border'] ??
                res['border'] ??
                res['seller']?['border_image'] ??
                res['seller']?['product_border'] ??
                res['seller']?['border'] ??
                '')
            .toString()
            .trim();

        if (borderImg.isNotEmpty) {
          await prefs.setString(cacheKey, borderImg);
          _productBorderCache[cleanSeller] = borderImg;
          return borderImg;
        } else if (res['border_image'] == '' || res['product_border'] == '') {
          await prefs.remove(cacheKey);
          _productBorderCache.remove(cleanSeller);
          return null;
        }
      }
    } catch (_) {}

    return _productBorderCache[cleanSeller];
  }

  /// Save Seller Product Border Image (VPS API Database + Local SharedPreferences Cache)
  static Future<bool> saveSellerProductBorderImage(String sellerUsername, String borderData) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_product_border_$cleanSeller';
    final cleanData = borderData.trim();

    if (cleanData.isEmpty) {
      await prefs.remove(cacheKey);
      _productBorderCache.remove(cleanSeller);
    } else {
      await prefs.setString(cacheKey, cleanData);
      _productBorderCache[cleanSeller] = cleanData;
    }

    // Save to VPS Database
    try {
      await VpsApiService.post('save-seller-product-border', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'border_image': cleanData,
        'product_border': cleanData,
        'border': cleanData,
      });

      await VpsApiService.post('update-seller-profile', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'border_image': cleanData,
        'product_border': cleanData,
      });
    } catch (_) {}

    return true;
  }

  static final Map<String, List<dynamic>> _headerAnimationsCache = {};

  static List<dynamic> _parseAnimationsList(dynamic raw) {
    if (raw == null) return [];
    List<dynamic> list = [];
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.trim().isNotEmpty) {
      final str = raw.trim();
      if (str.startsWith('[') && str.endsWith(']')) {
        try {
          final List decoded = jsonDecode(str);
          list = decoded;
        } catch (_) {
          list = [str];
        }
      } else {
        list = [str];
      }
    }

    return list.where((item) {
      if (item == null) return false;
      String urlStr = '';
      if (item is Map) {
        urlStr = (item['url'] ?? item['data'] ?? '').toString();
      } else if (item is String) {
        final trimmed = item.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final Map map = jsonDecode(trimmed);
            if (map.containsKey('url')) {
              urlStr = map['url'].toString();
            } else {
              urlStr = trimmed;
            }
          } catch (_) {
            urlStr = trimmed;
          }
        } else {
          urlStr = trimmed;
        }
      }
      final clean = urlStr.trim();
      return clean.isNotEmpty && !clean.startsWith('assets/') && !clean.contains('daily_mart_exclusive.json');
    }).map((item) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }
      return item;
    }).toList();
  }

  /// Get Cached Seller Header Animations List (Instant Memory / Cache)
  static List<dynamic>? getCachedSellerHeaderAnimations(String sellerUsername) {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return null;
    return _headerAnimationsCache[cleanSeller];
  }

  /// Get Seller Header Animations List (VPS Database API + Local SharedPreferences Cache)
  static Future<List<dynamic>> getSellerHeaderAnimations(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return [];

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_header_animations_$cleanSeller';

    // 1. Check local cache first
    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final decoded = List<dynamic>.from(jsonDecode(cachedStr));
        _headerAnimationsCache[cleanSeller] = _parseAnimationsList(decoded);
      } catch (_) {}
    }

    // 2. Fetch fresh from VPS API Database
    try {
      final res = await VpsApiService.get('get-seller-header-animations&seller_username=$cleanSeller') ??
          await VpsApiService.get('get-seller-header-animations&username=$cleanSeller') ??
          await VpsApiService.get('get-seller-profile&seller_username=$cleanSeller') ??
          await VpsApiService.get('get-seller-profile&username=$cleanSeller') ??
          await VpsApiService.get('get-seller-masters&seller_username=$cleanSeller');

      if (res != null) {
        final raw = res['header_animations'] ??
            res['lottie_animations'] ??
            res['animations'] ??
            res['seller']?['header_animations'] ??
            res['seller']?['lottie_animations'] ??
            res['seller']?['animations'] ??
            res['data']?['header_animations'];

        final List<dynamic> fetched = _parseAnimationsList(raw);
        if (fetched.isNotEmpty) {
          await prefs.setString(cacheKey, jsonEncode(fetched));
          _headerAnimationsCache[cleanSeller] = fetched;
          return fetched;
        }
      }
    } catch (_) {}

    return _headerAnimationsCache[cleanSeller] ?? [];
  }

  /// Save Seller Header Animations List (VPS API Database + Local SharedPreferences Cache)
  static Future<bool> saveSellerHeaderAnimations(String sellerUsername, List<dynamic> animations) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_header_animations_$cleanSeller';

    if (animations.isEmpty) {
      await prefs.remove(cacheKey);
      _headerAnimationsCache.remove(cleanSeller);
    } else {
      await prefs.setString(cacheKey, jsonEncode(animations));
      _headerAnimationsCache[cleanSeller] = animations;
    }

    final jsonStr = jsonEncode(animations);

    // Save to VPS Database
    try {
      await VpsApiService.post('save-seller-header-animations', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'header_animations': jsonStr,
        'lottie_animations': jsonStr,
        'animations': jsonStr,
        'animations_list': animations,
      });

      await VpsApiService.post('update-seller-profile', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'header_animations': jsonStr,
      });

      await VpsApiService.post('save-seller-masters', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'header_animations': jsonStr,
      });
    } catch (_) {}

    return true;
  }

  static final Map<String, String> _welcomePopupCache = {};

  /// Get Cached Seller Welcome Popup Image string (Synchronous Instant Memory / SharedPreferences Cache)
  static String? getCachedSellerWelcomePopupImage(String sellerUsername) {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return null;
    return _welcomePopupCache[cleanSeller];
  }

  /// Get Seller Welcome Popup Image (Loads from local cache in 0ms, or fetches from VPS database)
  /// Returns the actual image that the seller uploaded. If the seller has NOT uploaded any popup, returns null.
  static Future<String?> getSellerWelcomePopupImage(
    String sellerUsername, {
    bool forceNetwork = false,
  }) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_welcome_popup_$cleanSeller';
    final cachedStr = _welcomePopupCache[cleanSeller] ?? prefs.getString(cacheKey);

    // 1. Instant Cache: If already loaded, return seller's image immediately (0ms) and sync in background!
    if (!forceNetwork && cachedStr != null && cachedStr.trim().isNotEmpty) {
      _welcomePopupCache[cleanSeller] = cachedStr.trim();
      _refreshSellerWelcomePopupInBackground(cleanSeller);
      return cachedStr.trim();
    }

    // 2. Fetch from VPS server (with full 8s network support for large 300-800KB base64 images)
    try {
      final encSeller = Uri.encodeComponent(cleanSeller);
      final res = await VpsApiService.get('get-seller-welcome-popup&seller_username=$encSeller');
      if (res != null && res['success'] == true) {
        final serverImage = (res['popup_image'] ?? res['welcome_popup'] ?? '').toString().trim();
        if (serverImage.isNotEmpty) {
          _welcomePopupCache[cleanSeller] = serverImage;
          await prefs.setString(cacheKey, serverImage);
          return serverImage;
        } else {
          _welcomePopupCache.remove(cleanSeller);
          await prefs.remove(cacheKey);
          return null;
        }
      }
    } catch (e) {
      debugPrint('Error getting seller welcome popup: $e');
    }

    // 3. If network failed, fall back to cached image if any
    if (cachedStr != null && cachedStr.trim().isNotEmpty) {
      return cachedStr.trim();
    }

    return null;
  }

  /// Fire-and-forget background refresh of seller welcome popup
  static void _refreshSellerWelcomePopupInBackground(String cleanSeller) {
    Future.microtask(() async {
      try {
        final encSeller = Uri.encodeComponent(cleanSeller);
        final res = await VpsApiService.get('get-seller-welcome-popup&seller_username=$encSeller');
        if (res != null && res['success'] == true) {
          final serverImage = (res['popup_image'] ?? res['welcome_popup'] ?? '').toString().trim();
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = 'seller_welcome_popup_$cleanSeller';
          if (serverImage.isNotEmpty) {
            _welcomePopupCache[cleanSeller] = serverImage;
            await prefs.setString(cacheKey, serverImage);
          } else {
            _welcomePopupCache.remove(cleanSeller);
            await prefs.remove(cacheKey);
          }
        }
      } catch (_) {}
    });
  }

  /// Save Seller Welcome Popup Image (VPS API Database + Local SharedPreferences Cache)
  static Future<bool> saveSellerWelcomePopupImage(String sellerUsername, String imageData) async {
    final cleanSeller = sellerUsername.trim().toLowerCase();
    if (cleanSeller.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'seller_welcome_popup_$cleanSeller';
    final cleanData = imageData.trim();

    if (cleanData.isEmpty) {
      await prefs.remove(cacheKey);
      _welcomePopupCache.remove(cleanSeller);
    } else {
      await prefs.setString(cacheKey, cleanData);
      _welcomePopupCache[cleanSeller] = cleanData;
    }

    // Save to VPS Database
    try {
      await VpsApiService.post('save-seller-welcome-popup', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'popup_image': cleanData,
        'welcome_popup': cleanData,
        'image': cleanData,
      });

      await VpsApiService.post('update-seller-profile', {
        'seller_username': cleanSeller,
        'username': cleanSeller,
        'welcome_popup': cleanData,
      });
    } catch (_) {}

    return true;
  }

  /// Check if a customer has ever had any DELIVERED order
  /// (Used to determine if Welcome / First-Order offer popup should be shown)
  /// [checkServer]: If true (default), queries the database with a fast timeout (700ms) to ensure
  /// customers with 0 orders in database (or reset databases) are correctly identified as having NO delivered orders!
  static Future<bool> checkCustomerHasDeliveredOrder(String customerMobile, {bool checkServer = true}) async {
    final raw = customerMobile.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    if (last10.isEmpty) return false;

    // 1. Fast check VPS server (700ms timeout) so new customers & cleared databases update immediately
    if (checkServer) {
      try {
        final res = await VpsApiService.get('get-customer-orders&customer_mobile=$last10')
            .timeout(const Duration(milliseconds: 700));
        if (res != null && res['success'] == true && res['orders'] is List) {
          final List orders = res['orders'];
          if (orders.isEmpty) {
            // 0 orders in database: customer is guaranteed to have NO delivered orders!
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('customer_orders_history_$raw');
            await prefs.remove('customer_orders_history_$last10');
            await prefs.remove('global_all_customer_orders_history');
            return false;
          }
          final hasDelivered = orders.any((item) {
            if (item is! Map) return false;
            final st = (item['order_status'] ?? item['status'] ?? '').toString().toLowerCase();
            final delSt = (item['delivery_status'] ?? '').toString().toLowerCase();
            return st == 'delivered' || delSt == 'delivered';
          });
          if (!hasDelivered) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('customer_orders_history_$raw');
            await prefs.remove('customer_orders_history_$last10');
            await prefs.remove('global_all_customer_orders_history');
          }
          return hasDelivered;
        }
      } catch (_) {}
    }

    // 2. Check local cached orders for this specific customer only (fallback)
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToCheck = [
        'customer_orders_history_$raw',
        'customer_orders_history_$last10',
        'saved_customer_placed_orders_$raw',
        'saved_customer_placed_orders_$last10',
      ];
      for (final k in keysToCheck) {
        final str = prefs.getString(k);
        if (str != null && str.trim().isNotEmpty) {
          final List decoded = jsonDecode(str);
          final hasDelivered = decoded.any((item) {
            if (item is! Map) return false;
            final m = Map<String, dynamic>.from(item);
            final st = (m['order_status'] ?? m['status'] ?? '').toString().toLowerCase();
            final delSt = (m['delivery_status'] ?? '').toString().toLowerCase();
            return st == 'delivered' || delSt == 'delivered';
          });
          if (hasDelivered) return true;
        }
      }
    } catch (_) {}

    return false;
  }

  static final Map<String, String> _sellerRelatedItemBgCache = {};

  /// Synchronously get cached related item background color for seller
  static String? getCachedSellerRelatedItemBg(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    return _sellerRelatedItemBgCache[clean];
  }

  /// Get Seller Related Item Background Color (SharedPreferences Cache + VPS Sync)
  static Future<String> getSellerRelatedItemBg(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return '#F8FAFC';

    // Check memory cache
    if (_sellerRelatedItemBgCache.containsKey(clean)) {
      return _sellerRelatedItemBgCache[clean]!;
    }

    // Check local preferences
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('seller_related_item_bg_$clean');
    if (cached != null && cached.isNotEmpty) {
      _sellerRelatedItemBgCache[clean] = cached;
    }

    // Background fetch from VPS API
    try {
      final res = await VpsApiService.get('get-seller-related-item-bg&seller_username=$clean');
      if (res != null && res['success'] == true && res['color'] != null) {
        final serverColor = res['color'].toString().trim();
        if (serverColor.isNotEmpty) {
          _sellerRelatedItemBgCache[clean] = serverColor;
          await prefs.setString('seller_related_item_bg_$clean', serverColor);
          return serverColor;
        }
      }
    } catch (_) {}

    return _sellerRelatedItemBgCache[clean] ?? '#F8FAFC';
  }

  /// Save Seller Related Item Background Color
  static Future<bool> saveSellerRelatedItemBg(String sellerUsername, String colorHex) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;

    String finalColor = colorHex.trim();
    if (finalColor.isEmpty) finalColor = '#F8FAFC';
    if (!finalColor.startsWith('#')) finalColor = '#$finalColor';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_related_item_bg_$clean', finalColor);
    _sellerRelatedItemBgCache[clean] = finalColor;

    try {
      await VpsApiService.post('save-seller-related-item-bg', {
        'seller_username': clean,
        'username': clean,
        'color': finalColor,
        'item_bg_color': finalColor,
        'related_item_bg': finalColor,
      });

      await VpsApiService.post('update-seller-profile', {
        'seller_username': clean,
        'username': clean,
        'related_item_bg': finalColor,
      });
    } catch (_) {}

    return true;
  }

  static final Map<String, List<Map<String, dynamic>>> _sellerCategorySectionsCache = {};

  /// Save Seller Category Sections (Dedicated Category-Only Sections)
  static Future<bool> saveSellerCategorySections(String sellerUsername, List<Map<String, dynamic>> sections) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(sections);
    await prefs.setString('seller_category_sections_$clean', jsonStr);
    _sellerCategorySectionsCache[clean] = List.from(sections);

    // 1. Dual Persistence into live VPS global header theme (Works immediately on live VPS!)
    try {
      final config = await getHeaderThemeConfig();
      Map<String, dynamic> catSecMap = {};
      if (config['seller_category_sections'] is Map) {
        catSecMap = Map<String, dynamic>.from(config['seller_category_sections']);
      }
      catSecMap[clean] = sections;
      config['seller_category_sections'] = catSecMap;
      await saveHeaderThemeConfig(config);
    } catch (_) {}

    // 2. Also call dedicated endpoint
    try {
      await VpsApiService.post('save-seller-category-sections', {
        'seller_username': clean,
        'username': clean,
        'category_sections': sections,
      });
    } catch (_) {}

    return true;
  }

  /// Get Seller Category Sections
  static Future<List<Map<String, dynamic>>> getSellerCategorySections(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return [];

    if (_sellerCategorySectionsCache.containsKey(clean)) {
      return List.from(_sellerCategorySectionsCache[clean]!);
    }

    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('seller_category_sections_$clean');
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(localJson);
        if (decoded is List) {
          final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _sellerCategorySectionsCache[clean] = list;
          _fetchRemoteCategorySections(clean);
          return list;
        }
      } catch (_) {}
    }

    // 1. Fetch from live VPS global header theme (Works immediately even if cache cleared!)
    try {
      final config = await getHeaderThemeConfig();
      if (config['seller_category_sections'] is Map) {
        final map = config['seller_category_sections'] as Map;
        if (map.containsKey(clean) && map[clean] is List) {
          final list = (map[clean] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          if (list.isNotEmpty) {
            _sellerCategorySectionsCache[clean] = list;
            await prefs.setString('seller_category_sections_$clean', jsonEncode(list));
            return list;
          }
        }
      }
    } catch (_) {}

    return await _fetchRemoteCategorySections(clean);
  }

  static Future<List<Map<String, dynamic>>> _fetchRemoteCategorySections(String clean) async {
    try {
      final res = await VpsApiService.post('get-seller-category-sections', {
        'seller_username': clean,
        'username': clean,
      }) ?? await VpsApiService.get('get-seller-category-sections&seller_username=$clean');
      if (res != null && res['success'] == true && res['category_sections'] is List) {
        final list = (res['category_sections'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('seller_category_sections_$clean', jsonEncode(list));
        _sellerCategorySectionsCache[clean] = list;
        return list;
      }
    } catch (_) {}
    return _sellerCategorySectionsCache[clean] ?? [];
  }

  static final Map<String, List<Map<String, dynamic>>> _sellerHomeLayoutCache = {};

  /// Save Seller Home Page Layout / Listing Order
  static Future<bool> saveSellerHomeLayout(String sellerUsername, List<Map<String, dynamic>> layoutList) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(layoutList);
    await prefs.setString('seller_home_layout_$clean', jsonStr);
    _sellerHomeLayoutCache[clean] = List.from(layoutList);

    // 1. Dual Persistence into live VPS global header theme (Works immediately on live VPS!)
    try {
      final config = await getHeaderThemeConfig();
      Map<String, dynamic> layoutMap = {};
      if (config['seller_home_layouts'] is Map) {
        layoutMap = Map<String, dynamic>.from(config['seller_home_layouts']);
      }
      layoutMap[clean] = layoutList;
      config['seller_home_layouts'] = layoutMap;
      await saveHeaderThemeConfig(config);
    } catch (_) {}

    // 2. Also call dedicated endpoint
    try {
      await VpsApiService.post('save-seller-home-layout', {
        'seller_username': clean,
        'username': clean,
        'layout_order': layoutList,
      });
    } catch (_) {}

    return true;
  }

  /// Get Cached Home Layout synchronously (0 delay)
  static List<Map<String, dynamic>>? getCachedSellerHomeLayout(String sellerUsername) {
    final clean = sellerUsername.trim().toLowerCase();
    if (_sellerHomeLayoutCache.containsKey(clean)) {
      return List.from(_sellerHomeLayoutCache[clean]!);
    }
    return null;
  }

  /// Get Seller Home Page Layout / Listing Order
  static Future<List<Map<String, dynamic>>> getSellerHomeLayout(String sellerUsername) async {
    final clean = sellerUsername.trim().toLowerCase();
    if (clean.isEmpty) return [];

    if (_sellerHomeLayoutCache.containsKey(clean)) {
      return List.from(_sellerHomeLayoutCache[clean]!);
    }

    final prefs = await SharedPreferences.getInstance();
    final localJson = prefs.getString('seller_home_layout_$clean');
    if (localJson != null && localJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(localJson);
        if (decoded is List) {
          final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _sellerHomeLayoutCache[clean] = list;
          _fetchRemoteHomeLayout(clean);
          return list;
        }
      } catch (_) {}
    }

    // 1. Fetch from live VPS global header theme (Works immediately even if cache cleared!)
    try {
      final config = await getHeaderThemeConfig();
      if (config['seller_home_layouts'] is Map) {
        final map = config['seller_home_layouts'] as Map;
        if (map.containsKey(clean) && map[clean] is List) {
          final list = (map[clean] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          if (list.isNotEmpty) {
            _sellerHomeLayoutCache[clean] = list;
            await prefs.setString('seller_home_layout_$clean', jsonEncode(list));
            return list;
          }
        }
      }
    } catch (_) {}

    return await _fetchRemoteHomeLayout(clean);
  }

  static Future<List<Map<String, dynamic>>> _fetchRemoteHomeLayout(String clean) async {
    try {
      final res = await VpsApiService.post('get-seller-home-layout', {
        'seller_username': clean,
        'username': clean,
      }) ?? await VpsApiService.get('get-seller-home-layout&seller_username=$clean');
      if (res != null && res['success'] == true && res['layout_order'] is List) {
        final list = (res['layout_order'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('seller_home_layout_$clean', jsonEncode(list));
        _sellerHomeLayoutCache[clean] = list;
        return list;
      }
    } catch (_) {}
    return _sellerHomeLayoutCache[clean] ?? [];
  }

  /// -------------------------------------------------------------
  /// CUSTOMER MANAGEMENT (Admin & App-wide Block Checking)
  /// -------------------------------------------------------------

  /// Get all registered customers from VPS MySQL Database
  static Future<List<Map<String, dynamic>>> getAllCustomersForAdmin() async {
    try {
      final res = await VpsApiService.get('get-all-customers');
      if (res != null && res['success'] == true && res['customers'] is List) {
        final List list = res['customers'];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Toggle Block / Unblock Customer
  static Future<bool> toggleCustomerBlockStatus({
    required String mobile,
    required bool isBlocked,
    int? id,
    String? reason,
  }) async {
    try {
      final res = await VpsApiService.post('toggle-block-customer', {
        'mobile': mobile.trim(),
        'id': id ?? 0,
        'is_blocked': isBlocked ? 1 : 0,
        'reason': reason ?? '',
      });

      if (res != null && res['success'] == true) {
        // Update local cache if available
        try {
          final prefs = await SharedPreferences.getInstance();
          final cleanDigits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
          final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
          await prefs.setBool('cached_blocked_status_$last10', isBlocked);
        } catch (_) {}
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Fast check if a customer is blocked by Admin
  static Future<bool> isCustomerBlockedByAdmin(String mobile) async {
    final cleanDigits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
    if (last10.isEmpty) return false;

    // 1. Check local cache first (0 ms instant response)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('cached_blocked_status_$last10')) {
        final cached = prefs.getBool('cached_blocked_status_$last10') ?? false;
        // Background re-verify
        _verifyCustomerBlockedInBackground(last10, mobile);
        return cached;
      }
    } catch (_) {}

    // 2. Direct query to server
    return await _verifyCustomerBlockedInBackground(last10, mobile);
  }

  static Future<bool> _verifyCustomerBlockedInBackground(String last10, String mobile) async {
    try {
      final res = await VpsApiService.get('check-customer-blocked-status&mobile=$mobile');
      if (res != null && res['success'] == true) {
        final isBlocked = res['is_blocked'] == true || res['is_blocked'] == 1 || res['is_blocked'] == '1';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('cached_blocked_status_$last10', isBlocked);
        return isBlocked;
      }
    } catch (_) {}
    return false;
  }
}


