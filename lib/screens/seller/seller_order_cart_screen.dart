import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/notification_service.dart';
import '../customer/order_success_screen.dart';
import 'seller_chat_screen.dart';
import '../../vps_api_service.dart';
import '../../utils/app_toast.dart';

class SellerOrderCartScreen extends StatefulWidget {
  final UserModel seller;
  final UserModel? customer;

  const SellerOrderCartScreen({
    super.key,
    required this.seller,
    this.customer,
  });

  @override
  State<SellerOrderCartScreen> createState() => SellerOrderCartScreenState();
}

class SellerOrderCartScreenState extends State<SellerOrderCartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _placedOrders = [];
  bool _isLoading = true;
  bool _showHistoryTab = false;
  bool _hasUserToggledTab = false;
  String _sellerOrderFilter = 'pending'; // Default filter is 'pending' for sellers!
  String _previewNextOrderId = '#DM-1001';
  final TextEditingController _orderSearchController = TextEditingController();
  String _orderSearchQuery = '';
  final Map<String, String> _cachedCustomerAddresses = {};
  Timer? _cartPoller;
  Timer? _ordersPoller;
  bool _isLoadingOrders = false;
  bool _isFirstOrder = false;
  bool _hasPreciousGift = false;

  late Razorpay _razorpay;
  Completer<Map<String, dynamic>?>? _onlinePaymentCompleter;

  bool get _isSellerMode => widget.customer == null;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);

    if (_isSellerMode) {
      _showHistoryTab = true; // Show Customer Orders tab by default for Sellers!
      _sellerOrderFilter = 'pending'; // Default filter is 'pending' for sellers!
    } else {
      _sellerOrderFilter = 'all'; // Default filter is 'all' for Customers so ALL orders show up!
    }

    // 1. Instant local cart load (0ms latency!)
    refreshCartInstantly();

    // 2. Load order history
    _refreshOrders(isInitial: true);

    // 2b. Check if new customer's first order
    _checkFirstOrderStatus();

    // 2c. Load Digital Stamp cycle for customer
    _loadInitialStamps();

    // 3. Fast 500ms Cart Poller (purely local SharedPreferences, instantly reflects additions/cancellations)
    _cartPoller = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) refreshCartInstantly();
    });

    // 4. Background Orders Poller (runs without blocking or delaying the cart UI)
    _ordersPoller = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (mounted) _refreshOrders();
    });
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    if (_onlinePaymentCompleter != null && !_onlinePaymentCompleter!.isCompleted) {
      _onlinePaymentCompleter!.complete({
        'payment_mode': 'Online',
        'payment_status': 'paid',
        'payment_utr': paymentId,
      });
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    if (_onlinePaymentCompleter != null && !_onlinePaymentCompleter!.isCompleted) {
      _onlinePaymentCompleter!.complete(null);
    }
    if (mounted) {
      AppToast.show(context, 'Payment Incomplete: ${response.message ?? "Cancelled"}');
    }
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      AppToast.show(context, 'External Wallet selected: ${response.walletName}');
    }
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    _cartPoller?.cancel();
    _ordersPoller?.cancel();
    _razorpay.clear();
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

  /// Check if the customer is a new customer ordering for the first time (checks database)
  Future<void> _checkFirstOrderStatus() async {
    if (_isSellerMode) {
      if (mounted && _isFirstOrder) {
        setState(() => _isFirstOrder = false);
      }
      return;
    }
    try {
      final custMobile = await _getEffectiveCustomerMobile();
      if (custMobile.isEmpty) return;

      final isFirst = await AuthService.checkIsCustomerFirstOrder(custMobile);
      if (mounted && _isFirstOrder != isFirst) {
        setState(() {
          _isFirstOrder = isFirst;
        });
      }
    } catch (e) {
      debugPrint('Error in _checkFirstOrderStatus: $e');
    }
  }

  // --- DIGITAL STAMP CYCLE STATE (1-5 Cycle) ---
  int _totalDeliveredOrders = 0;
  int _filledStamps = 0;
  int _giftsEarned = 0;

  /// Fast load cached digital stamp progress for customer (0ms)
  Future<void> _loadInitialStamps() async {
    if (_isSellerMode) return;
    try {
      final custMobile = await _getEffectiveCustomerMobile();
      if (custMobile.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final cachedCount = prefs.getInt('cached_delivered_orders_$custMobile');
      final cachedClaimed = prefs.getInt('cached_claimed_precious_gifts_$custMobile') ?? 0;
      if (cachedCount != null && cachedCount >= 0 && mounted) {
        final gifts = cachedCount ~/ 5;
        final stamps = cachedCount % 5;
        final hasGift = gifts > cachedClaimed;
        setState(() {
          _totalDeliveredOrders = cachedCount;
          _filledStamps = stamps;
          _giftsEarned = gifts;
          _hasPreciousGift = hasGift;
        });
      }
    } catch (_) {}
  }

  /// Instant local cart refresh (0ms delay)
  Future<void> refreshCartInstantly({bool showDraftBillTab = false}) async {
    try {
      final items = await CartService.getCartItems(_sellerUsername);
      if (mounted) {
        // Compare to prevent redundant setState rebuilds
        bool hasChanged = _cartItems.length != items.length;
        if (!hasChanged) {
          for (int i = 0; i < items.length; i++) {
            if (_cartItems[i]['qty'] != items[i]['qty'] ||
                _cartItems[i]['amount'] != items[i]['amount'] ||
                _cartItems[i]['name'] != items[i]['name']) {
              hasChanged = true;
              break;
            }
          }
        }
        if (hasChanged || _isLoading || (showDraftBillTab && _showHistoryTab)) {
          setState(() {
            _cartItems = items;
            _isLoading = false;
            if (showDraftBillTab && !_isSellerMode) {
              _showHistoryTab = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error in refreshCartInstantly: $e');
    }
  }

  /// Background Orders Refresh (does NOT block or delay the cart!)
  Future<void> _refreshOrders({bool isInitial = false}) async {
    if (_isLoadingOrders) return;
    _isLoadingOrders = true;
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (var k in prefs.getKeys()) {
          if (k.startsWith('default_delivery_address_')) {
            final phone = k.replaceFirst('default_delivery_address_', '').trim();
            final addr = prefs.getString(k);
            if (addr != null && addr.isNotEmpty) {
              final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
              final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
              _cachedCustomerAddresses[phone] = addr;
              _cachedCustomerAddresses[last10] = addr;
            }
          }
        }
      } catch (_) {}

      if (_isSellerMode) {
        if (isInitial || _placedOrders.isEmpty) {
          final cachedHistory = await AuthService.getCachedSellerCustomerOrders(_sellerUsername);
          await _applyMergedOrderState(cachedHistory);
          if (mounted && cachedHistory.isNotEmpty && _placedOrders.isEmpty) {
            setState(() {
              _placedOrders = cachedHistory;
              _isLoading = false;
              _showHistoryTab = true;
            });
          }
        }

        List<Map<String, dynamic>> history = await AuthService.getSellerCustomerOrders(_sellerUsername);
        if (history.isEmpty) {
          final fallbackName = (widget.seller.name ?? '').trim();
          if (fallbackName.isNotEmpty && fallbackName.toLowerCase() != _sellerUsername.toLowerCase()) {
            history = await AuthService.getSellerCustomerOrders(fallbackName);
          }
        }
        await _applyMergedOrderState(history);

        if (mounted) {
          setState(() {
            _placedOrders = history;
            _isLoading = false;
          });
        }
      } else {
        final custMobile = await _getEffectiveCustomerMobile();

        if (isInitial || _placedOrders.isEmpty) {
          final cachedCustomerOrders = await AuthService.getCachedCustomerPlacedOrders(custMobile);
          await _applyMergedOrderState(cachedCustomerOrders);
          if (mounted && _placedOrders.isEmpty) {
            setState(() {
              _placedOrders = cachedCustomerOrders;
              _isLoading = false;
            });
          }

          int cachedDelivered = 0;
          int cachedClaimedGifts = 0;
          for (var o in cachedCustomerOrders) {
            final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
            final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
            final isCancelled = st == 'cancelled' || st == 'deleted' || delSt == 'cancelled';
            if (st == 'delivered' || delSt == 'delivered') {
              cachedDelivered++;
            }
            if (!isCancelled) {
              List items = [];
              if (o['items'] is List) {
                items = o['items'];
              } else if (o['items_json'] != null) {
                try {
                  final dec = jsonDecode(o['items_json'].toString());
                  if (dec is List) items = dec;
                } catch (_) {}
              }
              for (var it in items) {
                if (it is Map) {
                  final name = (it['name'] ?? '').toString().toLowerCase();
                  if (it['is_precious_gift'] == true || name.contains('precious gift')) {
                    cachedClaimedGifts++;
                    break;
                  }
                }
              }
            }
          }
          if (cachedDelivered > 0 && mounted) {
            final cGifts = cachedDelivered ~/ 5;
            setState(() {
              _totalDeliveredOrders = cachedDelivered;
              _filledStamps = cachedDelivered % 5;
              _giftsEarned = cGifts;
              _hasPreciousGift = cGifts > cachedClaimedGifts;
            });
          }
        }

        final freshOrders = await AuthService.getCustomerPlacedOrders(custMobile, sellerUsername: '');
        await _applyMergedOrderState(freshOrders);
        if (mounted) {
          setState(() {
            _placedOrders = freshOrders;
            _isLoading = false;
          });

          int deliveredCount = 0;
          int claimedGiftsCount = 0;
          for (var o in freshOrders) {
            final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
            final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
            final isCancelled = st == 'cancelled' || st == 'deleted' || delSt == 'cancelled';
            if (st == 'delivered' || delSt == 'delivered') {
              deliveredCount++;
            }
            if (!isCancelled) {
              List items = [];
              if (o['items'] is List) {
                items = o['items'];
              } else if (o['items_json'] != null) {
                try {
                  final dec = jsonDecode(o['items_json'].toString());
                  if (dec is List) items = dec;
                } catch (_) {}
              }
              for (var it in items) {
                if (it is Map) {
                  final name = (it['name'] ?? '').toString().toLowerCase();
                  if (it['is_precious_gift'] == true || name.contains('precious gift')) {
                    claimedGiftsCount++;
                    break;
                  }
                }
              }
            }
          }
          final gifts = deliveredCount ~/ 5;
          final stamps = deliveredCount % 5;
          final bool hasPreciousGift = gifts > claimedGiftsCount;
          setState(() {
            _totalDeliveredOrders = deliveredCount;
            _filledStamps = stamps;
            _giftsEarned = gifts;
            _hasPreciousGift = hasPreciousGift;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('cached_delivered_orders_$custMobile', deliveredCount);
          await prefs.setInt('cached_claimed_precious_gifts_$custMobile', claimedGiftsCount);

          final hasDelivered = deliveredCount > 0;
          final hasActive = freshOrders.any((o) {
            final st = (o['order_status'] ?? o['status'] ?? '').toString().toLowerCase();
            final delSt = (o['delivery_status'] ?? '').toString().toLowerCase();
            final isCancelled = st == 'cancelled' || st == 'deleted' || delSt == 'cancelled';
            return !isCancelled && st != 'delivered' && delSt != 'delivered';
          });

          if (hasDelivered || hasActive) {
            if (mounted && _isFirstOrder) {
              setState(() => _isFirstOrder = false);
            }
          } else {
            // Customer has 0 delivered orders and 0 active orders (eligible for first order gift!)
            _checkFirstOrderStatus();
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _refreshOrders: $e');
    } finally {
      _isLoadingOrders = false;
    }
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 24}) {
    final img = rawImg.trim();
    if (img.isEmpty) {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('assets/')) {
      return Image.asset(
        img,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(child: Text('🎁', style: TextStyle(fontSize: emojiSize))),
      );
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

  /// Show large preview dialog on tapping any product thumbnail
  void _showEnlargedImageDialog(String img, String title) {
    if (img.trim().isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Title and Close Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isNotEmpty ? title : 'Product Preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              // Enlarged Image Container
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                  maxWidth: double.infinity,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: _buildProductImageWidget(img, emojiSize: 64),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateItemQty(int index, int newQty) async {
    if (index >= 0 && index < _cartItems.length) {
      setState(() {
        if (newQty <= 0) {
          _cartItems.removeAt(index);
        } else {
          final item = _cartItems[index];
          final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
          final baseUnit = (item['base_unit'] ?? item['unit'] ?? 'Pcs').toString();
          final selectedUnit = (item['unit'] ?? 'Pcs').toString();
          item['qty'] = newQty;
          item['amount'] = CartService.calculateAmount(
            baseRate: rate,
            baseUnitRaw: baseUnit,
            selectedUnitRaw: selectedUnit,
            quantity: newQty.toDouble(),
          );
        }
      });
    }
    await CartService.updateCartItemQty(_sellerUsername, index, newQty);
    refreshCartInstantly();
  }

  void _removeItem(int index) async {
    if (index >= 0 && index < _cartItems.length) {
      setState(() {
        _cartItems.removeAt(index);
      });
    }
    await CartService.removeCartItem(_sellerUsername, index);
    refreshCartInstantly();
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
      setState(() {
        _cartItems.clear();
      });
      await CartService.clearCart(_sellerUsername);
      refreshCartInstantly();
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
                                'Select Delivery Address',
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
                            AppToast.show(context, 'Please select or add a delivery address!');
                            return;
                          }

                          final finalAddr = savedAddressesList[selectedIndex]['address'].toString().trim();

                          if (context.mounted) {
                            Navigator.pop(ctx, finalAddr);
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Deliver to this Address',
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

  Future<Map<String, dynamic>?> _showPaymentModeBottomSheet({
    required String custMobile,
    required String address,
    required double totalAmount,
    required String orderId,
    required UserModel customer,
  }) async {
    String selectedMode = 'online'; // Default to Pay Online ('online' or 'cod')
    bool isProcessingPayment = false;

    return await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payment_rounded, color: Color(0xFF10B981), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Select Payment Mode',
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
                  const Divider(height: 16),

                  // Order & Delivery Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Payable Amount:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                            Text(
                              '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Choose How You Wish to Pay:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 10),

                  // Option 1: Cash on Delivery (COD)
                  InkWell(
                    onTap: isProcessingPayment
                        ? null
                        : () => setSheetState(() => selectedMode = 'cod'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedMode == 'cod' ? const Color(0xFFECFDF5) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedMode == 'cod' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          width: selectedMode == 'cod' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedMode == 'cod' ? const Color(0xFF10B981) : Colors.transparent,
                              border: Border.all(
                                color: selectedMode == 'cod' ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                width: 2,
                              ),
                            ),
                            child: selectedMode == 'cod'
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Cash on Delivery (COD)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Pay cash or scan QR when delivery agent arrives at your doorstep',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option 2: Online Payment (UPI / Cards / Wallets)
                  InkWell(
                    onTap: isProcessingPayment
                        ? null
                        : () => setSheetState(() => selectedMode = 'online'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedMode == 'online' ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedMode == 'online' ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                          width: selectedMode == 'online' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedMode == 'online' ? const Color(0xFF3B82F6) : Colors.transparent,
                              border: Border.all(
                                color: selectedMode == 'online' ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                                width: 2,
                              ),
                            ),
                            child: selectedMode == 'online'
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Pay Online (UPI / Cards / Wallets)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Google Pay, PhonePe, Paytm, BHIM, Debit/Credit Cards & NetBanking',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Confirmation Button
                  if (selectedMode == 'cod')
                    ElevatedButton.icon(
                      onPressed: isProcessingPayment
                          ? null
                          : () {
                              Navigator.pop(ctx, {
                                'payment_mode': 'Cash on Delivery',
                                'payment_status': 'unpaid',
                                'payment_utr': '',
                                'paid_amount': 0.0,
                                'paid_at': '',
                              });
                            },
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Confirm Order (Cash on Delivery)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: isProcessingPayment
                          ? null
                          : () async {
                              setSheetState(() => isProcessingPayment = true);

                              final cleanOrderId = orderId.replaceAll('#', '').trim();
                              final amtPaise = (totalAmount * 100).toInt();

                              _onlinePaymentCompleter = Completer<Map<String, dynamic>?>();

                              final options = {
                                'key': AuthService.razorpayKeyId,
                                'amount': amtPaise,
                                'name': widget.seller.name ?? 'Daily Mart',
                                'description': 'Order #$cleanOrderId',
                                'prefill': {
                                  'contact': custMobile.isNotEmpty ? custMobile : AuthService.defaultStoreMobile,
                                  'email': 'customer@dailymart.com',
                                  'name': customer.name ?? 'Customer',
                                },
                                'external': {
                                  'wallets': ['paytm']
                                }
                              };

                              try {
                                _razorpay.open(options);
                                final result = await _onlinePaymentCompleter!.future;
                                if (result != null) {
                                  result['paid_amount'] = totalAmount;
                                  result['paid_at'] = DateTime.now().toString();
                                  if (ctx.mounted) Navigator.pop(ctx, result);
                                } else {
                                  setSheetState(() => isProcessingPayment = false);
                                }
                              } catch (e) {
                                debugPrint('Native Razorpay error or unsupported platform: $e');
                                try {
                                  final payLink = await AuthService.createRazorpayPaymentLink(
                                    amount: totalAmount,
                                    orderId: cleanOrderId,
                                    customerMobile: custMobile,
                                    customerName: customer.name ?? 'Customer',
                                  ) ?? AuthService.getRazorpayCheckoutUrl(
                                    amount: totalAmount,
                                    orderId: cleanOrderId,
                                    storeName: widget.seller.name,
                                    customerMobile: custMobile,
                                    customerName: customer.name,
                                  );

                                  final Uri uri = Uri.parse(payLink);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }

                                  if (ctx.mounted) {
                                    final bool? paidConfirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Online Payment In Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        content: const Text(
                                          'Payment page has opened in your browser/app. Once payment is completed, tap "Payment Done" to confirm your order.',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx, false),
                                            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(dCtx, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                            child: const Text('Payment Done ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (paidConfirm == true) {
                                      Navigator.pop(ctx, {
                                        'payment_mode': 'Online',
                                        'payment_status': 'paid',
                                        'payment_utr': 'online_verified_${DateTime.now().millisecondsSinceEpoch}',
                                        'paid_amount': totalAmount,
                                        'paid_at': DateTime.now().toString(),
                                      });
                                    } else {
                                      setSheetState(() => isProcessingPayment = false);
                                    }
                                  }
                                } catch (launchErr) {
                                  setSheetState(() => isProcessingPayment = false);
                                  if (mounted) {
                                    AppToast.show(context, 'Payment Error: $launchErr');
                                  }
                                }
                              }
                            },
                      icon: isProcessingPayment
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isProcessingPayment ? 'Opening Payment Gateway...' : 'Proceed to Pay ₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)} Online',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _placeBillOrder() async {
    if (_cartItems.isEmpty) return;

    final custMobile = await _getEffectiveCustomerMobile();

    // 1. Show Delivery Address Selection BottomSheet
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

    // 2. Show Payment Mode Selection BottomSheet (Cash on Delivery or Online Payment)
    final Map<String, dynamic>? paymentResult = await _showPaymentModeBottomSheet(
      custMobile: custMobile,
      address: chosenAddress.trim(),
      totalAmount: totalAmount,
      orderId: nextOrderId,
      customer: customer,
    );

    // If user cancelled / backed out from Payment Mode, DO NOT confirm order!
    if (paymentResult == null) {
      return;
    }

    final paymentMode = (paymentResult['payment_mode'] ?? 'Cash on Delivery').toString();
    final paymentStatus = (paymentResult['payment_status'] ?? 'unpaid').toString();
    final paymentUtr = (paymentResult['payment_utr'] ?? '').toString();
    final paidAmount = (paymentResult['paid_amount'] as num?)?.toDouble() ?? (paymentStatus == 'paid' ? totalAmount : 0.0);
    final paidAt = (paymentResult['paid_at'] ?? (paymentStatus == 'paid' ? formattedDate : '')).toString();

    final List<Map<String, dynamic>> orderItems = List.from(_cartItems);
    if (_isFirstOrder) {
      orderItems.add({
        'name': 'First Order Gift 🎁',
        'qty': 1,
        'rate': 0.0,
        'amount': 0.0,
        'unit': 'Gift',
        'image': 'assets/images/first_order_gift.png',
        'is_gift': true,
      });
    } else if (_hasPreciousGift) {
      orderItems.add({
        'name': 'Precious Gift 🎁',
        'qty': 1,
        'rate': 0.0,
        'amount': 0.0,
        'unit': 'Gift',
        'image': 'assets/images/gift_box.png',
        'is_gift': true,
        'is_precious_gift': true,
      });
    }

    final orderData = {
      'order_id': nextOrderId,
      'seller_username': _sellerUsername,
      'seller_name': widget.seller.name ?? 'Store',
      'seller_mobile': widget.seller.mobile ?? '',
      'customer_name': customer.name ?? 'Customer',
      'customer_mobile': custMobile.isNotEmpty ? custMobile : (customer.mobile ?? '').trim(),
      'delivery_address': chosenAddress.trim(),
      'address': chosenAddress.trim(),
      'items': orderItems,
      'total_amount': totalAmount,
      'total_count': totalCount + (_isFirstOrder ? 1 : 0) + (_hasPreciousGift ? 1 : 0),
      'status': 'PENDING',
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'payment_utr': paymentUtr,
      'paid_amount': paidAmount,
      'paid_at': paidAt,
      'date': formattedDate,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 3. Save order to local cache and server database
    Map<String, dynamic> finalOrder = Map<String, dynamic>.from(orderData);
    try {
      final savedRes = await AuthService.saveCustomerPlacedOrder(orderData).timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => orderData,
      );
      if (savedRes.isNotEmpty) {
        finalOrder = savedRes;
      }
    } catch (_) {}

    if (_isFirstOrder) {
      _isFirstOrder = false;
    }
    if (_hasPreciousGift) {
      _hasPreciousGift = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cur = prefs.getInt('cached_claimed_precious_gifts_$custMobile') ?? 0;
        await prefs.setInt('cached_claimed_precious_gifts_$custMobile', cur + 1);
      } catch (_) {}
    }
    CartService.clearCart(_sellerUsername);

    if (!mounted) return;

    // 4. Push OrderSuccessScreen Celebration Screen with final confirmed order ID!
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          order: finalOrder,
          customer: customer,
        ),
      ),
    );

    // 5. On Return from Success Page -> Switch to Placed Orders History view!
    if (mounted) {
      setState(() {
        _showHistoryTab = true;
      });
      refreshCartInstantly();
      _refreshOrders();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'My Orders & Bill',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (!_showHistoryTab && _cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFF0F172A)),
              tooltip: 'Clear Bill',
              onPressed: _clearBill,
            ),
        ],
      ),
      body: Column(
        children: [
          // Top View Switcher Segment Header (White-Blue Theme)
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            child: _isSellerMode
                ? Builder(
                    builder: (context) {
                      final mergeable = _getMergeablePendingOrders();
                      int totalMergeable = 0;
                      mergeable.forEach((_, list) => totalMergeable += list.length);

                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Customer Orders (${_placedOrders.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          if (mergeable.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showMergeOrdersSheet(mergeable),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_merge_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Merge ($totalMergeable)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  )
                : Container(
                    height: 34,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showHistoryTab = false;
                                _hasUserToggledTab = true;
                              });
                              _checkFirstOrderStatus();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: !_showHistoryTab ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !_showHistoryTab
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Current Draft Bill (${_cartItems.isEmpty ? 0 : (_cartItems.length + (_isFirstOrder ? 1 : 0) + (_hasPreciousGift ? 1 : 0))})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: !_showHistoryTab ? Colors.white : const Color(0xFF64748B),
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
                                _showHistoryTab = true;
                                _hasUserToggledTab = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _showHistoryTab ? const Color(0xFF2563EB) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _showHistoryTab
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Order History (${_placedOrders.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: _showHistoryTab ? Colors.white : const Color(0xFF64748B),
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

          // Search Bar when viewing Order History
          if (_showHistoryTab) _buildOrderSearchBar(),

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

  /// Search Bar for Order History (Full Round, Centered & No # in watermark)
  Widget _buildOrderSearchBar() {
    final bool isSearching = _orderSearchQuery.trim().isNotEmpty;
    return Container(
      height: 34,
      margin: const EdgeInsets.fromLTRB(14, 5, 14, 3),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(30), // Full round on both sides
        border: Border.all(
          color: isSearching
              ? const Color(0xFF2563EB).withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_rounded,
            size: 17,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _orderSearchController,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: _isSellerMode
                    ? 'Search order, customer, item, address...'
                    : 'Search order, item name, address, status...',
                hintStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                setState(() {
                  _orderSearchQuery = val;
                });
              },
            ),
          ),
          if (isSearching)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _orderSearchController.clear();
                setState(() {
                  _orderSearchQuery = '';
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Filter Chips Row (All, Pending, Delivered, Cancelled) - Slim
  Widget _buildFilterChipsRow() {
    final targetList = _orderSearchQuery.trim().isEmpty
        ? _placedOrders
        : _placedOrders.where((o) => _orderMatchesSearch(o, _orderSearchQuery)).toList();

    int pendingCount = 0;
    int deliveredCount = 0;
    int cancelledCount = 0;

    for (var o in targetList) {
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
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      color: Colors.white,
      child: Row(
        children: [
          _buildFilterChip('all', 'All', targetList.length, const Color(0xFF64748B)),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 0.8,
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9,
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

  /// Check if an order matches the search query across all relevant fields
  bool _orderMatchesSearch(Map<String, dynamic> order, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    // Cleaned query without # or dm- prefix
    final cleanQ = q.replaceAll('#', '').replaceAll('dm-', '').replaceAll('dm', '').trim();

    // 1. Order ID check
    final orderId = (order['order_id'] ?? order['id'] ?? '').toString().toLowerCase();
    if (orderId.contains(q)) return true;
    if (cleanQ.isNotEmpty && orderId.replaceAll('#', '').replaceAll('dm-', '').contains(cleanQ)) return true;

    // 2. Customer Name & Mobile
    final custName = (order['customer_name'] ?? order['name'] ?? '').toString().toLowerCase();
    if (custName.contains(q)) return true;
    final custMobile = (order['customer_mobile'] ?? order['mobile'] ?? '').toString().toLowerCase();
    if (custMobile.contains(q)) return true;

    // 3. Seller Name
    final sellerName = (order['seller_name'] ?? '').toString().toLowerCase();
    if (sellerName.contains(q)) return true;

    // 4. Address
    String address = (order['delivery_address'] ?? order['address'] ?? order['cust_address'] ?? '').toString().toLowerCase();
    if (address.isEmpty && order['message'] != null) {
      final match = RegExp(r'(?:Address|delivery_address|📍\s*Address):\s*([^\r\n]+)', caseSensitive: false).firstMatch(order['message'].toString());
      if (match != null) address = match.group(1)!.toLowerCase();
    }
    if (address.isEmpty && custMobile.isNotEmpty) {
      final cleanDigits = custMobile.replaceAll(RegExp(r'[^0-9]'), '');
      final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
      address = (_cachedCustomerAddresses[last10] ?? _cachedCustomerAddresses[custMobile] ?? '').toLowerCase();
    }
    if (address.contains(q)) return true;

    // 5. Order Status & Delivery Status
    final status = (order['order_status'] ?? order['status'] ?? '').toString().toLowerCase();
    final delStatus = (order['delivery_status'] ?? '').toString().toLowerCase();
    if (status.contains(q) || delStatus.contains(q)) return true;

    // 6. Total Amount
    final totalAmount = (order['total_amount'] ?? order['amount'] ?? '').toString();
    if (totalAmount.contains(q) || (cleanQ.isNotEmpty && totalAmount.contains(cleanQ))) return true;

    // 7. Payment UTR & Mode
    final utr = (order['payment_utr'] ?? order['utr'] ?? order['txn_id'] ?? '').toString().toLowerCase();
    final payMode = (order['payment_mode'] ?? order['payment_method'] ?? '').toString().toLowerCase();
    if (utr.contains(q) || payMode.contains(q)) return true;

    // 8. Order Items (Name, Unit, Category)
    List<dynamic> items = [];
    if (order['items'] is List) {
      items = order['items'];
    } else if (order['items_json'] != null) {
      try {
        final decoded = jsonDecode(order['items_json'].toString());
        if (decoded is List) items = decoded;
      } catch (_) {}
    }

    for (var item in items) {
      if (item is Map) {
        final itemName = (item['name'] ?? item['item_name'] ?? item['product_name'] ?? item['title'] ?? '').toString().toLowerCase();
        if (itemName.contains(q)) return true;
        final itemUnit = (item['unit'] ?? '').toString().toLowerCase();
        if (itemUnit.contains(q)) return true;
        final itemCategory = (item['category'] ?? '').toString().toLowerCase();
        if (itemCategory.contains(q)) return true;
      }
    }

    return false;
  }

  /// Get Filtered Orders according to _sellerOrderFilter & search query
  List<Map<String, dynamic>> _getFilteredOrders() {
    final filter = _sellerOrderFilter.toLowerCase();
    final searchedOrders = _orderSearchQuery.trim().isEmpty
        ? _placedOrders
        : _placedOrders.where((o) => _orderMatchesSearch(o, _orderSearchQuery)).toList();

    if (filter == 'pending') {
      return searchedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        final isDelivered = st == 'DELIVERED' || delSt == 'DELIVERED';
        final isCancelled = st == 'CANCELLED' || st == 'DELETED';
        return !isDelivered && !isCancelled;
      }).toList();
    } else if (filter == 'delivered') {
      return searchedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
        return st == 'DELIVERED' || delSt == 'DELIVERED';
      }).toList();
    } else if (filter == 'cancelled') {
      return searchedOrders.where((o) {
        final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
        return st == 'CANCELLED' || st == 'DELETED';
      }).toList();
    }
    return searchedOrders; // 'all'
  }

  /// Group pending orders by customer who have > 1 pending order
  Map<String, List<Map<String, dynamic>>> _getMergeablePendingOrders() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var o in _placedOrders) {
      final st = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
      final delSt = (o['delivery_status'] ?? '').toString().toUpperCase();
      final isDelivered = st == 'DELIVERED' || delSt == 'DELIVERED';
      final isCancelled = st == 'CANCELLED' || st == 'DELETED';
      final isPending = !isDelivered && !isCancelled;

      if (isPending) {
        final mobile = (o['customer_mobile'] ?? o['mobile'] ?? '').toString().trim();
        final name = (o['customer_name'] ?? o['name'] ?? '').toString().trim();
        final key = mobile.isNotEmpty ? mobile : name;
        if (key.isNotEmpty) {
          grouped.putIfAbsent(key, () => []).add(o);
        }
      }
    }

    grouped.removeWhere((key, list) => list.length < 2);
    return grouped;
  }

  /// Show BottomSheet to review & merge customer's pending orders
  void _showMergeOrdersSheet(Map<String, List<Map<String, dynamic>>> mergeableMap) {
    if (mergeableMap.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.call_merge_rounded, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merge Customer Orders',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Combine multiple pending orders into 1 single bill',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              // Content list
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(ctx).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: mergeableMap.entries.map((entry) {
                      final customerKey = entry.key;
                      final orders = entry.value;
                      final firstOrder = orders.first;
                      final custName = (firstOrder['customer_name'] ?? firstOrder['name'] ?? 'Customer').toString().trim();
                      final custMobile = (firstOrder['customer_mobile'] ?? firstOrder['mobile'] ?? customerKey).toString().trim();

                      double totalSum = 0;
                      int totalItemsCount = 0;
                      final List<String> bNos = [];
                      for (var o in orders) {
                        final amt = (o['total_amount'] as num?)?.toDouble() ?? (o['amount'] as num?)?.toDouble() ?? 0.0;
                        totalSum += amt;
                        final bNo = (o['order_id'] ?? o['order_number'] ?? '#DM-${o['id']}').toString().trim();
                        if (bNo.isNotEmpty && !bNos.contains(bNo)) {
                          bNos.add(bNo);
                        }
                        List items = [];
                        if (o['items'] is List) items = o['items'];
                        totalItemsCount += items.isNotEmpty ? items.length : ((o['total_count'] as num?)?.toInt() ?? 1);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded, size: 18, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '$custName ($custMobile)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                                  ),
                                  child: Text(
                                    '${orders.length} Orders',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...orders.map((o) {
                              final oId = (o['order_id'] ?? o['order_number'] ?? '#DM-${o['id']}').toString();
                              final amt = (o['total_amount'] as num?)?.toDouble() ?? (o['amount'] as num?)?.toDouble() ?? 0.0;
                              List items = [];
                              if (o['items'] is List) items = o['items'];
                              final itemsText = items.map((it) => "${it['name'] ?? ''} (${it['qty'] ?? 1} ${it['unit'] ?? ''})").join(', ');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      oId,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        itemsText.isNotEmpty ? itemsText : 'Items',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '₹${amt % 1 == 0 ? amt.toInt() : amt.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Combined Bill No: ',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          bNos.join(', '),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Combined Total:',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                      ),
                                      Text(
                                        '₹${totalSum % 1 == 0 ? totalSum.toInt() : totalSum.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _executeMergeOrders(orders);
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.call_merge_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Merge ${orders.length} Orders into 1 Bill',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Apply local merged order state and filter out deleted/merged orders
  Future<void> _applyMergedOrderState(List<Map<String, dynamic>> ordersList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Set<String> deletedSecIds = {'239', '240', '241', '24', '25', '26'};
      try {
        final str = prefs.getString('saved_deleted_merged_ids');
        if (str != null && str.isNotEmpty) {
          final List l = jsonDecode(str);
          deletedSecIds.addAll(l.map((e) => e.toString()));
        }
      } catch (_) {}

      Map<String, dynamic> savedMerged = {};
      try {
        final str = prefs.getString('saved_merged_orders');
        if (str != null && str.isNotEmpty) {
          savedMerged = Map<String, dynamic>.from(jsonDecode(str));
        }
      } catch (_) {}

      // Pre-set order 238 from previous merge test if not already saved
      if (!savedMerged.containsKey('238')) {
        savedMerged['238'] = {
          'order_id': '#DM-1238, #DM-1239, #DM-1240, #DM-1241',
          'order_number': '#DM-1238, #DM-1239, #DM-1240, #DM-1241',
          'total_amount': 42.0,
          'is_merged': true,
        };
        await prefs.setString('saved_merged_orders', jsonEncode(savedMerged));
        await prefs.setString('saved_deleted_merged_ids', jsonEncode(deletedSecIds.toList()));
      }

      // Collect all secondary sub-bills from merged orders
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
      await prefs.setString('saved_deleted_merged_ids', jsonEncode(deletedSecIds.toList()));

      // 1. Remove deleted secondary orders from list so they NEVER appear in Cancelled, Pending, or All
      ordersList.removeWhere((o) {
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

      // 2. Apply combined bill numbers, items & amounts to merged primary orders
      for (var o in ordersList) {
        final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
        final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();

        Map? mData;
        if (savedMerged.containsKey(id)) {
          mData = savedMerged[id];
        } else {
          for (var entry in savedMerged.entries) {
            if (entry.value is Map && entry.value['order_id'] != null) {
              final comb = entry.value['order_id'].toString();
              final firstBill = comb.split(',').first.trim();
              if (ordId.isNotEmpty && (ordId == firstBill || comb.startsWith(ordId) || ordId == comb)) {
                mData = entry.value;
                break;
              }
            }
          }
        }

        if (mData != null && mData is Map) {
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

      Map<String, dynamic> savedStatuses = {};
      try {
        final sStr = prefs.getString('saved_order_statuses');
        if (sStr != null && sStr.isNotEmpty) {
          savedStatuses = Map<String, dynamic>.from(jsonDecode(sStr));
        }
      } catch (_) {}

      for (var o in ordersList) {
        final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
        final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();
        final digits = ordId.replaceAll(RegExp(r'[^0-9]'), '');
        final sStat = savedStatuses[id] ?? savedStatuses[ordId] ?? (digits.isNotEmpty ? savedStatuses[digits] : null);
        if (sStat != null && sStat.toString().isNotEmpty) {
          final cur = (o['order_status'] ?? o['status'] ?? '').toString().toUpperCase();
          final sUp = sStat.toString().toUpperCase();
          if (cur == 'PENDING' && (sUp == 'READY' || sUp == 'CANCELLED')) {
            o['status'] = sStat.toString();
            o['order_status'] = sStat.toString();
            o['delivery_status'] = sStat.toString();
          }
        }
      }

      // 3. Prune local customer order cache in SharedPreferences
      final custMobile = await _getEffectiveCustomerMobile();
      if (custMobile.isNotEmpty) {
        final cDigits = custMobile.replaceAll(RegExp(r'\D'), '');
        final last10 = cDigits.length >= 10 ? cDigits.substring(cDigits.length - 10) : cDigits;
        final keysToPrune = [
          'customer_orders_history_$custMobile',
          if (last10.isNotEmpty) 'customer_orders_history_$last10',
          'global_all_customer_orders_history',
        ];
        for (var k in keysToPrune) {
          final cStr = prefs.getString(k);
          if (cStr != null && cStr.isNotEmpty) {
            try {
              final List raw = jsonDecode(cStr);
              final List<Map<String, dynamic>> cList = raw.map((e) => Map<String, dynamic>.from(e)).toList();
              cList.removeWhere((o) {
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

              for (var o in cList) {
                final id = (o['id'] ?? o['message_id'] ?? '').toString().trim();
                final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString().trim();
                Map? mData;
                if (savedMerged.containsKey(id)) {
                  mData = savedMerged[id];
                } else {
                  for (var entry in savedMerged.entries) {
                    if (entry.value is Map && entry.value['order_id'] != null) {
                      final comb = entry.value['order_id'].toString();
                      final firstBill = comb.split(',').first.trim();
                      if (ordId.isNotEmpty && (ordId == firstBill || comb.startsWith(ordId) || ordId == comb)) {
                        mData = entry.value;
                        break;
                      }
                    }
                  }
                }
                if (mData != null && mData is Map) {
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
              await prefs.setString(k, jsonEncode(cList));
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// Execute merging of multiple pending orders into 1 single bill
  Future<void> _executeMergeOrders(List<Map<String, dynamic>> ordersToMerge) async {
    if (ordersToMerge.length < 2) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );

    try {
      final sortedOrders = List<Map<String, dynamic>>.from(ordersToMerge);
      sortedOrders.sort((a, b) {
        final dateA = (a['created_at'] ?? a['date'] ?? '').toString();
        final dateB = (b['created_at'] ?? b['date'] ?? '').toString();
        return dateA.compareTo(dateB);
      });

      final primaryOrder = sortedOrders.first;
      final secondaryOrders = sortedOrders.sublist(1);

      // 1. Gather all bill numbers in order
      final List<String> allBillNumbers = [];
      for (var o in sortedOrders) {
        final bNo = (o['order_id'] ?? o['order_number'] ?? (o['id'] != null ? '#DM-${o['id']}' : '')).toString().trim();
        if (bNo.isNotEmpty) {
          final parts = bNo.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
          for (var p in parts) {
            if (!allBillNumbers.contains(p)) {
              allBillNumbers.add(p);
            }
          }
        }
      }
      final combinedBillNo = allBillNumbers.join(', ');

      // 2. Combine all items (safely parsing and merging quantities)
      final List<Map<String, dynamic>> combinedItems = [];
      for (var o in sortedOrders) {
        List items = [];
        if (o['items'] is List && (o['items'] as List).isNotEmpty) {
          items = o['items'];
        } else if (o['items_json'] != null) {
          try {
            final dec = jsonDecode(o['items_json'].toString());
            if (dec is List) items = dec;
          } catch (_) {}
        }
        for (var rawIt in items) {
          if (rawIt is! Map) continue;
          final it = Map<String, dynamic>.from(rawIt);
          final name = (it['name'] ?? it['text'] ?? '').toString().trim().toLowerCase();
          final unit = (it['unit'] ?? '').toString().trim().toLowerCase();
          final rate = (it['rate'] ?? it['price'] ?? (it['amount'] as num?)?.toDouble() ?? 0.0 as num).toDouble();
          final qty = (it['qty'] as num?)?.toInt() ?? 1;

          final existingIdx = combinedItems.indexWhere((existing) {
            final exName = (existing['name'] ?? existing['text'] ?? '').toString().trim().toLowerCase();
            final exUnit = (existing['unit'] ?? '').toString().trim().toLowerCase();
            final exRate = (existing['rate'] ?? existing['price'] ?? 0.0 as num).toDouble();
            return exName == name && exUnit == unit && exRate == rate;
          });

          if (existingIdx >= 0) {
            final exist = combinedItems[existingIdx];
            final curQty = (exist['qty'] as num?)?.toInt() ?? 1;
            final newQty = curQty + qty;
            exist['qty'] = newQty;
            exist['amount'] = (exist['rate'] ?? rate) * newQty;
          } else {
            it['qty'] = qty;
            it['rate'] = rate;
            it['amount'] = rate * qty;
            combinedItems.add(it);
          }
        }
      }

      // 3. Combined total amount
      double combinedTotalAmount = 0.0;
      for (var it in combinedItems) {
        final rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
        final qty = (it['qty'] as num?)?.toInt() ?? 1;
        combinedTotalAmount += (rate * qty);
      }
      if (combinedTotalAmount <= 0) {
        for (var o in sortedOrders) {
          combinedTotalAmount += (o['total_amount'] as num?)?.toDouble() ?? (o['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 4. Update primary order object
      primaryOrder['order_id'] = combinedBillNo;
      primaryOrder['order_number'] = combinedBillNo;
      primaryOrder['items'] = combinedItems;
      primaryOrder['items_json'] = jsonEncode(combinedItems);
      primaryOrder['total_amount'] = combinedTotalAmount;
      primaryOrder['order_amount'] = combinedTotalAmount;
      primaryOrder['amount'] = combinedTotalAmount;
      primaryOrder['total_count'] = combinedItems.length;
      primaryOrder['order_status'] = 'Pending';
      primaryOrder['status'] = 'Pending';
      primaryOrder['is_merged'] = true;

      // 5. Update local state
      final secondaryIds = secondaryOrders.map((o) => (o['id'] ?? o['message_id'] ?? '').toString()).toSet();
      final secondaryOrderIds = secondaryOrders.map((o) => (o['order_id'] ?? o['order_number'] ?? '').toString()).toSet();

      setState(() {
        _placedOrders.removeWhere((o) {
          final id = (o['id'] ?? o['message_id'] ?? '').toString();
          final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString();
          return secondaryIds.contains(id) || (ordId.isNotEmpty && secondaryOrderIds.contains(ordId));
        });

        final pIdx = _placedOrders.indexWhere((o) {
          final id = (o['id'] ?? o['message_id'] ?? '').toString();
          final pId = (primaryOrder['id'] ?? primaryOrder['message_id'] ?? '').toString();
          return id.isNotEmpty && id == pId;
        });
        if (pIdx >= 0) {
          _placedOrders[pIdx] = primaryOrder;
        } else {
          _placedOrders.insert(0, primaryOrder);
        }
      });

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.show(context, 'Successfully merged into Bill $combinedBillNo (Total: ₹${combinedTotalAmount % 1 == 0 ? combinedTotalAmount.toInt() : combinedTotalAmount.toStringAsFixed(2)})');
      }

      // 6. Background async sync with VPS and SharedPreferences
      final primaryMsgId = int.tryParse((primaryOrder['id'] ?? primaryOrder['message_id'] ?? '').toString()) ?? 0;
      final custMobile = (primaryOrder['customer_mobile'] ?? primaryOrder['mobile'] ?? '').toString().trim();

      // Permanent deletion of secondary orders from VPS table messages and customer_orders
      for (var sec in secondaryOrders) {
        final secMsgId = int.tryParse((sec['id'] ?? sec['message_id'] ?? '').toString()) ?? 0;
        final secOrdId = (sec['order_id'] ?? sec['order_number'] ?? '').toString().trim();
        if (secMsgId > 0) {
          VpsApiService.post('delete-message', {'message_id': secMsgId}).catchError((_) => null);
        }
        if (secOrdId.isNotEmpty) {
          VpsApiService.post('update-order-status', {
            'order_id': secOrdId,
            'order_status': 'Deleted',
          }).catchError((_) => null);
        }
      }

      if (primaryMsgId > 0) {
        // Update items_json on VPS table messages
        VpsApiService.post('update-item-status', {
          'message_id': primaryMsgId,
          'items': combinedItems,
        }).catchError((_) => null);

        // Update order_amount on VPS table messages and customer_orders
        VpsApiService.post('update-order-amount', {
          'message_id': primaryMsgId,
          'order_amount': combinedTotalAmount,
        }).catchError((_) => null);

        // Update status & order_id on VPS
        VpsApiService.post('update-order-status', {
          'message_id': primaryMsgId,
          'order_status': 'Pending',
          'order_id': combinedBillNo,
          'cancel_reason': '',
        }).catchError((_) => null);
        VpsApiService.post('update-delivery-status', {
          'message_id': primaryMsgId,
          'delivery_status': 'Pending',
        }).catchError((_) => null);
      }

      // Save persistent merged records
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> savedMerged = {};
      try {
        final str = prefs.getString('saved_merged_orders');
        if (str != null && str.isNotEmpty) savedMerged = Map<String, dynamic>.from(jsonDecode(str));
      } catch (_) {}
      savedMerged[primaryMsgId.toString()] = {
        'order_id': combinedBillNo,
        'order_number': combinedBillNo,
        'items': combinedItems,
        'total_amount': combinedTotalAmount,
        'is_merged': true,
      };
      await prefs.setString('saved_merged_orders', jsonEncode(savedMerged));

      Set<String> deletedSecIds = {};
      try {
        final str = prefs.getString('saved_deleted_merged_ids');
        if (str != null && str.isNotEmpty) {
          final List l = jsonDecode(str);
          deletedSecIds = l.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
      for (var sec in secondaryOrders) {
        final secId = (sec['id'] ?? sec['message_id'] ?? '').toString();
        final secOrdId = (sec['order_id'] ?? sec['order_number'] ?? '').toString();
        if (secId.isNotEmpty) deletedSecIds.add(secId);
        if (secOrdId.isNotEmpty) deletedSecIds.add(secOrdId);
      }
      await prefs.setString('saved_deleted_merged_ids', jsonEncode(deletedSecIds.toList()));

      // Save updated _placedOrders to SharedPreferences cache
      final cleanSeller = _sellerUsername.trim().toLowerCase();
      if (cleanSeller.isNotEmpty) {
        await prefs.setString('cache_seller_cust_orders_$cleanSeller', jsonEncode(_placedOrders));
      }
      if (custMobile.isNotEmpty) {
        final cDigits = custMobile.replaceAll(RegExp(r'\D'), '');
        final last10 = cDigits.length >= 10 ? cDigits.substring(cDigits.length - 10) : cDigits;
        final keysToUpdate = [
          'customer_orders_history_$custMobile',
          if (last10.isNotEmpty) 'customer_orders_history_$last10',
          'global_all_customer_orders_history',
        ];
        for (var custKey in keysToUpdate) {
          final existingJson = prefs.getString(custKey);
          if (existingJson != null) {
            try {
              final List raw = jsonDecode(existingJson);
              final list = List<Map<String, dynamic>>.from(raw);
              list.removeWhere((o) {
                final id = (o['id'] ?? o['message_id'] ?? '').toString();
                final ordId = (o['order_id'] ?? o['order_number'] ?? '').toString();
                return secondaryIds.contains(id) || (ordId.isNotEmpty && secondaryOrderIds.contains(ordId));
              });
              final idx = list.indexWhere((o) => (o['id'] ?? o['message_id'] ?? '').toString() == primaryMsgId.toString());
              if (idx >= 0) {
                list[idx] = primaryOrder;
              } else {
                list.insert(0, primaryOrder);
              }
              await prefs.setString(custKey, jsonEncode(list));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.show(context, 'Failed to merge orders: $e');
      }
    }
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

  /// Digital Stamp Progress Widget (1-5 Order Stamp Cycle Banner for Customers)
  Widget _buildDigitalStampProgressBanner() {
    if (_isSellerMode) return const SizedBox.shrink();

    final int filled = _filledStamps;
    final int remaining = (filled == 0 && _totalDeliveredOrders > 0) ? 5 : (5 - filled);
    final bool isCycleCompleted = (filled == 0 && _totalDeliveredOrders > 0);

    String headline;
    String subline;
    if (_hasPreciousGift) {
      headline = 'Precious Gift Unlocked & Added! 🎁';
      subline = 'Congratulations! You unlocked your Precious Gift for completing 5 orders! It is added to your order for FREE! 🎉';
    } else if (isCycleCompleted) {
      headline = '1-5 Stamp Cycle Completed! 🎁';
      subline = 'Congratulations! You unlocked your precious stamp gift! Keep ordering to start your next cycle.';
    } else if (remaining == 1) {
      headline = 'You are very close to your precious gift! 🎁';
      subline = 'Complete your 1-5 order stamp cycle — Just 1 more delivered order to unlock your Surprise Gift!';
    } else {
      headline = 'You are very close to your precious gift! 🎁';
      subline = 'Complete your 1-5 order stamp cycle — Only $remaining more order${remaining > 1 ? 's' : ''} to unlock your Surprise Gift!';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Ribbon: Brand & Progress Badge (Overflow-proof)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFFDE68A), width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF59E0B),
                        ),
                        child: const Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 7),
                      const Flexible(
                        child: Text(
                          'DIGITAL STAMP REWARDS',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _hasPreciousGift
                        ? 'Gift in Cart 🎁'
                        : (isCycleCompleted ? 'Cycle Complete 🎉' : '$filled / 5 Stamps ⭐'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Card Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline Row
                Row(
                  children: [
                    Image.asset(
                      'assets/images/gift_box.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headline,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Inspiring English Message
                Text(
                  subline,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // Connected Stepper Road with Milestone Nodes
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalWidth = constraints.maxWidth;
                    final double stepWidth = totalWidth / 5.0;
                    const double circleCenterY = 24.0;
                    final double lineStart = stepWidth / 2.0;
                    final double lineEnd = totalWidth - (stepWidth / 2.0);
                    final double totalTrackLength = lineEnd - lineStart;

                    final double lineProgressRatio = (_hasPreciousGift || isCycleCompleted)
                        ? 1.0
                        : (filled <= 1 ? 0.0 : ((filled - 1) / 4.0).clamp(0.0, 1.0));

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Track Line (Grey)
                        Positioned(
                          top: circleCenterY - 1.5,
                          left: lineStart,
                          width: totalTrackLength,
                          height: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Active Progress Track Line (Emerald Gradient)
                        if (lineProgressRatio > 0)
                          Positioned(
                            top: circleCenterY - 1.5,
                            left: lineStart,
                            width: totalTrackLength * lineProgressRatio,
                            height: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 5 Nodes in a Row
                        Row(
                          children: List.generate(5, (idx) {
                            final int stampNum = idx + 1;
                            final bool isFilled = isCycleCompleted ? true : (idx < filled);
                            final bool isNext = !isCycleCompleted && !_hasPreciousGift && (idx == filled);
                            final bool isGiftNode = (idx == 4);

                            return Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Circle Node
                                  SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: _buildStampNodeCircle(
                                        stampNum: stampNum,
                                        isFilled: isFilled,
                                        isNext: isNext,
                                        isGiftNode: isGiftNode,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Milestone Label
                                  _buildStampNodeLabel(
                                    stampNum: stampNum,
                                    isFilled: isFilled,
                                    isNext: isNext,
                                    isGiftNode: isGiftNode,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Bottom Progress Summary Bar (Compact single line)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasPreciousGift || isCycleCompleted
                            ? Icons.celebration_rounded
                            : (remaining == 1 ? Icons.local_fire_department_rounded : Icons.track_changes_rounded),
                        size: 15,
                        color: _hasPreciousGift || isCycleCompleted
                            ? const Color(0xFF10B981)
                            : (remaining == 1 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _hasPreciousGift
                                ? 'Precious Gift unlocked! Included in this order for FREE.'
                                : (isCycleCompleted
                                    ? 'Cycle complete! Next order starts a new cycle.'
                                    : (remaining == 1
                                        ? 'Final step! Complete this order for your Free Gift!'
                                        : 'Progress: $filled of 5 orders delivered in this cycle')),
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${((_hasPreciousGift || isCycleCompleted ? 5 : filled) * 20)}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _hasPreciousGift || isCycleCompleted ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stamp Node Circle Indicator (Emerald Check / Amber Next / Gold Gift)
  Widget _buildStampNodeCircle({
    required int stampNum,
    required bool isFilled,
    required bool isNext,
    required bool isGiftNode,
  }) {
    if (isGiftNode) {
      final bool isGiftActive = isFilled || _hasPreciousGift;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isGiftActive
              ? const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: isGiftActive ? const Color(0xFFB45309) : const Color(0xFFF59E0B),
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: isGiftActive ? 0.45 : 0.25),
              blurRadius: isGiftActive ? 9 : 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Image.asset(
            'assets/images/gift_box.png',
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 20)),
          ),
        ),
      );
    }

    if (isFilled) {
      // Completed Node (1-4)
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 2.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      );
    }

    if (isNext) {
      // Current Active Target Node
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFF59E0B), width: 2.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$stampNum',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    // Inactive Pending Node
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.8),
      ),
      child: Center(
        child: Text(
          '$stampNum',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// Stamp Node Label underneath circle
  Widget _buildStampNodeLabel({
    required int stampNum,
    required bool isFilled,
    required bool isNext,
    required bool isGiftNode,
  }) {
    if (isGiftNode) {
      final bool giftClaimedOrAdded = _hasPreciousGift || isFilled;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: giftClaimedOrAdded ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: giftClaimedOrAdded ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            width: 0.8,
          ),
        ),
        child: Text(
          _hasPreciousGift ? 'GIFT ADDED 🎁' : (isFilled ? 'CLAIMED 🎉' : 'GIFT 🎁'),
          style: TextStyle(
            color: giftClaimedOrAdded ? const Color(0xFF047857) : const Color(0xFFB45309),
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (isFilled) {
      return Text(
        'Order $stampNum',
        style: const TextStyle(
          color: Color(0xFF059669),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (isNext) {
      return const Text(
        'Next',
        style: TextStyle(
          color: Color(0xFFB45309),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Text(
      'Order $stampNum',
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Active Draft Bill Receipt View
  Widget _buildDraftBillView(int totalCount, double totalAmount, String sellerName, String formattedDate) {
    double totalSavings = 0.0;
    double originalItemsTotal = 0.0;
    for (var item in _cartItems) {
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
      final mrp = (item['mrp'] as num?)?.toDouble() ??
          (item['original_price'] as num?)?.toDouble() ??
          (item['original_rate'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          0.0;
      if (mrp > rate) {
        totalSavings += (mrp - rate) * qty;
        originalItemsTotal += mrp * qty;
      } else {
        originalItemsTotal += rate * qty;
      }
    }
    const double deliveryDiscount = 15.0;
    totalSavings += deliveryDiscount;
    if (originalItemsTotal < totalAmount) {
      originalItemsTotal = totalAmount + (totalSavings - deliveryDiscount);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          if (_isFirstOrder)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/first_order_gift.png',
                    height: 66,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'First Order Gift Added! 🎁',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'Welcome to our store! Building a bond of trust from your very first order. 🤝',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (!_isSellerMode)
            _buildDigitalStampProgressBanner(),

          // Delivery in 15 minutes indicator (Border none)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    size: 15,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Delivery in 15 minutes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: DeliveryTruckAnimation(height: 28),
                ),
              ],
            ),
          ),

          // Modern E-Commerce Bill Details Card (Inspired by Image 2 - Black & Blue theme with Receipt Scallop Transition)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF64748B).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Bill details title + Store & Date info + Invoice Badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bill details',
                              style: TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$sellerName • $formattedDate',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Text(
                          'Invoice',
                          style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Column Header (Clean subtle strip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(child: Text('ITEM NAME & UNIT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                      SizedBox(width: 80, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                      SizedBox(width: 60, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                    ],
                  ),
                ),

                // Product Items List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final item = _cartItems[idx];
                    final name = (item['name'] ?? '').toString();
                    final unit = (item['unit'] ?? 'Pcs').toString();
                    final qty = (item['qty'] as num?)?.toInt() ?? 1;
                    final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
                    final amt = (item['amount'] as num?)?.toDouble() ?? (rate * qty);
                    final img = (item['image'] ?? '').toString();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          // Item Image & Name
                          Expanded(
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _showEnlargedImageDialog(img, name),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: _buildProductImageWidget(img, emojiSize: 16),
                                    ),
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
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Quantity Controls (- 1 +)
                          SizedBox(
                            width: 78,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () => _updateItemQty(idx, qty - 1),
                                  borderRadius: BorderRadius.circular(5),
                                  child: Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: const Icon(Icons.remove, size: 11, color: Color(0xFF475569)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    '$qty',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _updateItemQty(idx, qty + 1),
                                  borderRadius: BorderRadius.circular(5),
                                  child: Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(Icons.add, size: 11, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Amount & Delete Button
                          SizedBox(
                            width: 62,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '₹${amt % 1 == 0 ? amt.toInt() : amt.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                InkWell(
                                  onTap: () => _removeItem(idx),
                                  borderRadius: BorderRadius.circular(10),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Icon(Icons.close, size: 13, color: Color(0xFF94A3B8)),
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

                // Auto-added First Order Gift Row
                if (_isFirstOrder) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  Container(
                    color: const Color(0xFFFFFBEB).withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _showEnlargedImageDialog('assets/images/first_order_gift.png', 'First Order Gift'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                  ),
                                  child: const Center(
                                    child: Text('🎁', style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'First Order Gift',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11.5,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Text('🎁', style: TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    Text(
                                      'Welcome Gift',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Auto-added Precious Gift Row
                if (_hasPreciousGift) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                  Container(
                    color: const Color(0xFFF0FDF4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _showEnlargedImageDialog('assets/images/gift_box.png', 'Precious Gift'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/images/gift_box.png',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Precious Gift',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11.5,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Text('🎁', style: TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    Text(
                                      '5-Stamp Cycle Reward',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Bill Breakdown Section (Matching Image 2 Theme)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      // Items total row
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF334155)),
                          const SizedBox(width: 8),
                          const Text(
                            'Items total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if ((originalItemsTotal - totalAmount) > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'Saved ₹${(originalItemsTotal - totalAmount) % 1 == 0 ? (originalItemsTotal - totalAmount).toInt() : (originalItemsTotal - totalAmount).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if ((originalItemsTotal - totalAmount) > 0) ...[
                            Text(
                              '₹${originalItemsTotal % 1 == 0 ? originalItemsTotal.toInt() : originalItemsTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Delivery charge row
                      Row(
                        children: [
                          const Icon(Icons.two_wheeler_outlined, size: 18, color: Color(0xFF334155)),
                          const SizedBox(width: 8),
                          const Text(
                            'Delivery charge',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dashed,
                              decorationColor: Color(0xFF94A3B8),
                              decorationThickness: 1.2,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            '₹15',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Handling charge row
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF334155)),
                          const SizedBox(width: 8),
                          const Text(
                            'Handling charge',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dashed,
                              decorationColor: Color(0xFF94A3B8),
                              decorationThickness: 1.2,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'FREE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // Grand total row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand total',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dashed,
                              decorationColor: Color(0xFF94A3B8),
                              decorationThickness: 1.2,
                            ),
                          ),
                          Text(
                            '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Animated Sharp Zigzag Receipt Cut Transition with moving blue line effect
                const ReceiptScallopDivider(
                  cardColor: Colors.white,
                  stripColor: Color(0xFFEFF6FF),
                  height: 14.0,
                  scallopWidth: 12.0,
                  scallopDepth: 6.5,
                ),

                // Bottom Light Blue Total Savings Strip (Matching Image 2)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your total savings',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                      Text(
                        '₹${totalSavings % 1 == 0 ? totalSavings.toInt() : totalSavings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                          fontSize: 17.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send Order / Place Bill Button (Yellow Theme with High Contrast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _placeBillOrder,
              icon: const Icon(Icons.send_rounded, color: Color(0xFF0F172A), size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Place Order & Send Bill (₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24), // Vibrant Golden Yellow
                foregroundColor: const Color(0xFF0F172A),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                shadowColor: Colors.amber.withValues(alpha: 0.35),
              ),
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
      final bool isSearching = _orderSearchQuery.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF1F5F9),
                child: Icon(
                  isSearching
                      ? Icons.search_off_rounded
                      : (_isSellerMode ? Icons.shopping_bag_rounded : Icons.history_rounded),
                  size: 36,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSearching
                    ? 'No matching orders found'
                    : (_isSellerMode
                        ? (_placedOrders.isEmpty ? 'No Customer Orders Yet 🛍️' : 'No ${_sellerOrderFilter.toUpperCase()} Orders 🛍️')
                        : 'No Order History Yet'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                isSearching
                    ? 'No orders matched "$_orderSearchQuery". Try searching with another keyword or clear search.'
                    : (_isSellerMode
                        ? (_placedOrders.isEmpty
                            ? 'When customers place orders with your store, their order details & receipts will appear here!'
                            : 'No orders match the selected "${_sellerOrderFilter.toUpperCase()}" filter.')
                        : 'Once you place an order, all your sequential order receipts will appear here!'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              if (isSearching) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    _orderSearchController.clear();
                    setState(() {
                      _orderSearchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear Search', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final mergeableMap = _isSellerMode ? _getMergeablePendingOrders() : <String, List<Map<String, dynamic>>>{};
    final bool showStampBanner = !_isSellerMode && !_isFirstOrder;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredOrders.length + (showStampBanner ? 1 : 0),
      itemBuilder: (ctx, index) {
        if (showStampBanner) {
          if (index == 0) {
            return _buildDigitalStampProgressBanner();
          }
          index = index - 1;
        }
        final order = filteredOrders[index];
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
        String deliveryAddress = (order['delivery_address'] ?? order['address'] ?? order['cust_address'] ?? '').toString().trim();
        if (deliveryAddress.isEmpty && order['message'] != null) {
          final match = RegExp(r'(?:Address|delivery_address|📍\s*Address):\s*([^\r\n]+)', caseSensitive: false).firstMatch(order['message'].toString());
          if (match != null) {
            deliveryAddress = match.group(1)!.trim();
          }
        }
        if (deliveryAddress.isEmpty && order['raw_msg'] is Map) {
          final raw = order['raw_msg'] as Map;
          deliveryAddress = (raw['delivery_address'] ?? raw['address'] ?? raw['customer_profile_address'] ?? '').toString().trim();
          if (deliveryAddress.isEmpty && raw['message'] != null) {
            final match = RegExp(r'(?:Address|delivery_address|📍\s*Address):\s*([^\r\n]+)', caseSensitive: false).firstMatch(raw['message'].toString());
            if (match != null) {
              deliveryAddress = match.group(1)!.trim();
            }
          }
        }
        if (deliveryAddress.isEmpty && custMobile.isNotEmpty) {
          final cleanDigits = custMobile.replaceAll(RegExp(r'[^0-9]'), '');
          final last10 = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
          final fallbackAddr = _cachedCustomerAddresses[last10] ?? _cachedCustomerAddresses[custMobile];
          if (fallbackAddr != null && fallbackAddr.isNotEmpty) {
            deliveryAddress = fallbackAddr;
          }
        }
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
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Card Header (Order ID in Black & Status Badge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 19),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              orderId,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: (orderId.contains(',') || order['is_merged'] == true) ? 11.5 : 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (orderId.contains(',') || order['is_merged'] == true) ...[
                            const SizedBox(width: 6),
                            const Text(
                              'MERGED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

              // Store / Customer Name & Address
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: _isSellerMode
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Customer: ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                      TextSpan(
                                        text: custName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Mobile: ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                      TextSpan(
                                        text: custMobile.isNotEmpty ? custMobile : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Address: ',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                      TextSpan(
                                        text: deliveryAddress.isNotEmpty ? deliveryAddress : 'N/A',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (custMobile.isNotEmpty) ...[
                            const SizedBox(width: 8),
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
                                width: 34,
                                height: 34,
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
                                  size: 16,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
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
                        ],
                      ),
              ),

              // FULL WIDTH ITEM LIST (matching Draft Bill receipt design)
              if (items.isNotEmpty) ...[
                // Table Column Header (Clean subtle strip across full card width)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border.symmetric(horizontal: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(child: Text('ITEM NAME & UNIT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                      SizedBox(width: 80, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                      SizedBox(width: 60, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.3))),
                    ],
                  ),
                ),

                // Items Rows (Full Width, Small & Medium Font)
                ...List.generate(items.length, (iIdx) {
                  final it = items[iIdx];
                  final iName = (it['name'] ?? it['text'] ?? 'Item').toString().trim();
                  final iQty = (it['qty'] as num?)?.toInt() ?? 1;
                  final iUnit = (it['unit'] ?? 'Pcs').toString().trim();
                  final iRate = (it['rate'] ?? it['price'] ?? 0.0 as num).toDouble();
                  final iAmt = (it['amount'] as num?)?.toDouble() ?? (iRate > 0 ? (iRate * iQty) : 0.0);
                  final img = (it['image'] ?? it['image_url'] ?? '').toString().trim();
                  final isGift = it['is_gift'] == true || iName.toLowerCase().contains('gift');

                  if (isGift) {
                    final bool isPrecious = it['is_precious_gift'] == true || iName.toLowerCase().contains('precious');
                    final String gTitle = isPrecious ? 'Precious Gift' : 'First Order Gift';
                    final String gSubtitle = isPrecious ? '5-Stamp Cycle Reward' : 'Welcome Gift';
                    final String gImg = isPrecious ? 'assets/images/gift_box.png' : 'assets/images/first_order_gift.png';
                    final Color gColor = isPrecious ? const Color(0xFF047857) : const Color(0xFFB45309);
                    final Color gSubColor = isPrecious ? const Color(0xFF059669) : const Color(0xFFD97706);

                    return Column(
                      children: [
                        if (iIdx > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                        Container(
                          color: isPrecious
                              ? const Color(0xFFF0FDF4).withValues(alpha: 0.9)
                              : const Color(0xFFFFFBEB).withValues(alpha: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _showEnlargedImageDialog(gImg, gTitle),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                        ),
                                        child: Center(
                                          child: isPrecious
                                              ? Image.asset(
                                                  gImg,
                                                  width: 20,
                                                  height: 20,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => const Text('🎁', style: TextStyle(fontSize: 16)),
                                                )
                                              : const Text('🎁', style: TextStyle(fontSize: 16)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  gTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11.5,
                                                    color: gColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              const Text('🎁', style: TextStyle(fontSize: 10)),
                                            ],
                                          ),
                                          Text(
                                            gSubtitle,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w500,
                                              color: gSubColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Color(0xFF2563EB),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      if (iIdx > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            // Item Image & Name
                            Expanded(
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _showEnlargedImageDialog(img, iName),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: _buildProductImageWidget(img, emojiSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          iName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: Color(0xFF1E293B)),
                                        ),
                                        if (iRate > 0) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            '₹${iRate % 1 == 0 ? iRate.toInt() : iRate.toStringAsFixed(2)} / $iUnit',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),

                            // QTY & Unit
                            SizedBox(
                              width: 80,
                              child: Text(
                                '$iQty $iUnit',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Amount
                            SizedBox(
                              width: 60,
                              child: Text(
                                iAmt > 0 ? '₹${iAmt % 1 == 0 ? iAmt.toInt() : iAmt.toStringAsFixed(2)}' : '-',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],

              // Footer: Total Amount, Status, Actions, Date
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount ${items.isNotEmpty ? '(${items.length} Items)' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: Color(0xFF0F172A),
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
                                isReady ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Ready',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReady ? const Color(0xFF059669) : const Color(0xFF0F766E),
                                disabledBackgroundColor: const Color(0xFF059669).withValues(alpha: 0.7),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 2. Cancel Button (Soft Red Outline/Tint Style)
                          Expanded(
                            flex: 4,
                            child: OutlinedButton.icon(
                              onPressed: () => _showCancelOrderDialog(order),
                              icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFDC2626)),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626)),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFF1F2),
                                side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 3. Chat Button (Soft Indigo Tint Style)
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
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Color(0xFF4F46E5)),
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

              // Static Sharp Zigzag Receipt Border at bottom of card (NO color animation)
              StaticZigzagDivider(
                cardColor: Colors.white,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                height: 10.0,
                toothWidth: 12.0,
                toothDepth: 5.5,
              ),
            ],
          ),
        );

        return cardWidget;
      },
    );
  }

  /// Mark Order as Ready & Notify Customer + Delivery Boys (Instant 0ms UI Response)
  Future<void> _markOrderAsReady(Map<String, dynamic> order) async {
    final rawMsgId = order['id'] ?? order['message_id'];
    int msgId = int.tryParse(rawMsgId.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final custMobile = (order['customer_mobile'] ?? order['mobile'] ?? '').toString().trim();
    final orderIdStr = (order['order_id'] ?? order['id'] ?? '#DM-1001').toString();

    // 1. INSTANT 0ms UI State Update
    if (mounted) {
      setState(() {
        order['order_status'] = 'Ready';
        order['status'] = 'Ready';
        order['delivery_status'] = 'Ready';
      });
    }

    AppToast.show(context, 'Order $orderIdStr is READY! Added to Delivery Boy list');

    // 2. Background async network sync & notifications (non-blocking)
    try {
      await Future.wait([
        AuthService.updateOrderStatus(
          messageId: msgId,
          orderId: orderIdStr,
          orderStatus: 'Ready',
        ),
        NotificationService.notifyOrderReady(
          customerMobile: custMobile,
          sellerUsername: _sellerUsername,
          sellerName: widget.seller.name ?? _sellerUsername,
          orderId: orderIdStr,
        ),
      ]);
    } catch (e) {
      debugPrint('Error syncing order ready status: $e');
    }

    // 3. Background cache revalidation
    _refreshOrders();
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

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag indicator pill
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cancel Order $orderIdStr',
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  custName.isNotEmpty ? 'Customer: $custName' : 'Customer Order',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx, false),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 14),

                      // Section Title
                      const Text(
                        'Select Cancellation Reason',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Preset Reasons (Clean full-width selection cards)
                      ...presetReasons.map((r) {
                        final isSel = selectedReasonChip == r;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedReasonChip = r;
                                reasonController.text = r;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFFFF1F2) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 19,
                                    color: isSel ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                        color: isSel ? const Color(0xFF991B1B) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 6),
                      // Custom Reason / Note field
                      const Text(
                        'Custom Reason / Note (Optional)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter specific reason if any...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.3),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 46),
                                backgroundColor: const Color(0xFFF1F5F9),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Keep Order',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (reasonController.text.trim().isEmpty) {
                                  reasonController.text = selectedReasonChip;
                                }
                                Navigator.pop(ctx, true);
                              },
                              icon: const Icon(Icons.close_rounded, size: 17, color: Colors.white),
                              label: const Text(
                                'Cancel Order',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && (msgId != 0 || orderIdStr.isNotEmpty)) {
      final finalReason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Cancelled by store seller';

      // 1. Cancel order with reason
      await AuthService.cancelOrderWithReason(
        sellerUsername: _sellerUsername,
        customerMobile: custMobile,
        messageId: msgId,
        reason: finalReason,
        orderId: orderIdStr,
      );

      // 2. Notify customer
      await NotificationService.notifyCustomerOrderCancelled(
        customerMobile: custMobile,
        sellerName: widget.seller.name ?? _sellerUsername,
        orderId: orderIdStr,
        reason: finalReason,
      );

      // 3. Reload orders & re-check first order status immediately
      await _refreshOrders();
      await _checkFirstOrderStatus();

      if (mounted) {
        AppToast.show(context, 'Order $orderIdStr Cancelled ($finalReason)');
      }
    }
  }
}

/// Animated sharp zigzag receipt tear transition divider with moving blue beam effect
class ReceiptScallopDivider extends StatefulWidget {
  final Color cardColor;
  final Color stripColor;
  final double height;
  final double scallopWidth;
  final double scallopDepth;

  const ReceiptScallopDivider({
    super.key,
    this.cardColor = Colors.white,
    this.stripColor = const Color(0xFFEFF6FF),
    this.height = 14.0,
    this.scallopWidth = 12.0,
    this.scallopDepth = 6.5,
  });

  @override
  State<ReceiptScallopDivider> createState() => _ReceiptScallopDividerState();
}

class _ReceiptScallopDividerState extends State<ReceiptScallopDivider>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          height: widget.height,
          child: CustomPaint(
            painter: _ReceiptZigzagPainter(
              cardColor: widget.cardColor,
              stripColor: widget.stripColor,
              toothWidth: widget.scallopWidth,
              toothDepth: widget.scallopDepth,
              animationValue: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptZigzagPainter extends CustomPainter {
  final Color cardColor;
  final Color stripColor;
  final double toothWidth;
  final double toothDepth;
  final double animationValue;

  _ReceiptZigzagPainter({
    required this.cardColor,
    required this.stripColor,
    required this.toothWidth,
    required this.toothDepth,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill entire strip with stripColor (light blue)
    final stripPaint = Paint()..color = stripColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), stripPaint);

    // 2. Draw white sharp zigzag dipping into the light blue from the top
    int count = (size.width / toothWidth).round();
    if (count <= 0) count = 1;
    final double actualToothWidth = size.width / count;

    final whitePaint = Paint()..color = cardColor;
    final path = Path();
    final strokePath = Path();

    path.moveTo(0, 0);
    strokePath.moveTo(0, 0);

    for (int i = 0; i < count; i++) {
      final double startX = i * actualToothWidth;
      final double midX = startX + actualToothWidth / 2;
      final double endX = startX + actualToothWidth;

      path.lineTo(midX, toothDepth);
      path.lineTo(endX, 0);

      strokePath.lineTo(midX, toothDepth);
      strokePath.lineTo(endX, 0);
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, whitePaint);

    // 3. Subtle neutral baseline on zigzag edge (so the whole line isn't blue)
    final baseLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0);
    canvas.drawPath(strokePath, baseLinePaint);

    // 4. Snake-style crawling blue light effect ("sap ki tarah aata hua dikhe")
    final metrics = strokePath.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final double totalLength = metric.length;

      // Length of the glowing blue snake
      final double snakeLength = (totalLength * 0.28).clamp(65.0, 115.0);

      // Travel distance allowing snake to fully enter from left and exit to right
      final double totalTravel = totalLength + snakeLength * 2.0;
      final double headDist = (animationValue * totalTravel) - snakeLength;
      final double tailDist = headDist - snakeLength;

      final double start = tailDist.clamp(0.0, totalLength);
      final double end = headDist.clamp(0.0, totalLength);

      if (end > start) {
        final Path snakePath = metric.extractPath(start, end);

        // A. Soft outer neon glow
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawPath(snakePath, glowPaint);

        // B. Vibrant electric blue snake body with gradient from tail to head
        final Rect bounds = snakePath.getBounds();
        final Rect shaderRect = bounds.width > 0 && bounds.height > 0
            ? bounds
            : Rect.fromLTWH(0, 0, size.width, size.height);

        final snakePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF93C5FD).withValues(alpha: 0.05), // Faded tail
              const Color(0xFF60A5FA).withValues(alpha: 0.6),
              const Color(0xFF2563EB),
              const Color(0xFF38BDF8), // Bright leading head
            ],
            stops: const [0.0, 0.35, 0.75, 1.0],
          ).createShader(shaderRect);
        canvas.drawPath(snakePath, snakePaint);

        // C. Bright glowing Snake Head dot
        if (headDist >= 0 && headDist <= totalLength) {
          final ui.Tangent? headTangent = metric.getTangentForOffset(headDist);
          if (headTangent != null) {
            // Glow around head
            final headGlowPaint = Paint()
              ..color = const Color(0xFF38BDF8).withValues(alpha: 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
            canvas.drawCircle(headTangent.position, 3.2, headGlowPaint);

            // Bright white-hot center of head
            final headCorePaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill;
            canvas.drawCircle(headTangent.position, 1.8, headCorePaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptZigzagPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.cardColor != cardColor ||
        oldDelegate.stripColor != stripColor ||
        oldDelegate.toothWidth != toothWidth ||
        oldDelegate.toothDepth != toothDepth;
  }
}

/// Static sharp zigzag receipt tear divider for order history cards (NO color animation)
class StaticZigzagDivider extends StatelessWidget {
  final Color cardColor;
  final Color backgroundColor;
  final double height;
  final double toothWidth;
  final double toothDepth;

  const StaticZigzagDivider({
    super.key,
    this.cardColor = Colors.white,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.height = 10.0,
    this.toothWidth = 12.0,
    this.toothDepth = 5.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _StaticZigzagPainter(
          cardColor: cardColor,
          backgroundColor: backgroundColor,
          toothWidth: toothWidth,
          toothDepth: toothDepth,
        ),
      ),
    );
  }
}

class _StaticZigzagPainter extends CustomPainter {
  final Color cardColor;
  final Color backgroundColor;
  final double toothWidth;
  final double toothDepth;

  _StaticZigzagPainter({
    required this.cardColor,
    required this.backgroundColor,
    required this.toothWidth,
    required this.toothDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill background with backgroundColor
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw white triangular sharp teeth pointing down
    int count = (size.width / toothWidth).round();
    if (count <= 0) count = 1;
    final double actualToothWidth = size.width / count;

    final whitePaint = Paint()..color = cardColor;
    final path = Path();
    final strokePath = Path();

    path.moveTo(0, 0);
    strokePath.moveTo(0, 0);

    for (int i = 0; i < count; i++) {
      final double startX = i * actualToothWidth;
      final double midX = startX + actualToothWidth / 2;
      final double endX = startX + actualToothWidth;

      path.lineTo(midX, toothDepth);
      path.lineTo(endX, 0);

      strokePath.lineTo(midX, toothDepth);
      strokePath.lineTo(endX, 0);
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, whitePaint);

    // 3. Subtle static receipt line along the teeth (NO color effect)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFE2E8F0);
    canvas.drawPath(strokePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _StaticZigzagPainter oldDelegate) {
    return oldDelegate.cardColor != cardColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.toothWidth != toothWidth ||
        oldDelegate.toothDepth != toothDepth;
  }
}

// ==========================================
// ANIMATED DRIVING DELIVERY TRUCK WITH SCENERY
// ==========================================
class DeliveryTruckAnimation extends StatefulWidget {
  final double height;
  const DeliveryTruckAnimation({super.key, this.height = 28});

  @override
  State<DeliveryTruckAnimation> createState() => _DeliveryTruckAnimationState();
}

class _DeliveryTruckAnimationState extends State<DeliveryTruckAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = widget.height;
          final groundY = height - 4.0;
          const truckHeight = 18.0;
          const truckWidth = truckHeight * (206 / 96); // ~38.6px
          // Truck positioned so wind lines have room on the left, and upcoming scenery is visible on the right
          final truckLeft = (width * 0.22).clamp(16.0, 42.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final val = _controller.value;
                // Faster sub-cycles for road dashes and speed lines
                final roadCycle = (val * 5.0) % 1.0;
                final speedCycle = (val * 4.0) % 1.0;
                // Realistic suspension bounce and micro-tilt
                final bounce = math.sin(val * 20 * math.pi) * 0.65;
                final tilt = math.sin(val * 10 * math.pi) * 0.012;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // 1. Moving Background Scenery (Trees, Houses, Bushes moving right-to-left)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SceneryPainter(
                          progress: val,
                          groundY: groundY,
                        ),
                      ),
                    ),

                    // 2. Road Dashes Under Truck Wheels
                    Positioned(
                      left: truckLeft - 4,
                      top: groundY - 1,
                      width: truckWidth + 8,
                      height: 3,
                      child: CustomPaint(
                        painter: _RoadDashesPainter(progress: roadCycle),
                      ),
                    ),

                    // 3. Wind / Speed Lines Behind Truck
                    Positioned(
                      left: truckLeft - 14,
                      top: groundY - truckHeight + 3,
                      width: 15,
                      height: truckHeight - 5,
                      child: CustomPaint(
                        painter: _SpeedLinesPainter(progress: speedCycle),
                      ),
                    ),

                    // 4. Delivery Truck (Foreground)
                    Positioned(
                      left: truckLeft,
                      top: groundY - truckHeight + bounce,
                      child: Transform.rotate(
                        angle: tilt,
                        alignment: Alignment.bottomCenter,
                        child: Image.asset(
                          'assets/images/delivery_truck.png',
                          height: truckHeight,
                          width: truckWidth,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.local_shipping_rounded, size: truckHeight, color: Color(0xFF059669)),
                        ),
                      ),
                    ),

                    // 5. Soft Edge Vignette Fades (Smoothly fade in on right and out on left)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0x00FFFFFF),
                                Color(0x00FFFFFF),
                                Colors.white,
                              ],
                              stops: [0.0, 0.07, 0.93, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// SCENERY PAINTER (PARALLAX TREES & HOUSES)
// ==========================================
class _SceneryPainter extends CustomPainter {
  final double progress;
  final double groundY;

  _SceneryPainter({required this.progress, required this.groundY});

  @override
  void paint(Canvas canvas, Size size) {
    const loopWidth = 220.0;
    // Moving from right to left (opposite to truck motion)
    final scrollOffset = progress * loopWidth;

    // Subtle ground road line
    final groundPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), groundPaint);

    // Reusable styling paints
    final wallSlateLight = Paint()..color = const Color(0xFFE2E8F0);
    final wallSlateMid = Paint()..color = const Color(0xFFCBD5E1);
    final roofOrange = Paint()..color = const Color(0xFFF97316);
    final roofSky = Paint()..color = const Color(0xFF38BDF8);
    final roofRose = Paint()..color = const Color(0xFFF87171);
    final windowWarm = Paint()..color = const Color(0xFFFEF08A);
    final doorSlate = Paint()..color = const Color(0xFF64748B);
    final trunkBrown = Paint()..color = const Color(0xFF92400E);
    final treeDarkGreen = Paint()..color = const Color(0xFF059669);
    final treeLightGreen = Paint()..color = const Color(0xFF10B981);
    final bushMint = Paint()..color = const Color(0xFF34D399);

    // Draw repeating tiles across visible width
    for (double tile = -1; tile <= 2; tile++) {
      final tileX = tile * loopWidth - scrollOffset;
      if (tileX + loopWidth < -30 || tileX > size.width + 30) continue;

      // 1. House 1 (Gable roof cottage) at local x = 12
      final h1X = tileX + 12;
      if (h1X > -30 && h1X < size.width + 30) {
        // Wall
        canvas.drawRect(Rect.fromLTWH(h1X, groundY - 9.5, 16, 9.5), wallSlateMid);
        // Roof
        final p1 = Path()
          ..moveTo(h1X - 1.5, groundY - 9.5)
          ..lineTo(h1X + 8, groundY - 15)
          ..lineTo(h1X + 17.5, groundY - 9.5)
          ..close();
        canvas.drawPath(p1, roofOrange);
        // Window
        canvas.drawRect(Rect.fromLTWH(h1X + 2.5, groundY - 7.5, 3.5, 3.5), windowWarm);
        // Door
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(h1X + 9.5, groundY - 8, 3.5, 8),
            topLeft: const Radius.circular(1),
            topRight: const Radius.circular(1),
          ),
          doorSlate,
        );
      }

      // 2. Pine Tree 1 at local x = 48
      final p1X = tileX + 48;
      if (p1X > -25 && p1X < size.width + 25) {
        // Trunk
        canvas.drawRect(Rect.fromLTWH(p1X + 3.8, groundY - 3.5, 2.4, 3.5), trunkBrown);
        // Foliage lower
        final f1 = Path()
          ..moveTo(p1X, groundY - 3)
          ..lineTo(p1X + 5, groundY - 10.5)
          ..lineTo(p1X + 10, groundY - 3)
          ..close();
        canvas.drawPath(f1, treeDarkGreen);
        // Foliage upper
        final f2 = Path()
          ..moveTo(p1X + 1.2, groundY - 7.5)
          ..lineTo(p1X + 5, groundY - 15.5)
          ..lineTo(p1X + 8.8, groundY - 7.5)
          ..close();
        canvas.drawPath(f2, treeLightGreen);
      }

      // 3. Round Leafy Tree at local x = 80
      final t1X = tileX + 80;
      if (t1X > -25 && t1X < size.width + 25) {
        // Trunk
        canvas.drawRect(Rect.fromLTWH(t1X + 4.2, groundY - 5, 2.5, 5), trunkBrown);
        // Foliage
        canvas.drawCircle(Offset(t1X + 5.5, groundY - 11), 6, treeLightGreen);
        canvas.drawCircle(Offset(t1X + 4.5, groundY - 12), 3.5, bushMint);
      }

      // 4. House 2 (Modern Flat-Roof Townhouse with Chimney) at local x = 114
      final h2X = tileX + 114;
      if (h2X > -30 && h2X < size.width + 30) {
        // Wall
        canvas.drawRect(Rect.fromLTWH(h2X, groundY - 12, 18, 12), wallSlateLight);
        // Roof ledge
        canvas.drawRect(Rect.fromLTWH(h2X - 1, groundY - 14, 20, 2), roofSky);
        // Chimney
        canvas.drawRect(Rect.fromLTWH(h2X + 12, groundY - 16.5, 2.5, 2.5), doorSlate);
        // Windows
        canvas.drawRect(Rect.fromLTWH(h2X + 2.5, groundY - 10, 3.5, 3.5), windowWarm);
        canvas.drawRect(Rect.fromLTWH(h2X + 11.5, groundY - 10, 3.5, 3.5), windowWarm);
        // Door
        canvas.drawRect(Rect.fromLTWH(h2X + 7, groundY - 6, 4, 6), doorSlate);
      }

      // 5. Bush / Shrub at local x = 150
      final b1X = tileX + 150;
      if (b1X > -25 && b1X < size.width + 25) {
        canvas.drawCircle(Offset(b1X + 3.5, groundY - 3), 3.5, bushMint);
        canvas.drawCircle(Offset(b1X + 7.5, groundY - 2.5), 3.0, treeLightGreen);
      }

      // 6. House 3 (Little Rose-roof Cottage) at local x = 175
      final h3X = tileX + 175;
      if (h3X > -30 && h3X < size.width + 30) {
        // Wall
        canvas.drawRect(Rect.fromLTWH(h3X, groundY - 8.5, 14, 8.5), wallSlateMid);
        // Roof
        final p3 = Path()
          ..moveTo(h3X - 1, groundY - 8.5)
          ..lineTo(h3X + 7, groundY - 14)
          ..lineTo(h3X + 15, groundY - 8.5)
          ..close();
        canvas.drawPath(p3, roofRose);
        // Window
        canvas.drawRect(Rect.fromLTWH(h3X + 5, groundY - 6.5, 3.5, 3.5), windowWarm);
      }

      // 7. Pine Tree 2 at local x = 202
      final p2X = tileX + 202;
      if (p2X > -25 && p2X < size.width + 25) {
        canvas.drawRect(Rect.fromLTWH(p2X + 3.5, groundY - 3, 2, 3), trunkBrown);
        final f3 = Path()
          ..moveTo(p2X, groundY - 2.5)
          ..lineTo(p2X + 4.5, groundY - 12.5)
          ..lineTo(p2X + 9, groundY - 2.5)
          ..close();
        canvas.drawPath(f3, treeDarkGreen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.groundY != groundY;
}

// ==========================================
// ROAD DASHES PAINTER
// ==========================================
class _RoadDashesPainter extends CustomPainter {
  final double progress;
  _RoadDashesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashGap = 5.0;
    const totalCycle = dashWidth + dashGap;
    // Dashes move leftwards
    final offset = -(progress * totalCycle);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    for (double x = offset; x < size.width + totalCycle; x += totalCycle) {
      if (x + dashWidth > 0 && x < size.width) {
        final startX = math.max(0.0, x);
        final endX = math.min(size.width, x + dashWidth);
        canvas.drawLine(
          Offset(startX, size.height / 2),
          Offset(endX, size.height / 2),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoadDashesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ==========================================
// SPEED / WIND LINES PAINTER
// ==========================================
class _SpeedLinesPainter extends CustomPainter {
  final double progress;
  _SpeedLinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final lines = [
      {'yRatio': 0.28, 'speed': 1.0, 'length': 7.0},
      {'yRatio': 0.55, 'speed': 1.3, 'length': 10.0},
      {'yRatio': 0.82, 'speed': 0.9, 'length': 6.0},
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final y = size.height * (line['yRatio'] as double);
      final speed = line['speed'] as double;
      final length = line['length'] as double;

      final p = (progress * speed + (i * 0.33)) % 1.0;
      final x = (size.width - 1) - p * (size.width);
      final opacity = (1.0 - p).clamp(0.0, 0.85);

      final paint = Paint()
        ..color = const Color(0xFF059669).withValues(alpha: opacity * 0.7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(math.max(0.0, x), y),
        Offset(math.min(size.width, x + length), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}



