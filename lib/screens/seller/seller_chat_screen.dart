import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/order_card_widget.dart';

class SellerChatScreen extends StatefulWidget {
  final UserModel seller;
  final String customerMobile;

  const SellerChatScreen({
    super.key,
    required this.seller,
    required this.customerMobile,
  });

  @override
  State<SellerChatScreen> createState() => _SellerChatScreenState();
}

class _SellerChatScreenState extends State<SellerChatScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _customerDisplayName = 'Customer';

  @override
  void initState() {
    super.initState();
    _loadCustomerProfileName();
    _markReadAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }



  Future<void> _loadCustomerProfileName() async {
    final profile = await AuthService.getCustomerProfile(widget.customerMobile);
    if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
      final pName = profile['name'].toString().trim();
      if (!pName.startsWith('Customer')) {
        if (mounted) {
          setState(() {
            _customerDisplayName = pName;
          });
        }
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('customer_addresses_${widget.customerMobile}');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        if (list.isNotEmpty) {
          final defaultAddr = list.firstWhere((a) => a['isDefault'] == true, orElse: () => list.first);
          final rName = defaultAddr['receiverName']?.toString().trim() ?? '';
          if (rName.isNotEmpty) {
            if (mounted) {
              setState(() {
                _customerDisplayName = rName;
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _markReadAndLoad() async {
    final sellerUsername = widget.seller.username ?? '';
    await AuthService.markMessagesRead(
      sellerUsername: sellerUsername,
      customerMobile: widget.customerMobile,
    );
    _loadMessages();
  }

  bool _isBlocked = false;

  Future<void> _checkBlockedStatus() async {
    final blocked = await AuthService.isCustomerBlocked(
      sellerUsername: widget.seller.username ?? '',
      customerMobile: widget.customerMobile,
    );
    if (mounted) {
      setState(() {
        _isBlocked = blocked;
      });
    }
  }

  void _toggleBlockCustomer() async {
    if (_isBlocked) {
      await AuthService.unblockCustomer(
        sellerUsername: widget.seller.username ?? '',
        customerMobile: widget.customerMobile,
      );
      setState(() {
        _isBlocked = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer unblocked successfully! 🟢'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Block Customer?'),
            ],
          ),
          content: Text('Are you sure you want to block $_customerDisplayName?\n\nThey will not be able to send messages or place orders to your store.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block 🚫', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await AuthService.blockCustomer(
          sellerUsername: widget.seller.username ?? '',
          customerMobile: widget.customerMobile,
        );
        setState(() {
          _isBlocked = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer blocked! 🚫'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadMessages() async {
    _checkBlockedStatus();
    final msgs = await AuthService.getMessages(
      sellerUsername: widget.seller.username ?? '',
      customerMobile: widget.customerMobile,
    );
    await AuthService.annotateMessagesWithLifetimeHierarchy(
      sellerUsername: widget.seller.username ?? '',
      customerMobile: widget.customerMobile,
      messages: msgs,
    );
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  Future<void> _showCustomerDetailsSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('customer_addresses_${widget.customerMobile}');
    List<Map<String, dynamic>> savedAddresses = [];

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        savedAddresses = List<Map<String, dynamic>>.from(list);

        // Sanitize: Strictly ONLY 1 address must be default!
        bool foundDefault = false;
        for (var addr in savedAddresses) {
          if (addr['isDefault'] == true) {
            if (foundDefault) {
              addr['isDefault'] = false;
            } else {
              foundDefault = true;
            }
          }
        }
        if (!foundDefault && savedAddresses.isNotEmpty) {
          savedAddresses.first['isDefault'] = true;
        }
      } catch (e) {
        debugPrint('Error parsing customer saved addresses: $e');
      }
    }

    final totalOrders = _messages.length;
    final readyOrders = _messages.where((m) => (m['order_status'] ?? '').toString().toLowerCase() == 'ready').length;
    final pendingOrders = totalOrders - readyOrders;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row with Avatar and Mobile
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF8B5CF6),
                    child: Icon(Icons.person_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customerDisplayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mobile: +91 ${widget.customerMobile}',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Verified Customer Account',
                            style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick Contact Action Buttons (Send SMS 💬 & Call Customer 📞)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6), // Royal Purple Accent
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.sms_rounded, color: Colors.white, size: 20),
                      label: const Text('Send SMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () async {
                        final url = Uri.parse('sms:+91${widget.customerMobile}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Could not open SMS app.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6), // Phone Blue
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                      label: const Text('Call Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () async {
                        final url = Uri.parse('tel:+91${widget.customerMobile}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Could not initiate phone call.')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Order Stats Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Text('$totalOrders', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          const Text('Total Orders', style: TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        children: [
                          Text('$readyOrders', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          const SizedBox(height: 2),
                          const Text('Approved / Ready', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE047)),
                      ),
                      child: Column(
                        children: [
                          Text('$pendingOrders', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFA16207))),
                          const SizedBox(height: 2),
                          const Text('Pending', style: TextStyle(fontSize: 11, color: Color(0xFFA16207))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Delivery Address Section Header
              const Text('Customer Delivery Address 📍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),

              if (savedAddresses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_off_rounded, color: Colors.grey, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No saved delivery address provided by customer yet.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...savedAddresses.map((addr) {
                  final tag = addr['tag'] ?? 'Home';
                  final houseNo = addr['houseNo'] ?? '';
                  final building = addr['building'] ?? '';
                  final locality = addr['locality'] ?? '';
                  final landmark = addr['landmark'] ?? '';
                  final city = addr['city'] ?? '';
                  final pincode = addr['pincode'] ?? '';
                  final receiver = addr['receiverName'] ?? '';
                  final phone = addr['mobile'] ?? '';
                  final isDefault = addr['isDefault'] == true;

                  IconData tagIcon = Icons.home_rounded;
                  if (tag == 'Work') tagIcon = Icons.work_rounded;
                  if (tag == 'Other') tagIcon = Icons.location_on_rounded;

                  final fullAddress = [
                    if (houseNo.isNotEmpty) houseNo,
                    if (building.isNotEmpty) building,
                    if (locality.isNotEmpty) locality,
                    if (landmark.isNotEmpty) 'Near $landmark',
                    if (city.isNotEmpty) city,
                    if (pincode.isNotEmpty) 'PIN: $pincode',
                  ].join(', ');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDefault ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: isDefault ? 1.5 : 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tagIcon, size: 14, color: const Color(0xFF15803D)),
                                  const SizedBox(width: 4),
                                  Text(tag.toUpperCase(), style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11)),
                                ],
                              ),
                            ),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF9C3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('DEFAULT ⭐', style: TextStyle(color: Color(0xFFA16207), fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ],
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: '$receiver\n$fullAddress\nPhone: +91 $phone'));
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Address copied to clipboard! 📋'), backgroundColor: Color(0xFF10B981)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.copy_rounded, size: 14, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text('Copy', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (receiver.isNotEmpty)
                          Text(receiver, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(fullAddress, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3)),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Phone: +91 $phone', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStatusTap(Map<String, dynamic> msgData) async {
    final msgId = (msgData['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final delStat = (msgData['delivery_status'] ?? '').toString().toLowerCase();
    if (delStat == 'picked up' || delStat == 'out for delivery' || delStat == 'delivered') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Delivery Boy order Pick Up kar chuka hai! Ab status nahi badla ja sakta.'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Parse items to verify all serial items are checked (Yes/No)
    List<Map<String, dynamic>> items = [];
    final rawJson = msgData['items_json'];
    if (rawJson != null && rawJson.toString().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson.toString());
        items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    } else {
      final rawText = msgData['message'] ?? '';
      final lines = rawText.toString().split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          items.add({'text': trimmed, 'status': 0});
        }
      }
    }

    final hasUncheckedItem = items.any((it) => ((it['status'] as num?)?.toInt() ?? 0) == 0);

    final currentStatus = (msgData['order_status'] ?? 'Status').toString();
    final isCurrentlyReady = currentStatus.toLowerCase() == 'ready';

    final String? selectedStatus = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentlyReady ? const Color(0xFFFEF2F2) : const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyReady ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                    color: isCurrentlyReady ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  isCurrentlyReady ? 'Mark Order as Pending?' : 'Mark Order as Ready?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isCurrentlyReady
                      ? 'Revert order status back to Pending?'
                      : 'Is this customer order packed & ready for delivery?',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    // Ready Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: const Text('Ready ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          Navigator.pop(ctx, 'Ready');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cancel Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                        label: const Text('Cancel ✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          Navigator.pop(ctx, 'Cancel');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedStatus == null) return;

    if (selectedStatus == 'Ready') {
      // 1. Check if items are checked (Yes/No)
      if (hasUncheckedItem) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Pehle saare items ko Yes (✓) ya No (✕) check karein, tabhi Order Ready ho sakta hai!'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 2. Check if Order Amount is added
      final rawAmt = msgData['order_amount'] ?? msgData['amount'];
      double orderAmt = 0.0;
      if (rawAmt != null && rawAmt.toString().isNotEmpty && rawAmt.toString() != 'null') {
        orderAmt = double.tryParse(rawAmt.toString()) ?? 0.0;
      }

      if (orderAmt <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Pehle Order Total Amount (₹) enter karein, tabhi Order Ready ho sakta hai!'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 3. Check if Bill Photo is attached
      final String billImg = (msgData['bill_image'] ?? '').toString();
      if (billImg.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Pehle Paper Bill Photo (📷+) attach karein, tabhi Order Ready ho sakta hai!'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    final finalStatus = (selectedStatus == 'Cancel' || selectedStatus == 'Cancelled') ? 'Cancelled' : selectedStatus;

    setState(() {
      msgData['order_status'] = finalStatus;
    });

    await AuthService.updateOrderStatus(
      messageId: msgId,
      orderStatus: finalStatus,
    );

    final String rawOrderId = (msgData['order_id'] ?? 'Order #$msgId').toString();
    final String sellerDisplayName = (widget.seller.name.isNotEmpty ? widget.seller.name : widget.seller.username).toString();
    final String sellerUser = widget.seller.username.toString();

    if (finalStatus == 'Cancelled') {
      // Scenario 2: Seller cancels order -> Notify Customer
      await NotificationService.notifyCustomerOrderCancelled(
        customerMobile: widget.customerMobile,
        sellerName: sellerDisplayName,
        orderId: rawOrderId,
        reason: 'Cancelled by seller',
      );
    } else if (finalStatus == 'Ready' || finalStatus == 'Approved') {
      // Scenario 3: Seller sets Ready/Approved -> Notify Customer & Delivery Boys
      await NotificationService.notifyOrderReady(
        customerMobile: widget.customerMobile,
        sellerUsername: sellerUser,
        sellerName: sellerDisplayName,
        orderId: rawOrderId,
      );
    }
  }

  void _showItemStatusDialog(Map<String, dynamic> msgData, int itemIndex) {
    final delStat = (msgData['delivery_status'] ?? '').toString().toLowerCase();
    if (delStat == 'picked up' || delStat == 'out for delivery' || delStat == 'delivered') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Delivery Boy order Pick Up kar chuka hai! Ab items update nahi honge.'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    List<Map<String, dynamic>> items = [];
    final rawJson = msgData['items_json'];
    if (rawJson != null && rawJson.toString().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson.toString());
        items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    } else {
      final rawText = msgData['message'] ?? '';
      final lines = rawText.toString().split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          items.add({'text': trimmed, 'status': 0});
        }
      }
    }

    if (itemIndex < 0 || itemIndex >= items.length) return;
    final itemText = items[itemIndex]['text'] ?? 'Item';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  itemText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: const Text('Yes ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateItemStatusInBackend(msgData, itemIndex, 1);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                        label: const Text('No ✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateItemStatusInBackend(msgData, itemIndex, 2);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateItemStatusInBackend(Map<String, dynamic> msgData, int itemIndex, int newStatusVal) async {
    List<Map<String, dynamic>> items = [];
    final rawJson = msgData['items_json'];
    if (rawJson != null && rawJson.toString().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson.toString());
        items = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    } else {
      final rawText = msgData['message'] ?? '';
      final lines = rawText.toString().split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          items.add({'text': trimmed, 'status': 0});
        }
      }
    }

    if (itemIndex < 0 || itemIndex >= items.length) return;

    items[itemIndex]['status'] = newStatusVal;

    final updatedJsonStr = jsonEncode(items);

    setState(() {
      msgData['items_json'] = updatedJsonStr;
    });

    final msgId = (msgData['id'] as num?)?.toInt() ?? 0;
    if (msgId != 0) {
      await AuthService.updateItemStatus(
        messageId: msgId,
        items: items,
        sellerName: widget.seller.name,
        itemNum: itemIndex + 1,
        status: newStatusVal,
      );
    }
  }

  void _showAddAmountDialog(Map<String, dynamic> msgData) {
    final delStat = (msgData['delivery_status'] ?? '').toString().toLowerCase().trim();
    final ordStat = (msgData['order_status'] ?? '').toString().toLowerCase().trim();
    final pickedUpAt = (msgData['picked_up_at'] ?? msgData['pickup_time'] ?? '').toString().trim();
    final deliveredAt = (msgData['delivered_at'] ?? msgData['delivered_time'] ?? '').toString().trim();

    final bool isPickedUpOrBeyond = delStat == 'picked up' ||
        delStat == 'out for delivery' ||
        delStat == 'delivered' ||
        ordStat == 'pickup' ||
        ordStat == 'delivered' ||
        pickedUpAt.isNotEmpty ||
        deliveredAt.isNotEmpty;

    if (isPickedUpOrBeyond) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Delivery Boy order Pick Up kar chuka hai! Ab bill / amount edit nahi ho sakta 🔒'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final msgId = (msgData['id'] as num?)?.toInt() ?? 0;
    if (msgId == 0) return;

    final rawAmtStr = (msgData['order_amount'] ?? msgData['amount'] ?? '').toString().trim();
    final double? existingAmtNum = double.tryParse(rawAmtStr);
    
    // Initial text: if 0, 0.0, 0.00, or null/empty, leave text EMPTY so seller doesn't have to backspace!
    final String initialText = (existingAmtNum == null || existingAmtNum == 0)
        ? ''
        : (existingAmtNum % 1 == 0 ? existingAmtNum.toInt().toString() : existingAmtNum.toString());

    final TextEditingController amountController = TextEditingController(text: initialText);
    final FocusNode amountFocusNode = FocusNode();

    amountFocusNode.addListener(() {
      if (amountFocusNode.hasFocus) {
        final text = amountController.text.trim();
        if (text == '0' || text == '0.0' || text == '0.00') {
          amountController.clear();
        } else if (text.isNotEmpty) {
          amountController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: amountController.text.length,
          );
        }
      }
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.currency_rupee_rounded, color: Color(0xFF0F172A), size: 22),
              SizedBox(width: 6),
              Text('Enter Order Amount', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter bill/order total amount for this order:', style: TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                focusNode: amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                onTap: () {
                  final text = amountController.text.trim();
                  if (text == '0' || text == '0.0' || text == '0.00') {
                    amountController.clear();
                  }
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF0F172A)),
                  hintText: '0.00',
                  hintStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final text = amountController.text.trim();
                final double parsed = double.tryParse(text) ?? 0.0;
                Navigator.pop(ctx);

                setState(() {
                  msgData['order_amount'] = parsed;
                });

                await AuthService.updateOrderAmount(
                  messageId: msgId,
                  orderAmount: parsed,
                );
              },
              child: const Text('Save Amount ₹', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: InkWell(
          onTap: _showCustomerDetailsSheet,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF8B5CF6),
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerDisplayName != 'Customer' ? _customerDisplayName : 'Customer (+91 ${widget.customerMobile})',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Tap for address & details 📍',
                        style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
            tooltip: 'Call Customer',
            onPressed: () async {
              final mobile = widget.customerMobile.trim();
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'block_unblock') {
                _toggleBlockCustomer();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'block_unblock',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                      color: _isBlocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isBlocked ? 'Unblock Customer 🟢' : 'Block Customer 🚫',
                      style: TextStyle(
                        color: _isBlocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            // Messages list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No order messages found.',
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
                            final isSellerSender = senderType == 'seller';

                            return Align(
                              alignment: isSellerSender ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.84,
                                ),
                                child: OrderCardWidget(
                                  messageData: msg,
                                  isSeller: true,
                                  onItemTap: (itemIdx) {
                                    _showItemStatusDialog(msg, itemIdx);
                                  },
                                  onStatusTap: () {
                                    _handleStatusTap(msg);
                                  },
                                  onAmountTap: () {
                                    _showAddAmountDialog(msg);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Blocked Banner (If customer is blocked)
            if (_isBlocked)
              Container(
                width: double.infinity,
                color: const Color(0xFFFEF2F2),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This customer is blocked. Tap 3 dots above to unblock.',
                            style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
