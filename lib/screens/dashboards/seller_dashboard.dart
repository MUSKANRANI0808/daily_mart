import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../seller/seller_chat_screen.dart';
import '../seller/seller_sliders_screen.dart';
import '../role_selection_screen.dart';

class SellerDashboard extends StatefulWidget {
  final UserModel seller;

  SellerDashboard({
    super.key,
    UserModel? seller,
    UserModel? user,
  }) : seller = seller ?? user!;

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'pending', 'ready'

  int _activeSliderPage = 0;
  final PageController _sliderPageController = PageController();
  Timer? _sliderTimer;
  List<Map<String, dynamic>> _sliders = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadSellerSliders();
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _sliderPageController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerSliders() async {
    final list = await AuthService.getSellerSliders(widget.seller.username ?? '');

    if (mounted) {
      setState(() {
        _sliders = list;
      });
      if (list.isNotEmpty) {
        _startSliderAutoScroll();
      }
    }
  }

  void _startSliderAutoScroll() {
    _sliderTimer?.cancel();
    if (_sliders.length <= 1) return;
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_sliderPageController.hasClients) {
        final nextPage = (_activeSliderPage + 1) % _sliders.length;
        _sliderPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadConversations() async {
    final convs = await AuthService.getSellerConversations(widget.seller.username ?? '');
    final prefs = await SharedPreferences.getInstance();

    for (var item in convs) {
      final custMobile = item['customer_mobile']?.toString() ?? '';
      if (custMobile.isNotEmpty) {
        item['display_name'] = await AuthService.getCustomerDisplayName(custMobile);

        // Calculate pending orders count for this customer
        int pendingOrdersCount = 0;
        final msgs = await AuthService.getMessages(
          sellerUsername: widget.seller.username ?? '',
          customerMobile: custMobile,
        );

        if (msgs.isNotEmpty) {
          final orderMsgs = msgs.where((m) => m['is_order'] == true || m['items_json'] != null).toList();
          for (var orderMsg in orderMsgs) {
            final orderStatus = (orderMsg['order_status'] ?? '').toString().toLowerCase();
            final isDeleted = orderStatus == 'deleted' ||
                orderMsg['is_deleted'] == true ||
                orderMsg['is_deleted'] == 1 ||
                orderMsg['is_deleted'] == '1' ||
                orderMsg['message'].toString().contains('Deleted');

            if (orderStatus == 'ready' || isDeleted) {
              continue;
            }
            if (orderMsg['items_json'] != null) {
              try {
                final List<dynamic> decoded = jsonDecode(orderMsg['items_json'].toString());
                if (decoded.isNotEmpty) {
                  final allDone = decoded.every((it) => (it['status'] as num?)?.toInt() == 1);
                  if (allDone) {
                    continue;
                  }
                }
              } catch (_) {}
            }
            pendingOrdersCount++;
          }
        }
        item['pending_orders_count'] = pendingOrdersCount;
        item['is_ready'] = (pendingOrdersCount == 0);
      }
    }

    if (mounted) {
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_selectedFilter == 'pending') {
      return _conversations.where((c) => c['is_ready'] != true).toList();
    } else if (_selectedFilter == 'ready') {
      return _conversations.where((c) => c['is_ready'] == true).toList();
    }
    return _conversations;
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

  Widget _buildSliderSection() {
    if (_sliders.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 145,
          child: PageView.builder(
            controller: _sliderPageController,
            onPageChanged: (idx) {
              setState(() => _activeSliderPage = idx);
            },
            itemCount: _sliders.length,
            itemBuilder: (ctx, idx) {
              final slider = _sliders[idx];
              final title = (slider['title'] ?? slider['titleText'] ?? '').toString();
              final subtitle = (slider['description'] ?? slider['subtitle'] ?? slider['descText'] ?? '').toString();
              final tag = (slider['tag'] ?? slider['tagText'] ?? '').toString();
              final bg = (slider['bg'] ?? slider['bg_image_url'] ?? slider['bgImageUrl'] ?? slider['image'] ?? slider['imageUrl'] ?? 'preset_1').toString();

              final tagBgHex = (slider['tag_bg_color'] ?? slider['tagBgColor'] ?? '#10B981').toString();
              final tagShape = (slider['tag_shape'] ?? slider['tagShape'] ?? 'pill').toString();
              final titleHex = (slider['title_color'] ?? slider['titleColor'] ?? '#FFFFFF').toString();
              final descHex = (slider['desc_color'] ?? slider['descColor'] ?? '#E2E8F0').toString();

              final tagBg = SellerSlidersScreen.hexToColor(tagBgHex, defaultColor: const Color(0xFF10B981));
              final titleColor = SellerSlidersScreen.hexToColor(titleHex, defaultColor: Colors.white);
              final descColor = SellerSlidersScreen.hexToColor(descHex, defaultColor: const Color(0xFFE2E8F0));
              final tagDecor = SellerSlidersScreen.buildTagDecoration(tagShape, tagBg);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: SellerSlidersScreen.buildBannerBackground(
                  bg: bg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tag.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: tagDecor,
                            child: Text(
                              tag.toUpperCase(),
                              style: TextStyle(
                                color: tagShape.toLowerCase() == 'outline'
                                    ? tagBg
                                    : (tagBg.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: descColor,
                              fontSize: 12,
                              height: 1.3,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_sliders.length, (index) {
            final isSelected = _activeSliderPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final allCount = _conversations.length;
    final pendingCount = _conversations.where((c) => c['is_ready'] != true).length;
    final readyCount = _conversations.where((c) => c['is_ready'] == true).length;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterChip(
            id: 'all',
            label: 'All',
            count: allCount,
            activeColor: const Color(0xFF0F172A),
          ),
          const SizedBox(width: 3),
          _buildFilterChip(
            id: 'pending',
            label: 'Pending',
            count: pendingCount,
            activeColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 3),
          _buildFilterChip(
            id: 'ready',
            label: 'Ready',
            count: readyCount,
            activeColor: const Color(0xFF059669),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    required Color activeColor,
  }) {
    final isSelected = _selectedFilter == id;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = id;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredConversations;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sleek Light Grey Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark Black Contrast Header
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF8B5CF6), // Royal Purple Accent
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Seller (${widget.seller.name ?? widget.seller.username})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _loadConversations();
              _loadSellerSliders();
            },
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
              // Top Banner Carousel Slider
              _buildSliderSection(),

              const SizedBox(height: 16),

              // Hide Seller Management Area card when conversations exist
              if (_conversations.isEmpty) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.store_rounded, color: Color(0xFF8B5CF6)),
                            SizedBox(width: 8),
                            Text(
                              'Seller Management Area',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No customer messages yet. When customers search for your store and place orders, they will appear here automatically!',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Customer Orders Header
              const Text(
                'Customer Conversations & Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),

              // Filter Bar (All, Pending, Ready)
              _buildFilterBar(),

              // Conversation list
              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF8B5CF6))))
                  : filteredList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: Text(
                              _selectedFilter == 'pending'
                                  ? 'No pending customer orders.'
                                  : _selectedFilter == 'ready'
                                      ? 'No ready customer orders.'
                                      : 'No customer conversations yet.',
                              style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredList.length,
                          itemBuilder: (ctx, idx) {
                            final item = filteredList[idx];
                            final custMobile = item['customer_mobile'] ?? 'Customer';
                            final lastMsg = item['last_message'] ?? '';
                            final lastTime = item['last_time'] ?? '';
                            final unreadCount = (item['unread_count'] as num?)?.toInt() ?? 0;
                            final displayName = item['display_name'] ?? 'Customer';
                            final isReady = item['is_ready'] == true;
                            final pendingCount = (item['pending_orders_count'] as num?)?.toInt() ?? 0;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide.none,
                              ),
                              color: Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SellerChatScreen(
                                        seller: widget.seller,
                                        customerMobile: custMobile,
                                      ),
                                    ),
                                  );
                                  _loadConversations();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                        child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    lastMsg,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: isReady
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isReady ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                                        size: 10,
                                                        color: isReady ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        isReady ? 'Ready' : 'Pending',
                                                        style: TextStyle(
                                                          color: isReady ? const Color(0xFF047857) : const Color(0xFFB45309),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 10,
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
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            lastTime.toString().length >= 10
                                                ? lastTime.toString().substring(11, 16)
                                                : lastTime.toString(),
                                            style: const TextStyle(color: Colors.black45, fontSize: 10.5),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (pendingCount > 0)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFD97706),
                                                    borderRadius: BorderRadius.circular(9),
                                                  ),
                                                  child: Text(
                                                    '$pendingCount',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF8B5CF6),
                                                    borderRadius: BorderRadius.circular(9),
                                                  ),
                                                  child: Text(
                                                    '$unreadCount',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
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
}
