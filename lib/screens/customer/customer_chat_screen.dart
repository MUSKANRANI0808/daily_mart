import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/order_card_widget.dart';

class CustomerChatScreen extends StatefulWidget {
  final UserModel customer;
  final String sellerUsername;
  final String sellerName;
  final String sellerMobile;

  const CustomerChatScreen({
    super.key,
    required this.customer,
    required this.sellerUsername,
    required this.sellerName,
    required this.sellerMobile,
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isBlocked = false;
  List<Map<String, dynamic>> _sellerProducts = [];

  late Razorpay _razorpay;
  int _activePendingMsgId = 0;
  double _activePendingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkBlockedStatus();
    _loadMessages();
    _loadSellerProducts();
  }

  Future<void> _loadSellerProducts() async {
    final products = await AuthService.getSellerProducts(widget.sellerUsername);
    if (mounted) {
      setState(() {
        _sellerProducts = products;
      });
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _chatScrollController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    if (_activePendingMsgId != 0) {
      await AuthService.markOrderPaid(
        sellerUsername: widget.sellerUsername,
        customerMobile: widget.customer.mobile ?? '',
        messageId: _activePendingMsgId,
        utrNumber: paymentId,
        amount: _activePendingAmount,
      );
      _loadMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Successful! ($paymentId) Order marked as PAID ✅'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    _activePendingMsgId = 0;
    _activePendingAmount = 0.0;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _activePendingMsgId = 0;
    _activePendingAmount = 0.0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Cancelled / Failed: ${response.message ?? "User Cancelled"}'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
  }

  Future<void> _checkBlockedStatus() async {
    final blocked = await AuthService.isCustomerBlocked(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
    );
    if (mounted) {
      setState(() {
        _isBlocked = blocked;
      });
    }
  }

  Future<void> _loadMessages() async {
    _checkBlockedStatus();
    final msgs = await AuthService.getMessages(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
    );
    await AuthService.annotateMessagesWithLifetimeHierarchy(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
      messages: msgs,
    );
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  String _formatAddressToString(Map<String, dynamic> addr) {
    final parts = <String>[];
    if ((addr['houseNo'] ?? '').toString().isNotEmpty) parts.add(addr['houseNo']);
    if ((addr['building'] ?? '').toString().isNotEmpty) parts.add(addr['building']);
    if ((addr['locality'] ?? '').toString().isNotEmpty) parts.add(addr['locality']);
    if ((addr['landmark'] ?? '').toString().isNotEmpty) parts.add('Near ${addr['landmark']}');
    if ((addr['city'] ?? '').toString().isNotEmpty) parts.add(addr['city']);
    if ((addr['pincode'] ?? '').toString().isNotEmpty) parts.add(addr['pincode']);
    final tag = addr['tag'] ?? 'Address';
    return '📍 Delivery Address ($tag): ${parts.join(', ')}';
  }

  void _sendMessage() async {
    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been blocked by this seller.')),
      );
      return;
    }
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // Load saved customer addresses
    final prefs = await SharedPreferences.getInstance();
    final prefsKey = 'customer_addresses_${widget.customer.mobile}';
    final jsonStr = prefs.getString(prefsKey);
    List<Map<String, dynamic>> savedAddresses = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        savedAddresses = List<Map<String, dynamic>>.from(list);
      } catch (_) {}
    }

    if (mounted) {
      _showAddressSelectionSheet(text, savedAddresses);
    }
  }

