import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/header_theme_helper.dart';
import '../dashboards/customer_dashboard.dart';
import '../role_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_chat_screen.dart';
import 'customer_main_nav_screen.dart';
import '../seller/seller_sliders_screen.dart';

class AbstractPatternPainter extends CustomPainter {
  final String presetId;
  AbstractPatternPainter(this.presetId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final width = size.width;
    final height = size.height;

    switch (presetId) {
      case 'preset_1':
        paint.color = Colors.white.withOpacity(0.09);
        canvas.drawCircle(Offset(width * 0.85, height * 0.8), 70, paint);
        canvas.drawCircle(Offset(width * 0.75, height * 0.4), 100, paint);
        canvas.drawCircle(Offset(width * 0.3, height * 0.2), 90, paint);
        canvas.drawCircle(Offset(width * 0.5, height * 0.7), 60, paint);
        break;
      case 'preset_2':
        paint.color = Colors.cyan.withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.9, height * 0.1), 120, paint);
        canvas.drawCircle(Offset(width * 0.1, height * 0.9), 110, paint);
        break;
      case 'preset_3':
        paint.color = Colors.amber.withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.2, height * 0.3), 80, paint);
        canvas.drawCircle(Offset(width * 0.8, height * 0.7), 130, paint);
        break;
      case 'preset_4':
        paint.color = const Color(0xFFA855F7).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.95, height * 0.5), 140, paint);
        canvas.drawCircle(Offset(width * 0.15, height * 0.8), 75, paint);
        break;
      case 'preset_5':
        paint.color = const Color(0xFF34D399).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.7, height * 0.2), 110, paint);
        canvas.drawCircle(Offset(width * 0.2, height * 0.7), 90, paint);
        break;
      case 'preset_6':
        paint.color = const Color(0xFFFBBF24).withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.8, height * 0.3), 100, paint);
        canvas.drawCircle(Offset(width * 0.3, height * 0.8), 85, paint);
        break;
      case 'preset_7':
        paint.color = const Color(0xFFF43F5E).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.85, height * 0.7), 120, paint);
        canvas.drawCircle(Offset(width * 0.25, height * 0.3), 95, paint);
        break;
      case 'preset_8':
        paint.color = const Color(0xFFC084FC).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.1, height * 0.2), 100, paint);
        canvas.drawCircle(Offset(width * 0.9, height * 0.8), 110, paint);
        break;
      case 'preset_9':
        paint.color = const Color(0xFF38BDF8).withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.5, height * 0.2), 90, paint);
        canvas.drawCircle(Offset(width * 0.85, height * 0.7), 115, paint);
        break;
      case 'preset_10':
        paint.color = const Color(0xFFFDE047).withOpacity(0.18);
        canvas.drawCircle(Offset(width * 0.3, height * 0.8), 130, paint);
        canvas.drawCircle(Offset(width * 0.8, height * 0.2), 80, paint);
        break;
      default:
        paint.color = Colors.white.withOpacity(0.1);
        canvas.drawCircle(Offset(width * 0.8, height * 0.5), 90, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CustomerSellerOrdersScreen extends StatefulWidget {
  final UserModel customer;
  final String sellerUsername;
  final String sellerName;
  final String sellerMobile;
  final bool hideBottomNav;

  const CustomerSellerOrdersScreen({
    super.key,
    required this.customer,
    required this.sellerUsername,
    required this.sellerName,
    required this.sellerMobile,
    this.hideBottomNav = false,
  });

  @override
  State<CustomerSellerOrdersScreen> createState() => _CustomerSellerOrdersScreenState();
}

class _CustomerSellerOrdersScreenState extends State<CustomerSellerOrdersScreen> {
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _sliders = [];
  Map<String, dynamic> _headerThemeConfig = {};
  bool _isLoading = true;
  int _currentSliderPage = 0;
  String _selectedOrderFilter = 'All'; // 'All', 'Pending', 'Delivered', 'Cancelled'
  final PageController _sliderController = PageController(viewportFraction: 0.92);

  @override
  void initState() {
    super.initState();
    AuthService.saveLastSelectedSeller(
      username: widget.sellerUsername,
      name: widget.sellerName,
      mobile: widget.sellerMobile,
    );
    _loadData();
  }

  static List<Map<String, dynamic>> get presetThemes => [
    {
      'id': 'preset_1',
      'name': 'Purple Bokeh',
      'colors': [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
    },
    {
      'id': 'preset_2',
      'name': 'Ocean Wave',
      'colors': [const Color(0xFF1E3A8A), const Color(0xFF06B6D4)],
    },
    {
      'id': 'preset_3',
      'name': 'Sunset Flare',
      'colors': [const Color(0xFFDC2626), const Color(0xFFF59E0B)],
    },
    {
      'id': 'preset_4',
      'name': 'Cyberpunk',
      'colors': [const Color(0xFF09090B), const Color(0xFF7C3AED)],
    },
    {
      'id': 'preset_5',
      'name': 'Emerald Mesh',
      'colors': [const Color(0xFF065F46), const Color(0xFF10B981)],
    },
    {
      'id': 'preset_6',
      'name': 'Golden Luxe',
      'colors': [const Color(0xFF1E293B), const Color(0xFFD97706)],
    },
    {
      'id': 'preset_7',
      'name': 'Neon Party',
      'colors': [const Color(0xFF6B21A8), const Color(0xFFF43F5E)],
    },
    {
      'id': 'preset_8',
      'name': 'Royal Indigo',
      'colors': [const Color(0xFF3730A3), const Color(0xFFA855F7)],
    },
    {
      'id': 'preset_9',
      'name': 'Cosmic Dark',
      'colors': [const Color(0xFF0F172A), const Color(0xFF1E40AF)],
    },
    {
      'id': 'preset_10',
      'name': 'Coral Sunrise',
      'colors': [const Color(0xFFF43F5E), const Color(0xFFFACC15)],
    },
  ];

  static Color hexToColor(String code, {Color defaultColor = Colors.white}) {
    try {
      String cleanHex = code.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  static BoxDecoration buildTagDecoration(String shape, Color tagBg) {
    final s = shape.toLowerCase();
    if (s == 'outline') {
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tagBg, width: 2),
      );
    } else if (s == 'circle') {
      return BoxDecoration(
        color: tagBg,
        shape: BoxShape.circle,
      );
    } else if (s == 'square') {
      return BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.zero,
      );
    } else if (s == 'ribbon') {
      return BoxDecoration(
        color: tagBg,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      );
    } else if (s == 'stadium') {
      return BoxDecoration(
        color: tagBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      );
    } else if (s == 'rounded') {
      return BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(8),
      );
    } else if (s == 'badge') {
      return BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(4),
      );
    } else {
      return BoxDecoration(
        color: tagBg,
        borderRadius: BorderRadius.circular(20),
      );
    }
  }

  static Widget buildBannerBackground({
    required String bg,
    required Widget child,
    BorderRadius? borderRadius,
    double overlayDim = 0.0,
    bool removeWhiteBg = false,
    String imgFit = 'cover',
  }) {
    return SellerSlidersScreen.buildBannerBackground(
      bg: bg,
      child: child,
      borderRadius: borderRadius,
      overlayDim: overlayDim,
      removeWhiteBg: removeWhiteBg,
      imgFit: imgFit,
    );
  }

  final ScrollController _ordersScrollController = ScrollController();
  Timer? _sliderTimer;

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _sliderController.dispose();
    _ordersScrollController.dispose();
    super.dispose();
  }

  void _startAutoSlider() {
    _sliderTimer?.cancel();
    if (_sliders.length <= 1) return;

    _sliderTimer = Timer.periodic(const Duration(seconds: 3, milliseconds: 500), (timer) {
      if (!mounted || _sliders.isEmpty || !_sliderController.hasClients) return;
      int nextPage = _currentSliderPage + 1;
      if (nextPage >= _sliders.length) {
        nextPage = 0;
      }
      _sliderController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  bool _isBlockedBySeller = false;
  bool _hasDraft = false;
  String _draftSnippet = '';

  Future<void> _checkBlockedBySeller() async {
    final blocked = await AuthService.isCustomerBlocked(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
    );
    if (mounted) {
      setState(() {
        _isBlockedBySeller = blocked;
      });
    }
  }

  Future<void> _loadData() async {
    _checkBlockedBySeller();

    // 1. Instant Cache Load (0 ms perceived latency)
    final cached = await AuthService.getCachedMessages(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
    );
    final headerTheme = await AuthService.getHeaderThemeConfig();
    if (mounted) {
      setState(() {
        _headerThemeConfig = headerTheme;
      });
    }

    if (cached.isNotEmpty && mounted) {
      await AuthService.annotateMessagesWithLifetimeHierarchy(
        sellerUsername: widget.sellerUsername,
        customerMobile: widget.customer.mobile ?? '',
        messages: cached,
      );
      if (mounted) {
        setState(() {
          _messages = cached;
          _isLoading = false;
        });
      }
    }

    // 2. Background Revalidation from VPS Server
    final msgs = await AuthService.getMessages(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
    );
    await AuthService.annotateMessagesWithLifetimeHierarchy(
      sellerUsername: widget.sellerUsername,
      customerMobile: widget.customer.mobile ?? '',
      messages: msgs,
    );
    final sliders = await AuthService.getSellerSliders(widget.sellerUsername);
    final prefs = await SharedPreferences.getInstance();
    final cleanCust = (widget.customer.mobile ?? '').trim();
    final cleanSeller = widget.sellerUsername.trim();
    final draftKey = 'draft_order_${cleanCust}_$cleanSeller';
    final draftStr = prefs.getString(draftKey);
    bool hasDraft = false;
    String draftSnippet = '';
    if (draftStr != null && draftStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(draftStr);
        final activeMode = (data['activeMode'] ?? 'chat').toString();
        final chatText = (data['chatText'] ?? data['text'] ?? '').toString().trim();
        final List rawItems = data['items'] ?? [];

        if (activeMode == 'list' && rawItems.isNotEmpty) {
          hasDraft = true;
          final firstItemName = rawItems.first['name'] ?? 'Item';
          final count = rawItems.length;
          draftSnippet = count > 1 ? '$firstItemName & ${count - 1} more items (List Mode)' : '$firstItemName (List Mode)';
        } else if (chatText.isNotEmpty) {
          hasDraft = true;
          final lines = chatText.split('\n').where((l) => l.trim().isNotEmpty).toList();
          draftSnippet = lines.isNotEmpty ? lines.first : chatText;
        } else if (rawItems.isNotEmpty) {
          hasDraft = true;
          draftSnippet = '${rawItems.length} items (List Mode)';
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _messages = msgs;
        _sliders = sliders;
        _isLoading = false;
        _hasDraft = hasDraft;
        _draftSnippet = draftSnippet;
      });
      _startAutoSlider();
    }
  }

  Future<void> _callSeller() async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calling Seller: +91 $mobile'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seller mobile number is not available'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildSliderSection() {
    if (_sliders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _sliderController,
            onPageChanged: (idx) {
              setState(() => _currentSliderPage = idx);
            },
            itemCount: _sliders.length,
            itemBuilder: (ctx, idx) {
              final item = _sliders[idx];
              final tag = (item['tag'] ?? item['tagText'] ?? '').toString().trim();
              final title = (item['title'] ?? item['titleText'] ?? '').toString().trim();
              final desc = (item['description'] ?? item['subtitle'] ?? item['descText'] ?? '').toString().trim();
              final bg = (item['bg'] ?? item['bg_image_url'] ?? item['bgImageUrl'] ?? item['image'] ?? item['imageUrl'] ?? 'transparent').toString();
              final tagBg = hexToColor(item['tag_bg_color']?.toString() ?? '#10B981');
              final tagShape = item['tag_shape']?.toString() ?? 'pill';
              final titleCol = hexToColor(item['title_color']?.toString() ?? '#FFFFFF');
              final descCol = hexToColor(item['desc_color']?.toString() ?? '#E2E8F0');
              final overlayDim = (item['overlay_dim'] as num?)?.toDouble() ?? 0.0;
              final removeWhiteBg = (item['remove_white_bg'] == true || item['remove_white_bg'] == 1);
              final imgFit = item['img_fit']?.toString() ?? 'cover';

              final isSelected = _currentSliderPage == idx;

              return AnimatedScale(
                scale: isSelected ? 1.0 : 0.93,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: (bg == 'none' || bg == 'transparent' || bg.isEmpty || removeWhiteBg)
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: buildBannerBackground(
                    bg: bg,
                    overlayDim: overlayDim,
                    removeWhiteBg: removeWhiteBg,
                    imgFit: imgFit,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 140),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (tag.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: buildTagDecoration(tagShape, tagBg),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: tagShape.toLowerCase() == 'outline'
                                      ? tagBg
                                      : (tagBg.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (title.isNotEmpty) ...[
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: titleCol, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (desc.isNotEmpty) ...[
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: descCol, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (_sliders.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _sliders.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentSliderPage == index ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentSliderPage == index ? const Color(0xFF8B5CF6) : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSegmentedFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Sleek Slate 100 Track Background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegmentTab('All', 'All')),
          Expanded(child: _buildSegmentTab('Pending', 'Pending')),
          Expanded(child: _buildSegmentTab('Delivered', 'Delivered')),
          Expanded(child: _buildSegmentTab('Cancelled', 'Cancelled')),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String filterKey, String labelText) {
    final bool isSelected = _selectedOrderFilter == filterKey;

    Color activeColor;
    switch (filterKey) {
      case 'Pending':
        activeColor = const Color(0xFFD97706); // Warm Amber
        break;
      case 'Delivered':
        activeColor = const Color(0xFF10B981); // Emerald Green
        break;
      case 'Cancelled':
        activeColor = const Color(0xFFEF4444); // Crimson Red
        break;
      default:
        activeColor = const Color(0xFF0F172A); // Deep Slate Navy
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOrderFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Future<bool> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Exit App?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text('Are you sure you want to exit Daily Mart?', style: TextStyle(color: Colors.black87, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  Future<void> _exitToSellerList() async {
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
  }

  Future<void> _disconnectAndDeleteSeller() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Remove Seller?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${widget.sellerName}" from your sellers list?\n\nYou will be redirected to the seller search list screen to select or add another seller.',
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove & Exit 🗑️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.deleteCustomerSellerConnection(
        sellerUsername: widget.sellerUsername,
        customerMobile: widget.customer.mobile ?? '',
      );
      await AuthService.clearLastSelectedSeller();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seller "${widget.sellerName}" removed! 🗑️'),
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

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
          ],
        ),
        content: const Text('Are you sure you want to logout from Daily Mart?', style: TextStyle(color: Colors.black87, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.clearLastSelectedSeller();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (ctx) => const RoleSelectionScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildRecentOrdersList() {
    final activeMsgs = _messages.where((msg) {
      final status = (msg['order_status'] ?? '').toString().toLowerCase();
      final isDel = msg['is_deleted'] == true ||
          msg['is_deleted'] == 1 ||
          msg['is_deleted'] == '1' ||
          status == 'deleted' ||
          msg['message'].toString().contains('Deleted');
      return !isDel;
    }).toList();

    if (activeMsgs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No orders placed yet.\nTap chat button to order!',
              style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final displayMsgsAll = activeMsgs.reversed.toList();

    // Filter orders according to _selectedOrderFilter
    final displayMsgs = displayMsgsAll.where((msg) {
      final status = (msg['order_status'] ?? '').toString().trim().toLowerCase();
      final delStatus = (msg['delivery_status'] ?? '').toString().trim().toLowerCase();

      final bool isCancelled = status == 'cancelled' ||
          status == 'rejected' ||
          delStatus == 'cancelled' ||
          msg['cancel_reason'] != null;

      final bool isDelivered = status == 'delivered' || delStatus == 'delivered';

      if (_selectedOrderFilter == 'Pending') {
        return !isDelivered && !isCancelled;
      } else if (_selectedOrderFilter == 'Delivered') {
        return isDelivered;
      } else if (_selectedOrderFilter == 'Cancelled') {
        return isCancelled;
      }
      return true; // 'All'
    }).toList();

    if (displayMsgs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedOrderFilter == 'Cancelled'
                  ? Icons.cancel_outlined
                  : _selectedOrderFilter == 'Delivered'
                      ? Icons.check_circle_outline_rounded
                      : Icons.hourglass_empty_rounded,
              size: 44,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              'No ${_selectedOrderFilter.toLowerCase()} orders found',
              style: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select "All" to view all placed orders.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      reverse: false,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      itemCount: displayMsgs.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 18),
      itemBuilder: (ctx, idx) {
        final msg = displayMsgs[idx];
        final msgId = msg['id'];
        String rawOrderId = (msg['order_id'] ?? '').toString().trim();
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
        final orderStatus = (msg['order_status'] ?? '').toString().trim();
        final delStatus = (msg['delivery_status'] ?? '').toString().trim();
        final createdAt = msg['created_at'] ?? '';

        final lowerStatus = orderStatus.toLowerCase();
        final lowerDelStatus = delStatus.toLowerCase();

        final bool isCancelled = lowerStatus == 'cancelled' ||
            lowerStatus == 'rejected' ||
            lowerDelStatus == 'cancelled' ||
            msg['cancel_reason'] != null;

        final bool isDelivered = lowerStatus == 'delivered' ||
            lowerDelStatus == 'delivered';

        final bool isOutForDelivery = lowerDelStatus == 'out_for_delivery' ||
            lowerDelStatus == 'out for delivery' ||
            lowerStatus == 'out for delivery';

        final bool isApproved = lowerStatus == 'ready' ||
            lowerStatus == 'approved' ||
            lowerStatus == 'processing';

        String badgeText = 'Pending';
        Color badgeBgColor = const Color(0xFFFEF9C3);
        Color badgeTextColor = const Color(0xFFD97706);
        Border? badgeBorder;

        if (isCancelled) {
          badgeText = 'Cancelled';
          badgeBgColor = const Color(0xFFFEE2E2);
          badgeTextColor = const Color(0xFFDC2626);
          badgeBorder = Border.all(color: const Color(0xFFFCA5A5));
        } else if (isDelivered) {
          badgeText = 'Delivered';
          badgeBgColor = const Color(0xFFDCFCE7);
          badgeTextColor = const Color(0xFF15803D);
          badgeBorder = Border.all(color: const Color(0xFF86EFAC));
        } else if (isOutForDelivery) {
          badgeText = 'Out for Delivery';
          badgeBgColor = const Color(0xFFDBEAFE);
          badgeTextColor = const Color(0xFF1D4ED8);
          badgeBorder = Border.all(color: const Color(0xFF93C5FD));
        } else if (isApproved) {
          badgeText = 'Approved';
          badgeBgColor = const Color(0xFFE0E7FF);
          badgeTextColor = const Color(0xFF4338CA);
          badgeBorder = Border.all(color: const Color(0xFFA5B4FC));
        }

        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerChatScreen(
                  customer: widget.customer,
                  sellerUsername: widget.sellerUsername,
                  sellerName: widget.sellerName,
                  sellerMobile: widget.sellerMobile,
                ),
              ),
            );
            _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
            child: Row(
              children: [
                InkWell(
                  onTap: _callSeller,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
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
                              orderId,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(10),
                              border: badgeBorder,
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF0F172A)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.hideBottomNav,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.hideBottomNav) return;
        final exit = await _showExitDialog();
        if (exit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: Stack(
            children: [
              // Original Delivery Boy Background Image
              Positioned(
                right: -10,
                bottom: 26,
                top: 130,
                width: 260,
                child: Image.asset(
                  'assets/images/delivery_boy.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomRight,
                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                ),
              ),

              // Main Content Layout
              Positioned.fill(
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
                                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.sellerName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (widget.sellerMobile.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Mobile: +91 ${widget.sellerMobile}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: PulsingStoreBadge(),
                                              ),
                                            ],
                                          ),
                                        ),
                                         Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             IconButton(
                                               visualDensity: VisualDensity.compact,
                                               padding: const EdgeInsets.all(4),
                                               constraints: const BoxConstraints(),
                                               icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF34D399), size: 22),
                                               tooltip: 'Call Seller 📞',
                                               onPressed: _callSeller,
                                             ),
                                             const SizedBox(width: 4),
                                             IconButton(
                                               visualDensity: VisualDensity.compact,
                                               padding: const EdgeInsets.all(4),
                                               constraints: const BoxConstraints(),
                                               icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                                               tooltip: 'Refresh Data 🔄',
                                               onPressed: _loadData,
                                             ),
                                             const SizedBox(width: 4),
                                             IconButton(
                                               visualDensity: VisualDensity.compact,
                                               padding: const EdgeInsets.all(4),
                                               constraints: const BoxConstraints(),
                                               icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 22),
                                               tooltip: 'Exit to Seller List 🚪',
                                               onPressed: _exitToSellerList,
                                             ),
                                             const SizedBox(width: 2),
                                             PopupMenuButton<String>(
                                               padding: const EdgeInsets.all(4),
                                               constraints: const BoxConstraints(),
                                               icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                                               color: Colors.white,
                                               surfaceTintColor: Colors.white,
                                               elevation: 4,
                                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                               onSelected: (val) async {
                                                 if (val == 'switch_seller') {
                                                   _exitToSellerList();
                                                 } else if (val == 'delete_seller') {
                                                   _disconnectAndDeleteSeller();
                                                 } else if (val == 'call_seller') {
                                                   _callSeller();
                                                 } else if (val == 'logout') {
                                                   _logout();
                                                 } else if (val == 'refresh') {
                                                   _loadData();
                                                 }
                                               },
                                               itemBuilder: (ctx) => [
                                                 const PopupMenuItem(
                                                   value: 'switch_seller',
                                                   child: Row(
                                                     children: [
                                                       Icon(Icons.swap_horiz_rounded, color: Color(0xFF0F172A), size: 20),
                                                       SizedBox(width: 10),
                                                       Text('Switch / Add Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                     ],
                                                   ),
                                                 ),
                                                 const PopupMenuItem(
                                                   value: 'delete_seller',
                                                   child: Row(
                                                     children: [
                                                       Icon(Icons.delete_outline_rounded, color: Color(0xFF0F172A), size: 20),
                                                       SizedBox(width: 10),
                                                       Text('Remove Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                     ],
                                                   ),
                                                 ),
                                                 const PopupMenuItem(
                                                   value: 'call_seller',
                                                   child: Row(
                                                     children: [
                                                       Icon(Icons.phone_rounded, color: Color(0xFF0F172A), size: 20),
                                                       SizedBox(width: 10),
                                                       Text('Call Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                     ],
                                                   ),
                                                 ),
                                                 const PopupMenuItem(
                                                   value: 'refresh',
                                                   child: Row(
                                                     children: [
                                                       Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
                                                       SizedBox(width: 10),
                                                       Text('Refresh Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                     ],
                                                   ),
                                                 ),
                                                 const PopupMenuItem(
                                                   value: 'logout',
                                                   child: Row(
                                                     children: [
                                                       Icon(Icons.logout_rounded, color: Color(0xFF0F172A), size: 20),
                                                       SizedBox(width: 10),
                                                       Text('Logout App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ],
                                         ),
                                      ],
                                    ),
                                  ),

                                  // Top Banner 3D Carousel Slider & Indicator Dots
                                  if (_sliders.isNotEmpty) ...[
                                    _buildSliderSection(),
                                    const SizedBox(height: 28),
                                  ] else
                                    const SizedBox(height: 90),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Section Title Header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                      child: Text(
                        'Recent Orders',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    // Draft Order Notification Banner Card (if customer has an unsent draft order)
                    if (_hasDraft) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB), // Soft Warm Amber Tint
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCD34D), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Draft Order Pending ✏️',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _draftSnippet.isNotEmpty ? _draftSnippet : 'Unsent draft order found. Tap to resume.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerChatScreen(
                                      customer: widget.customer,
                                      sellerUsername: widget.sellerUsername,
                                      sellerName: widget.sellerName,
                                      sellerMobile: widget.sellerMobile,
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text('Resume', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Premium Segmented Filter Bar Track
                    _buildSegmentedFilterBar(),

                    // Orders List inside Expanded for scrollability over delivery boy image
                    Expanded(
                      child: _isLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Color(0xFF8B5CF6))))
                          : _buildRecentOrdersList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_isBlockedBySeller) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have been blocked by this seller. You cannot place orders.'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerChatScreen(
                customer: widget.customer,
                sellerUsername: widget.sellerUsername,
                sellerName: widget.sellerName,
                sellerMobile: widget.sellerMobile,
              ),
            ),
          );
          _loadData();
        },
        backgroundColor: _isBlockedBySeller
            ? const Color(0xFFEF4444)
            : (_hasDraft ? const Color(0xFFD97706) : const Color(0xFF10B981)),
        icon: Icon(
          _isBlockedBySeller
              ? Icons.block_rounded
              : (_hasDraft ? Icons.edit_note_rounded : Icons.chat_bubble_rounded),
          color: Colors.white,
        ),
        label: Text(
          _isBlockedBySeller
              ? 'Seller Blocked'
              : (_hasDraft ? 'Resume Draft Order ✏️' : 'Chat & Order'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      bottomNavigationBar: widget.hideBottomNav ? null : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              // Recent Orders page IS the Home Page - Stay on this screen
              return;
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (ctx) => CustomerMainNavScreen(
                    customer: widget.customer,
                    initialTab: 1, // Profile
                  ),
                ),
                (route) => false,
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, size: 26),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              activeIcon: Icon(Icons.person_rounded, size: 26),
              label: 'Profile',
            ),
          ],
        ),
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
          const Flexible(
            child: Text(
              'Express 30-Min Delivery',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFECFDF5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
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
    {'icon': Icons.egg_alt_rounded, 'top': 110.0, 'left': 30.0, 'size': 26.0, 'dx': 8.0, 'dy': -14.0, 'phase': 2.8, 'opacity': 0.88},
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
            final finalOpacity = ((p['opacity'] as double) * widget.particleOpacity).clamp(0.0, 1.0);

            return Positioned(
              top: p['top'] != null ? (p['top'] as double) + offsetY : null,
              bottom: p['bottom'] != null ? (p['bottom'] as double) + offsetY : null,
              left: p['left'] != null ? (p['left'] as double) + offsetX : null,
              right: p['right'] != null ? (p['right'] as double) + offsetX : null,
              child: Icon(
                p['icon'] as IconData,
                size: p['size'] as double,
                color: Colors.white.withValues(alpha: finalOpacity),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
