import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/header_theme_helper.dart';
import '../customer/search_seller_screen.dart';
import '../customer/seller_orders_screen.dart';
import '../role_selection_screen.dart';

/// Waving Hand Animation Widget (Rotational Hand Wave 👋)
class WavingHandWidget extends StatefulWidget {
  const WavingHandWidget({super.key});

  @override
  State<WavingHandWidget> createState() => _WavingHandWidgetState();
}

class _WavingHandWidgetState extends State<WavingHandWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -0.22, end: 0.22).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: const Text(
            '👋',
            style: TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }
}

/// Continuous Shimmering Glass Verified Badge Widget
class ShimmerVerifiedBadgeWidget extends StatefulWidget {
  const ShimmerVerifiedBadgeWidget({super.key});

  @override
  State<ShimmerVerifiedBadgeWidget> createState() => _ShimmerVerifiedBadgeWidgetState();
}

class _ShimmerVerifiedBadgeWidgetState extends State<ShimmerVerifiedBadgeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
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
        final progress = _controller.value;
        final double alignX = -2.5 + (progress * 5.0);

        return Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.8), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  alignment: Alignment(alignX, 0),
                  child: Transform(
                    transform: Matrix4.skewX(-0.35),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.75),
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CustomerDashboard extends StatefulWidget {
  final UserModel customer;

  CustomerDashboard({
    super.key,
    UserModel? customer,
    UserModel? user,
  }) : customer = customer ?? user!;

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<Map<String, dynamic>> _myChats = [];
  bool _isLoading = true;
  final TextEditingController _sellerSearchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _headerThemeConfig = {};

  @override
  void initState() {
    super.initState();
    _loadHeaderTheme();
    _checkSavedSellerAndLoad();
  }

  Future<void> _loadHeaderTheme() async {
    final config = await AuthService.getHeaderThemeConfig();
    if (mounted) {
      setState(() {
        _headerThemeConfig = config;
      });
    }
  }

  @override
  void dispose() {
    _sellerSearchController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedSellerAndLoad() async {
    final lastSeller = await AuthService.getLastSelectedSeller();
    if (lastSeller != null && (lastSeller['username'] ?? '').isNotEmpty && mounted) {
      final sUsername = lastSeller['username']!;
      final sName = lastSeller['name']!;
      final sMobile = lastSeller['mobile']!;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => CustomerSellerOrdersScreen(
            customer: widget.customer,
            sellerUsername: sUsername,
            sellerName: sName,
            sellerMobile: sMobile,
          ),
        ),
      );
      _loadCustomerChats();
    } else if (mounted) {
      // If NO seller selected or seller deleted, stay on CustomerDashboard Seller List Page!
      _loadCustomerChats();
    }
  }

  Future<void> _loadCustomerChats() async {
    final cleanCust = (widget.customer.mobile ?? '').trim();

    // 1. Instant 0ms Local Cache Load
    final cachedChats = await AuthService.getCachedCustomerConversations(cleanCust);
    if (cachedChats.isNotEmpty && mounted) {
      await _processDraftsAndSetState(cachedChats);
    }

    // 2. Background Revalidation from VPS Database
    final chats = await AuthService.getCustomerConversations(cleanCust);
    if (mounted) {
      await _processDraftsAndSetState(chats);
    }
  }

  Future<void> _processDraftsAndSetState(List<Map<String, dynamic>> chats) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanCust = (widget.customer.mobile ?? '').trim();

    for (var chat in chats) {
      final sUsername = (chat['seller_username'] ?? '').toString().trim();
      final draftKey = 'draft_order_${cleanCust}_$sUsername';
      final draftStr = prefs.getString(draftKey);
      if (draftStr != null && draftStr.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(draftStr);
          final activeMode = (data['activeMode'] ?? 'chat').toString();
          final chatText = (data['chatText'] ?? data['text'] ?? '').toString().trim();
          final List rawItems = data['items'] ?? [];

          if (activeMode == 'list' && rawItems.isNotEmpty) {
            final firstItemName = rawItems.first['name'] ?? 'Item';
            final count = rawItems.length;
            chat['draft_text'] = count > 1 ? '$firstItemName & ${count - 1} more items (List)' : '$firstItemName (List)';
          } else if (chatText.isNotEmpty) {
            final lines = chatText.split('\n').where((l) => l.trim().isNotEmpty).toList();
            chat['draft_text'] = lines.isNotEmpty ? lines.first : chatText;
          } else if (rawItems.isNotEmpty) {
            chat['draft_text'] = '${rawItems.length} items (List)';
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _myChats = chats;
        _isLoading = false;
      });
    }
  }

  void _openSearchSeller() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchSellerScreen(customer: widget.customer),
      ),
    );
    _loadCustomerChats();
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sleek Light Grey Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark Black Header Contrast
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981), // Emerald Accent
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Daily Mart',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadCustomerChats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Welcome Card
              // Luxury Black & White Customer Welcome Header Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle Decorative Background Shapes
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 30,
                      bottom: -30,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ),

                    // Main Card Content
                    Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          // Sleek Black & White Profile Avatar Frame
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              child: Text(
                                (widget.customer.name ?? 'C').isNotEmpty
                                    ? (widget.customer.name ?? 'C')[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Customer Name & Welcome Greetings
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Welcome back, ',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8), // Soft Metallic Silver
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const WavingHandWidget(),
                                    const Spacer(),
                                    const ShimmerVerifiedBadgeWidget(),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.customer.name ?? 'Customer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_iphone_rounded, color: Color(0xFFCBD5E1), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+91 ${widget.customer.mobile ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFE2E8F0),
                                        fontWeight: FontWeight.w500,
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
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Hide Customer Dashboard Area card when conversations exist
              if (_myChats.isEmpty) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.dashboard_rounded, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text(
                              'Customer Dashboard Area',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You haven\'t messaged any sellers yet. Tap the search icon below to search and connect with local sellers!',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.search_rounded, color: Colors.white),
                          label: const Text(
                            'Search Sellers',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _openSearchSeller,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Conversation Sellers List Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Sellers & Orders',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.2,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openSearchSeller,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                    label: const Text(
                      'New Seller',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Professional Seller Search Bar (Live Filter)
              if (_myChats.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _sellerSearchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search my sellers by name or mobile...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: Colors.grey, size: 18),
                                    onPressed: () {
                                      _sellerSearchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Filtered Chat List Computation & Executive Card Builder
              Builder(
                builder: (context) {
                  final filteredChats = _myChats.where((chat) {
                    if (_searchQuery.isEmpty) return true;
                    final sName = (chat['seller_name'] ?? '').toString().toLowerCase();
                    final sUsername = (chat['seller_username'] ?? '').toString().toLowerCase();
                    final sMobile = (chat['seller_mobile'] ?? '').toString().toLowerCase();
                    return sName.contains(_searchQuery) ||
                        sUsername.contains(_searchQuery) ||
                        sMobile.contains(_searchQuery);
                  }).toList();

                  if (_isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: Color(0xFF10B981)),
                      ),
                    );
                  }

                  if (_myChats.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text(
                          'No active seller chats.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                    );
                  }

                  if (filteredChats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'No sellers found matching "$_searchQuery"',
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredChats.length,
                    itemBuilder: (ctx, idx) {
                      final chat = filteredChats[idx];
                      final sUsername = chat['seller_username'] ?? '';
                      final sName = chat['seller_name'] ?? sUsername;
                      final sMobile = chat['seller_mobile'] ?? '';
                      final lastMsg = chat['last_message'] ?? '';
                      final lastTime = chat['last_time'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => CustomerSellerOrdersScreen(
                                    customer: widget.customer,
                                    sellerUsername: sUsername,
                                    sellerName: sName,
                                    sellerMobile: sMobile,
                                  ),
                                ),
                              );
                              _loadCustomerChats();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  // Store Badge with Active Online Dot Indicator
                                  Stack(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.storefront_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 11,
                                          height: 11,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),

                                  // Seller Info Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (sMobile.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '+91 $sMobile',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (chat['draft_text'] != null && (chat['draft_text'] as String).isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.edit_rounded, size: 13, color: Color(0xFFD97706)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: RichText(
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  text: TextSpan(
                                                    children: [
                                                      const TextSpan(
                                                        text: 'Draft: ',
                                                        style: TextStyle(
                                                          color: Color(0xFFD97706),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12.5,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: chat['draft_text'],
                                                        style: const TextStyle(
                                                          color: Color(0xFF334155),
                                                          fontSize: 12.5,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (lastMsg.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            lastMsg,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF334155),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Time & Action Chevron
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          lastTime.toString().length >= 10
                                              ? lastTime.toString().substring(11, 16)
                                              : (lastTime.toString().isEmpty ? 'Store' : lastTime.toString()),
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Round Icon-Only Floating Action Button (💬)
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearchSeller,
        backgroundColor: const Color(0xFF10B981),
        shape: const CircleBorder(),
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
