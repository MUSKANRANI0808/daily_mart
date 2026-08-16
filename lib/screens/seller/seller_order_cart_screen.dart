import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/notification_service.dart';
import '../customer/order_success_screen.dart';
import 'seller_chat_screen.dart';

class SellerOrderCartScreen extends StatefulWidget {
  final UserModel seller;
  final UserModel? customer;

  const SellerOrderCartScreen({
    super.key,
    required this.seller,
    this.customer,
  });

  @override
  State<SellerOrderCartScreen> createState() => _SellerOrderCartScreenState();
}

class _SellerOrderCartScreenState extends State<SellerOrderCartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _placedOrders = [];
  bool _isLoading = true;
  bool _showHistoryTab = false;
  bool _hasUserToggledTab = false;
  String _sellerOrderFilter = 'pending'; // Default filter is 'pending' for sellers!
  String _previewNextOrderId = '#DM-1001';
  Timer? _cartPoller;

  bool get _isSellerMode => widget.customer == null;

  @override
  void initState() {
    super.initState();
    if (_isSellerMode) {
      _showHistoryTab = true; // Show Customer Orders tab by default for Sellers!
      _sellerOrderFilter = 'pending'; // Default filter is 'pending'!
    }
    _loadCart();
    _cartPoller = Timer.periodic(const Duration(milliseconds: 3000), (timer) {
      _loadCart();
    });
  }

  @override
  void dispose() {
    _cartPoller?.cancel();
    super.dispose();
  }

  String get _sellerUsername => (widget.seller.username ?? widget.seller.mobile ?? '').trim();

  Future<String> _getEffectiveCustomerMobile() async {
    final argMobile = (widget.customer?.mobile ?? '').trim();
    if (argMobile.isNotEmpty && argMobile != 'Customer') return argMobile;

    final currentUser = await AuthService.getCurrentUser();
    final userMobile = (currentUser?.mobile ?? '').trim();
    if (userMobile.isNotEmpty && userMobile != 'Customer') return userMobile;

    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('last_logged_in_customer_mobile') ??
            prefs.getString('user_mobile') ??
            prefs.getString('customer_mobile') ??
            '').trim();
  }

  Future<void> _loadCart() async {
    final items = await CartService.getCartItems(_sellerUsername);
    List<Map<String, dynamic>> history = [];

    if (_isSellerMode) {
      // 1. Instant 0ms cache load
      final cachedHistory = await AuthService.getCachedSellerCustomerOrders(_sellerUsername);
      if (cachedHistory.isNotEmpty && mounted && _isLoading) {
        setState(() {
          _placedOrders = cachedHistory;
          _cartItems = items;
          _isLoading = false;
        });
      }

      // 2. Fetch fresh from VPS
      history = await AuthService.getSellerCustomerOrders(_sellerUsername);
      if (history.isEmpty) {
        final fallbackName = (widget.seller.name ?? '').trim();
        if (fallbackName.isNotEmpty && fallbackName.toLowerCase() != _sellerUsername.toLowerCase()) {
          history = await AuthService.getSellerCustomerOrders(fallbackName);
        }
      }
    } else {
      final custMobile = await _getEffectiveCustomerMobile();
      history = await AuthService.getCustomerPlacedOrders(custMobile, sellerUsername: _sellerUsername);
    }
    
    if (mounted) {
      final newCartJson = jsonEncode(items);
      final oldCartJson = jsonEncode(_cartItems);
      final newHistJson = jsonEncode(history);
      final oldHistJson = jsonEncode(_placedOrders);

      if (newCartJson != oldCartJson || newHistJson != oldHistJson || _isLoading) {
        setState(() {
          _cartItems = items;
          _placedOrders = history;
          _isLoading = false;
          if (!_hasUserToggledTab) {
            if (_isSellerMode) {
              _showHistoryTab = true; // Always default to Customer Orders tab for Sellers!
            } else if (items.isEmpty && history.isNotEmpty) {
              _showHistoryTab = true;
            }
          }
        });
      }
    }
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 24}) {
    final img = rawImg.trim();
    if (img.isEmpty) {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
      );
    }

    String base64Str = img;
    if (img.startsWith('data:image')) {
      final parts = img.split(',');
      if (parts.length > 1) {
        base64Str = parts.last.trim();
      }
    }

    if (base64Str.length > 20) {
      try {
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
        );
      } catch (_) {}
    }

    if (img.length <= 4 && img.isNotEmpty) {
      return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
    }

    return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
  }

  void _updateItemQty(int index, int newQty) async {
    await CartService.updateCartItemQty(_sellerUsername, index, newQty);
    _loadCart();
  }

  void _removeItem(int index) async {
    await CartService.removeCartItem(_sellerUsername, index);
    _loadCart();
  }

  void _clearBill() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Clear Order Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text('Are you sure you want to remove all items from this order bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CartService.clearCart(_sellerUsername);
      _loadCart();
    }
  }

  /// Full "Add New Delivery Address" Modal Sheet (matching CustomerAddressesScreen form)
  Future<Map<String, dynamic>?> _openFullAddNewAddressBottomSheet(
    BuildContext sheetContext,
    Set<String> phoneKeys,
    String defaultName,
    String defaultMobile,
  ) async {
    final formKey = GlobalKey<FormState>();

    String tag = 'Home';
    final houseController = TextEditingController();
    final buildingController = TextEditingController();
    final localityController = TextEditingController();
    final landmarkController = TextEditingController();
    final cityController = TextEditingController();
    final pincodeController = TextEditingController();
    final receiverController = TextEditingController(text: defaultName);
    final phoneController = TextEditingController(text: defaultMobile);
    bool isDefault = true;

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Delivery Address 📍',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Save Address As:
                  const Text('Save Address As:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((t) {
                      final isSelected = tag == t;
                      IconData iconData = Icons.home_rounded;
                      if (t == 'Work') iconData = Icons.work_rounded;
                      if (t == 'Other') iconData = Icons.location_on_rounded;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ChoiceChip(
                          avatar: Icon(iconData, size: 16, color: isSelected ? Colors.white : const Color(0xFF10B981)),
                          label: Text(t, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setModalState(() => tag = t);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Flat / House No. / Floor *
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House No. / Floor *',
                      prefixIcon: const Icon(Icons.other_houses_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter House/Flat No.' : null,
                  ),
                  const SizedBox(height: 12),

                  // Building / Apartment Name
                  TextFormField(
                    controller: buildingController,
                    decoration: InputDecoration(
                      labelText: 'Building / Apartment Name',
                      prefixIcon: const Icon(Icons.apartment_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Street / Area / Locality *
                  TextFormField(
                    controller: localityController,
                    decoration: InputDecoration(
                      labelText: 'Street / Area / Locality *',
                      prefixIcon: const Icon(Icons.add_road_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter Street or Locality' : null,
                  ),
                  const SizedBox(height: 12),

                  // Landmark / Near
                  TextFormField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Landmark / Near (e.g. Near Shiv Mandir, School)',
                      hintText: 'e.g. Near Temple / School',
                      prefixIcon: const Icon(Icons.near_me_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row: City & Pincode
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter City' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: pincodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Pincode *',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_drop_rounded, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().length < 6) ? '6 digits' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Receiver Name & Phone
                  TextFormField(
                    controller: receiverController,
                    decoration: InputDecoration(
                      labelText: 'Receiver Name *',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Name' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone Number *',
                      counterText: '',
                      prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().length < 10) ? '10 digits' : null,
                  ),
                  const SizedBox(height: 12),

                  // Set Default Checkbox
                  CheckboxListTile(
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make this my default delivery address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isDefault,
                    onChanged: (val) {
                      setModalState(() => isDefault = val ?? true);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newAddrObj = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'tag': tag,
                          'houseNo': houseController.text.trim(),
                          'building': buildingController.text.trim(),
                          'locality': localityController.text.trim(),
                          'landmark': landmarkController.text.trim(),
                          'city': cityController.text.trim(),
                          'pincode': pincodeController.text.trim(),
                          'receiverName': receiverController.text.trim(),
                          'mobile': phoneController.text.trim(),
                          'isDefault': isDefault,
                        };

                        final prefs = await SharedPreferences.getInstance();

                        // Save for all phone variations
                        for (var phone in phoneKeys) {
                          try {
                            final listKey = 'customer_addresses_$phone';
                            final defaultKey = 'default_delivery_address_$phone';

                            List<Map<String, dynamic>> existingList = [];
                            final listStr = prefs.getString(listKey);
                            if (listStr != null && listStr.isNotEmpty) {
                              final List decoded = jsonDecode(listStr);
                              existingList = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
                            }
                            if (isDefault) {
                              for (var e in existingList) {
                                e['isDefault'] = false;
                              }
                            }
                            existingList.insert(0, newAddrObj);
                            await prefs.setString(listKey, jsonEncode(existingList));

                            // Build full string
                            final parts = [
                              if (newAddrObj['houseNo'].toString().isNotEmpty) newAddrObj['houseNo'].toString(),
                              if (newAddrObj['building'].toString().isNotEmpty) newAddrObj['building'].toString(),
                              if (newAddrObj['locality'].toString().isNotEmpty) newAddrObj['locality'].toString(),
                              if (newAddrObj['landmark'].toString().isNotEmpty) 'Near ${newAddrObj['landmark']}',
                              if (newAddrObj['city'].toString().isNotEmpty) newAddrObj['city'].toString(),
                              if (newAddrObj['pincode'].toString().isNotEmpty) 'PIN: ${newAddrObj['pincode']}',
                            ];
                            final fullStr = parts.join(', ');

                            if (isDefault) {
                              await prefs.setString(defaultKey, fullStr);
                              await prefs.setString('saved_customer_address', fullStr);
                            }
                          } catch (_) {}
                        }

                        if (context.mounted) {
                          Navigator.pop(ctx, newAddrObj);
                        }
                      }
                    },
                    child: const Text('Save Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Address Selection Bottom Sheet Dialog
  Future<String?> _showAddressSelectionBottomSheet(String custMobile) async {
    final prefs = await SharedPreferences.getInstance();

    // Get all possible phone variations for keys
    final currentUser = await AuthService.getCurrentUser();
    final Set<String> phoneKeys = {};

    void addPhoneVariants(String? mob) {
      if (mob == null || mob.trim().isEmpty) return;
      final raw = mob.trim();
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      phoneKeys.add(raw);
      if (digits.isNotEmpty) phoneKeys.add(digits);
      if (digits.length >= 10) phoneKeys.add(digits.substring(digits.length - 10));
    }

    addPhoneVariants(custMobile);
    addPhoneVariants(widget.customer?.mobile);
    addPhoneVariants(currentUser?.mobile);
    if (phoneKeys.isEmpty) phoneKeys.add('default');

    List<Map<String, dynamic>> savedAddressesList = [];
    final Set<String> uniqueAddrs = {};

    void addAddress(String title, String addr, {bool isDefault = false}) {
      final cleanAddr = addr.trim();
      if (cleanAddr.isEmpty || uniqueAddrs.contains(cleanAddr.toLowerCase())) return;
      uniqueAddrs.add(cleanAddr.toLowerCase());
      savedAddressesList.add({
        'title': title,
        'address': cleanAddr,
        'isDefault': isDefault,
      });
    }

    String extractFullAddress(Map item) {
      final direct = (item['address'] ?? item['full_address'] ?? '').toString().trim();
      if (direct.isNotEmpty) return direct;

      final houseNo = (item['houseNo'] ?? '').toString().trim();
      final building = (item['building'] ?? '').toString().trim();
      final locality = (item['locality'] ?? '').toString().trim();
      final landmark = (item['landmark'] ?? '').toString().trim();
      final city = (item['city'] ?? '').toString().trim();
      final pincode = (item['pincode'] ?? '').toString().trim();

      final parts = [
        if (houseNo.isNotEmpty) houseNo,
        if (building.isNotEmpty) building,
        if (locality.isNotEmpty) locality,
        if (landmark.isNotEmpty) 'Near $landmark',
        if (city.isNotEmpty) city,
        if (pincode.isNotEmpty) 'PIN: $pincode',
      ];
      return parts.join(', ');
    }

    // Load from customer_addresses_<mobile> for all phone variations
    for (var phone in phoneKeys) {
      try {
        final listStr = prefs.getString('customer_addresses_$phone');
        if (listStr != null && listStr.isNotEmpty) {
          final List decoded = jsonDecode(listStr);
          for (var item in decoded) {
            if (item is Map) {
              final aStr = extractFullAddress(item);
              final tag = (item['tag'] ?? item['title'] ?? 'Saved Address').toString().trim();
              final isDef = item['isDefault'] == true;
              addAddress(tag.isNotEmpty ? tag : 'Saved Address', aStr, isDefault: isDef);
            } else if (item is String) {
              addAddress('Saved Address', item);
            }
          }
        }
      } catch (_) {}

      try {
        final defAddr = prefs.getString('default_delivery_address_$phone');
        if (defAddr != null && defAddr.isNotEmpty) {
          addAddress('Default Address', defAddr, isDefault: true);
        }
      } catch (_) {}

      try {
        final histKey = 'customer_orders_history_$phone';
        final hStr = prefs.getString(histKey);
        if (hStr != null && hStr.isNotEmpty) {
          final List decoded = jsonDecode(hStr);
          for (var item in decoded) {
            if (item is Map) {
              final aStr = (item['delivery_address'] ?? item['address'] ?? '').toString().trim();
              if (aStr.isNotEmpty) {
                addAddress('Previous Order Address', aStr);
              }
            }
          }
        }
      } catch (_) {}
    }

    // Also check global saved_customer_address
    final globalDef = prefs.getString('saved_customer_address') ?? '';
    if (globalDef.isNotEmpty) {
      addAddress('Home Address', globalDef);
    }

    // Initial selected address index
    int selectedIndex = savedAddressesList.isNotEmpty ? 0 : -1;

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Drag Handle & Header Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Select Delivery Address 🚚',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx, null),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Section 1: Saved Addresses List
                      if (savedAddressesList.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Choose From Saved Addresses:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${savedAddressesList.length} Saved',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(savedAddressesList.length, (idx) {
                          final item = savedAddressesList[idx];
                          final isSelected = selectedIndex == idx;
                          final title = item['title'].toString();
                          final addressText = item['address'].toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () {
                                setSheetState(() {
                                  selectedIndex = idx;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(top: 2, right: 10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: idx == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  idx == 0 ? 'DEFAULT 🏠' : 'SAVED 📍',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: idx == 0 ? const Color(0xFF15803D) : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            addressText,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                      ],

                      // Section 2: Enter New Delivery Address Button -> Opens Full Form
                      InkWell(
                        onTap: () async {
                          final newAddrObj = await _openFullAddNewAddressBottomSheet(
                            ctx,
                            phoneKeys,
                            widget.customer?.name ?? currentUser?.name ?? 'Customer',
                            custMobile.replaceAll(RegExp(r'\D'), ''),
                          );
                          if (newAddrObj != null) {
                            final newStr = extractFullAddress(newAddrObj);
                            if (newStr.isNotEmpty) {
                              setSheetState(() {
                                addAddress(newAddrObj['tag'] ?? 'Home', newStr, isDefault: true);
                                final findIdx = savedAddressesList.indexWhere((e) => e['address'].toString().trim().toLowerCase() == newStr.trim().toLowerCase());
                                if (findIdx >= 0) {
                                  selectedIndex = findIdx;
                                } else {
                                  selectedIndex = 0;
                                }
                              });
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_location_alt_rounded, size: 18, color: Color(0xFF10B981)),
                              SizedBox(width: 10),
                              Text(
                                '➕ Add New Delivery Address',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              ),
                              Spacer(),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Confirm & Deliver Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (selectedIndex < 0 || selectedIndex >= savedAddressesList.length) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select or add a delivery address! 📍')),
                            );
                            return;
                          }

                          final finalAddr = savedAddressesList[selectedIndex]['address'].toString().trim();

                          if (context.mounted) {
                            Navigator.pop(ctx, finalAddr);
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Deliver to this Address 🚚',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _placeBillOrder() async {
    if (_cartItems.isEmpty) return;

    final custMobile = await _getEffectiveCustomerMobile();

    // Show Delivery Address Selection BottomSheet
    final String? chosenAddress = await _showAddressSelectionBottomSheet(custMobile);
    if (chosenAddress == null || chosenAddress.trim().isEmpty) {
      return;
    }

    final nextOrderId = await AuthService.getNextGlobalOrderId(_sellerUsername, customerMobile: custMobile);
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final currentUser = await AuthService.getCurrentUser();

    final customer = widget.customer ?? currentUser ??
        UserModel(
          id: 'cust_default',
          name: 'Customer',
          mobile: custMobile.isNotEmpty ? custMobile : '9999999999',
          role: UserRole.customer,
        );

    final totalCount = CartService.getTotalCount(_cartItems);
    final totalAmount = CartService.getTotalAmount(_cartItems);

    final orderData = {
      'order_id': nextOrderId,
      'seller_username': _sellerUsername,
      'seller_name': widget.seller.name ?? 'Store',
      'seller_mobile': widget.seller.mobile ?? '',
      'customer_name': customer.name ?? 'Customer',
      'customer_mobile': custMobile.isNotEmpty ? custMobile : (customer.mobile ?? '').trim(),
      'delivery_address': chosenAddress.trim(),
      'address': chosenAddress.trim(),
      'items': List.from(_cartItems),
      'total_amount': totalAmount,
      'total_count': totalCount,
      'status': 'PENDING',
      'date': formattedDate,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 1. Save Placed Order in MySQL Server Database
    final savedOrder = await AuthService.saveCustomerPlacedOrder(orderData);
    final finalOrderData = savedOrder ?? orderData;

    // 2. Clear Active Cart
    await CartService.clearCart(_sellerUsername);

    if (!mounted) return;

    // 3. Push OrderSuccessScreen Celebration Screen with MySQL Order ID!
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          order: finalOrderData,
          customer: customer,
        ),
      ),
    );

    // 4. On Return from Success Page -> Switch to Placed Orders History view!
    if (mounted) {
      setState(() {
        _showHistoryTab = true;
      });
      _loadCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = CartService.getTotalCount(_cartItems);
    final totalAmount = CartService.getTotalAmount(_cartItems);
    final sellerName = widget.seller.name ?? 'Store Catalog';
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'My Orders & Bill 🧾',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          if (!_showHistoryTab && _cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFFCA5A5)),
              tooltip: 'Clear Bill',
              onPressed: _clearBill,
            ),
        ],
      ),
      body: Column(
        children: [
          // Top View Switcher Segment Tabs (Draft Bill vs Order History)
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showHistoryTab = _isSellerMode ? true : false;
                          _hasUserToggledTab = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (_isSellerMode ? _showHistoryTab : !_showHistoryTab)
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSellerMode
                                ? 'Customer Orders (${_placedOrders.length})'
                                : 'Current Draft Bill (${_cartItems.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: (_isSellerMode ? _showHistoryTab : !_showHistoryTab)
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showHistoryTab = _isSellerMode ? false : true;
                          _hasUserToggledTab = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: (_isSellerMode ? !_showHistoryTab : _showHistoryTab)
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isSellerMode
                                ? 'My Draft Bill (${_cartItems.length})'
                                : 'Order History (${_placedOrders.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: (_isSellerMode ? !_showHistoryTab : _showHistoryTab)
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Chips (All, Pending, Delivered, Cancelled) when viewing Order History
          if (_showHistoryTab) _buildFilterChipsRow(),

          // Main Body View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : _showHistoryTab
                    ? _buildOrderHistoryView()
                    : _cartItems.isEmpty
                        ? _buildEmptyCartView()
                        : _buildDraftBillView(totalCount, totalAmount, sellerName, formattedDate),
          ),
        ],
      ),
    );
  }

  /// Filter Chips Row (All, Pending, Delivered, Cancelled)
  Widget _buildFilterChipsRow() {
    int pendingCount = 0;
    int deliveredCount = 0;
    int cancelledCount = 0;

    for (var o in _placedOrders) {
      final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
      final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
      final isDelivered = st == 'DELIVERED' || delSt == 'DELIVERED';
      final isCancelled = st == 'CANCELLED' || st == 'DELETED';

      if (isDelivered) {
        deliveredCount++;
      } else if (isCancelled) {
        cancelledCount++;
      } else {
        pendingCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _buildFilterChip('all', 'All', _placedOrders.length, const Color(0xFF64748B)),
          const SizedBox(width: 5),
          _buildFilterChip('pending', 'Pending', pendingCount, const Color(0xFFD97706)),
          const SizedBox(width: 5),
          _buildFilterChip('delivered', 'Delivered', deliveredCount, const Color(0xFF059669)),
          const SizedBox(width: 5),
          _buildFilterChip('cancelled', 'Cancelled', cancelledCount, const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count, Color activeColor) {
    final bool isSelected = _sellerOrderFilter.toLowerCase() == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _sellerOrderFilter = key;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Get Filtered Orders according to _sellerOrderFilter
  List<Map<String, dynamic>> _getFilteredOrders() {
    final filter = _sellerOrderFilter.toLowerCase();
    if (filter == 'pending') {
      return _placedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        final isDelivered = st == 'DELIVERED' || delSt == 'DELIVERED';
        final isCancelled = st == 'CANCELLED' || st == 'DELETED';
        return !isDelivered && !isCancelled;
      }).toList();
    } else if (filter == 'delivered') {
      return _placedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        return st == 'DELIVERED' || delSt == 'DELIVERED';
      }).toList();
    } else if (filter == 'cancelled') {
      return _placedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        return st == 'CANCELLED' || st == 'DELETED';
      }).toList();
    }
    return _placedOrders; // 'all'
  }

  /// Empty Cart State View
  Widget _buildEmptyCartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.receipt_long_rounded, size: 40, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Draft Bill is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap any item in the Store Products catalog to add items to your bill!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            if (_placedOrders.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showHistoryTab = true;
                  });
                },
                icon: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                label: Text('View ${_placedOrders.length} Placed Orders History', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Active Draft Bill Receipt View
  Widget _buildDraftBillView(int totalCount, double totalAmount, String sellerName, String formattedDate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // E-Commerce Bill Format Container (Receipt Card)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Bill Top Header with Order Hierarchy Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Invoice Date: $formattedDate',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tax Invoice',
                          style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Items Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF1F5F9),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('ITEM NAME & UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                // Items List Rows inside Bill
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, idx) {
                    final item = _cartItems[idx];
                    final name = (item['name'] ?? '').toString();
                    final unit = (item['unit'] ?? 'Pcs').toString();
                    final qty = (item['qty'] as num?)?.toInt() ?? 1;
                    final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                    final amt = (item['amount'] as num?)?.toDouble() ?? (rate * qty);
                    final img = (item['image'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          // Item Image & Name
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildProductImageWidget(img, emojiSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Quantity Controls (- 1 +)
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => _updateItemQty(idx, qty - 1),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Icon(Icons.remove, size: 14, color: Color(0xFF475569)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _updateItemQty(idx, qty + 1),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Amount & Delete Button
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${amt % 1 == 0 ? amt.toInt() : amt.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669)),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _removeItem(idx),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Icon(Icons.close, size: 15, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Divider(height: 1),

                // Bill Footer Calculation Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Items Count ($totalCount)', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text('₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Delivery Charges', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          Text('FREE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL BILL AMOUNT',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send Order / Place Bill Button
          ElevatedButton.icon(
            onPressed: _placeBillOrder,
            icon: const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(
              'Place Order & Send Bill (₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Placed Orders History View with Order Numbers & Status
  Widget _buildOrderHistoryView() {
    final filteredOrders = _getFilteredOrders();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF1F5F9),
                child: Icon(_isSellerMode ? Icons.shopping_bag_rounded : Icons.history_rounded, size: 36, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Text(
                _isSellerMode
                    ? (_placedOrders.isEmpty ? 'No Customer Orders Yet 🛍️' : 'No ${_sellerOrderFilter.toUpperCase()} Orders 🛍️')
                    : 'No Order History Yet',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                _isSellerMode
                    ? (_placedOrders.isEmpty
                        ? 'When customers place orders with your store, their order details & receipts will appear here!'
                        : 'No orders match the selected "${_sellerOrderFilter.toUpperCase()}" filter.')
                    : 'Once you place an order, all your sequential order receipts will appear here!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredOrders.length,
      itemBuilder: (ctx, idx) {
        final order = filteredOrders[idx];
        final orderId = (order['order_id'] ?? order['id'] ?? '#DM-1001').toString();
        final sellerName = (order['seller_name'] ?? 'Store').toString();
        final custName = (order['customer_name'] ?? order['name'] ?? 'Customer').toString();
        final custMobile = (order['customer_mobile'] ?? order['mobile'] ?? '').toString();
        final status = (order['order_status'] ?? order['status'] ?? 'PENDING').toString().toUpperCase();
        final dateStr = (order['date'] ?? order['created_at'] ?? '').toString();
        final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? (order['amount'] as num?)?.toDouble() ?? 0.0;
        final totalCount = (order['total_count'] as num?)?.toInt() ?? (order['count'] as num?)?.toInt() ?? 0;

        List<Map<String, dynamic>> items = [];
        if (order['items'] is List) {
          items = List<Map<String, dynamic>>.from(order['items']);
        } else if (order['items_json'] != null) {
          try {
            final decoded = jsonDecode(order['items_json'].toString());
            if (decoded is List) {
              items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          } catch (_) {}
        }

        final bool isDelivered = status == 'DELIVERED' ||
            (order['delivery_status'] ?? '').toString().toUpperCase() == 'DELIVERED';
        final bool isCancelled = status == 'CANCELLED' || status == 'DELETED';
        final bool isReady = status == 'READY';

        final String pickedUpAt = (order['picked_up_at'] ?? order['pickup_time'] ?? '').toString().trim();
        final String deliveredAt = (order['delivered_at'] ?? order['delivered_time'] ?? '').toString().trim();
        final String cancelledAt = (order['cancelled_at'] ?? order['cancel_time'] ?? order['cancelled_time'] ?? order['updated_at'] ?? order['created_at'] ?? order['date'] ?? '').toString().trim();
        final String deliveryAddress = (order['delivery_address'] ?? order['address'] ?? order['cust_address'] ?? '').toString().trim();
        final bool isPickedUpOrBeyond = pickedUpAt.isNotEmpty ||
            (order['delivery_status'] ?? '').toString().toLowerCase() == 'picked up' ||
            isDelivered;

        final String msgText = (order['message'] ?? '').toString().trim().toLowerCase();
        String rawUtr = (order['payment_utr'] ?? order['utr'] ?? order['utr_number'] ?? order['txn_id'] ?? order['transaction_id'] ?? order['razorpay_payment_id'] ?? order['payment_id'] ?? '').toString().trim();
        final String payMode = (order['payment_mode_display'] ?? order['payment_mode'] ?? order['payment_type'] ?? order['payment_method'] ?? '').toString().trim().toLowerCase();
        final String payStatus = (order['payment_status_display'] ?? order['payment_status'] ?? '').toString().trim().toLowerCase();

        if (rawUtr.isEmpty && msgText.isNotEmpty) {
          final utrMatch = RegExp(r'(?:UTR|Txn|Transaction ID|Payment ID|Razorpay ID|Ref):\s*([A-Za-z0-9_]+)', caseSensitive: false).firstMatch(order['message'].toString());
          if (utrMatch != null) {
            rawUtr = utrMatch.group(1)!.trim();
          } else {
            final payMatch = RegExp(r'\b(pay_[A-Za-z0-9]+)\b').firstMatch(order['message'].toString());
            if (payMatch != null) {
              rawUtr = payMatch.group(1)!.trim();
            }
          }
        }

        final bool isExplicitCash = payMode == 'cash' ||
            payMode == 'cod' ||
            payMode == 'cash on delivery' ||
            rawUtr.toLowerCase() == 'cash';

        final bool isExplicitOnline = (rawUtr.isNotEmpty && rawUtr.toLowerCase() != 'cash' && rawUtr.toLowerCase() != 'null') ||
            payMode.contains('online') ||
            payMode.contains('upi') ||
            payMode.contains('razorpay') ||
            payMode.contains('card') ||
            payMode.contains('netbanking') ||
            payMode.contains('wallet') ||
            payMode.contains('paytm') ||
            payMode.contains('phonepe') ||
            payMode.contains('gpay') ||
            msgText.contains('online') ||
            msgText.contains('upi') ||
            msgText.contains('razorpay') ||
            msgText.contains('paid online');

        String utrDisplay = 'Cash';
        if (rawUtr.isNotEmpty && rawUtr.toLowerCase() != 'null' && rawUtr.toLowerCase() != 'cash') {
          utrDisplay = rawUtr;
        } else if (isExplicitOnline && !isExplicitCash) {
          utrDisplay = 'Online (Paid)';
        } else {
          utrDisplay = 'Cash';
        }

        final cardWidget = Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Card Header (Order ID & Status Badge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          orderId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (status == 'DELIVERED' || status == 'READY')
                            ? const Color(0xFFDCFCE7)
                            : (status == 'CANCELLED' || status == 'DELETED' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: (status == 'DELIVERED' || status == 'READY')
                              ? const Color(0xFF15803D)
                              : (status == 'CANCELLED' || status == 'DELETED' ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Order Details (Store/Customer Name, Date, Items & Total)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _isSellerMode
                                ? '$custName ${custMobile.isNotEmpty ? '($custMobile)' : ''}'
                                : sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                        if (_isSellerMode && custMobile.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final Uri phoneUri = Uri.parse('tel:$custMobile');
                              try {
                                if (await canLaunchUrl(phoneUri)) {
                                  await launchUrl(phoneUri);
                                }
                              } catch (_) {}
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFDCFCE7).withValues(alpha: 0.85),
                                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.phone_in_talk_rounded,
                                size: 17,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFE11D48)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Address: $deliveryAddress',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (items.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            // Bill Table Header Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(flex: 5, child: Text('ITEM NAME & UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF475569)))),
                                  Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF475569)))),
                                ],
                              ),
                            ),
                            // Items Rows inside Table
                            ...List.generate(items.length, (iIdx) {
                              final it = items[iIdx];
                              final iName = (it['name'] ?? it['text'] ?? 'Item').toString().trim();
                              final iQty = (it['qty'] as num?)?.toInt() ?? 1;
                              final iUnit = (it['unit'] ?? 'Pcs').toString().trim();
                              final iRate = (it['rate'] ?? it['price'] ?? 0.0 as num).toDouble();
                              final iAmt = (it['amount'] as num?)?.toDouble() ?? (iRate > 0 ? (iRate * iQty) : 0.0);

                              return Column(
                                children: [
                                  if (iIdx > 0) const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    child: Row(
                                      children: [
                                        // Item Name & Unit Rate
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                iName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF0F172A)),
                                              ),
                                              if (iRate > 0)
                                                Text(
                                                  '₹${iRate % 1 == 0 ? iRate.toInt() : iRate.toStringAsFixed(2)} / $iUnit',
                                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // QTY & Unit
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            '$iQty $iUnit',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF334155)),
                                          ),
                                        ),
                                        // Amount
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            iAmt > 0
                                                ? '₹${iAmt % 1 == 0 ? iAmt.toInt() : iAmt.toStringAsFixed(2)}'
                                                : '-',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF059669)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount ${items.isNotEmpty ? '(${items.length} Items)' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isCancelled) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 15),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Reason: ${order['cancel_reason'] ?? order['cancellation_reason'] ?? 'Cancelled'}',
                                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 10.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            if (cancelledAt.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, color: Color(0xFFDC2626), size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Cancelled: $cancelledAt',
                                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else if (isDelivered) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                                        SizedBox(width: 5),
                                        Text(
                                          'Order Delivered 🛵✔️',
                                          style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    if (_isSellerMode && custMobile.isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (ctx) => SellerChatScreen(
                                                seller: widget.seller,
                                                customerMobile: custMobile,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF16A34A)),
                                              SizedBox(width: 3),
                                              Text('Chat 💬', style: TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const Divider(height: 12, color: Color(0xFFDCFCE7)),
                                if (isPickedUpOrBeyond) ...[
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/images/Pickup_boy.png',
                                        width: 18,
                                        height: 18,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF9333EA)),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Picked Up: ${pickedUpAt.isNotEmpty ? pickedUpAt : dateStr}',
                                          style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 10.5, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/Deliverd_boy.png',
                                      width: 18,
                                      height: 18,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.task_alt_rounded, size: 16, color: Color(0xFF15803D)),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Delivered: ${deliveredAt.isNotEmpty ? deliveredAt : dateStr}',
                                        style: const TextStyle(color: Color(0xFF15803D), fontSize: 10.5, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_rounded, size: 15, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Payment / UTR: $utrDisplay',
                                      style: const TextStyle(color: Color(0xFF0369A1), fontSize: 10.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // VERIFIED STAMP PNG (Positioned on the right side inside green delivered box!)
                            Positioned(
                              right: 0,
                              bottom: -2,
                              child: IgnorePointer(
                                child: Transform.rotate(
                                  angle: -0.15,
                                  child: Image.asset(
                                    'assets/images/VERIFIDE.png',
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 14),
                                          SizedBox(width: 3),
                                          Text(
                                            'VERIFIED',
                                            style: TextStyle(
                                              color: Color(0xFF15803D),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPickedUpOrBeyond && !isDelivered) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.delivery_dining_rounded, color: Color(0xFF9333EA), size: 16),
                                SizedBox(width: 5),
                                Text(
                                  'Order Picked Up 🛵💨',
                                  style: TextStyle(color: Color(0xFF7E22CE), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const Divider(height: 12, color: Color(0xFFE9D5FF)),
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/Pickup_boy.png',
                                  width: 18,
                                  height: 18,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.delivery_dining_rounded, size: 16, color: Color(0xFF9333EA)),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Picked Up: ${pickedUpAt.isNotEmpty ? pickedUpAt : dateStr}',
                                    style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 10.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_isSellerMode) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'PICKED UP 🛵 (Out for Delivery)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => SellerChatScreen(
                                      seller: widget.seller,
                                      customerMobile: custMobile,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 38,
                                width: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                ),
                                child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Color(0xFF8B5CF6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else if (_isSellerMode) ...[
                      Row(
                        children: [
                          // 1. Ready Button
                          Expanded(
                            flex: 4,
                            child: ElevatedButton.icon(
                              onPressed: isReady
                                  ? null
                                  : () => _markOrderAsReady(order),
                              icon: Icon(
                                isReady ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              label: Text(
                                isReady ? 'READY ✔️' : 'Ready 📦',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReady ? const Color(0xFF059669) : const Color(0xFF10B981),
                                disabledBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 2. Cancel Button
                          Expanded(
                            flex: 4,
                            child: ElevatedButton.icon(
                              onPressed: () => _showCancelOrderDialog(order),
                              icon: const Icon(Icons.cancel_outlined, size: 15, color: Colors.white),
                              label: const Text(
                                'Cancel ❌',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 3. Chat Button
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => SellerChatScreen(
                                    seller: widget.seller,
                                    customerMobile: custMobile,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Color(0xFF8B5CF6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          'Order Placed: $dateStr',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return cardWidget;
      },
    );
  }

  /// Mark Order as Ready & Notify Customer + Delivery Boys
  Future<void> _markOrderAsReady(Map<String, dynamic> order) async {
    final rawMsgId = order['id'] ?? order['message_id'];
    final msgId = int.tryParse(rawMsgId.toString()) ?? 0;
    final custMobile = (order['customer_mobile'] ?? order['mobile'] ?? '').toString().trim();
    final custName = (order['customer_name'] ?? order['name'] ?? 'Customer').toString().trim();
    final orderIdStr = (order['order_id'] ?? '#DM-1001').toString();

    if (msgId == 0) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marking $orderIdStr as READY... 📦'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF10B981),
      ),
    );

    // 1. Update order status to 'Ready'
    await AuthService.updateOrderStatus(messageId: msgId, orderStatus: 'Ready');

    // 2. Notify customer & delivery boys
    await NotificationService.notifyOrderReady(
      customerMobile: custMobile,
      sellerUsername: _sellerUsername,
      sellerName: widget.seller.name ?? _sellerUsername,
      orderId: orderIdStr,
    );

    // 3. Reload cart & orders list
    await _loadCart();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $orderIdStr is READY! Added to Delivery Boy list 📦✔️'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  /// Cancel Order Dialog with Preset & Custom Reasons
  Future<void> _showCancelOrderDialog(Map<String, dynamic> order) async {
    final rawMsgId = order['id'] ?? order['message_id'];
    final msgId = int.tryParse(rawMsgId.toString()) ?? 0;
    final custMobile = (order['customer_mobile'] ?? order['mobile'] ?? '').toString().trim();
    final custName = (order['customer_name'] ?? order['name'] ?? 'Customer').toString().trim();
    final orderIdStr = (order['order_id'] ?? '#DM-1001').toString();

    final reasonController = TextEditingController();
    String selectedReasonChip = 'Item Out of Stock';

    final presetReasons = [
      'Item Out of Stock',
      'Store Closed Today',
      'Delivery Address Out of Reach',
      'Customer Cancel Request',
    ];

    reasonController.text = selectedReasonChip;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancel Order $orderIdStr',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select cancellation reason for $custName:',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presetReasons.map((r) {
                        final isSel = selectedReasonChip == r;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedReasonChip = r;
                              reasonController.text = r;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              r,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? const Color(0xFFB91C1C) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter reason here...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Back', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (reasonController.text.trim().isEmpty) {
                      reasonController.text = selectedReasonChip;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirm Cancel ❌', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && msgId != 0) {
      final finalReason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Cancelled by store seller';

      // 1. Cancel order with reason
      await AuthService.cancelOrderWithReason(
        sellerUsername: _sellerUsername,
        customerMobile: custMobile,
        messageId: msgId,
        reason: finalReason,
      );

      // 2. Notify customer
      await NotificationService.notifyCustomerOrderCancelled(
        customerMobile: custMobile,
        sellerName: widget.seller.name ?? _sellerUsername,
        orderId: orderIdStr,
        reason: finalReason,
      );

      // 3. Reload cart & orders
      await _loadCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $orderIdStr Cancelled ($finalReason) ❌'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
