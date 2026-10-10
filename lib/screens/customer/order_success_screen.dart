import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';

class OrderSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final UserModel customer;

  const OrderSuccessScreen({
    super.key,
    required this.order,
    required this.customer,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderId = (widget.order['order_id'] ?? '#DM-1001').toString();
    final sellerName = (widget.order['seller_name'] ?? 'Store').toString();
    final totalAmount = (widget.order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final totalCount = (widget.order['total_count'] as num?)?.toInt() ?? 0;
    final dateStr = (widget.order['date'] ?? '').toString();
    final items = List<Map<String, dynamic>>.from(widget.order['items'] ?? []);

    final paymentMode = (widget.order['payment_mode'] ?? 'Cash on Delivery').toString();
    final paymentStatus = (widget.order['payment_status'] ?? 'unpaid').toString();
    final isOnlinePaid = paymentStatus.toLowerCase() == 'paid' || paymentMode.toLowerCase() == 'online';
    final paymentUtr = (widget.order['payment_utr'] ?? '').toString();
    final deliveryAddress = (widget.order['delivery_address'] ?? widget.order['address'] ?? '').toString();

    const scaffoldBg = Color(0xFFF8FAFC); // Clean slate-50 light background

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: scaffoldBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Stack(
            children: [
              // Subtle Top Light Green Radial Ambient
              Positioned(
                top: -80,
                left: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Subtle Bottom Blue Radial Ambient
              Positioned(
                bottom: -60,
                right: -60,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                  ),
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. Celebration Spring Badge Animation
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFECFDF5), // Emerald 50
                            border: Border.all(
                              color: const Color(0xFFA7F3D0), // Emerald 200
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFD1FAE5), // Emerald 100
                              ),
                              child: Center(
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 2. Heading & Subtitle
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'Order Placed Successfully! 🎉',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'Your order '),
                                  TextSpan(
                                    text: orderId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const TextSpan(text: ' has been placed with '),
                                  TextSpan(
                                    text: sellerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // 3. Receipt Bill Summary Card (White Light Theme with Zigzag Edge)
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Card Top Header: Order ID & Status Badge (Compact & Sleek)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.receipt_long_rounded,
                                                  color: Color(0xFF0F172A),
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                orderId,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7), // Soft Amber
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 4.5,
                                                  height: 4.5,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFD97706),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'PENDING',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFD97706),
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Store & Date Metadata Row
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              sellerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          if (dateStr.isNotEmpty) ...[
                                            const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              dateStr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),
                                    const DashedReceiptDivider(),

                                    // Items Table Header
                                    Container(
                                      color: const Color(0xFFF8FAFC),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'ITEM NAME & UNIT (${items.length})',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 60,
                                            child: Text(
                                              'QTY',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 65,
                                            child: Text(
                                              'AMOUNT',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10.5,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                                    // Items List Rows
                                    ...items.asMap().entries.map((entry) {
                                      final iIdx = entry.key;
                                      final it = entry.value;
                                      final iName = (it['name'] ?? '').toString();
                                      final iQty = (it['qty'] as num?)?.toInt() ?? 1;
                                      final iUnit = (it['unit'] ?? 'Pcs').toString();
                                      final iRate = (it['rate'] as num?)?.toDouble() ?? 0.0;
                                      final iAmt = (it['amount'] as num?)?.toDouble() ?? 0.0;
                                      final img = (it['image'] ?? '').toString();
                                      final isGift = it['is_gift'] == true || it['is_precious_gift'] == true;

                                      return Column(
                                        children: [
                                          if (iIdx > 0)
                                            const Divider(
                                              height: 1,
                                              indent: 16,
                                              endIndent: 16,
                                              color: Color(0xFFF1F5F9),
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            child: Row(
                                              children: [
                                                // Item Thumbnail & Name
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 32,
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color: isGift ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(
                                                            color: isGift ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                                                          ),
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(6),
                                                          child: isGift
                                                              ? const Center(
                                                                  child: Icon(
                                                                    Icons.card_giftcard_rounded,
                                                                    size: 18,
                                                                    color: Color(0xFF2563EB),
                                                                  ),
                                                                )
                                                              : _buildProductImageWidget(img, emojiSize: 16),
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
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w500,
                                                                fontSize: 11.5,
                                                                color: Color(0xFF1E293B),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 1),
                                                            if (isGift) ...[
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFEFF6FF),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: const Text(
                                                                  'FREE GIFT',
                                                                  style: TextStyle(
                                                                    fontSize: 9.5,
                                                                    color: Color(0xFF2563EB),
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ] else if (iRate > 0) ...[
                                                              Text(
                                                                '₹${iRate % 1 == 0 ? iRate.toInt() : iRate.toStringAsFixed(2)} / $iUnit',
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(0xFF2563EB),
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ] else ...[
                                                              Text(
                                                                iUnit,
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(0xFF64748B),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),

                                                // Qty
                                                SizedBox(
                                                  width: 60,
                                                  child: Text(
                                                    '$iQty $iUnit',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 11.5,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),

                                                // Amount
                                                SizedBox(
                                                  width: 65,
                                                  child: Text(
                                                    isGift
                                                        ? '₹0'
                                                        : (iAmt > 0
                                                            ? '₹${iAmt % 1 == 0 ? iAmt.toInt() : iAmt.toStringAsFixed(2)}'
                                                            : '₹0'),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }),

                                    const SizedBox(height: 8),
                                    const DashedReceiptDivider(),

                                    // Payment Method & Address Details
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.payment_rounded, size: 15, color: Color(0xFF64748B)),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Payment Mode:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF64748B),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: isOnlinePaid
                                                      ? const Color(0xFFEFF6FF)
                                                      : const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isOnlinePaid
                                                        ? const Color(0xFFBFDBFE)
                                                        : const Color(0xFFA7F3D0),
                                                  ),
                                                ),
                                                child: Text(
                                                  isOnlinePaid ? '⚡ Online (PAID)' : '💵 Cash on Delivery',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: isOnlinePaid
                                                        ? const Color(0xFF1D4ED8)
                                                        : const Color(0xFF047857),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (paymentUtr.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Txn / UTR ID:',
                                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                                Text(
                                                  paymentUtr,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF334155),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (deliveryAddress.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      deliveryAddress,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF475569),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Total Bill Amount Highlight Box
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4), // Soft green highlight
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFDCFCE7)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Total Bill Amount',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF166534),
                                                  ),
                                                ),
                                                Text(
                                                  '($totalCount ${totalCount == 1 ? 'Item' : 'Items'})',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF15803D),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Sharp Static Zigzag Receipt Tear Bottom Edge
                              const SuccessReceiptZigzagDivider(
                                cardColor: Colors.white,
                                backgroundColor: scaffoldBg,
                                height: 10.0,
                                toothWidth: 12.0,
                                toothDepth: 5.5,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // 4. Primary "DONE" Action Button
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              // Return to My Order page with confirmation
                              Navigator.pop(context, true);
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'DONE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to render image or fallback emoji/icon
  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 16}) {
    final img = rawImg.trim();
    if (img.isEmpty) {
      return Center(
        child: Icon(Icons.inventory_2_outlined, size: emojiSize, color: const Color(0xFF94A3B8)),
      );
    }

    if (img.startsWith('assets/')) {
      return Image.asset(
        img,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(Icons.inventory_2_outlined, size: emojiSize, color: const Color(0xFF94A3B8)),
        ),
      );
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(Icons.inventory_2_outlined, size: emojiSize, color: const Color(0xFF94A3B8)),
        ),
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
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(Icons.inventory_2_outlined, size: emojiSize, color: const Color(0xFF94A3B8)),
          ),
        );
      } catch (_) {}
    }

    if (img.length <= 4 && img.isNotEmpty) {
      return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
    }

    return Center(
      child: Icon(Icons.inventory_2_outlined, size: emojiSize, color: const Color(0xFF94A3B8)),
    );
  }
}

/// Custom Dashed Divider for authentic bill receipts
class DashedReceiptDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashGap;

  const DashedReceiptDivider({
    super.key,
    this.color = const Color(0xFFCBD5E1),
    this.height = 1.0,
    this.dashWidth = 5.0,
    this.dashGap = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final count = (boxWidth / (dashWidth + dashGap)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(count, (_) {
                return SizedBox(
                  width: dashWidth,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: color),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

/// Sharp zigzag receipt divider cut for OrderSuccessScreen
class SuccessReceiptZigzagDivider extends StatelessWidget {
  final Color cardColor;
  final Color backgroundColor;
  final double height;
  final double toothWidth;
  final double toothDepth;

  const SuccessReceiptZigzagDivider({
    super.key,
    this.cardColor = Colors.white,
    this.backgroundColor = const Color(0xFFF8FAFC),
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
        painter: _SuccessReceiptZigzagPainter(
          cardColor: cardColor,
          backgroundColor: backgroundColor,
          toothWidth: toothWidth,
          toothDepth: toothDepth,
        ),
      ),
    );
  }
}

class _SuccessReceiptZigzagPainter extends CustomPainter {
  final Color cardColor;
  final Color backgroundColor;
  final double toothWidth;
  final double toothDepth;

  _SuccessReceiptZigzagPainter({
    required this.cardColor,
    required this.backgroundColor,
    required this.toothWidth,
    required this.toothDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill entire box with background color (outside the card)
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw card's sharp zigzag teeth reaching downwards
    final teethPath = Path();
    teethPath.moveTo(0, 0);

    final count = (size.width / toothWidth).ceil();
    final actualToothWidth = size.width / count;
    final half = actualToothWidth / 2;

    for (int i = 0; i < count; i++) {
      final startX = i * actualToothWidth;
      teethPath.lineTo(startX + half, toothDepth);
      teethPath.lineTo(startX + actualToothWidth, 0);
    }

    teethPath.lineTo(size.width, 0);
    teethPath.close();

    final cardPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(teethPath, cardPaint);

    // 3. Subtle stroke along zigzag edge for clear definition
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    for (int i = 0; i < count; i++) {
      final startX = i * actualToothWidth;
      borderPath.lineTo(startX + half, toothDepth);
      borderPath.lineTo(startX + actualToothWidth, 0);
    }
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SuccessReceiptZigzagPainter oldDelegate) {
    return oldDelegate.cardColor != cardColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.toothWidth != toothWidth ||
        oldDelegate.toothDepth != toothDepth;
  }
}
