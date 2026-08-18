import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'seller_chat_screen.dart';

class SellerAccountsScreen extends StatefulWidget {
  final UserModel seller;

  const SellerAccountsScreen({super.key, required this.seller});

  @override
  State<SellerAccountsScreen> createState() => _SellerAccountsScreenState();
}

class _SellerAccountsScreenState extends State<SellerAccountsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Unpaid, Cash, Online
  String _dateFilter = 'All'; // Default to All Time so ALL seller orders load instantly like user reference photo!
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  double _totalRevenue = 0.0;
  double _cashRevenue = 0.0;
  double _onlineRevenue = 0.0;
  int _totalOrdersCount = 0;

  int _allCount = 0;
  int _unpaidCount = 0;
  int _cashCount = 0;
  int _onlineCount = 0;

  String get _sellerUsername {
    final u = (widget.seller.username ?? '').trim();
    if (u.isNotEmpty) return u;
    return (widget.seller.mobile ?? '').trim();
  }

  @override
  void initState() {
    super.initState();
    _loadLedgerData();
  }

  Future<void> _loadLedgerData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String sellerUser = _sellerUsername;
    final String sellerMobile = (widget.seller.mobile ?? '').trim();
    final String sellerName = (widget.seller.name ?? '').trim();

    if (sellerUser.isEmpty && sellerMobile.isEmpty && sellerName.isEmpty) {
      if (mounted) {
        setState(() {
          _allOrders = [];
          _filteredOrders = [];
          _totalRevenue = 0.0;
          _cashRevenue = 0.0;
          _onlineRevenue = 0.0;
          _totalOrdersCount = 0;
          _allCount = 0;
          _unpaidCount = 0;
          _cashCount = 0;
          _onlineCount = 0;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // 1. Instant 0ms cache load
      final cachedOrders = await AuthService.getCachedSellerCustomerOrders(sellerUser);
      if (cachedOrders.isNotEmpty && mounted && _isLoading) {
        _processRawOrders(cachedOrders);
      }

      // 2. Fetch fresh orders from VPS
      List<Map<String, dynamic>> freshOrders = await AuthService.getSellerCustomerOrders(sellerUser);
      if (freshOrders.isEmpty && sellerMobile.isNotEmpty && sellerMobile != sellerUser) {
        freshOrders = await AuthService.getSellerCustomerOrders(sellerMobile);
      }
      if (freshOrders.isEmpty && sellerName.isNotEmpty && sellerName != sellerUser && sellerName != sellerMobile) {
        freshOrders = await AuthService.getSellerCustomerOrders(sellerName);
      }

      if (mounted) {
        _processRawOrders(freshOrders);
      }
    } catch (e) {
      debugPrint('Error fetching ledger data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processRawOrders(List<Map<String, dynamic>> rawOrders) {
    List<Map<String, dynamic>> ordersList = [];

    for (var o in rawOrders) {
      final msgId = (o['id'] ?? o['msg_id'] as num?)?.toInt() ?? 0;
      final rawOrderId = (o['order_id'] ?? 'Order #$msgId').toString();
      final custMobile = (o['customer_mobile'] ?? '').toString();
      final custName = (o['customer_name'] ?? 'Customer').toString();

      final rawAmt = o['total_amount'] ?? o['order_amount'] ?? o['amount'] ?? 0.0;
      double amt = (rawAmt as num?)?.toDouble() ?? double.tryParse(rawAmt.toString()) ?? 0.0;

      final payStat = (o['payment_status'] ?? '').toString().toLowerCase();
      final isPaid = payStat == 'paid' || payStat == 'success';
      final utr = (o['payment_utr'] ?? o['utr'] ?? '').toString();
      final payMode = (o['payment_mode'] ?? '').toString().toLowerCase();
      final isOnline = utr.isNotEmpty || (isPaid && (payMode == 'online' || payMode == 'upi' || payMode.contains('online')));

      final ordStat = (o['order_status'] ?? o['status'] ?? 'Pending').toString();
      final isDeleted = ordStat.toLowerCase() == 'deleted' || o['is_deleted'] == true || o['is_deleted'] == 1 || o['is_deleted'] == '1';

      String pBadge = 'Unpaid';
      String pType = 'Unpaid';

      if (isPaid) {
        if (isOnline) {
          pBadge = 'Online';
          pType = 'Online';
        } else {
          pBadge = 'Cash';
          pType = 'Cash';
        }
      }

      final createdAtStr = (o['created_at'] ?? o['date'] ?? '').toString();
      final deliveredAtStr = (o['delivered_at'] ?? o['delivered_time'] ?? '').toString();
      final paidAtStr = (o['paid_at'] ?? o['payment_time'] ?? '').toString();

      final createdDate = _parseOrderDate(createdAtStr);
      final deliveredDate = _parseOrderDate(deliveredAtStr);
      final paidDate = _parseOrderDate(paidAtStr);

      final primaryDate = deliveredDate ?? paidDate ?? createdDate ?? DateTime.now();

      ordersList.add({
        'msg_id': msgId,
        'customer_name': custName,
        'customer_mobile': custMobile,
        'order_id': rawOrderId,
        'order_amount': amt,
        'payment_status': payStat,
        'is_paid': isPaid,
        'payment_badge': pBadge,
        'payment_type': pType,
        'order_status': isDeleted ? 'Deleted' : ordStat,
        'created_at': createdAtStr.isNotEmpty ? createdAtStr : primaryDate.toString().substring(0, 16),
        'delivered_at': deliveredAtStr,
        'paid_at': paidAtStr,
        'created_date': createdDate,
        'delivered_date': deliveredDate,
        'paid_date': paidDate,
        'primary_date': primaryDate,
        'raw_msg': o,
      });
    }

    // Sort by primary timestamp newest first
    ordersList.sort((a, b) => (b['primary_date'] as DateTime).compareTo(a['primary_date'] as DateTime));

    setState(() {
      _allOrders = ordersList;
      _isLoading = false;
    });
    _applyFilter();
  }

  DateTime? _parseOrderDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    // 1. Try standard ISO parse ("2026-08-15 10:23:14" -> "2026-08-15T10:23:14")
    try {
      final isoStr = str.replaceAll(' ', 'T');
      final dt = DateTime.tryParse(isoStr) ?? DateTime.tryParse(str);
      if (dt != null) return dt;
    } catch (_) {}

    // 2. YYYY-MM-DD
    try {
      final ymdMatch = RegExp(r'(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})').firstMatch(str);
      if (ymdMatch != null) {
        final year = int.parse(ymdMatch.group(1)!);
        final month = int.parse(ymdMatch.group(2)!);
        final day = int.parse(ymdMatch.group(3)!);
        return DateTime(year, month, day);
      }
    } catch (_) {}

    // 3. DD/MM/YYYY
    try {
      final dmyMatch = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})').firstMatch(str);
      if (dmyMatch != null) {
        final day = int.parse(dmyMatch.group(1)!);
        final month = int.parse(dmyMatch.group(2)!);
        final year = int.parse(dmyMatch.group(3)!);
        return DateTime(year, month, day);
      }
    } catch (_) {}

    return null;
  }

  bool _isOrderInDateFilter(Map<String, dynamic> o, String filter) {
    if (filter == 'All') return true;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = todayStart.subtract(const Duration(days: 29));

    final List<DateTime> datesToCheck = [];
    if (o['delivered_date'] != null) datesToCheck.add(o['delivered_date'] as DateTime);
    if (o['paid_date'] != null) datesToCheck.add(o['paid_date'] as DateTime);
    if (o['primary_date'] != null) datesToCheck.add(o['primary_date'] as DateTime);
    if (o['created_date'] != null) datesToCheck.add(o['created_date'] as DateTime);

    if (datesToCheck.isEmpty) return true;

    if (filter == 'Today') {
      return datesToCheck.any((d) =>
          (d.year == now.year && d.month == now.month && d.day == now.day) ||
          (d.isAfter(todayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd.add(const Duration(seconds: 1)))));
    } else if (filter == 'Yesterday') {
      return datesToCheck.any((d) =>
          (d.year == yesterdayStart.year && d.month == yesterdayStart.month && d.day == yesterdayStart.day) ||
          (d.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) && d.isBefore(yesterdayEnd.add(const Duration(seconds: 1)))));
    } else if (filter == 'ThisWeek' || filter == 'Week') {
      return datesToCheck.any((d) =>
          d.isAfter(weekStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd.add(const Duration(seconds: 1))));
    } else if (filter == 'ThisMonth' || filter == 'Month' || filter == '30 Days' || filter.contains('30')) {
      return datesToCheck.any((d) =>
          d.isAfter(monthStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd.add(const Duration(seconds: 1))));
    } else if (filter == 'Custom' && _customStartDate != null && _customEndDate != null) {
      final start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      final end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59);

      return datesToCheck.any((d) =>
          d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1))));
    }

    return true;
  }

  void _applyFilter() {
    // 1. Date Filter First
    List<Map<String, dynamic>> dateFiltered = _allOrders.where((o) => _isOrderInDateFilter(o, _dateFilter)).toList();

    // Recalculate summary metrics dynamically for the selected Date Filter
    double totRev = 0.0;
    double cashRev = 0.0;
    double onlineRev = 0.0;
    int cAll = 0;
    int cUnpaid = 0;
    int cCash = 0;
    int cOnline = 0;

    for (var o in dateFiltered) {
      final bool isPaid = o['is_paid'] == true;
      final String pType = o['payment_type'] ?? '';
      final double amt = o['order_amount'] ?? 0.0;
      final String ordStat = (o['order_status'] ?? '').toString().toLowerCase();
      final bool isDeleted = ordStat == 'deleted';

      cAll++;
      if (isPaid) {
        if (pType == 'Online') {
          cOnline++;
          if (amt > 0 && !isDeleted) {
            totRev += amt;
            onlineRev += amt;
          }
        } else {
          cCash++;
          if (amt > 0 && !isDeleted) {
            totRev += amt;
            cashRev += amt;
          }
        }
      } else {
        cUnpaid++;
      }
    }

    // 2. Apply Payment Type Filter (All, Unpaid, Cash, Online)
    List<Map<String, dynamic>> typeFiltered = List.from(dateFiltered);
    if (_selectedFilter == 'Unpaid') {
      typeFiltered = typeFiltered.where((o) => o['is_paid'] == false).toList();
    } else if (_selectedFilter == 'Cash') {
      typeFiltered = typeFiltered.where((o) => o['is_paid'] == true && o['payment_type'] == 'Cash').toList();
    } else if (_selectedFilter == 'Online') {
      typeFiltered = typeFiltered.where((o) => o['is_paid'] == true && o['payment_type'] == 'Online').toList();
    }

    // 3. Apply Search Query Filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      typeFiltered = typeFiltered.where((o) {
        final name = o['customer_name'].toString().toLowerCase();
        final ordId = o['order_id'].toString().toLowerCase();
        final mob = o['customer_mobile'].toString().toLowerCase();
        return name.contains(q) || ordId.contains(q) || mob.contains(q);
      }).toList();
    }

    setState(() {
      _totalRevenue = totRev;
      _cashRevenue = cashRev;
      _onlineRevenue = onlineRev;
      _totalOrdersCount = dateFiltered.length;

      _allCount = cAll;
      _unpaidCount = cUnpaid;
      _cashCount = cCash;
      _onlineCount = cOnline;

      _filteredOrders = typeFiltered;
    });
  }

  void _showDateFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title Header with Black Filter Icon
                Row(
                  children: const [
                    Icon(Icons.filter_alt_rounded, color: Color(0xFF0F172A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Select Date Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. Today
                _buildCleanDateItem(
                  key: 'Today',
                  title: 'Today (Aaj)',
                  icon: Icons.calendar_today_rounded,
                ),

                // 2. Yesterday
                _buildCleanDateItem(
                  key: 'Yesterday',
                  title: 'Yesterday (Bita Kal)',
                  icon: Icons.history_rounded,
                ),

                // 3. Last 7 Days (Is Hafte)
                _buildCleanDateItem(
                  key: 'ThisWeek',
                  title: 'Last 7 Days (Is Hafte)',
                  icon: Icons.view_week_rounded,
                ),

                // 4. Last 30 Days (Is Mahine)
                _buildCleanDateItem(
                  key: 'ThisMonth',
                  title: 'Last 30 Days (Is Mahine)',
                  icon: Icons.calendar_month_rounded,
                ),

                // 5. Custom Date Range
                _buildCleanDateItem(
                  key: 'Custom',
                  title: 'Custom (Select From & To Date)',
                  icon: Icons.edit_calendar_rounded,
                ),

                // 6. All Time (Clear Filter)
                _buildCleanDateItem(
                  key: 'All',
                  title: 'All Time (Clear Filter)',
                  icon: Icons.sync_rounded,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCleanDateItem({
    required String key,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _dateFilter == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          if (key == 'Custom') {
            _showEasyCustomDateDialog();
          } else {
            setState(() {
              _dateFilter = key;
            });
            _applyFilter();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0F172A), size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ULTRA-EASY CUSTOM DATE DIALOG (2 Simple Single-Date Buttons)
  Future<void> _showEasyCustomDateDialog() async {
    DateTime tempStart = _customStartDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempEnd = _customEndDate ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formatD(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.date_range_rounded, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Text('Select Date Range 📅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select Start (From) Date and End (To) Date:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  // From Date Button
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: tempStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        setDialogState(() {
                          tempStart = d;
                          if (tempEnd.isBefore(tempStart)) tempEnd = tempStart;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('From Date:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          Row(
                            children: [
                              Text(formatD(tempStart), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF059669)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // To Date Button
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: tempEnd,
                        firstDate: tempStart,
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        setDialogState(() {
                          tempEnd = d;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('To Date:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          Row(
                            children: [
                              Text(formatD(tempEnd), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF059669)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _customStartDate = tempStart;
                      _customEndDate = tempEnd;
                      _dateFilter = 'Custom';
                    });
                    _applyFilter();
                  },
                  child: const Text('Apply Range', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _markAsPaidCash(Map<String, dynamic> item) async {
    final int msgId = item['msg_id'] ?? 0;
    final String sellerUser = (widget.seller.username ?? '').trim();
    final String custMob = item['customer_mobile'] ?? '';
    final double amt = item['order_amount'] ?? 0.0;

    if (msgId <= 0 || custMob.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Cash Payment'),
        content: Text('Did ${item['customer_name']} pay ₹${amt % 1 == 0 ? amt.toInt() : amt.toStringAsFixed(2)} in Cash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cash Received', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await AuthService.markOrderPaid(
        sellerUsername: sellerUser,
        customerMobile: custMob,
        messageId: msgId,
        utrNumber: 'CASH',
        amount: amt,
      );

      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Status updated to Paid (Cash)!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadLedgerData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String sName = widget.seller.name.trim();
    final String sUser = (widget.seller.username ?? '').trim();
    final String sellerDisplayName = sName.isNotEmpty ? sName : sUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clean Light Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669), // Rich Emerald Green Header
        elevation: 0,
        toolbarHeight: 52,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accounts & Orders Ledger 👛',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              'Seller: $sellerDisplayName',
              style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Refresh Ledger',
            onPressed: _loadLedgerData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : RefreshIndicator(
              color: const Color(0xFF059669),
              onRefresh: _loadLedgerData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // COMPACT REVENUE SUMMARY CARD (LIGHT GREEN / EMERALD THEME)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)], // Emerald to Vibrant Light Green
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateFilter == 'Today'
                                    ? "TODAY'S REVENUE"
                                    : (_dateFilter == 'Yesterday'
                                        ? "YESTERDAY'S REVENUE"
                                        : (_dateFilter == 'ThisWeek'
                                            ? "LAST 7 DAYS REVENUE"
                                            : (_dateFilter == 'ThisMonth'
                                                ? "LAST 30 DAYS REVENUE"
                                                : (_dateFilter == 'Custom' ? "CUSTOM RANGE REVENUE" : "COLLECTED REVENUE")))),
                                style: const TextStyle(
                                  color: Color(0xFFD1FAE5),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_totalOrdersCount Orders',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_totalRevenue % 1 == 0 ? _totalRevenue.toInt() : _totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              // Cash Sub Card
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.payments_rounded, color: Colors.white, size: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Cash 💵', style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 10, fontWeight: FontWeight.w600)),
                                            Text(
                                              '₹${_cashRevenue % 1 == 0 ? _cashRevenue.toInt() : _cashRevenue.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Online Sub Card
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Online 💳', style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 10, fontWeight: FontWeight.w600)),
                                            Text(
                                              '₹${_onlineRevenue % 1 == 0 ? _onlineRevenue.toInt() : _onlineRevenue.toStringAsFixed(2)}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                    ),
                    const SizedBox(height: 14),

                    // SEARCH BAR + FILTER BUTTON ROW
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              onChanged: (val) {
                                _searchQuery = val;
                                _applyFilter();
                              },
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: 'Search Name or Order #...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                          _applyFilter();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Date Filter Button -> Opens Modal Bottom Sheet (Black Filter Icon)
                        InkWell(
                          onTap: _showDateFilterBottomSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _dateFilter != 'All' ? const Color(0xFF059669) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _dateFilter != 'All' ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list_rounded,
                                  size: 16,
                                  color: _dateFilter != 'All' ? Colors.white : const Color(0xFF0F172A), // Black Icon
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _dateFilter == 'Custom'
                                      ? 'Custom'
                                      : (_dateFilter == 'ThisWeek'
                                          ? '7 Days'
                                          : (_dateFilter == 'ThisMonth'
                                              ? '30 Days'
                                              : (_dateFilter == 'All' ? 'Filter' : _dateFilter))),
                                  style: TextStyle(
                                    color: _dateFilter != 'All' ? Colors.white : const Color(0xFF0F172A), // Black Text
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // PREMIUM UNIFIED SEGMENTED FILTER CONTROL BAR (With Live Order Count Badges)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Light Slate Segment Track
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentTab('All', 'All', count: _allCount, activeColor: const Color(0xFF059669)),
                          _buildSegmentTab('Unpaid', 'Unpaid', count: _unpaidCount, activeColor: const Color(0xFFEF4444)),
                          _buildSegmentTab('Cash', 'Cash', count: _cashCount, activeColor: const Color(0xFF10B981)),
                          _buildSegmentTab('Online', 'Online', count: _onlineCount, activeColor: const Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ORDERS LIST HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Customer Orders (${_filteredOrders.length})',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (_dateFilter != 'All')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_rounded, size: 12, color: Color(0xFF047857)),
                                const SizedBox(width: 4),
                                Text(
                                  _dateFilter == 'Custom' && _customStartDate != null && _customEndDate != null
                                      ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                                      : (_dateFilter == 'ThisWeek'
                                          ? 'Last 7 Days'
                                          : (_dateFilter == 'ThisMonth' ? 'Last 30 Days' : 'Date: $_dateFilter')),
                                  style: const TextStyle(color: Color(0xFF047857), fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ORDERS CARDS LIST
                    if (_filteredOrders.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF94A3B8), size: 40),
                            const SizedBox(height: 10),
                            Text(
                              _dateFilter != 'All'
                                  ? 'No orders found for selected date period.'
                                  : 'No matching customer orders found.',
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final item = _filteredOrders[index];
                          final double amt = item['order_amount'] ?? 0.0;
                          final String amtStr = (amt % 1 == 0) ? amt.toInt().toString() : amt.toStringAsFixed(2);
                          final bool isPaid = item['is_paid'] == true;
                          final String pType = item['payment_type'] ?? 'Unpaid';
                          final String status = item['order_status'] ?? 'Status';
                          final bool isDeleted = status.toLowerCase() == 'deleted';
                          final bool isReady = status.toLowerCase() == 'ready' || status.toLowerCase() == 'completed' || status.toLowerCase() == 'delivered';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                final cMob = (item['customer_mobile'] ?? '').toString();
                                if (cMob.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => SellerChatScreen(
                                        seller: widget.seller,
                                        customerMobile: cMob,
                                      ),
                                    ),
                                  ).then((_) => _loadLedgerData());
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Customer Avatar Circle
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFECFDF5),
                                      child: const Icon(Icons.person_rounded, color: Color(0xFF059669), size: 22),
                                    ),
                                    const SizedBox(width: 10),

                                    // Customer Name & Order ID
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['customer_name'],
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item['order_id'],
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 3),
                                              Text(
                                                item['created_at'],
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Right Side: Amount & Badges (ORDER STATUS FIRST GREEN THEME, PAYMENT STATUS SECOND NO ICONS)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹$amtStr',
                                          style: TextStyle(
                                            color: isPaid ? const Color(0xFF10B981) : const Color(0xFF475569),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15.5,
                                          ),
                                        ),
                                        const SizedBox(height: 5),

                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 1. Order Status Badge FIRST (GREEN THEME FOR READY)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: isReady
                                                    ? const Color(0xFFECFDF5) // Green Light Tint
                                                    : (isDeleted ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC)),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isReady
                                                      ? const Color(0xFF10B981) // Green Border
                                                      : (isDeleted ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  color: isReady
                                                      ? const Color(0xFF047857) // Rich Green Text
                                                      : (isDeleted ? const Color(0xFF64748B) : const Color(0xFF334155)),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),

                                            // 2. Payment Status Badge SECOND (NO EMOJIS / ICONS)
                                            InkWell(
                                              onTap: !isPaid && amt > 0
                                                  ? () => _markAsPaidCash(item)
                                                  : null,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: !isPaid
                                                      ? const Color(0xFFFEF2F2)
                                                      : (pType == 'Online' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: !isPaid
                                                        ? const Color(0xFFEF4444)
                                                        : (pType == 'Online' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  !isPaid ? 'Unpaid' : (pType == 'Online' ? 'Online' : 'Cash'),
                                                  style: TextStyle(
                                                    color: !isPaid
                                                        ? const Color(0xFFDC2626)
                                                        : (pType == 'Online' ? const Color(0xFF2563EB) : const Color(0xFF059669)),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 9.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSegmentTab(String label, String value, {required int count, required Color activeColor}) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
          _applyFilter();
        },
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
