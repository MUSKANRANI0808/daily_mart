import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  static String _getKey(String sellerUsername) => 'draft_cart_${sellerUsername.trim().toLowerCase()}';

  // Fast In-Memory cache & instant reactive notifier (0ms delay)
  static final Map<String, List<Map<String, dynamic>>> _memoryCart = {};
  static final ValueNotifier<int> cartUpdateNotifier = ValueNotifier<int>(0);

  /// Synchronously get cached cart items if available (0ms instant access)
  static List<Map<String, dynamic>> getCachedCartItems(String sellerUsername) {
    final key = sellerUsername.trim().toLowerCase();
    if (_memoryCart.containsKey(key)) {
      return List<Map<String, dynamic>>.from(_memoryCart[key]!);
    }
    return [];
  }

  /// Calculate amount based on unit conversion
  static double calculateAmount({
    required double baseRate,
    required String baseUnitRaw,
    required String selectedUnitRaw,
    required double quantity,
  }) {
    final b = baseUnitRaw.trim().toLowerCase();
    final s = selectedUnitRaw.trim().toLowerCase();
    double effectiveBaseQty = quantity;

    if (b == 'kg') {
      if (s == 'gram' || s == 'gm' || s == 'g') {
        effectiveBaseQty = quantity / 1000.0;
      }
    } else if (b == 'gram' || b == 'gm' || b == 'g') {
      if (s == 'kg') {
        effectiveBaseQty = quantity * 1000.0;
      }
    } else if (b == 'l' || b == 'liter' || b == 'litre') {
      if (s == 'ml') {
        effectiveBaseQty = quantity / 1000.0;
      }
    } else if (b == 'ml') {
      if (s == 'l' || s == 'liter' || s == 'litre') {
        effectiveBaseQty = quantity * 1000.0;
      }
    }

    return baseRate * effectiveBaseQty;
  }

  /// Get list of cart items
  static Future<List<Map<String, dynamic>>> getCartItems(String sellerUsername) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return [];
    final key = cleanSeller.toLowerCase();
    if (_memoryCart.containsKey(key)) {
      return List<Map<String, dynamic>>.from(_memoryCart[key]!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString(_getKey(cleanSeller));
      if (jsonStr == null || jsonStr.isEmpty) {
        // Fallback for case-sensitive legacy key
        jsonStr = prefs.getString('draft_cart_$cleanSeller');
      }
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final loaded = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _memoryCart[key] = List<Map<String, dynamic>>.from(loaded);
        return loaded;
      }
    } catch (_) {}
    _memoryCart[key] = [];
    return [];
  }

  /// Save cart items
  static Future<bool> saveCartItems(String sellerUsername, List<Map<String, dynamic>> items) async {
    final cleanSeller = sellerUsername.trim();
    if (cleanSeller.isEmpty) return false;
    final key = cleanSeller.toLowerCase();

    // 1. Instantly update in-memory cache & notify UI listeners (0ms delay!)
    _memoryCart[key] = List<Map<String, dynamic>>.from(items);
    cartUpdateNotifier.value++;

    // 2. Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(items);
      await prefs.setString(_getKey(cleanSeller), jsonStr);
      if (cleanSeller != cleanSeller.toLowerCase()) {
        await prefs.setString('draft_cart_$cleanSeller', jsonStr);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Add or update item in cart
  static Future<bool> addToCart({
    required String sellerUsername,
    required Map<String, dynamic> product,
    required String selectedUnit,
    required int quantity,
  }) async {
    final items = await getCartItems(sellerUsername);
    final pId = product['id'];
    final pName = (product['name'] ?? '').toString().trim();
    final baseUnit = (product['unit'] ?? 'Pcs').toString().trim();
    final pRate = (product['rate'] as num?)?.toDouble() ?? 0.0;
    final pImg = (product['image_url'] ?? product['image'] ?? '📦').toString().trim();
    final pCat = (product['category'] ?? '').toString().trim();

    final amt = calculateAmount(
      baseRate: pRate,
      baseUnitRaw: baseUnit,
      selectedUnitRaw: selectedUnit,
      quantity: quantity.toDouble(),
    );

    // Check if item with same name & unit exists
    final existingIdx = items.indexWhere((it) =>
        (it['name'] ?? '').toString().trim().toLowerCase() == pName.toLowerCase() &&
        (it['unit'] ?? '').toString().trim().toLowerCase() == selectedUnit.toLowerCase());

    if (existingIdx >= 0) {
      final existing = items[existingIdx];
      final currentQty = (existing['qty'] as num?)?.toInt() ?? 1;
      final newQty = currentQty + quantity;
      existing['qty'] = newQty;
      existing['base_unit'] = baseUnit;
      existing['rate'] = pRate;
      existing['amount'] = calculateAmount(
        baseRate: pRate,
        baseUnitRaw: baseUnit,
        selectedUnitRaw: selectedUnit,
        quantity: newQty.toDouble(),
      );
      existing['unit'] = selectedUnit;
      existing['image'] = pImg;
    } else {
      items.add({
        'id': pId ?? DateTime.now().millisecondsSinceEpoch,
        'name': pName,
        'base_unit': baseUnit,
        'unit': selectedUnit,
        'qty': quantity,
        'rate': pRate,
        'amount': amt,
        'image': pImg,
        'category': pCat,
      });
    }

    return await saveCartItems(sellerUsername, items);
  }

  /// Update item qty at index
  static Future<bool> updateCartItemQty(String sellerUsername, int index, int newQty) async {
    final items = await getCartItems(sellerUsername);
    if (index < 0 || index >= items.length) return false;
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      final item = items[index];
      final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
      final baseUnit = (item['base_unit'] ?? item['unit'] ?? 'Pcs').toString();
      final selectedUnit = (item['unit'] ?? 'Pcs').toString();
      item['qty'] = newQty;
      item['amount'] = calculateAmount(
        baseRate: rate,
        baseUnitRaw: baseUnit,
        selectedUnitRaw: selectedUnit,
        quantity: newQty.toDouble(),
      );
    }
    return await saveCartItems(sellerUsername, items);
  }

  /// Remove item at index
  static Future<bool> removeCartItem(String sellerUsername, int index) async {
    final items = await getCartItems(sellerUsername);
    if (index < 0 || index >= items.length) return false;
    items.removeAt(index);
    return await saveCartItems(sellerUsername, items);
  }

  /// Clear all cart items
  static Future<bool> clearCart(String sellerUsername) async {
    return await saveCartItems(sellerUsername, []);
  }

  /// Calculate Total Items count
  static int getTotalCount(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var it in items) {
      total += (it['qty'] as num?)?.toInt() ?? 1;
    }
    return total;
  }

  /// Calculate Total Amount
  static double getTotalAmount(List<Map<String, dynamic>> items) {
    double total = 0.0;
    for (var it in items) {
      total += (it['amount'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }
}
