import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../customer/order_success_screen.dart';

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
  String _previewNextOrderId = '#DM-1001';
  Timer? _cartPoller;

  @override
  void initState() {
    super.initState();
    _loadCart();
    _cartPoller = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
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
    final custMobile = await _getEffectiveCustomerMobile();
    final history = await AuthService.getCustomerPlacedOrders(custMobile, sellerUsername: _sellerUsername);
    
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
          if (items.isEmpty && history.isNotEmpty && !_showHistoryTab) {
            _showHistoryTab = true;
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

  void _placeBillOrder() async {
    if (_cartItems.isEmpty) return;

    final custMobile = await _getEffectiveCustomerMobile();
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
                          _showHistoryTab = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_showHistoryTab ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Current Draft Bill (${_cartItems.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: !_showHistoryTab ? Colors.white : Colors.white70,
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
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _showHistoryTab ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Order History (${_placedOrders.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _showHistoryTab ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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
    if (_placedOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.history_rounded, size: 40, color: Color(0xFF8B5CF6)),
              ),
              SizedBox(height: 16),
              Text(
                'No Order History Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 6),
              Text(
                'Once you place an order, all your sequential order receipts will appear here!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _placedOrders.length,
      itemBuilder: (ctx, idx) {
        final order = _placedOrders[idx];
        final orderId = (order['order_id'] ?? '#DM-1001').toString();
        final sellerName = (order['seller_name'] ?? 'Store').toString();
        final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
        final dateStr = (order['date'] ?? '').toString();
        final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final totalCount = (order['total_count'] as num?)?.toInt() ?? 0;
        final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

        return Container(
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
                        color: status == 'DELIVERED'
                            ? const Color(0xFFDCFCE7)
                            : (status == 'CANCELLED' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: status == 'DELIVERED'
                              ? const Color(0xFF15803D)
                              : (status == 'CANCELLED' ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Order Details (Store Name, Date, Items & Total)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Store: $sellerName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: items.map((it) {
                        final iName = (it['name'] ?? '').toString();
                        final iQty = (it['qty'] as num?)?.toInt() ?? 1;
                        final iUnit = (it['unit'] ?? 'Pcs').toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$iName x $iQty $iUnit',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount ($totalCount Items)',
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