  void _showAddressSelectionSheet(String rawOrderText, List<Map<String, dynamic>> addresses) {
    int selectedIdx = addresses.indexWhere((a) => a['isDefault'] == true);
    if (selectedIdx < 0 && addresses.isNotEmpty) selectedIdx = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
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
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Drag Handle
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
                  const SizedBox(height: 12),

                  // Header Title
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Delivery Address',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose address to place your order',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Address List (or empty prompt)
                  if (addresses.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.house_rounded, color: Colors.black38, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'No saved address found.',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Please add a delivery address to place your order.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: addresses.length,
                        itemBuilder: (context, idx) {
                          final item = addresses[idx];
                          final isSelected = selectedIdx == idx;
                          final tag = item['tag'] ?? 'Home';
                          final house = item['houseNo'] ?? '';
                          final locality = item['locality'] ?? '';
                          final city = item['city'] ?? '';
                          final pin = item['pincode'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setModalState(() => selectedIdx = idx),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Radio<int>(
                                      value: idx,
                                      groupValue: selectedIdx,
                                      activeColor: const Color(0xFF10B981),
                                      onChanged: (val) {
                                        if (val != null) setModalState(() => selectedIdx = val);
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    color: Color(0xFF15803D),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (item['isDefault'] == true) ...[
                                                const SizedBox(width: 6),
                                                const Text('• Default', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$house, $locality, $city - $pin',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Add New Address Button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openAddNewAddressDialog(rawOrderText, addresses);
                    },
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF10B981), size: 20),
                    label: const Text(
                      'Add New Delivery Address',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Send Order Button
                  ElevatedButton(
                    onPressed: (addresses.isEmpty || selectedIdx < 0)
                        ? null
                        : () async {
                            final selectedAddress = addresses[selectedIdx];

                            Navigator.pop(ctx);
                            _msgController.clear();

                            final nextOrderId = await AuthService.getNextGlobalOrderId(
                              widget.sellerUsername,
                              customerMobile: widget.customer.mobile ?? '',
                              activeMessages: _messages,
                            );

                            final prefs = await SharedPreferences.getInstance();
                            Map<String, dynamic> deliveryDetailsMap = {};
                            try {
                              final str = prefs.getString('saved_order_delivery_details');
                              if (str != null && str.isNotEmpty) {
                                deliveryDetailsMap = Map<String, dynamic>.from(jsonDecode(str));
                              }
                            } catch (_) {}
                            final cleanTag = nextOrderId.replaceAll('#', '').replaceAll('Order', '').trim();
                            deliveryDetailsMap[cleanTag] = {
                              'address': selectedAddress,
                              'distance': '',
                            };
                            deliveryDetailsMap[nextOrderId] = {
                              'address': selectedAddress,
                              'distance': '',
                            };
                            await prefs.setString('saved_order_delivery_details', jsonEncode(deliveryDetailsMap));

                            final success = await AuthService.sendMessage(
                              sellerUsername: widget.sellerUsername,
                              customerMobile: widget.customer.mobile ?? '',
                              message: rawOrderText.trim(),
                              senderType: 'customer',
                              customOrderId: nextOrderId,
                            );

                          if (success) {
                            _loadMessages();
                            NotificationService.notifySellerNewOrder(
                              sellerUsername: widget.sellerUsername,
                              customerName: widget.customer.name ?? 'Customer',
                              customerMobile: widget.customer.mobile ?? '',
                              orderId: nextOrderId,
                            );
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to send order message.')),
                               );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Send Order with Address',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  }

  void _openAddNewAddressDialog(String rawOrderText, List<Map<String, dynamic>> existingAddresses) {
    final formKey = GlobalKey<FormState>();
    String tag = 'Home';
    final houseController = TextEditingController();
    final buildingController = TextEditingController();
    final localityController = TextEditingController();
    final landmarkController = TextEditingController();
    final cityController = TextEditingController();
    final pincodeController = TextEditingController();

    showModalBottomSheet(
      context: context,
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
                  Row(
                    children: [
                      const Icon(Icons.add_location_alt_rounded, color: Color(0xFF10B981), size: 26),
                      const SizedBox(width: 8),
                      const Text(
                        'Add New Delivery Address',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Tag selector
                  Row(
                    children: ['Home', 'Work', 'Other'].map((t) {
                      final isSelected = tag == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
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
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House No. / Building *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: localityController,
                    decoration: InputDecoration(
                      labelText: 'Area / Locality / Street *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Pincode *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => (v == null || v.trim().length < 6) ? '6 Digits' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newAddr = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'tag': tag,
                          'houseNo': houseController.text.trim(),
                          'building': buildingController.text.trim(),
                          'locality': localityController.text.trim(),
                          'landmark': landmarkController.text.trim(),
                          'city': cityController.text.trim(),
                          'pincode': pincodeController.text.trim(),
                          'isDefault': existingAddresses.isEmpty,
                        };

                        final updatedAddresses = List<Map<String, dynamic>>.from(existingAddresses);
                        updatedAddresses.add(newAddr);

                        final prefs = await SharedPreferences.getInstance();
                        final prefsKey = 'customer_addresses_${widget.customer.mobile}';
                        await prefs.setString(prefsKey, jsonEncode(updatedAddresses));

                        if (mounted) {
                          Navigator.pop(ctx);
                          _showAddressSelectionSheet(rawOrderText, updatedAddresses);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Address & Continue 📍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMessage(Map<String, dynamic> msgData) {
    final msgId = (msgData['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final orderStatus = (msgData['order_status'] ?? '').toString().toLowerCase();
    if (orderStatus == 'ready') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This order is marked as Ready by seller and cannot be deleted.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Order?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this order message?', style: TextStyle(color: Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.deleteMessage(msgId);
                _loadMessages();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showUpiPaymentQrSheet(Map<String, dynamic> msg) async {
    final msgId = (msg['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final rawAmt = msg['order_amount'] ?? msg['amount'];
    double? orderAmt;
    if (rawAmt != null && rawAmt.toString().isNotEmpty) {
      orderAmt = double.tryParse(rawAmt.toString());
    }
    if (orderAmt == null || orderAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order amount is invalid.')),
      );
      return;
    }
    final double validAmount = orderAmt;

    final rawOrderId = (msg['order_id'] ?? msg['_calculated_order_id'] ?? '').toString();
    final cleanOrderId = rawOrderId.replaceAll('#', '').trim();

    _activePendingMsgId = msgId;
    _activePendingAmount = validAmount;

    // 1. Launch Official Razorpay Native SDK
    final options = {
      'key': AuthService.razorpayKeyId,
      'amount': (validAmount * 100).toInt(),
      'name': widget.sellerName.trim().isNotEmpty ? widget.sellerName.trim() : 'Daily Mart Store',
      'description': 'Order #$cleanOrderId',
      'prefill': {
        'contact': (widget.customer.mobile != null && widget.customer.mobile!.trim().isNotEmpty)
            ? widget.customer.mobile!.trim()
            : AuthService.defaultStoreMobile,
        'email': 'customer@dailymart.com',
        'name': widget.customer.name ?? 'Customer',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay Native SDK: $e');
      // 2. Fallback to Official Razorpay Payment Link API
      final createdLink = await AuthService.createRazorpayPaymentLink(
        amount: validAmount,
        orderId: cleanOrderId,
        customerMobile: widget.customer.mobile ?? '',
        customerName: widget.customer.name ?? 'Customer',
      );
      final payUrl = createdLink ?? AuthService.getRazorpayCheckoutUrl(
        amount: validAmount,
        orderId: cleanOrderId,
        storeName: widget.sellerName,
        customerMobile: widget.customer.mobile,
        customerName: widget.customer.name,
      );
      try {
        final Uri uri = Uri.parse(payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri);
        }
      } catch (err) {
        debugPrint('Fallback launch error: $err');
      }
    }
  }

  void _addItemToOrderText(String name, String unit, int qty, double rate) {
    final existingText = _msgController.text.trim();
    final lines = existingText.isEmpty ? <String>[] : existingText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final lineNum = lines.length + 1;
    final rateStr = rate > 0 ? ' - ₹${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}' : '';
    final qtyStr = qty > 1 ? '$unit (x$qty)' : unit;
    final newItemStr = '$lineNum. $name ($qtyStr)$rateStr';

    setState(() {
      if (existingText.isEmpty) {
        _msgController.text = newItemStr;
      } else {
        _msgController.text = '$existingText\n$newItemStr';
      }
      _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
    });
  }

  void _showProductListPickerSheet() {
    String searchKey = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = searchKey.trim().toLowerCase();
          final filteredList = _sellerProducts.where((p) {
            final n = (p['name'] ?? '').toString().toLowerCase();
            final d = (p['description'] ?? '').toString().toLowerCase();
            final u = (p['unit'] ?? '').toString().toLowerCase();
            return query.isEmpty || n.contains(query) || d.contains(query) || u.contains(query);
          }).toList();

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title Header
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEDE9FE),
                      child: Icon(Icons.list_alt_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.sellerName} Products List 📋',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Search & tap products to add into your order list',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Box
                TextField(
                  autofocus: true,
                  onChanged: (val) {
                    setModalState(() {
                      searchKey = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or description...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8B5CF6), size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filtered Products List
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: filteredList.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.search_off_rounded, color: Colors.grey, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                searchKey.isNotEmpty ? 'No products matching "$searchKey"' : 'No products in seller catalog yet.',
                                style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredList.length,
                          itemBuilder: (context, idx) {
                            final item = filteredList[idx];
                            final pName = item['name'] ?? '';
                            final pDesc = item['description'] ?? '';
                            final pUnit = item['unit'] ?? 'Pcs';
                            final pQty = (item['qty'] ?? 1) is num ? (item['qty'] as num).toInt() : 1;
                            final pRate = (item['rate'] ?? 0.0) is num ? (item['rate'] as num).toDouble() : 0.0;
                            final rateStr = pRate > 0 ? '₹${pRate.toStringAsFixed(pRate.truncateToDouble() == pRate ? 0 : 2)}' : '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        pQty > 1 ? '$pUnit (x$pQty)' : pUnit,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (pDesc.isNotEmpty)
                                      Text(pDesc, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                    if (rateStr.isNotEmpty)
                                      Text(rateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ],
                                ),
                                trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    _addItemToOrderText(pName, pUnit, pQty, pRate);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added "$pName" to order list 🛒'),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                  label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),

                // Done Button
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text('Done Selecting Items', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sleek Light Grey Slate Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark Black-Navy Header Contrast
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF10B981), // Emerald Green Accent
              child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sellerName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Mobile: +91 ${widget.sellerMobile}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
            tooltip: 'Call Seller',
            onPressed: () async {
              final mobile = widget.sellerMobile.trim();
              if (mobile.isNotEmpty) {
                final Uri telUri = Uri(scheme: 'tel', path: mobile);
                try {
                  if (await canLaunchUrl(telUri)) {
                    await launchUrl(telUri, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(telUri);
                  }
                } catch (e) {
                  debugPrint('Error launching call dialer: $e');
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_background.png'),
            repeat: ImageRepeat.repeat,
            opacity: 0.25,
          ),
        ),
        child: Column(
          children: [
          // Messages list with Order Cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Type your order items below and send!',
                          style: TextStyle(color: Colors.black45, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final reversedMsgs = _messages.reversed.toList();
                          final msg = reversedMsgs[idx];
                          final senderType = msg['sender_type'] ?? 'customer';
                          final isCustomer = senderType == 'customer';

                          return Align(
                            alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.84,
                              ),
                              child: OrderCardWidget(
                                messageData: msg,
                                isSeller: false,
                                onDeleteTap: isCustomer ? () => _confirmDeleteMessage(msg) : null,
                                onPayNowTap: () => _showUpiPaymentQrSheet(msg),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Multiline Input Bar or Blocked Banner
          _isBlocked
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFFEF2F2),
                  child: const Row(
                    children: [
                      Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have been blocked by this seller. You cannot send messages or place orders.',
                          style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode Selector Bar: List 📋 vs Chat 💬
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _showProductListPickerSheet,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.format_list_bulleted_add, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'List 📋 (Select Items)',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF475569), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Chat 💬',
                                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_sellerProducts.isNotEmpty)
                            Text(
                              '${_sellerProducts.length} Items Available',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),

                    // Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Quick List Picker Icon Button
                          IconButton(
                            icon: const Icon(Icons.playlist_add_rounded, color: Color(0xFF8B5CF6), size: 26),
                            tooltip: 'Select from Product List',
                            onPressed: _showProductListPickerSheet,
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: _msgController,
                                keyboardType: TextInputType.multiline,
                                maxLines: 5,
                                minLines: 1,
                                textInputAction: TextInputAction.newline,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: 'Type order or tap List 📋...',
                                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFF10B981),
                            radius: 22,
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    ),
    );
  }
}
