import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class SellerAccountScreen extends StatefulWidget {
  final UserModel seller;

  const SellerAccountScreen({
    super.key,
    required this.seller,
  });

  @override
  State<SellerAccountScreen> createState() => _SellerAccountScreenState();
}

class _SellerAccountScreenState extends State<SellerAccountScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];
  String _searchQuery = '';
  String _selectedPaymentFilter = 'All'; // 'All', 'Cash', 'Online'

  double _totalRevenue = 0.0;
  double _totalCash = 0.0;
  double _totalOnline = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAccountOrders();
  }

  Future<void> _loadAccountOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final conversations = await AuthService.getSellerConversations(widget.seller.username ?? '');
      final prefs = await SharedPreferences.getInstance();
      final savedAmountsStr = prefs.getString('saved_order_amounts');
      Map<String, dynamic> savedAmounts = {};
      if (savedAmountsStr != null && savedAmountsStr.isNotEmpty) {
        try {
          savedAmounts = Map<String, dynamic>.from(jsonDecode(savedAmountsStr));
        } catch (_) {}
      }

      final savedPaymentsStr = prefs.getString('saved_order_payments');
      Map<String, dynamic> savedPayments = {};
      if (savedPaymentsStr != null && savedPaymentsStr.isNotEmpty) {
        try {
          savedPayments = Map<String, dynamic>.from(jsonDecode(savedPaymentsStr));
        } catch (_) {}
      }

      List<Map<String, dynamic>> fetchedOrders = [];
      double sumRevenue = 0.0;
      double sumCash = 0.0;
      double sumOnline = 0.0;

      for (var conv in conversations) {
        final custMobile = (conv['customer_mobile'] ?? '').toString().trim();
        if (custMobile.isEmpty) continue;

        final dbName = (conv['customer_name'] ?? conv['name'] ?? '').toString().trim();
        final customerName = await AuthService.getCustomerDisplayName(custMobile, dbCustomerName: dbName);

        final msgs = await AuthService.getMessages(
          sellerUsername: widget.seller.username ?? '',
          customerMobile: custMobile,
        );

        final orderMsgs = msgs.where((m) => m['is_order'] == true || m['items_json'] != null).toList();

        for (var msg in orderMsgs) {
          final msgId = msg['id'];
          final idStr = msgId?.toString() ?? '';

          String rawOrderId = (msg['order_id'] ?? '').toString().trim();
          if (rawOrderId.isEmpty || rawOrderId == 'null') {
            if (msgId != null && msgId is num) {
              rawOrderId = 'Order ${msgId.toInt()}';
            } else {
              rawOrderId = 'Order $idStr';
            }
          }
          if (!rawOrderId.toLowerCase().startsWith('order')) {
            rawOrderId = 'Order $rawOrderId';
          }
          final orderNumber = rawOrderId.replaceAll('#', '').replaceAll('  ', ' ');

          // Amount
          double amount = (msg['order_amount'] as num?)?.toDouble() ?? 0.0;
          if (amount <= 0 && idStr.isNotEmpty && savedAmounts.containsKey(idStr)) {
            amount = (savedAmounts[idStr] as num?)?.toDouble() ?? 0.0;
          }

          // Payment Status & Method (Cash vs Online)
          String payStatus = (msg['payment_status'] ?? '').toString().toLowerCase();
          String payUtr = (msg['payment_utr'] ?? '').toString().trim();
          String payMethod = (msg['payment_method'] ?? msg['payment_type'] ?? '').toString().toLowerCase();

          if (idStr.isNotEmpty && savedPayments.containsKey(idStr)) {
            final pInfo = Map<String, dynamic>.from(savedPayments[idStr]);
            if (pInfo['payment_status'] != null) payStatus = pInfo['payment_status'].toString().toLowerCase();
            if (pInfo['payment_utr'] != null) payUtr = pInfo['payment_utr'].toString().trim();
          }

          final orderStatus = (msg['order_status'] ?? '').toString().trim();
          final delStatus = (msg['delivery_status'] ?? '').toString().trim();
          final createdAt = (msg['created_at'] ?? '').toString().trim();

          final isCancelledOrDeleted = orderStatus.toLowerCase() == 'cancelled' ||
              orderStatus.toLowerCase() == 'rejected' ||
              orderStatus.toLowerCase() == 'deleted' ||
              delStatus.toLowerCase() == 'cancelled' ||
              delStatus.toLowerCase() == 'deleted';

          String paymentType = 'Unpaid';

          if (isCancelledOrDeleted) {
            paymentType = 'Cancelled';
          } else if (payUtr.isNotEmpty && payUtr.toUpperCase() != 'CASH') {
            paymentType = 'Online';
          } else if (payMethod == 'online' || payMethod == 'upi' || payStatus == 'paid') {
            paymentType = 'Online';
          } else if (payUtr.toUpperCase() == 'CASH' || payMethod == 'cash' || payMethod == 'cod' || payStatus == 'cash_collected') {
            paymentType = 'Cash';
          } else {
            paymentType = 'Unpaid';
          }

          fetchedOrders.add({
            'id': msgId,
            'order_number': orderNumber,
            'customer_name': customerName,
            'customer_mobile': custMobile,
            'amount': amount,
            'payment_type': paymentType,
            'order_status': orderStatus,
            'delivery_status': delStatus,
            'created_at': createdAt,
          });

          // Aggregate summary stats (only active paid or cash orders)
          if (!isCancelledOrDeleted) {
            sumRevenue += amount;
            if (paymentType == 'Online') {
              sumOnline += amount;
            } else if (paymentType == 'Cash') {
              sumCash += amount;
            }
          }
        }
      }

      // Sort recent orders first
      fetchedOrders.sort((a, b) {
        final tA = a['created_at']?.toString() ?? '';
        final tB = b['created_at']?.toString() ?? '';
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _allOrders = fetchedOrders;
          _totalRevenue = sumRevenue;
          _totalCash = sumCash;
          _totalOnline = sumOnline;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller account orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _allOrders.where((order) {
      final custName = (order['customer_name'] ?? '').toString().toLowerCase();
      final orderNum = (order['order_number'] ?? '').toString().toLowerCase();
      final custMobile = (order['customer_mobile'] ?? '').toString().toLowerCase();
      final payType = (order['payment_type'] ?? '').toString();

      final matchesQuery = _searchQuery.isEmpty ||
          custName.contains(_searchQuery.toLowerCase()) ||
          orderNum.contains(_searchQuery.toLowerCase()) ||
          custMobile.contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedPaymentFilter == 'All' ||
          payType.toLowerCase() == _selectedPaymentFilter.toLowerCase();

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFA78BFA), size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounts & Orders Ledger',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5),
                ),
                Text(
                  'Seller: ${widget.seller.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Ledger',
            onPressed: _loadAccountOrders,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccountOrders,
        color: const Color(0xFF8B5CF6),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Cards Header
              _buildSummaryHeader(),
              const SizedBox(height: 18),

              // Search & Payment Filter Controls
              _buildSearchAndFilterBar(),
              const SizedBox(height: 16),

              // Orders List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Customer Orders (${_filteredOrders.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Orders List Body
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                    )
                  : _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) => _buildOrderAccountCard(_filteredOrders[idx]),
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Soft Light Green Background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5), // Light Emerald Border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL REVENUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857), // Deep Emerald
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 4),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_allOrders.length} Orders',
                  style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${_totalRevenue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF064E3B), // Rich Dark Emerald
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFA7F3D0), height: 1),
          const SizedBox(height: 14),

          // Breakdown: Cash vs Online
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cash',
                              style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₹${_totalCash.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF047857), fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.credit_card_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Online',
                              style: TextStyle(color: Color(0xFF1E40AF), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '₹${_totalOnline.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 14, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: const InputDecoration(
              hintText: 'Search by Customer Name or Order #...',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Payment Type Filter Segmented Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildFilterTab('All'),
              _buildFilterTab('Cash'),
              _buildFilterTab('Online'),
              _buildFilterTab('Unpaid'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String filterName) {
    final isSelected = _selectedPaymentFilter == filterName;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentFilter = filterName),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            filterName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentType) {
    Color bg = const Color(0xFFFEF3C7);
    Color border = const Color(0xFFFDE68A);
    Color fg = const Color(0xFFD97706);
    IconData icon = Icons.hourglass_top_rounded;
    String text = 'Unpaid ⏳';

    if (paymentType == 'Online') {
      bg = const Color(0xFFDBEAFE);
      border = const Color(0xFF93C5FD);
      fg = const Color(0xFF1D4ED8);
      icon = Icons.credit_card_rounded;
      text = 'Online';
    } else if (paymentType == 'Cash') {
      bg = const Color(0xFFDCFCE7);
      border = const Color(0xFF86EFAC);
      fg = const Color(0xFF15803D);
      icon = Icons.payments_rounded;
      text = 'Cash';
    } else if (paymentType == 'Cancelled') {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFCBD5E1);
      fg = const Color(0xFF64748B);
      icon = Icons.block_rounded;
      text = 'No Payment';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderAccountCard(Map<String, dynamic> order) {
    final customerName = (order['customer_name'] ?? 'Customer').toString();
    final orderNum = (order['order_number'] ?? 'Order').toString();
    final amount = (order['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentType = (order['payment_type'] ?? 'Unpaid').toString();
    final createdAt = (order['created_at'] ?? '').toString();
    final orderStatus = (order['order_status'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Customer Name & Amount
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderNum,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: paymentType == 'Cancelled'
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Payment Badge (Cash vs Online vs Unpaid vs No Payment)
                  _buildPaymentBadge(paymentType),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Bottom Row: Date/Time & Order Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    createdAt.isNotEmpty ? createdAt : 'Recent',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (orderStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    orderStatus,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No matching customer orders found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try clearing your search query or selecting "All" filter.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
