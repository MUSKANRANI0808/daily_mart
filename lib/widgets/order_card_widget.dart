import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class OrderCardWidget extends StatefulWidget {
  final Map<String, dynamic> messageData;
  final bool isSeller; // true if seller, false if customer
  final Function(int itemIndex)? onItemTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onAmountTap;
  final VoidCallback? onPayNowTap;

  const OrderCardWidget({
    super.key,
    required this.messageData,
    required this.isSeller,
    this.onItemTap,
    this.onStatusTap,
    this.onDeleteTap,
    this.onAmountTap,
    this.onPayNowTap,
  });

  @override
  State<OrderCardWidget> createState() => _OrderCardWidgetState();
}

class _OrderCardWidgetState extends State<OrderCardWidget> {
  bool _isExpanded = false;
  String? _loadedCancelReason;

  @override
  void initState() {
    super.initState();
    _loadCancelReason();
  }

  @override
  void didUpdateWidget(OrderCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageData != widget.messageData) {
      _loadCancelReason();
    }
  }

  void _loadCancelReason() async {
    final msgId = (widget.messageData['id'] ?? '').toString();
    final orderId = (widget.messageData['order_id'] ?? widget.messageData['_calculated_order_id'] ?? '').toString();
    final cleanOrderId = orderId.replaceAll('#', '').replaceAll('Order', '').trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('saved_cancel_reasons');
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> saved = Map<String, dynamic>.from(jsonDecode(str));
        final reason = (saved[msgId] ?? saved[cleanOrderId] ?? saved[orderId] ?? '').toString();
        if (reason.isNotEmpty && mounted) {
          setState(() {
            _loadedCancelReason = reason;
          });
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _parseItems() {
    final rawJson = widget.messageData['items_json'];
    if (rawJson != null && rawJson.toString().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson.toString());
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    final rawText = widget.messageData['message'] ?? '';
    final lines = rawText.toString().split('\n');
    final items = <Map<String, dynamic>>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.contains('📍 Delivery Address') &&
          !trimmed.contains('📍') &&
          !trimmed.contains('📏 Distance') &&
          !trimmed.contains('📏')) {
        items.add({'text': trimmed, 'status': 0});
      }
    }
    return items;
  }

  List<Map<String, dynamic>> _parseLogs() {
    final rawJson = widget.messageData['logs_json'];
    if (rawJson != null && rawJson.toString().isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson.toString());
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final items = _parseItems();
    final logs = _parseLogs();
    final msgId = widget.messageData['id'];
    String rawOrderId = (widget.messageData['order_id'] ?? widget.messageData['_calculated_order_id'] ?? '').toString().trim();
    if (rawOrderId.isEmpty || rawOrderId == 'null') {
      if (msgId != null && msgId is num) {
        rawOrderId = 'Order ${msgId.toInt()}';
      } else if (msgId != null && msgId.toString().isNotEmpty) {
        final numMatch = RegExp(r'\d+').firstMatch(msgId.toString());
        if (numMatch != null) {
          rawOrderId = 'Order ${numMatch.group(0)}';
        } else {
          rawOrderId = 'Order ${msgId.toString()}';
        }
      }
    }
    if (!rawOrderId.toLowerCase().startsWith('order')) {
      rawOrderId = 'Order $rawOrderId';
    }
    final orderId = rawOrderId.replaceAll('#', '').replaceAll('  ', ' ');
    String displayOrderId = orderId;
    if (!widget.isSeller && displayOrderId.contains('/')) {
      final clean = displayOrderId.replaceAll('Order', '').trim();
      final parts = clean.split('/');
      if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
        displayOrderId = 'Order ${parts[0].trim()}';
      }
    }

    final orderStatus = widget.messageData['order_status'] ?? 'Status';
    final createdAt = widget.messageData['created_at'] ?? '';
    final senderType = widget.messageData['sender_type'] ?? 'customer';
    final isReady = orderStatus.toString().toLowerCase() == 'ready';
    final isCancelled = orderStatus.toString().toLowerCase() == 'cancelled' || orderStatus.toString().toLowerCase() == 'cancel';
    final rawIsRead = widget.messageData['is_read'];
    final bool isRead = rawIsRead == true || rawIsRead == 1 || rawIsRead == '1' || rawIsRead == 'true';

    final rawAmt = widget.messageData['order_amount'] ?? widget.messageData['amount'];
    double? orderAmt;
    if (rawAmt != null && rawAmt.toString().isNotEmpty && rawAmt.toString() != 'null') {
      orderAmt = double.tryParse(rawAmt.toString());
    }

    if (orderAmt == null || orderAmt <= 0) {
      double totalFromItems = 0.0;
      for (var item in items) {
        final text = (item['text'] ?? '').toString();
        final match = RegExp(r'₹\s*([\d\.]+)').firstMatch(text);
        if (match != null) {
          final amt = double.tryParse(match.group(1) ?? '');
          if (amt != null && amt > 0) {
            totalFromItems += amt;
          }
        }
      }
      if (totalFromItems > 0) {
        orderAmt = totalFromItems;
      }
    }

    String? amountDisplay;
    if (orderAmt != null && orderAmt > 0) {
      amountDisplay = (orderAmt % 1 == 0) ? orderAmt.toInt().toString() : orderAmt.toStringAsFixed(2);
    }

    final String paymentStatus = (widget.messageData['payment_status'] ?? '').toString().toLowerCase();
    final bool isPaid = paymentStatus == 'paid';
    final String utrNumber = (widget.messageData['payment_utr'] ?? '').toString();

    final String deliveryStatus = (widget.messageData['delivery_status'] ?? '').toString().toLowerCase().trim();
    final String rawDeliveredAt = (widget.messageData['delivered_at'] ?? widget.messageData['delivered_time'] ?? widget.messageData['updated_at'] ?? '').toString().trim();
    final String rawCancelledAt = (widget.messageData['cancelled_at'] ?? widget.messageData['cancelled_time'] ?? widget.messageData['updated_at'] ?? '').toString().trim();
    final String cancelReasonFromMsg = (widget.messageData['cancel_reason'] ?? widget.messageData['cancellation_reason'] ?? widget.messageData['reason'] ?? '').toString();
    final String cancelReason = cancelReasonFromMsg.isNotEmpty ? cancelReasonFromMsg : (_loadedCancelReason ?? '');
    final String pickedUpAt = (widget.messageData['picked_up_at'] ?? widget.messageData['pickup_time'] ?? '').toString().trim();
    final String billImage = (widget.messageData['bill_image'] ?? '').toString();

    final String normOrderStatus = orderStatus.toString().toLowerCase().trim();
    final bool isDelivered = deliveryStatus == 'delivered' || normOrderStatus == 'delivered' || rawDeliveredAt.isNotEmpty;
    final bool isPickedUpOrBeyond = deliveryStatus == 'picked up' ||
        deliveryStatus == 'out for delivery' ||
        deliveryStatus == 'delivered' ||
        normOrderStatus == 'pickup' ||
        normOrderStatus == 'delivered' ||
        pickedUpAt.isNotEmpty ||
        rawDeliveredAt.isNotEmpty;

    final bool isDeleted = orderStatus.toString().toLowerCase() == 'deleted' ||
        widget.messageData['is_deleted'] == true ||
        widget.messageData['is_deleted'] == 1 ||
        widget.messageData['is_deleted'] == '1' ||
        widget.messageData['message'].toString().contains('Deleted');

    if (isDeleted) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Soft Light Grey
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9), // Muted Thin Grey Border
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B), size: 14),
            const SizedBox(width: 6),
            Text(
              '$displayOrderId ... Deleted',
              style: const TextStyle(
                color: Color(0xFF64748B), // Muted Slate Grey Text
                fontWeight: FontWeight.w500, // Thinner / Patala Weight
                fontSize: 11.5, // Smaller Font Size
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6, right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Base Order Card Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Items Checklist (With right padding so items don't overlap 3D Ribbon)
                Padding(
                  padding: const EdgeInsets.only(right: 85.0),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (ctx, idx) {
                      final item = items[idx];
                      final itemText = item['text'] ?? '';
                      final status = (item['status'] as num?)?.toInt() ?? 0;

                      return InkWell(
                        onTap: (widget.isSeller && !isPaid && !isPickedUpOrBeyond)
                            ? () {
                                if (widget.onItemTap != null) {
                                  widget.onItemTap!(idx);
                                }
                              }
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: _buildStatusIcon(status),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  itemText,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    decoration: status == 2 ? TextDecoration.lineThrough : TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

          // Action Logs Section (if logs exist)
          _buildLogsSection(logs),

          const SizedBox(height: 10),

          // Row 1: Action Controls [Status] | [₹ 250] | [ 💳 Pay Now ] OR [ PAID ✅ ]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Pill (Glassmorphic Light Green if Ready, Soft Red if Cancelled) - Disabled when PAID or Picked Up
                InkWell(
                  onTap: (widget.isSeller && !isPaid && !isPickedUpOrBeyond) ? widget.onStatusTap : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isReady
                          ? const Color(0xFFDCFCE7)
                          : (isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: isReady
                          ? Border.all(color: const Color(0xFF86EFAC))
                          : (isCancelled ? Border.all(color: const Color(0xFFFCA5A5)) : null),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isReady) ...[
                          const Icon(Icons.check_rounded, size: 13, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                        ] else if (isCancelled) ...[
                          const Icon(Icons.cancel_rounded, size: 13, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          isReady ? 'Ready' : (isCancelled ? 'Cancelled' : 'Status'),
                          style: TextStyle(
                            color: isReady
                                ? const Color(0xFF15803D)
                                : (isCancelled ? const Color(0xFFDC2626) : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Rupee Amount Badge - Disabled when PAID or Picked Up
                if (widget.isSeller || amountDisplay != null) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: (widget.isSeller && !isPaid && !isPickedUpOrBeyond) ? widget.onAmountTap : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: amountDisplay != null ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: amountDisplay != null
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                              : const Color(0xFFCBD5E1),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              color: amountDisplay != null ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          if (amountDisplay != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              amountDisplay,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24), // Glowing Amber Gold
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                // BILL IMAGE / (+) CAMERA BADGE RIGHT BESIDE AMOUNT:
                if (billImage.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: () => _showBillImageDialog(billImage, isPickedUpOrBeyond),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // Light Ice Blue
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2563EB), width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF2563EB)),
                          SizedBox(width: 3),
                          Text(
                            'Bill',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (widget.isSeller && !isPickedUpOrBeyond) ...[
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: _pickAndSaveBillImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Slate Soft Grey
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF64748B), width: 0.9),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF475569)),
                          SizedBox(width: 2),
                          Text(
                            '+',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // PAYMENT SECTION RIGHT BESIDE AMOUNT:
                // If Paid: Show Glowing Green [ PAID ✅ ] Stamp
                // Else if Customer & Amount Available & Not Paid: Show Interactive [ 💳 Pay Now ]
                if (isPaid) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: Color(0xFF15803D), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'PAID',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!widget.isSeller && !isCancelled && amountDisplay != null && orderAmt != null && orderAmt > 0) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onPayNowTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Pay Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Row 2: Date Timestamp (Moved down!) + UTR Ref + Read Ticks + Delete Icon
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                createdAt,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500),
              ),
              if (isPaid && utrNumber.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  '| UTR: $utrNumber',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 8.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                (senderType == 'customer' && isRead) ? Icons.done_all_rounded : Icons.check_rounded,
                size: 15,
                color: (senderType == 'customer' && isRead) ? const Color(0xFF0284C7) : Colors.grey,
              ),

              // Delete Icon (Customer Only - Hidden when Seller marks order as Ready or Paid)
              if (!widget.isSeller && widget.onDeleteTap != null && !isReady && !isPaid) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: widget.onDeleteTap,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                  ),
                ),
              ],
            ],
          ),

          // Row 3: Picked Up Date & Time (With Delivery Boy Icon directly in front!)
          if (isPickedUpOrBeyond) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Image.asset(
                  'assets/images/Pickup_boy.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.delivery_dining_rounded,
                    size: 20,
                    color: Color(0xFF9333EA),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Picked Up: ${_formatDeliveredTimestamp(pickedUpAt.isNotEmpty ? pickedUpAt : rawDeliveredAt, createdAt)}',
                  style: const TextStyle(
                    color: Color(0xFF9333EA),
                    fontSize: 9.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          // Row 4: Delivered Date & Time (If order is delivered)
          if (isDelivered) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Image.asset(
                  'assets/images/Deliverd_boy.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.task_alt_rounded,
                    size: 18,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Delivered: ${_formatDeliveredTimestamp(rawDeliveredAt, createdAt)}',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 9.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],

          // Row 5: Cancelled Date & Time & Reason (If order is cancelled)
          if (isCancelled) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Cancelled: ${_formatDeliveredTimestamp(rawCancelledAt, createdAt)}${cancelReason.isNotEmpty ? ' • Reason: $cancelReason' : ''}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),

        // 3D Illusion Ribbon Tag (Emerging out from behind the top-right card edge)
        Positioned(
          top: 10,
          right: -8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A), // Midnight Slate Navy
                      Color(0xFF1E293B), // Dark Royal Slate
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                    topRight: Radius.circular(3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 5,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_rounded, size: 11.5, color: Colors.white),
                    const SizedBox(width: 3.5),
                    Text(
                      displayOrderId,
                      style: const TextStyle(
                        color: Colors.white, // Crisp Pure White
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ClipPath(
                clipper: _TriangleFoldClipper(),
                child: Container(
                  width: 8,
                  height: 7,
                  color: const Color(0xFF020617), // Dark Shadow Fold behind card edge
                ),
              ),
            ],
          ),
        ),

        // Translucent Round DELIVERED Stamp (Half inside order card, half outside left edge!)
        if (isDelivered) _buildDeliveredWatermarkStamp(),
      ],
    ),
  );
}

  Widget _buildDeliveredWatermarkStamp() {
    return Positioned(
      right: 10,
      bottom: 8,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -0.15,
          child: Image.asset(
            'assets/images/VERIFIDE.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsSection(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();

    final visibleLogs = _isExpanded || logs.length <= 2 ? logs : logs.take(2).toList();
    final remainingCount = logs.length - 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16, color: Color(0xFFE2E8F0)),
        ...visibleLogs.map((log) => _buildSingleLogTile(log)),
        if (logs.length > 2)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                _isExpanded ? 'Show less' : '...and $remainingCount more logs. Tap to show all',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleLogTile(Map<String, dynamic> log) {
    final itemNum = log['item_num'] ?? 1;
    final status = log['status'] ?? 1;
    final sellerName = log['seller_name'] ?? 'SELLER';
    final timestamp = log['timestamp'] ?? '';

    final isYes = status == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '$itemNum. ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            WidgetSpan(
              child: Icon(
                isYes ? Icons.check_rounded : Icons.close_rounded,
                size: 14,
                color: isYes ? const Color(0xFF15803D) : const Color(0xFFDC2626),
              ),
            ),
            TextSpan(
              text: isYes ? ' (yes) ' : ' (no) ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isYes ? const Color(0xFF15803D) : const Color(0xFFDC2626),
              ),
            ),
            TextSpan(
              text: '— $sellerName — $timestamp',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(int status) {
    switch (status) {
      case 1:
        return const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22); // Yes
      case 2:
        return const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22); // No
      case 0:
      default:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1.8),
            borderRadius: BorderRadius.circular(3),
          ),
        );
    }
  }

  String _formatDeliveredTimestamp(String raw, String fallback) {
    if (raw.trim().isEmpty || raw == 'null') return fallback;
    if (raw.contains('T')) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
      } catch (_) {}
    }
    return raw;
  }

  Future<void> _pickAndSaveBillImage() async {
    final String orderStatus = (widget.messageData['order_status'] ?? '').toString().toLowerCase().trim();
    final String deliveryStatus = (widget.messageData['delivery_status'] ?? '').toString().toLowerCase().trim();
    final String pickedUpAt = (widget.messageData['picked_up_at'] ?? widget.messageData['pickup_time'] ?? '').toString().trim();
    final String deliveredAt = (widget.messageData['delivered_at'] ?? widget.messageData['delivered_time'] ?? '').toString().trim();

    final bool isPickedUpOrBeyond = deliveryStatus == 'picked up' ||
        deliveryStatus == 'out for delivery' ||
        deliveryStatus == 'delivered' ||
        orderStatus == 'pickup' ||
        orderStatus == 'delivered' ||
        pickedUpAt.isNotEmpty ||
        deliveredAt.isNotEmpty;

    if (isPickedUpOrBeyond) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Delivery Boy order Pick Up kar chuka hai! Ab bill edit / change nahi ho sakta 🔒'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64Img = base64Encode(bytes);

        setState(() {
          widget.messageData['bill_image'] = base64Img;
        });

        final msgId = (widget.messageData['id'] as num?)?.toInt() ?? 0;
        final sellerUsername = (widget.messageData['seller_username'] ?? widget.messageData['seller_name'] ?? '').toString();
        final customerMobile = (widget.messageData['customer_mobile'] ?? '').toString();

        if (msgId != 0) {
          await AuthService.saveOrderBillImage(
            messageId: msgId,
            base64Image: base64Img,
            sellerUsername: sellerUsername,
            customerMobile: customerMobile,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill photo saved successfully! 📄✅'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error capturing bill image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showFullScreenImageDialog(String base64Img) {
    showDialog(
      context: context,
      builder: (fullCtx) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(fullCtx),
              ),
              title: const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFFFBBF24), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bill Photo Zoom 🧾',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(fullCtx),
                ),
              ],
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 6.0,
                child: Image.memory(
                  base64Decode(base64Img),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Text('Failed to load bill image.', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBillImageDialog(String base64Img, bool isPickedUpOrBeyond) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Order Bill Photo 🧾',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFFFBBF24), size: 22),
                        tooltip: 'Full Screen Zoom',
                        onPressed: () => _showFullScreenImageDialog(base64Img),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Image Preview (With Pinch-to-Zoom & Full Screen Overlay Button)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.memory(
                              base64Decode(base64Img),
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Padding(
                                padding: EdgeInsets.all(30.0),
                                child: Text('Failed to load bill image.', style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () => _showFullScreenImageDialog(base64Img),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFFFBBF24)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Full Screen 🔍',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Action for Seller (Retake)
                if (widget.isSeller)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: isPickedUpOrBeyond
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_rounded, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Order Picked Up - Bill Locked 🔒',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: const Text('Retake / Update Bill Photo 📸', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _pickAndSaveBillImage();
                              },
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TriangleFoldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
