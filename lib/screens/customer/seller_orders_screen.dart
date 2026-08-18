import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../utils/header_theme_helper.dart';
import '../../widgets/product_detail_bottom_sheet.dart';
import '../dashboards/customer_dashboard.dart';
import '../role_selection_screen.dart';
import '../seller/seller_order_cart_screen.dart';
import '../seller/seller_sliders_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_main_nav_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _rawCategories = [];
  List<String> _categories = [];
  Map<String, dynamic> _headerThemeConfig = {};
  bool _isLoading = true;
  int _currentSliderPage = 0;
  String _selectedCategory = 'All';
  String _selectedOrderFilter = 'All';
  String _searchQuery = '';
  int _cartBadgeCount = 0;
  double _cartTotalAmount = 0.0;
  String _sellerLocation = '';
  final PageController _sliderController = PageController();

  @override
  void initState() {
    super.initState();
    AuthService.saveLastSelectedSeller(
      username: widget.sellerUsername,
      name: widget.sellerName,
      mobile: widget.sellerMobile,
    );
    _loadData();
    _startSellerOrdersPolling();
  }

  Timer? _ordersPoller;

  bool _messagesChanged(List<Map<String, dynamic>> oldMsgs, List<Map<String, dynamic>> newMsgs) {
    if (oldMsgs.length != newMsgs.length) return true;
    for (int i = 0; i < oldMsgs.length; i++) {
      if (oldMsgs[i]['id'] != newMsgs[i]['id']) return true;
      if (oldMsgs[i]['order_status'] != newMsgs[i]['order_status']) return true;
      if (oldMsgs[i]['delivery_status'] != newMsgs[i]['delivery_status']) return true;
      if (oldMsgs[i]['payment_status'] != newMsgs[i]['payment_status']) return true;
      if (oldMsgs[i]['items_json'] != newMsgs[i]['items_json']) return true;
    }
    return false;
  }

  void _startSellerOrdersPolling() {
    _ordersPoller?.cancel();
    _ordersPoller = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!mounted) return;
      try {
        final msgs = await AuthService.getMessages(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
        );
        await AuthService.annotateMessagesWithLifetimeHierarchy(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
          messages: msgs,
        );
        if (mounted && (_isLoading || _messagesChanged(_messages, msgs))) {
          setState(() {
            _messages = msgs;
            _isLoading = false;
          });
        }
      } catch (_) {}
    });
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
    _ordersPoller?.cancel();
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
  List<Map<String, dynamic>> _sellerSections = [];

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

    try {
      // 1. Instant Cache Load for Location & Header Theme
      final prefs = await SharedPreferences.getInstance();
      final cachedLoc = prefs.getString('cached_seller_loc_${widget.sellerUsername}');
      if (cachedLoc != null && cachedLoc.isNotEmpty && mounted) {
        setState(() {
          _sellerLocation = cachedLoc;
        });
      }

      final headerTheme = await AuthService.getHeaderThemeConfig();
      if (mounted) {
        setState(() {
          _headerThemeConfig = headerTheme;
        });
      }

      // 2. Fetch Products, Categories & Sections FIRST (High Priority for Store UI)
      final results = await Future.wait([
        AuthService.getSellerProducts(widget.sellerUsername),
        AuthService.getSellerCategories(widget.sellerUsername),
        CartService.getCartItems(widget.sellerUsername),
        AuthService.getSellerSections(widget.sellerUsername),
      ]);

      final prods = results[0] as List<Map<String, dynamic>>;
      final rawCats = results[1] as List<Map<String, dynamic>>;
      final cartItems = results[2] as List<Map<String, dynamic>>;
      final sections = results[3] as List<Map<String, dynamic>>;

      final List<Map<String, dynamic>> parsedRawCats = [];
      final List<String> parsedCats = [];
      for (var c in rawCats) {
        if (c is Map) {
          parsedRawCats.add(Map<String, dynamic>.from(c));
          final name = (c['name'] ?? c['category_name'] ?? '').toString().trim();
          if (name.isNotEmpty && !parsedCats.contains(name)) parsedCats.add(name);
        } else {
          final name = c.toString().trim();
          if (name.isNotEmpty && !parsedCats.contains(name)) {
            parsedCats.add(name);
            parsedRawCats.add({'name': name, 'image': '🏷️'});
          }
        }
      }

      final cartCount = CartService.getTotalCount(cartItems);
      final cartTotalAmount = CartService.getTotalAmount(cartItems);

      if (mounted) {
        setState(() {
          _products = prods;
          _rawCategories = parsedRawCats;
          _categories = parsedCats;
          _sellerSections = sections;
          _cartBadgeCount = cartCount;
          _cartTotalAmount = cartTotalAmount;
          _isLoading = false;
        });
      }

      // 3. Fetch Sellers List & Location
      try {
        final sellers = await AuthService.getSellersList();
        for (var s in sellers) {
          final u = (s['username'] ?? '').toString().trim().toLowerCase();
          final m = (s['mobile'] ?? '').toString().trim();
          final targetU = widget.sellerUsername.trim().toLowerCase();
          final targetM = widget.sellerMobile.trim();
          if ((u.isNotEmpty && u == targetU) || (m.isNotEmpty && m == targetM)) {
            final loc = (s['location'] ?? s['store_location'] ?? s['address'] ?? '').toString().trim();
            if (loc.isNotEmpty) {
              await prefs.setString('cached_seller_loc_${widget.sellerUsername}', loc);
              if (mounted) {
                setState(() {
                  _sellerLocation = loc;
                });
              }
            }
            break;
          }
        }
      } catch (_) {}

      // 4. Fetch Sliders & Messages in Background
      try {
        final sliders = await AuthService.getSellerSliders(widget.sellerUsername);
        final msgs = await AuthService.getMessages(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
        );
        await AuthService.annotateMessagesWithLifetimeHierarchy(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
          messages: msgs,
        );

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
            _hasDraft = hasDraft;
            _draftSnippet = draftSnippet;
          });
          _startAutoSlider();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading seller orders data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final topSliders = _sliders.where((s) {
      final sec = (s['section'] ?? 'Top Banner').toString().trim();
      return sec.isEmpty || sec.toLowerCase() == 'top banner';
    }).toList();

    if (topSliders.isEmpty) {
      return const SizedBox.shrink();
    }

    final String keyStr = topSliders.map((s) => s['id']).join('_');
    return TopBannerSliderWidget(
      key: ValueKey(keyStr),
      sliders: topSliders,
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

      final bool isApproved = status == 'ready' || status == 'approved' || status == 'processing';
      final bool isDelivered = status == 'delivered' || delStatus == 'delivered';
      final bool isOutForDelivery = delStatus == 'out_for_delivery' || delStatus == 'out for delivery' || status == 'out for delivery';
      final bool isCancelled = (status == 'cancelled' || status == 'rejected' || delStatus == 'cancelled') && !isApproved && !isDelivered && !isOutForDelivery;

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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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

        final bool isApproved = lowerStatus == 'ready' ||
            lowerStatus == 'approved' ||
            lowerStatus == 'processing';

        final bool isDelivered = lowerStatus == 'delivered' ||
            lowerDelStatus == 'delivered';

        final bool isOutForDelivery = lowerDelStatus == 'out_for_delivery' ||
            lowerDelStatus == 'out for delivery' ||
            lowerStatus == 'out for delivery';

        final bool isCancelled = (lowerStatus == 'cancelled' ||
            lowerStatus == 'rejected' ||
            lowerDelStatus == 'cancelled') &&
            !isApproved &&
            !isDelivered &&
            !isOutForDelivery;

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
          badgeText = (lowerStatus == 'ready' || lowerStatus == 'approved') ? 'Approved' : 'Processing';
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
              // Main Content Layout - Fixed Top Header + Scrollable Slider & List
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
                                              if (_sellerLocation.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  _sellerLocation,
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ] else if (widget.sellerMobile.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '+91 ${widget.sellerMobile}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
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
                                                } else if (val == 'search_bar_style') {
                                                  _showManageSearchBarDialog();
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
                                                  value: 'search_bar_style',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                                                      SizedBox(width: 10),
                                                      Text('Search Bar Style 🔍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
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

                                  // Search Bar placed in Header with Seller Custom Styling & Transparency
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_bg_color'] ?? '#FFFFFF').withValues(
                                          alpha: ((_headerThemeConfig['search_opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery = val.trim();
                                          });
                                        },
                                        style: TextStyle(
                                          color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#0F172A'),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Search products in ${widget.sellerName}...',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#0F172A').withValues(alpha: 0.65),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#8B5CF6'),
                                          ),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Scrollable Area: Slider, Recent Orders, Filter Bar & Orders List
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3D Banner Carousel Slider
                            if (_sliders.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildSliderSection(),
                              const SizedBox(height: 8),
                            ],

                             // Circular Category Avatars Carousel
                             _buildCircularCategorySection(),
                             const SizedBox(height: 8),

                             // Dynamic Section-Based Product Grid Catalog
                             _buildStoreProductsGrid(),
                             const SizedBox(height: 80),
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         ),

      bottomNavigationBar: widget.hideBottomNav ? null : Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (index) async {
            if (index == 0) {
              return;
            } else if (index == 1) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SellerOrderCartScreen(
                    seller: UserModel(
                      id: widget.sellerUsername,
                      name: widget.sellerName,
                      mobile: widget.sellerMobile,
                      username: widget.sellerUsername,
                      role: UserRole.seller,
                    ),
                    customer: widget.customer,
                  ),
                ),
              );
              _loadData();
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
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, size: 26),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _cartTotalAmount > 0
                  ? Badge(
                      label: Text(
                        '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(1)}',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      child: const Icon(Icons.receipt_long_rounded),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              activeIcon: _cartTotalAmount > 0
                  ? Badge(
                      label: Text(
                        '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(1)}',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      child: const Icon(Icons.receipt_long_rounded, size: 26),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 26),
              label: 'My Order',
            ),
            const BottomNavigationBarItem(
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

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || cat == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCat;
    }).toList();
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 38}) {
    final img = rawImg.trim();
    if (img.isEmpty) {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
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
          errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
        );
      } catch (_) {}
    }

    if (img.length <= 4 && img.isNotEmpty) {
      return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
    }

    return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
  }

  Widget _buildProductCard(Map<String, dynamic> p, {int columns = 2}) {
    final name = (p['name'] ?? '').toString();
    final cat = (p['category'] ?? '').toString();
    final rate = (p['rate'] as num?)?.toDouble() ?? 0.0;
    final unit = (p['unit'] ?? 'Pcs').toString();
    final qty = (p['qty'] as num?)?.toInt() ?? 1;
    final imgUrl = (p['image_url'] ?? '').toString().trim();
    final imgVal = (p['image'] ?? '').toString().trim();
    final img = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');
    final btnText = (p['button_text'] ?? '').toString().trim().isNotEmpty 
        ? (p['button_text'] ?? '').toString().trim() 
        : 'Buy Now';

    void handleProductTap() {
      showProductDetailBottomSheet(
        context: context,
        product: p,
        sellerUsername: widget.sellerUsername,
        onCartUpdated: () async {
          final items = await CartService.getCartItems(widget.sellerUsername);
          if (mounted) {
            setState(() {
              _cartBadgeCount = CartService.getTotalCount(items);
            });
          }
        },
      );
    }

    if (columns == 1) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: handleProductTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        child: _buildProductImageWidget(img, emojiSize: 34),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$qty Qty',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: handleProductTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      btnText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isCompact = columns == 3;

    return InkWell(
      onTap: handleProductTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Box with Stock Badge
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: _buildProductImageWidget(img, emojiSize: isCompact ? 28 : 40),
                    ),
                  ),
                  // Stock Qty Badge
                  Positioned(
                    top: isCompact ? 4 : 8,
                    right: isCompact ? 4 : 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 7, vertical: isCompact ? 1.5 : 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$qty Qty',
                        style: TextStyle(color: Colors.white, fontSize: isCompact ? 8.5 : 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Info Section
            Padding(
              padding: EdgeInsets.all(isCompact ? 6.0 : 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 11 : 13,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: isCompact ? 1 : 2),
                  Text(
                    '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 9.5 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: isCompact ? 4 : 6),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: isCompact ? 5 : 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(isCompact ? 7 : 9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      btnText,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 9.5 : 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreProductsGrid() {
    final filtered = _filteredProducts;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: const [
              Text('📦', style: TextStyle(fontSize: 48)),
              SizedBox(height: 12),
              Text(
                'No Products Found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              SizedBox(height: 4),
              Text(
                'This store currently has no items matching your filter.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // If specific Category filter is selected, render single grid for that category
    if (_selectedCategory != 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${filtered.length} Items Available',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, idx) => _buildProductCard(filtered[idx]),
          ),
        ],
      );
    }

    // Default 'All' Home Page View: Render Strictly By Seller Sections! NO DEFAULT "Store Products" HEADER!
    final List<Widget> sectionWidgets = [];
    final Set<dynamic> displayedProdIds = {};

    // 1. Build a unified list of unique Section descriptors from Seller Sections, Categories, or Product tags
    final List<Map<String, String>> effectiveSections = [];
    final Set<String> addedSecNames = {};

    // Add explicitly created seller_sections
    for (var sec in _sellerSections) {
      final sName = (sec['name'] ?? '').toString().trim();
      final sIcon = (sec['icon'] ?? '🏷️').toString().trim();
      final sBg = (sec['bg_color'] ?? '#FFFFFF').toString().trim();
      final sText = (sec['text_color'] ?? '').toString().trim();
      final sCols = (sec['columns'] ?? 2).toString().trim();
      if (sName.isNotEmpty && !addedSecNames.contains(sName.toLowerCase())) {
        addedSecNames.add(sName.toLowerCase());
        effectiveSections.add({
          'name': sName,
          'icon': sIcon.isNotEmpty ? sIcon : '🏷️',
          'bg_color': sBg.isNotEmpty ? sBg : '#FFFFFF',
          'text_color': sText.isNotEmpty ? sText : '#0F172A',
          'columns': sCols.isNotEmpty ? sCols : '2',
        });
      }
    }

    // Add seller_categories as sections
    for (var cat in _rawCategories) {
      final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
      final cIcon = (cat['image'] ?? cat['image_url'] ?? '📁').toString().trim();
      final cBg = (cat['color'] ?? '#FFFFFF').toString().trim();
      if (cName.isNotEmpty && !addedSecNames.contains(cName.toLowerCase())) {
        addedSecNames.add(cName.toLowerCase());
        effectiveSections.add({
          'name': cName,
          'icon': (cIcon.length <= 4 && cIcon.isNotEmpty) ? cIcon : '📁',
          'bg_color': cBg.isNotEmpty ? cBg : '#FFFFFF',
          'text_color': '#0F172A',
          'columns': '2',
        });
      }
    }

    // Add any section/category tags present on products that aren't in the list yet
    for (var p in filtered) {
      final pSec = (p['section'] ?? '').toString().trim();
      final pCat = (p['category'] ?? '').toString().trim();
      final tag = pSec.isNotEmpty ? pSec : pCat;
      if (tag.isNotEmpty && !addedSecNames.contains(tag.toLowerCase())) {
        addedSecNames.add(tag.toLowerCase());
        effectiveSections.add({'name': tag, 'icon': '🏷️', 'bg_color': '#FFFFFF', 'text_color': '#0F172A', 'columns': '2'});
      }
    }

    // If no section created yet, but products exist, create a default fallback section name using first available category or 'Items'
    if (effectiveSections.isEmpty && filtered.isNotEmpty) {
      effectiveSections.add({'name': 'Items', 'icon': '🏷️', 'bg_color': '#FFFFFF', 'text_color': '#0F172A', 'columns': '2'});
    }

    // 2. Render each section with its matching products
    for (int i = 0; i < effectiveSections.length; i++) {
      final sec = effectiveSections[i];
      final secName = sec['name']!;
      final secIcon = sec['icon']!;

      final isLastSection = (i == effectiveSections.length - 1);

      final matchingProducts = filtered.where((p) {
        if (displayedProdIds.contains(p['id'])) return false;
        final pSec = (p['section'] ?? '').toString().trim();
        final pCat = (p['category'] ?? '').toString().trim();

        bool isMatch = pSec.toLowerCase() == secName.toLowerCase() || pCat.toLowerCase() == secName.toLowerCase();
        // If last section, also include any remaining unassigned products into it so NO product is hidden and NO extra Store Products block is created!
        if (!isMatch && isLastSection && pSec.isEmpty && pCat.isEmpty) {
          isMatch = true;
        }
        return isMatch;
      }).toList();

      // Skip empty sections
      if (matchingProducts.isEmpty) {
        continue;
      }

      for (var p in matchingProducts) {
        displayedProdIds.add(p['id']);
      }

      // Find sliders assigned to this specific section
      final sectionSliders = _sliders.where((s) {
        final sSec = (s['section'] ?? '').toString().trim();
        return sSec.toLowerCase() == secName.toLowerCase();
      }).toList();

      final externalSliders = sectionSliders.where((s) {
        final pos = (s['position'] ?? 'internal').toString().trim().toLowerCase();
        return pos == 'external';
      }).toList();

      final internalSliders = sectionSliders.where((s) {
        final pos = (s['position'] ?? 'internal').toString().trim().toLowerCase();
        return pos != 'external';
      }).toList();

      // Find custom background color, text color & columns layout assigned to this section
      String secBgHex = (sec['bg_color'] ?? '#FFFFFF').toString().trim();
      String secTextHex = (sec['text_color'] ?? '').toString().trim();
      int secCols = int.tryParse((sec['columns'] ?? '2').toString()) ?? 2;

      final secMatch = _sellerSections.firstWhere(
        (s) => (s['name'] ?? '').toString().trim().toLowerCase() == secName.toLowerCase(),
        orElse: () => {},
      );

      if (secMatch.isNotEmpty) {
        if (secBgHex.isEmpty || secBgHex == '#FFFFFF') {
          if (secMatch['bg_color'] != null) secBgHex = secMatch['bg_color'].toString().trim();
        }
        if (secTextHex.isEmpty || secTextHex == '#0F172A') {
          if (secMatch['text_color'] != null) secTextHex = secMatch['text_color'].toString().trim();
        }
        if (secMatch['columns'] != null) {
          secCols = int.tryParse(secMatch['columns'].toString()) ?? secCols;
        }
      }

      if (secCols != 1 && secCols != 2 && secCols != 3) {
        secCols = 2;
      }

      final secBgColor = hexToColor(secBgHex.isEmpty ? '#FFFFFF' : secBgHex);
      Color secTextColor;
      if (secTextHex.isNotEmpty && secTextHex != '#0F172A') {
        secTextColor = hexToColor(secTextHex);
      } else {
        // Smart fallback: if background is dark, use White text for high contrast readability!
        secTextColor = secBgColor.computeLuminance() < 0.5 ? Colors.white : const Color(0xFF0F172A);
      }

      // Render External Sliders ABOVE / OUTSIDE the section box
      if (externalSliders.isNotEmpty) {
        sectionWidgets.add(_buildSectionSliderBanner(externalSliders));
      }

      sectionWidgets.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: secBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: secBgColor.computeLuminance() > 0.85 ? const Color(0xFFCBD5E1) : secBgColor.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (secIcon.isNotEmpty && secIcon != '🏷️') ...[
                          Text(secIcon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          secName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: secTextColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${matchingProducts.length} Items',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),

              // Render Internal Sliders INSIDE the Section Container!
              if (internalSliders.isNotEmpty)
                _buildSectionSliderBanner(internalSliders),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: secCols == 3 ? 8 : 16, vertical: 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: secCols,
                  childAspectRatio: secCols == 1 ? 2.8 : (secCols == 3 ? 0.68 : 0.72),
                  crossAxisSpacing: secCols == 3 ? 8 : 12,
                  mainAxisSpacing: secCols == 3 ? 8 : (secCols == 1 ? 8 : 12),
                ),
                itemCount: matchingProducts.length,
                itemBuilder: (ctx, idx) => _buildProductCard(matchingProducts[idx], columns: secCols),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
    }

    return Column(
      children: sectionWidgets,
    );
  }

  Widget _buildSectionSliderBanner(List<Map<String, dynamic>> slidersList) {
    if (slidersList.isEmpty) return const SizedBox.shrink();
    final String keyStr = slidersList.map((s) => '${s['id']}_${s['position']}').join('_');
    return SectionSliderBannerWidget(
      key: ValueKey(keyStr),
      slidersList: slidersList,
    );
  }

  /// Seller Search Bar Customization & Transparency Dialog
  void _showManageSearchBarDialog() {
    String bgColor = (_headerThemeConfig['search_bg_color'] ?? '#FFFFFF').toString();
    double opacity = ((_headerThemeConfig['search_opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    String textColor = (_headerThemeConfig['search_text_color'] ?? '#0F172A').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final Color previewColor = HeaderThemeHelper.hexToColor(bgColor).withValues(alpha: opacity);
          final Color previewTextColor = HeaderThemeHelper.hexToColor(textColor);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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

                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Manage Search Bar Style 🔍',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real-time Header Preview Box
                  const Text('Live Header Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF312E81)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: previewTextColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Search products in store...',
                            style: TextStyle(color: previewTextColor.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Background Color Selection
                  const Text('Search Bar Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#FFFFFF', '#F1F5F9', '#0F172A', '#8B5CF6', '#10B981', '#3B82F6', '#F97316', '#FEF3C7', '#ECFDF5', '#FEE2E2'
                      ].map((hex) {
                        final isSel = bgColor.toLowerCase() == hex.toLowerCase();
                        final c = HeaderThemeHelper.hexToColor(hex);
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              bgColor = hex;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 2.8 : 1),
                              boxShadow: isSel ? [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 6)] : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Transparency Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Transparency / Opacity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(opacity * 100).toInt()}% ${opacity == 1.0 ? '(Solid)' : opacity == 0.0 ? '(Transparent)' : '(Glass)'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: opacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: const Color(0xFF8B5CF6),
                    inactiveColor: const Color(0xFFE2E8F0),
                    onChanged: (val) {
                      setModalState(() {
                        opacity = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Text & Icon Color
                  const Text('Search Text & Icon Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      '#0F172A', '#FFFFFF', '#8B5CF6', '#2563EB', '#10B981'
                    ].map((hex) {
                      final isSel = textColor.toLowerCase() == hex.toLowerCase();
                      final c = HeaderThemeHelper.hexToColor(hex);
                      return InkWell(
                        onTap: () => setModalState(() => textColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                          ),
                          child: isSel ? const Icon(Icons.check, size: 16, color: Colors.amber) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updatedConfig = Map<String, dynamic>.from(_headerThemeConfig);
                      updatedConfig['search_bg_color'] = bgColor;
                      updatedConfig['search_opacity'] = opacity;
                      updatedConfig['search_text_color'] = textColor;

                      setState(() {
                        _headerThemeConfig = updatedConfig;
                      });

                      await AuthService.saveHeaderThemeConfig(updatedConfig);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Save Search Bar Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircularCategorySection() {
    final List<Map<String, dynamic>> allCatItems = List.from(_rawCategories);
    if (allCatItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allCatItems.length,
            itemBuilder: (ctx, idx) {
              final cat = allCatItems[idx];
              final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
              final cImg = (cat['image'] ?? cat['image_url'] ?? '').toString().trim();
              final isSel = _selectedCategory.toLowerCase() == cName.toLowerCase();

              final String rawColor = (cat['color'] ?? '#8B5CF6').toString().trim();
              Color catColor = const Color(0xFF8B5CF6);
              if (rawColor.isNotEmpty) {
                String hex = rawColor.replaceAll('#', '');
                if (hex.length == 6) hex = 'FF$hex';
                final val = int.tryParse(hex, radix: 16);
                if (val != null) catColor = Color(val);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedCategory.toLowerCase() == cName.toLowerCase()) {
                      _selectedCategory = 'All';
                    } else {
                      _selectedCategory = cName;
                    }
                  });
                },
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      // Round Avatar Circle Container with Database Color Rotating Ring Animation
                      RotatingCategoryAvatarRingWidget(
                        isSelected: isSel,
                        ringColor: catColor,
                        child: _buildCategoryImageWidget(cImg, emojiSize: 26),
                      ),
                      const SizedBox(height: 6),
                      // Category Name Text Below Round Circle
                      Text(
                        cName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? catColor : const Color(0xFF334155),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryImageWidget(String rawImg, {double emojiSize = 26}) {
    final img = rawImg.trim();
    if (img.isEmpty || img == '🏷️') {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
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
          errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
        );
      } catch (_) {}
    }

    if (img.length <= 4 && img.isNotEmpty) {
      return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
    }

    return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
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

/// Animated Continuous Rotating Gradient Ring Widget for Category Avatars
class RotatingCategoryAvatarRingWidget extends StatefulWidget {
  final bool isSelected;
  final Color ringColor;
  final Widget child;

  const RotatingCategoryAvatarRingWidget({
    super.key,
    required this.isSelected,
    required this.ringColor,
    required this.child,
  });

  @override
  State<RotatingCategoryAvatarRingWidget> createState() => _RotatingCategoryAvatarRingWidgetState();
}

class _RotatingCategoryAvatarRingWidgetState extends State<RotatingCategoryAvatarRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
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
    final baseColor = widget.ringColor;
    final lightColor = Color.alphaBlend(Colors.white.withOpacity(0.5), baseColor);
    final darkColor = Color.alphaBlend(Colors.black.withOpacity(0.25), baseColor);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;

        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1.5,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.15),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Spinning Metallic Gradient Ring Background using Category's exact Saved Database Color!
              Transform.rotate(
                angle: angle,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isSelected
                        ? SweepGradient(
                            colors: [
                              baseColor,
                              lightColor,
                              darkColor,
                              baseColor,
                              lightColor,
                              baseColor,
                            ],
                          )
                        : SweepGradient(
                            colors: [
                              baseColor.withValues(alpha: 0.8),
                              lightColor.withValues(alpha: 0.4),
                              baseColor.withValues(alpha: 0.8),
                              lightColor.withValues(alpha: 0.4),
                            ],
                          ),
                  ),
                ),
              ),

              // Inner Solid Circle Mask so ring forms a sleek 3px rotating border
              Container(
                width: widget.isSelected ? 52.0 : 53.5,
                height: widget.isSelected ? 52.0 : 53.5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: widget.child,
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

/// Dedicated Stateful Section Slider Banner Widget for 100% Rock Solid Smooth Auto-scroll with Zero Blinking
class SectionSliderBannerWidget extends StatefulWidget {
  final List<Map<String, dynamic>> slidersList;
  const SectionSliderBannerWidget({super.key, required this.slidersList});

  @override
  State<SectionSliderBannerWidget> createState() => _SectionSliderBannerWidgetState();
}

class _SectionSliderBannerWidgetState extends State<SectionSliderBannerWidget> {
  late PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.slidersList.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted || !_controller.hasClients) return;
      int next = (_currentPage + 1) % widget.slidersList.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant SectionSliderBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slidersList.length != widget.slidersList.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slidersList.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: SizedBox(
        height: 120,
        child: PageView.builder(
          controller: _controller,
          onPageChanged: (idx) {
            _currentPage = idx;
          },
          itemCount: widget.slidersList.length,
          itemBuilder: (ctx, sIdx) {
            final item = widget.slidersList[sIdx];
            final tag = (item['tag'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            final desc = (item['description'] ?? '').toString().trim();
            final bg = (item['bg_image_url'] ?? item['bg'] ?? 'preset_1').toString();
            final tagBg = SellerSlidersScreen.hexToColor(item['tag_bg_color']?.toString() ?? '#10B981');
            final tagShape = item['tag_shape']?.toString() ?? 'pill';
            final titleCol = SellerSlidersScreen.hexToColor(item['title_color']?.toString() ?? '#FFFFFF');
            final descCol = SellerSlidersScreen.hexToColor(item['desc_color']?.toString() ?? '#E2E8F0');
            final overlayDim = (item['overlay_dim'] as num?)?.toDouble() ?? 0.0;
            final removeWhiteBg = (item['remove_white_bg'] == true || item['remove_white_bg'] == 1);
            final imgFit = item['img_fit']?.toString() ?? 'cover';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SellerSlidersScreen.buildBannerBackground(
                  bg: bg,
                  overlayDim: overlayDim,
                  removeWhiteBg: removeWhiteBg,
                  imgFit: imgFit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tag.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: SellerSlidersScreen.buildTagDecoration(tagShape, tagBg),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tagBg.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleCol),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (desc.isNotEmpty)
                          Text(
                            desc,
                            style: TextStyle(fontSize: 11, color: descCol),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dedicated Stateful Top Banner Slider Widget for 100% Smooth Auto-scroll with Zero Blinking & Isolated State
class TopBannerSliderWidget extends StatefulWidget {
  final List<Map<String, dynamic>> sliders;
  const TopBannerSliderWidget({super.key, required this.sliders});

  @override
  State<TopBannerSliderWidget> createState() => _TopBannerSliderWidgetState();
}

class _TopBannerSliderWidgetState extends State<TopBannerSliderWidget> {
  late PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.sliders.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3, milliseconds: 500), (t) {
      if (!mounted || !_controller.hasClients) return;
      int next = (_currentPage + 1) % widget.sliders.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(covariant TopBannerSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sliders.length != widget.sliders.length) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sliders.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
            },
            itemCount: widget.sliders.length,
            itemBuilder: (ctx, idx) {
              final item = widget.sliders[idx];
              final tag = (item['tag'] ?? item['tagText'] ?? '').toString().trim();
              final title = (item['title'] ?? item['titleText'] ?? '').toString().trim();
              final desc = (item['description'] ?? item['subtitle'] ?? item['descText'] ?? '').toString().trim();
              final bg = (item['bg'] ?? item['bg_image_url'] ?? item['bgImageUrl'] ?? item['image'] ?? item['imageUrl'] ?? 'transparent').toString();
              final tagBg = SellerSlidersScreen.hexToColor(item['tag_bg_color']?.toString() ?? '#10B981');
              final tagShape = item['tag_shape']?.toString() ?? 'pill';
              final titleCol = SellerSlidersScreen.hexToColor(item['title_color']?.toString() ?? '#FFFFFF');
              final descCol = SellerSlidersScreen.hexToColor(item['desc_color']?.toString() ?? '#E2E8F0');
              final overlayDim = (item['overlay_dim'] as num?)?.toDouble() ?? 0.0;
              final removeWhiteBg = (item['remove_white_bg'] == true || item['remove_white_bg'] == 1);
              final imgFit = item['img_fit']?.toString() ?? 'cover';

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
                            decoration: SellerSlidersScreen.buildTagDecoration(tagShape, tagBg),
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
              );
            },
          ),
        ),
        if (widget.sliders.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.sliders.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _currentPage == index ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
