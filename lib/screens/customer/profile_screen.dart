import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../vps_api_service.dart';
import '../dashboards/customer_dashboard.dart';
import '../role_selection_screen.dart';
import 'customer_addresses_screen.dart';
import 'search_seller_screen.dart';

enum FlipAxis { horizontal, vertical }

class CustomerProfileScreen extends StatefulWidget {
  final UserModel customer;

  const CustomerProfileScreen({super.key, required this.customer});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> with TickerProviderStateMixin {
  String _addressSubtitle = 'Home, Work, Other';
  late String _currentName;
  String _selectedSellerUsername = '';
  String _selectedSellerName = '';
  String _selectedSellerMobile = '';

  late AnimationController _flipController;
  late AnimationController _shimmerController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  FlipAxis _currentFlipAxis = FlipAxis.horizontal;

  @override
  void initState() {
    super.initState();
    _currentName = widget.customer.name.isNotEmpty ? widget.customer.name : 'Customer';
    _loadProfileAndAddress();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _toggleFlipCard({FlipAxis axis = FlipAxis.horizontal}) {
    setState(() {
      _currentFlipAxis = axis;
    });
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _loadProfileAndAddress() async {
    final mobile = widget.customer.mobile ?? '';

    // Load saved customer profile name if available
    final profile = await AuthService.getCustomerProfile(mobile);
    if (profile != null && profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
      final pName = profile['name'].toString().trim();
      if (!pName.startsWith('Customer')) {
        widget.customer.name = pName;
        _currentName = pName;
      }
    }

    // Load active selected seller
    final savedSeller = await AuthService.getLastSelectedSeller();
    if (savedSeller != null) {
      if (mounted) {
        setState(() {
          _selectedSellerUsername = savedSeller['username'] ?? '';
          _selectedSellerName = savedSeller['name'] ?? savedSeller['username'] ?? '';
          _selectedSellerMobile = savedSeller['mobile'] ?? '';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedSellerUsername = '';
          _selectedSellerName = '';
          _selectedSellerMobile = '';
        });
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('customer_addresses_$mobile');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        if (list.isNotEmpty) {
          final defaultAddr = list.firstWhere((a) => a['isDefault'] == true, orElse: () => list.first);
          final tag = defaultAddr['tag'] ?? 'Address';
          final house = defaultAddr['houseNo'] ?? '';
          final city = defaultAddr['city'] ?? '';

          if (mounted) {
            setState(() {
              _addressSubtitle = '$tag: $house, $city (${list.length} Saved)';
            });
          }
        }
      } catch (e) {
        debugPrint('Error parsing profile address subtitle: $e');
      }
    }

    await _calculateOrderStamps();
  }

  int _totalDeliveredOrders = 0;
  int _filledStamps = 0;
  int _giftsEarned = 0;

  Future<void> _calculateOrderStamps() async {
    final mobile = (widget.customer.mobile ?? '').trim();
    if (mobile.isEmpty) return;

    try {
      final Set<String> processedOrderIds = {};
      int deliveredCount = 0;

      // 1. Fetch orders from VPS Database / merged placed orders
      try {
        final dbOrders = await AuthService.getCustomerPlacedOrders(mobile);
        for (var o in dbOrders) {
          final idStr = (o['id'] ?? o['order_id'] ?? '').toString();
          final delStat = (o['delivery_status'] ?? '').toString().toLowerCase();
          final ordStat = (o['status'] ?? o['order_status'] ?? '').toString().toLowerCase();

          final bool isDelivered = delStat == 'delivered' || ordStat == 'delivered';
          final bool isCancelled = delStat == 'cancelled' || ordStat == 'cancelled' || ordStat == 'deleted';

          if (isDelivered && !isCancelled) {
            final key = idStr.isNotEmpty ? idStr : (o['timestamp'] ?? o['date'] ?? '').toString();
            if (key.isNotEmpty && !processedOrderIds.contains(key)) {
              processedOrderIds.add(key);
              deliveredCount++;
            }
          }
        }
      } catch (_) {}

      // 2. Scan persistent saved_delivery_statuses from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> savedDeliveryStatuses = {};
      try {
        final dStr = prefs.getString('saved_delivery_statuses');
        if (dStr != null && dStr.isNotEmpty) {
          savedDeliveryStatuses = Map<String, dynamic>.from(jsonDecode(dStr));
        }
      } catch (_) {}

      savedDeliveryStatuses.forEach((msgId, data) {
        if (data is Map) {
          final custMob = (data['customer_mobile'] ?? '').toString().trim();
          if (custMob.isEmpty || custMob == mobile) {
            final delStat = (data['delivery_status'] ?? '').toString().toLowerCase();
            if (delStat == 'delivered' && !processedOrderIds.contains(msgId)) {
              processedOrderIds.add(msgId);
              deliveredCount++;
            }
          }
        }
      });

      // 3. Fallback scan local chat keys if needed
      if (processedOrderIds.isEmpty) {
        final allKeys = prefs.getKeys().toList();
        final msgKeys = allKeys.where((k) => (k.startsWith('msgs_') || k.startsWith('messages_')) && k.contains(mobile)).toList();

        for (var key in msgKeys) {
          final str = prefs.getString(key);
          if (str != null && str.isNotEmpty) {
            try {
              final List decoded = jsonDecode(str);
              for (var m in decoded) {
                if (m is! Map) continue;
                final msgIdStr = (m['id'] ?? m['order_id'] ?? m['_calculated_order_id'] ?? '').toString();
                if (msgIdStr.isEmpty) continue;

                String delStat = (m['delivery_status'] ?? '').toString().toLowerCase();
                String ordStat = (m['order_status'] ?? '').toString().toLowerCase();

                if (savedDeliveryStatuses.containsKey(msgIdStr)) {
                  final val = savedDeliveryStatuses[msgIdStr];
                  if (val is Map) {
                    delStat = (val['delivery_status'] ?? delStat).toString().toLowerCase();
                  } else if (val != null) {
                    delStat = val.toString().toLowerCase();
                  }
                }

                final bool isDelivered = delStat == 'delivered' || ordStat == 'delivered';
                final bool isCancelled = delStat == 'cancelled' || ordStat == 'cancelled';

                if (isDelivered && !isCancelled && !processedOrderIds.contains(msgIdStr)) {
                  processedOrderIds.add(msgIdStr);
                  deliveredCount++;
                }
              }
            } catch (_) {}
          }
        }
      }

      final gifts = deliveredCount ~/ 5;
      int stamps = 0;
      if (deliveredCount > 0) {
        final rem = deliveredCount % 5;
        stamps = (rem == 0) ? 5 : rem;
      }

      if (mounted) {
        setState(() {
          _totalDeliveredOrders = deliveredCount;
          _filledStamps = stamps;
          _giftsEarned = gifts;
        });
      }
    } catch (e) {
      debugPrint('Error calculating order stamps: $e');
    }
  }

  void _deleteSeller() async {
    final sellerName = _selectedSellerName.isNotEmpty ? _selectedSellerName : 'this seller';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Delete Seller?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$sellerName" from your connected store list?\n\nYou will need to search for this seller again if you wish to re-connect in the future.',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
            label: const Text('Delete 🗑️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.deleteCustomerSellerConnection(
        sellerUsername: _selectedSellerUsername,
        customerMobile: widget.customer.mobile ?? '',
      );
      await AuthService.clearLastSelectedSeller();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seller "$sellerName" removed! 🗑️'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (ctx) => CustomerDashboard(customer: widget.customer),
          ),
          (route) => false,
        );
      }
    }
  }

  void _editCustomerName() {
    final controller = TextEditingController(text: _currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Your Name ✏️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextFormField(
          controller: controller,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final mobile = widget.customer.mobile ?? '';
                await AuthService.saveCustomerProfile(mobile, name: newName);
                widget.customer.name = newName;
                await AuthService.saveUserSession(widget.customer);
                setState(() {
                  _currentName = newName;
                });
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name updated successfully! ✨'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Save Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildStampProgressWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🏵️', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    'Order Stamp Card (${_filledStamps}/5)',
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              if (_giftsEarned > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFF10B981)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.25), blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        '${_giftsEarned} Gift${_giftsEarned > 1 ? 's' : ''} Earned!',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Delivered: ${_totalDeliveredOrders}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 5 Digital Stamp Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (idx) {
              final bool isFilled = idx < _filledStamps;
              final int stampNum = idx + 1;

              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isFilled
                          ? const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isFilled ? null : const Color(0xFFF1F5F9),
                      border: Border.all(
                        color: isFilled ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        width: isFilled ? 2 : 1.5,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: isFilled
                          ? const Text('🏵️', style: TextStyle(fontSize: 18))
                          : Text(
                              '$stampNum',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFilled ? 'Filled ✅' : 'Blank $stampNum',
                    style: TextStyle(
                      color: isFilled ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      fontSize: 9.5,
                      fontWeight: isFilled ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),

          // Gift Unlocked Banner if earned
          if (_giftsEarned > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Earned Rewards: ', style: TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold)),
                  ...List.generate(
                    _giftsEarned > 5 ? 5 : _giftsEarned,
                    (_) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text('🎁', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  if (_giftsEarned > 5)
                    Text(' x${_giftsEarned}', style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF), // Pure White
              Color(0xFFF0FDF4), // Mint Snow
              Color(0xFFECFDF5), // Light Emerald Pearl
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
        ),
        child: Stack(
          children: [
            // Decorative Background Circle Highlights
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.06),
                ),
              ),
            ),

            // Card Main Content (Clean Light Layout)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
              child: Column(
                children: [
                  // Top Header Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: const [
                            Text('🏵️', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text(
                              'DIGITAL STAMP REWARDS',
                              style: TextStyle(color: Color(0xFF047857), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flip_camera_android_rounded, size: 12, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text('Tap to Flip 🔄', style: TextStyle(color: Color(0xFF334155), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Avatar + Name + Phone Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFF10B981)],
                          ),
                        ),
                        child: const CircleAvatar(
                          radius: 26,
                          backgroundColor: Color(0xFF0F172A),
                          child: Icon(Icons.person_rounded, size: 32, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _editCustomerName,
                                  child: const Icon(Icons.edit_rounded, size: 15, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mobile: +91 ${widget.customer.mobile ?? ''}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5 Digital Stamp Widget
                  _buildStampProgressWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF), // Pure White
              Color(0xFFF8FAFC), // Slate Snow
              Color(0xFFECFDF5), // Light Mint
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'DIGITAL STAMP REWARDS 🎁',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _giftsEarned > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _giftsEarned > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Text(
                          _giftsEarned > 0 ? '${_giftsEarned} GIFT UNLOCKED 🎁' : '${_filledStamps}/5 STAMPS 🏵️',
                          style: TextStyle(
                            color: _giftsEarned > 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 64, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentName,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'ID: DM-CUST-${widget.customer.mobile ?? '812885'}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Total Delivered Orders: ${_totalDeliveredOrders}',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _giftsEarned > 0
                                  ? '🎁 ${_giftsEarned} Gift Icon${_giftsEarned > 1 ? 's' : ''} Unlocked!'
                                  : 'Need 5 delivered orders for 1 Gift Icon (${_filledStamps}/5 Delivered)',
                              style: TextStyle(
                                color: _giftsEarned > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan at Merchant Store to Redeem Gifts 🎁',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.flip_camera_android_rounded, size: 12, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text('Tap to Flip Back 🔄', style: TextStyle(color: Color(0xFF334155), fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.person_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Interactive 3D Flip Header Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: GestureDetector(
                onTap: () => _toggleFlipCard(axis: FlipAxis.horizontal),
                onPanEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond;
                  final dx = velocity.dx.abs();
                  final dy = velocity.dy.abs();

                  if (dx > dy && dx > 80) {
                    // Left-to-Right or Right-to-Left Drag
                    _toggleFlipCard(axis: FlipAxis.horizontal);
                  } else if (dy > dx && dy > 80) {
                    // Top-to-Bottom or Bottom-to-Top Drag
                    _toggleFlipCard(axis: FlipAxis.vertical);
                  } else {
                    // Fallback tap toggle
                    _toggleFlipCard(axis: FlipAxis.horizontal);
                  }
                },
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final angle = _flipAnimation.value * 3.141592653589793;
                    final isBack = angle >= (3.141592653589793 / 2);

                    final transform = Matrix4.identity()..setEntry(3, 2, 0.001);
                    if (_currentFlipAxis == FlipAxis.horizontal) {
                      transform.rotateY(angle);
                    } else {
                      transform.rotateX(angle);
                    }

                    final backTransform = Matrix4.identity();
                    if (_currentFlipAxis == FlipAxis.horizontal) {
                      backTransform.rotateY(3.141592653589793);
                    } else {
                      backTransform.rotateX(3.141592653589793);
                    }

                    return Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child: isBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: backTransform,
                              child: _buildCardBack(),
                            )
                          : _buildCardFront(),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Full-Width Edge-to-Edge Profile Options Menu Container (0 side margin)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.location_on_rounded,
                    title: 'Saved Delivery Addresses',
                    subtitle: _addressSubtitle,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerAddressesScreen(customer: widget.customer),
                        ),
                      );
                      _loadProfileAndAddress();
                    },
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.notifications_rounded,
                    title: 'Order Notifications',
                    subtitle: 'SMS, WhatsApp, App Alert',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.language_rounded,
                    title: 'App Language',
                    subtitle: 'Hindi / English',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 64, endIndent: 0),
                  _buildProfileTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Customer Care',
                    subtitle: '24/7 Support Desk',
                    onTap: _showHelpSupportModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // My Selected Seller Card with Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('My Selected Seller 🏪', style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedSellerName.isNotEmpty ? _selectedSellerName : 'No Seller Selected',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            if (_selectedSellerMobile.isNotEmpty)
                              Text('Mobile: +91 $_selectedSellerMobile', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF8B5CF6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF8B5CF6)),
                            label: const Text('Switch', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              await AuthService.clearLastSelectedSeller();
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (ctx) => CustomerDashboard(customer: widget.customer),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                          if (_selectedSellerName.isNotEmpty && _selectedSellerName != 'No Seller Selected') ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _deleteSeller,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logout Button with Padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text(
                    'Logout from Daily Mart',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () => _logout(context),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Daily Mart • Powered by Apna Store', style: TextStyle(color: Colors.black45, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showHelpSupportModal() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('customer_support_email_${widget.customer.mobile}') ?? '';

    final nameController = TextEditingController(text: _currentName);
    final mobileController = TextEditingController(text: widget.customer.mobile ?? '');
    final emailController = TextEditingController(text: savedEmail);
    final messageController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
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

                      // Title Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.help_center_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Help & Customer Care 🎧',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Direct Support Desk: Daily_mart',
                                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.grey),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Name Field
                      const Text('Your Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 20),
                          hintText: 'Enter your name',
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mobile Field
                      const Text('Mobile Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter mobile number' : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF64748B), size: 20),
                          hintText: 'Enter mobile number',
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email Field
                      const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter email address';
                          if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                          return null;
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFF64748B), size: 20),
                          hintText: 'e.g. user@gmail.com',
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Message Field
                      const Text('Message / Query', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: messageController,
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your message' : null,
                        decoration: InputDecoration(
                          hintText: 'Type your message or issue description here...',
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Direct Submit Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        label: Text(
                          isSubmitting ? 'Sending Message...' : 'Send Message 🚀',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                setModalState(() => isSubmitting = true);

                                final name = nameController.text.trim();
                                final mobile = mobileController.text.trim();
                                final email = emailController.text.trim();
                                final msg = messageController.text.trim();

                                // Save email persistently for next time
                                prefs.setString('customer_support_email_${widget.customer.mobile}', email);

                                // 1. Background Silent HTTP POST to FormSubmit (With Browser User-Agent & Headers)
                                try {
                                  await http.post(
                                    Uri.parse('https://formsubmit.co/ajax/infopushpraj343@gmail.com'),
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Accept': 'application/json',
                                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, Gecko) Chrome/120.0.0.0 Safari/537.36',
                                      'Origin': 'https://formsubmit.co',
                                      'Referer': 'https://formsubmit.co/',
                                    },
                                    body: jsonEncode({
                                      'name': name,
                                      'mobile': mobile,
                                      'email': email,
                                      'message': 'Customer Query: $msg\nReply Email: $email\nMobile: +91 $mobile',
                                      '_subject': 'Daily Mart Support - $name ($mobile)',
                                      '_captcha': 'false',
                                      '_template': 'table',
                                    }),
                                  ).timeout(const Duration(seconds: 8));
                                } catch (e) {
                                  debugPrint('FormSubmit mailer error: $e');
                                }

                                // 2. Instant Backup POST to Web3Forms API
                                try {
                                  await http.post(
                                    Uri.parse('https://api.web3forms.com/submit'),
                                    headers: {
                                      'Content-Type': 'application/json',
                                      'Accept': 'application/json',
                                    },
                                    body: jsonEncode({
                                      'access_key': 'e4d92415-4676-476c-bd48-c84cb1c33f23',
                                      'email': email,
                                      'name': name,
                                      'subject': 'Daily Mart Support - $name ($mobile)',
                                      'message': 'Customer Name: $name\nMobile Number: +91 $mobile\nCustomer Email: $email\n\nQuery:\n$msg',
                                      'to_email': 'infopushpraj343@gmail.com',
                                    }),
                                  ).timeout(const Duration(seconds: 8));
                                } catch (e) {
                                  debugPrint('Web3Forms mailer error: $e');
                                }

                                // 3. Sync to VPS API Database
                                try {
                                  await VpsApiService.post('submit-support-ticket', {
                                    'name': name,
                                    'mobile': mobile,
                                    'email': email,
                                    'message': msg,
                                  });
                                } catch (_) {}

                                if (!mounted) return;
                                Navigator.pop(ctx); // Close Form BottomSheet

                                // 3. Show Direct In-App Success Alert Dialog (Zero external redirects!)
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFDCFCE7),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Message Sent! 🎉',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Thank you $name!',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Your message has been sent directly to Daily_mart.',
                                          style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '📩 Reply target: $email\n📞 Contact: +91 $mobile',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => Navigator.pop(dialogCtx),
                                        child: const Text('OK 👍', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF10B981)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
