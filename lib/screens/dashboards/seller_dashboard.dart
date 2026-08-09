import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/header_theme_helper.dart';
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
  Map<String, dynamic> _headerThemeConfig = {};

  @override
  void initState() {
    super.initState();
    _loadHeaderTheme();
    _loadConversations();
    _loadSellerSliders();
    _startSellerDashboardPolling();
  }

  Timer? _sellerDashboardPoller;
  final Set<String> _notifiedSellerOrderKeys = {};

  void _startSellerDashboardPolling() {
    _sellerDashboardPoller?.cancel();
    _sellerDashboardPoller = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (!mounted) return;
      try {
        final sellerUser = widget.seller.username ?? '';
        final convs = await AuthService.getSellerConversations(sellerUser);

        for (var c in convs) {
          final custMobile = (c['customer_mobile'] ?? '').toString().trim();
          final msgId = (c['last_message_id'] ?? c['id'] ?? 0).toString();
          final unreadCount = (c['unread_count'] as num?)?.toInt() ?? 0;
          final senderType = (c['last_sender_type'] ?? '').toString().toLowerCase();

          final notifKey = '${custMobile}_${msgId}_$unreadCount';

          if (unreadCount > 0 && (senderType == 'customer' || senderType.isEmpty) && !_notifiedSellerOrderKeys.contains(notifKey)) {
            _notifiedSellerOrderKeys.add(notifKey);
            final custName = (c['display_name'] ?? c['customer_name'] ?? 'Customer').toString();
            final orderId = (c['last_order_id'] ?? 'New Order').toString();

            NotificationService.showSystemNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: '🛍️ New Order Received!',
              body: 'Customer $custName ($custMobile) placed $orderId.',
              payload: 'seller_new_order',
            );
          }
        }

        if (mounted) {
          await _processSellerConversationsAndSetState(convs);
        }
      } catch (_) {}
    });
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
    _sellerDashboardPoller?.cancel();
    _sliderTimer?.cancel();
    _sliderPageController.dispose();
    super.dispose();
  }

  String get _sellerUsername {
    final u = (widget.seller.username ?? '').trim();
    if (u.isNotEmpty) return u;
    return (widget.seller.mobile ?? '').trim();
  }

  Future<void> _loadSellerSliders() async {
    final list = await AuthService.getSellerSliders(_sellerUsername);

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
    final sellerUser = widget.seller.username ?? '';

    // 1. Instant 0ms Local Cache Load
    final cachedConvs = await AuthService.getCachedSellerConversations(sellerUser);
    if (cachedConvs.isNotEmpty && mounted) {
      await _processSellerConversationsAndSetState(cachedConvs);
    }

    // 2. Background Revalidation from VPS Database
    final convs = await AuthService.getSellerConversations(sellerUser);
    if (mounted) {
      await _processSellerConversationsAndSetState(convs);
    }
  }

  Future<void> _processSellerConversationsAndSetState(List<Map<String, dynamic>> convs) async {
    final prefs = await SharedPreferences.getInstance();

    for (var item in convs) {
      final rawMobile = item['customer_mobile']?.toString() ?? '';
      final cleanDigits = rawMobile.replaceAll(RegExp(r'\D'), '');
      final custMobile = cleanDigits.length >= 10 ? cleanDigits.substring(cleanDigits.length - 10) : rawMobile.trim();

      if (custMobile.isNotEmpty) {
        String displayName = '';

        // 1. Check item['customer_name'] returned directly from backend API
        final apiName = (item['customer_name'] ?? item['name'] ?? '').toString().trim();
        if (apiName.isNotEmpty && !apiName.startsWith('Customer')) {
          displayName = apiName;
        }

        // 2. Fetch real customer profile from VPS API Database
        if (displayName.isEmpty) {
          final profile = await AuthService.getCustomerProfile(custMobile);
          if (profile != null && profile['name'] != null) {
            final pName = profile['name'].toString().trim();
            if (pName.isNotEmpty && !pName.startsWith('Customer')) {
              displayName = pName;
            }
          }
        }

        // 3. Fallback to Customer Saved Address receiverName
        if (displayName.isEmpty) {
          final jsonStr = prefs.getString('customer_addresses_$custMobile');
          if (jsonStr != null && jsonStr.isNotEmpty) {
            try {
              final List<dynamic> list = jsonDecode(jsonStr);
              if (list.isNotEmpty) {
                final defaultAddr = list.firstWhere((a) => a['isDefault'] == true, orElse: () => list.first);
                final rName = defaultAddr['receiverName']?.toString().trim() ?? '';
                if (rName.isNotEmpty && !rName.startsWith('Customer')) displayName = rName;
              }
            } catch (_) {}
          }
        }

        // 4. Fallback if no name exists anywhere
        if (displayName.isEmpty) {
          displayName = 'Customer ($custMobile)';
        }
        item['display_name'] = displayName;

        // Calculate pending orders count for this customer
        int pendingOrdersCount = 0;
        final msgs = await AuthService.getCachedMessages(
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
          height: 125,
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
              final bg = (slider['bg'] ?? slider['bg_image_url'] ?? slider['bgImageUrl'] ?? slider['image'] ?? slider['imageUrl'] ?? 'transparent').toString();

              final tagBgHex = (slider['tag_bg_color'] ?? slider['tagBgColor'] ?? '#10B981').toString();
              final tagShape = (slider['tag_shape'] ?? slider['tagShape'] ?? 'pill').toString();
              final titleHex = (slider['title_color'] ?? slider['titleColor'] ?? '#FFFFFF').toString();
              final descHex = (slider['desc_color'] ?? slider['descColor'] ?? '#E2E8F0').toString();

              final tagBg = SellerSlidersScreen.hexToColor(tagBgHex, defaultColor: const Color(0xFF10B981));
              final titleColor = SellerSlidersScreen.hexToColor(titleHex, defaultColor: Colors.white);
              final descColor = SellerSlidersScreen.hexToColor(descHex, defaultColor: const Color(0xFFE2E8F0));
              final tagDecor = SellerSlidersScreen.buildTagDecoration(tagShape, tagBg);
              final overlayDim = (slider['overlay_dim'] as num?)?.toDouble() ?? 0.0;
              final removeWhiteBg = (slider['remove_white_bg'] == true || slider['remove_white_bg'] == 1);
              final imgFit = slider['img_fit']?.toString() ?? 'cover';

              return Container(
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.zero,
                  boxShadow: (bg == 'none' || bg == 'transparent' || bg.isEmpty || removeWhiteBg)
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                  clipBehavior: Clip.antiAlias,
                  child: SellerSlidersScreen.buildBannerBackground(
                    bg: bg,
                    overlayDim: overlayDim,
                    removeWhiteBg: removeWhiteBg,
                    imgFit: imgFit,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 115),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

        const SizedBox(height: 10),

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
      margin: const EdgeInsets.only(top: 6, bottom: 4),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pro-Level Animated Organic Wave Header Container
            ClipPath(
              clipper: HeaderArcWaveClipper(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: HeaderThemeHelper.buildDecoration(_headerThemeConfig),
                child: Stack(
                  children: [
                    // Floating Translucent Grocery Icons Background Particles
                    Positioned.fill(
                      child: GroceryFloatingBackgroundParticles(
                        particleOpacity: (_headerThemeConfig['particle_opacity'] as num?)?.toDouble() ?? 0.9,
                      ),
                    ),

                    // Flipkart Style Festive Lottie Animation Overlay
                    Positioned.fill(
                      child: FestivalLottieHeaderWidget(config: _headerThemeConfig),
                    ),

                    // Continuous Metallic Shining Glass Light Beam
                    if (_headerThemeConfig['enable_shining'] != false)
                      const Positioned.fill(
                        child: ContinuousShiningGlassBeamWidget(),
                      ),

                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                      // Top App Header Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF818CF8), width: 1.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 15,
                                backgroundColor: Color(0xFF8B5CF6),
                                child: Icon(Icons.store_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.seller.name.isNotEmpty ? widget.seller.name : (widget.seller.username ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const PulsingStoreBadge(),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                              onPressed: () {
                                _loadHeaderTheme();
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
                      ),

                      const SizedBox(height: 95),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

            // 3D Banner Carousel Slider placed OUTSIDE green header, right ABOVE Customer Conversations & Orders
            if (_sliders.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSliderSection(),
              const SizedBox(height: 8),
            ],

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          ],
        ),
      ),
    );
  }
}

/// Organic Arc Wave Clipper for Pro Header
class HeaderArcWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 16,
      size.width,
      size.height - 24,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Continuous Pulsing Live Store Status Badge Widget
class PulsingStoreBadge extends StatefulWidget {
  const PulsingStoreBadge({super.key});

  @override
  State<PulsingStoreBadge> createState() => _PulsingStoreBadgeState();
}

class _PulsingStoreBadgeState extends State<PulsingStoreBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.45), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF34D399),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF34D399),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Express 30-Min Delivery',
            style: TextStyle(
              color: Color(0xFFECFDF5), // Crisp Pure Mint White
              fontSize: 11,
              fontWeight: FontWeight.w500, // Sleek & thin font
              letterSpacing: 0.2,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Grocery Background Icons Animation
class GroceryFloatingBackgroundParticles extends StatefulWidget {
  final double particleOpacity;
  const GroceryFloatingBackgroundParticles({super.key, this.particleOpacity = 0.9});

  @override
  State<GroceryFloatingBackgroundParticles> createState() => _GroceryFloatingBackgroundParticlesState();
}

class _GroceryFloatingBackgroundParticlesState extends State<GroceryFloatingBackgroundParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<Map<String, dynamic>> _particles = [
    {'icon': Icons.shopping_cart_rounded, 'top': 15.0, 'left': 15.0, 'size': 20.0, 'dx': 12.0, 'dy': 8.0, 'phase': 0.0, 'opacity': 0.95},
    {'icon': Icons.apple_rounded, 'top': 35.0, 'right': 20.0, 'size': 18.0, 'dx': -14.0, 'dy': 10.0, 'phase': 1.0, 'opacity': 0.90},
    {'icon': Icons.eco_rounded, 'bottom': 45.0, 'left': 25.0, 'size': 21.0, 'dx': 10.0, 'dy': -12.0, 'phase': 2.0, 'opacity': 0.92},
    {'icon': Icons.shopping_bag_rounded, 'top': 25.0, 'left': 160.0, 'size': 18.0, 'dx': -8.0, 'dy': 14.0, 'phase': 3.0, 'opacity': 0.90},
    {'icon': Icons.storefront_rounded, 'bottom': 55.0, 'right': 35.0, 'size': 20.0, 'dx': 14.0, 'dy': -9.0, 'phase': 4.0, 'opacity': 0.95},
    {'icon': Icons.bakery_dining_rounded, 'top': 75.0, 'left': 75.0, 'size': 17.0, 'dx': -10.0, 'dy': -8.0, 'phase': 1.5, 'opacity': 0.88},
    {'icon': Icons.local_grocery_store_rounded, 'bottom': 30.0, 'right': 140.0, 'size': 19.0, 'dx': 11.0, 'dy': 11.0, 'phase': 2.5, 'opacity': 0.92},
    {'icon': Icons.rice_bowl_rounded, 'top': 100.0, 'right': 110.0, 'size': 17.0, 'dx': 9.0, 'dy': -13.0, 'phase': 0.5, 'opacity': 0.90},
    {'icon': Icons.fastfood_rounded, 'bottom': 70.0, 'left': 130.0, 'size': 18.0, 'dx': -12.0, 'dy': 7.0, 'phase': 3.5, 'opacity': 0.85},
    {'icon': Icons.icecream_rounded, 'top': 45.0, 'left': 260.0, 'size': 16.0, 'dx': 13.0, 'dy': -10.0, 'phase': 4.5, 'opacity': 0.90},
    {'icon': Icons.water_drop_rounded, 'bottom': 20.0, 'left': 210.0, 'size': 15.0, 'dx': -11.0, 'dy': 12.0, 'phase': 1.2, 'opacity': 0.92},
    {'icon': Icons.egg_alt_rounded, 'top': 110.0, 'left': 30.0, 'size': 17.0, 'dx': 8.0, 'dy': -14.0, 'phase': 2.8, 'opacity': 0.88},
    {'icon': Icons.set_meal_rounded, 'bottom': 80.0, 'right': 190.0, 'size': 19.0, 'dx': -15.0, 'dy': 9.0, 'phase': 0.8, 'opacity': 0.90},
    {'icon': Icons.takeout_dining_rounded, 'top': 130.0, 'right': 40.0, 'size': 18.0, 'dx': 10.0, 'dy': 10.0, 'phase': 3.8, 'opacity': 0.88},
    {'icon': Icons.breakfast_dining_rounded, 'top': 15.0, 'right': 180.0, 'size': 19.0, 'dx': -7.0, 'dy': -11.0, 'phase': 4.2, 'opacity': 0.92},
    {'icon': Icons.local_cafe_rounded, 'bottom': 15.0, 'left': 90.0, 'size': 17.0, 'dx': 14.0, 'dy': -8.0, 'phase': 1.8, 'opacity': 0.88},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 7),
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
        final val = _controller.value * 2 * math.pi;

        return Stack(
          children: _particles.map((p) {
            final phase = (p['phase'] as double);
            final offsetX = math.sin(val + phase) * (p['dx'] as double);
            final offsetY = math.cos(val + phase) * (p['dy'] as double);

            final baseOp = p['opacity'] as double;
            final finalOp = (baseOp * widget.particleOpacity).clamp(0.0, 1.0);

            return Positioned(
              top: p['top'] != null ? (p['top'] as double) + offsetY : null,
              bottom: p['bottom'] != null ? (p['bottom'] as double) + offsetY : null,
              left: p['left'] != null ? (p['left'] as double) + offsetX : null,
              right: p['right'] != null ? (p['right'] as double) + offsetX : null,
              child: Icon(
                p['icon'] as IconData,
                size: p['size'] as double,
                color: Colors.white.withValues(alpha: finalOp),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
