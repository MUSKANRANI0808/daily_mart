import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../utils/header_theme_helper.dart';
import '../../utils/category_icon_helper.dart';
import '../../utils/app_toast.dart';
import '../../widgets/product_detail_bottom_sheet.dart';
import '../dashboards/customer_dashboard.dart';
import '../role_selection_screen.dart';
import '../seller/seller_order_cart_screen.dart';
import '../seller/seller_sliders_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_main_nav_screen.dart';
import 'customer_addresses_screen.dart';
import 'category_products_screen.dart';
import 'package:url_launcher/url_launcher.dart';

double safeDouble(dynamic val, [double defaultValue = 0.0]) {
  if (val == null) return defaultValue;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? defaultValue;
}

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
  final bool isSellerView;

  const CustomerSellerOrdersScreen({
    super.key,
    required this.customer,
    required this.sellerUsername,
    required this.sellerName,
    required this.sellerMobile,
    this.hideBottomNav = false,
    this.isSellerView = false,
  });

  @override
  State<CustomerSellerOrdersScreen> createState() => _CustomerSellerOrdersScreenState();
}

class _CustomerSellerOrdersScreenState extends State<CustomerSellerOrdersScreen> with TickerProviderStateMixin {
  late AnimationController _refreshSpinController;
  bool _isManualRefreshing = false;
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
  String _priceSortOrder = 'none'; // 'none', 'low_to_high', 'high_to_low'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _cartBadgeCount = 0;
  double _cartTotalAmount = 0.0;
  String _sellerLocation = '';
  final PageController _sliderController = PageController();
  bool _hasCheckedWelcomePopup = false;
  String _customerAddressDisplay = '';
  String _sellerHeaderText1 = '';
  String _sellerHeaderText2 = '';
  String _festivalAnimation = '';
  String _festivalAnimationBgColor = '';
  List<Map<String, dynamic>> _categorySections = [];
  List<Map<String, dynamic>> _homeLayoutOrder = [];
  Map<String, dynamic> _actionButtonsConfig = {};

  Future<void> _loadSellerFestivalAnimation() async {
    try {
      final conf = await AuthService.getSellerFestivalAnimationConfig(widget.sellerUsername);
      if (mounted) {
        setState(() {
          _festivalAnimation = (conf['animation'] ?? '').trim();
          _festivalAnimationBgColor = (conf['bg_color'] ?? '').trim();
        });
      }
    } catch (_) {}
  }

  String _getGreeting() {
    final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final hour = istNow.hour;
    if (hour >= 4 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _loadCustomerAddress() async {
    try {
      final addresses = await AuthService.getCustomerAddresses(widget.customer.mobile ?? '');
      if (addresses.isNotEmpty) {
        Map<String, dynamic>? selected;
        for (var a in addresses) {
          if (a['isDefault'] == true) {
            selected = a;
            break;
          }
        }
        selected ??= addresses.first;

        final area = (selected['locality'] ?? selected['area'] ?? '').toString().trim();
        final landmark = (selected['landmark'] ?? '').toString().trim();
        final city = (selected['city'] ?? '').toString().trim();

        final parts = <String>[];
        if (area.isNotEmpty) parts.add(area);
        if (landmark.isNotEmpty) parts.add(landmark);
        if (city.isNotEmpty) parts.add(city);

        if (mounted) {
          setState(() {
            _customerAddressDisplay = parts.isNotEmpty ? parts.join(', ') : 'Select Delivery Address';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _customerAddressDisplay = 'Add Delivery Address';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSellerHeaderTexts() async {
    try {
      final texts = await AuthService.getSellerHeaderText(widget.sellerUsername);
      if (mounted) {
        setState(() {
          _sellerHeaderText1 = texts['text1'] ?? '';
          _sellerHeaderText2 = texts['text2'] ?? '';
        });
      }
    } catch (_) {}
  }

  void _openCustomerAddressSelection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerAddressesScreen(customer: widget.customer),
      ),
    );
    _loadCustomerAddress();
  }

  @override
  void initState() {
    super.initState();
    _refreshSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ordersScrollController.addListener(_handleScrollForBackToTop);
    _festivalAnimation = AuthService.getCachedSellerFestivalAnimation(widget.sellerUsername) ?? '';
    _festivalAnimationBgColor = AuthService.getCachedSellerFestivalBgColor(widget.sellerUsername) ?? '';
    _homeLayoutOrder = AuthService.getCachedSellerHomeLayout(widget.sellerUsername) ?? [];
    _actionButtonsConfig = AuthService.getCachedSellerActionButtons(widget.sellerUsername) ?? {};
    AuthService.saveLastSelectedSeller(
      username: widget.sellerUsername,
      name: widget.sellerName,
      mobile: widget.sellerMobile,
    );
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndShowWelcomePopup();
      }
    });
  }

  Future<void> _checkAndShowWelcomePopup() async {
    if (widget.isSellerView) return;
    if (_hasCheckedWelcomePopup) return;
    _hasCheckedWelcomePopup = true;

    final customerMobile = (widget.customer.mobile ?? '').trim();
    final sellerUsername = widget.sellerUsername.trim();
    if (sellerUsername.isEmpty) return;

    try {
      // 1. Fast check if customer has ANY delivered order (0ms latency - local check)
      final hasDelivered = await AuthService.checkCustomerHasDeliveredOrder(customerMobile, checkServer: false);
      if (hasDelivered) {
        return;
      }

      // 2. Get seller's welcome popup image (checks 0ms memory & SharedPreferences cache first)
      final popupImage = await AuthService.getSellerWelcomePopupImage(sellerUsername);
      if (popupImage == null || popupImage.trim().isEmpty) {
        return;
      }

      // 3. Customer has no delivered order yet -> Show Bouncing Welcome Popup Dialog instantly on entry!
      if (!mounted) return;
      _showBouncingWelcomePopup(popupImage);
    } catch (e) {
      debugPrint('Error in _checkAndShowWelcomePopup: $e');
    }
  }

  void _showBouncingWelcomePopup(String popupImage) {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'WelcomePopup',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final bounceCurve = CurvedAnimation(
          parent: anim1,
          curve: Curves.elasticOut,
        );

        return ScaleTransition(
          scale: bounceCurve,
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topRight,
                children: [
                  // Main Card with Image
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.76,
                      maxWidth: MediaQuery.of(context).size.width * 0.92,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 30,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: _buildWelcomePopupImage(popupImage),
                    ),
                  ),

                  // Circular Close Cross Button on Top Right
                  Positioned(
                    top: -14,
                    right: -14,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomePopupImage(String popupImage) {
    if (popupImage.startsWith('http://') || popupImage.startsWith('https://')) {
      return Image.network(
        popupImage,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 250,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 200,
          child: Center(child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey)),
        ),
      );
    } else {
      try {
        String cleanBase = popupImage;
        if (cleanBase.contains(',')) {
          cleanBase = cleanBase.split(',').last.trim();
        }
        final bytes = base64Decode(cleanBase);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox(
            height: 200,
            child: Center(child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey)),
          ),
        );
      } catch (_) {
        return const SizedBox(
          height: 200,
          child: Center(child: Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey)),
        );
      }
    }
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
    // Disabled on home screen to eliminate periodic frame drops/lag during scrolling.
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
  final ValueNotifier<bool> _showBackToTopNotifier = ValueNotifier<bool>(false);
  double _lastScrollOffset = 0.0;
  Timer? _sliderTimer;
  Timer? _searchHintTimer;
  List<String> _searchHints = [];
  final ValueNotifier<int> _searchHintIndexNotifier = ValueNotifier<int>(0);

  void _handleScrollForBackToTop() {
    if (!_ordersScrollController.hasClients) return;
    final double currentOffset = _ordersScrollController.offset;
    final double delta = currentOffset - _lastScrollOffset;

    // Threshold: when close to top (<= 180), always hide
    if (currentOffset <= 180) {
      if (_showBackToTopNotifier.value) {
        _showBackToTopNotifier.value = false;
      }
    } else if (delta < -6) {
      // User is scrolling UP
      if (!_showBackToTopNotifier.value) {
        _showBackToTopNotifier.value = true;
      }
    } else if (delta > 6) {
      // User is scrolling DOWN
      if (_showBackToTopNotifier.value) {
        _showBackToTopNotifier.value = false;
      }
    }

    _lastScrollOffset = currentOffset;
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    if (_showBackToTopNotifier.value) {
      _showBackToTopNotifier.value = false;
    }
    if (_ordersScrollController.hasClients) {
      _ordersScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildBackToTopButton() {
    final String bgHex = (_actionButtonsConfig['back_to_top_bg'] ?? '#1E293B').toString();
    final double opacity = safeDouble(_actionButtonsConfig['back_to_top_opacity'], 1.0).clamp(0.05, 1.0);
    final rawBg = hexToColor(bgHex);
    final bgColor = rawBg.withValues(alpha: opacity);
    final labelText = (_actionButtonsConfig['back_to_top_text'] ?? 'Back to top').toString().trim();
    final textName = labelText.isNotEmpty ? labelText : 'Back to top';
    final fontSize = safeDouble(_actionButtonsConfig['back_to_top_size'], 12.5).clamp(9.0, 24.0);
    final textColorHex = (_actionButtonsConfig['back_to_top_text_color'] ?? '#FFFFFF').toString();
    final textColor = hexToColor(textColorHex);

    final double horizontalPadding = (fontSize * 1.1).clamp(10.0, 22.0);
    final double verticalPadding = (fontSize * 0.55).clamp(5.0, 14.0);
    final double iconContainerSize = (fontSize * 1.4).clamp(14.0, 28.0);
    final double iconSize = (fontSize * 0.95).clamp(10.0, 20.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _scrollToTop,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: textColor.withValues(alpha: (0.16 + 0.25 * (1.0 - opacity)).clamp(0.12, 0.45)),
              width: 0.8,
            ),
            boxShadow: opacity > 0.2
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: (0.22 * opacity * opacity).clamp(0.0, 0.22)),
                      blurRadius: (8 * opacity).toDouble(),
                      offset: Offset(0, (3 * opacity).toDouble()),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: textColor, width: 1.3),
                ),
                child: Center(
                  child: Icon(Icons.arrow_upward_rounded, size: iconSize, color: textColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                textName,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshSpinController.dispose();
    _ordersPoller?.cancel();
    _sliderTimer?.cancel();
    _searchHintTimer?.cancel();
    _searchHintIndexNotifier.dispose();
    _showBackToTopNotifier.dispose();
    _sliderController.dispose();
    _ordersScrollController.removeListener(_handleScrollForBackToTop);
    _ordersScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initSearchHints() async {
    final cached = AuthService.getCachedSellerSearchHints(widget.sellerUsername);
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _searchHints = List<String>.from(cached);
      });
      _searchHintIndexNotifier.value = 0;
      _startSearchHintTimer();
    }
    try {
      final hints = await AuthService.getSellerSearchHints(widget.sellerUsername);
      if (mounted && hints.isNotEmpty) {
        setState(() {
          _searchHints = hints;
        });
        _searchHintIndexNotifier.value = 0;
        _startSearchHintTimer();
      }
    } catch (_) {}
  }

  void _startSearchHintTimer() {
    _searchHintTimer?.cancel();
    if (_searchHints.length <= 1) return;

    _searchHintTimer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_searchHints.isNotEmpty) {
        _searchHintIndexNotifier.value = (_searchHintIndexNotifier.value + 1) % _searchHints.length;
      }
    });
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
  final Set<String> _expandedSectionNames = {};

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

  Future<void> _handleManualRefresh() async {
    if (_isManualRefreshing) return;
    setState(() {
      _isManualRefreshing = true;
    });
    _refreshSpinController.repeat();
    try {
      await _loadData(isPullToRefresh: true);
    } finally {
      if (mounted) {
        _refreshSpinController.stop();
        _refreshSpinController.reset();
        setState(() {
          _isManualRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadData({bool isPullToRefresh = false}) async {
    _checkBlockedBySeller();
    _loadCustomerAddress();
    _loadSellerHeaderTexts();
    _loadSellerFestivalAnimation();
    _initSearchHints();

    final startTime = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLoc = prefs.getString('cached_seller_loc_${widget.sellerUsername}');
      if (cachedLoc != null && cachedLoc.isNotEmpty) {
        _sellerLocation = cachedLoc;
      }

      final cachedButtons = AuthService.getCachedSellerActionButtons(widget.sellerUsername);
      if (cachedButtons != null && cachedButtons.isNotEmpty) {
        _actionButtonsConfig = cachedButtons;
      }

      final headerTheme = await AuthService.getHeaderThemeConfig();
      final sellerStyle = await AuthService.getSellerSearchBarStyle(widget.sellerUsername);
      _headerThemeConfig = Map<String, dynamic>.from(headerTheme);
      if (sellerStyle.isNotEmpty) {
        if (sellerStyle['search_bg_color'] != null) _headerThemeConfig['search_bg_color'] = sellerStyle['search_bg_color'];
        if (sellerStyle['search_opacity'] != null) _headerThemeConfig['search_opacity'] = sellerStyle['search_opacity'];
        if (sellerStyle['search_text_color'] != null) _headerThemeConfig['search_text_color'] = sellerStyle['search_text_color'];
      }

      // Concurrently fetch Store Products, Categories, Cart, Sections, Sliders, Messages, and Action Buttons
      final actionButtonsFuture = AuthService.getSellerActionButtons(widget.sellerUsername);
      final results = await Future.wait([
        AuthService.getSellerProducts(widget.sellerUsername),
        AuthService.getSellerCategories(widget.sellerUsername),
        CartService.getCartItems(widget.sellerUsername),
        AuthService.getSellerSections(widget.sellerUsername),
        AuthService.getSellerCategorySections(widget.sellerUsername),
        AuthService.getSellerHomeLayout(widget.sellerUsername),
        AuthService.getSellerSliders(widget.sellerUsername),
        AuthService.getMessages(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
        ),
      ]);

      final prods = results[0];
      final rawCats = results[1];
      final cartItems = results[2];
      final sections = results[3];
      final catSections = results[4];
      final homeLayout = results[5];
      final sliders = results[6];
      final msgs = results[7];
      final actionButtons = await actionButtonsFuture;

      // Annotate messages with hierarchy
      try {
        await AuthService.annotateMessagesWithLifetimeHierarchy(
          sellerUsername: widget.sellerUsername,
          customerMobile: widget.customer.mobile ?? '',
          messages: msgs,
        );
      } catch (_) {}

      // Check draft
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

      final List<Map<String, dynamic>> parsedRawCats = [];
      final List<String> parsedCats = [];
      for (var c in rawCats) {
        parsedRawCats.add(Map<String, dynamic>.from(c));
        final name = (c['name'] ?? c['category_name'] ?? '').toString().trim();
        if (name.isNotEmpty && !parsedCats.contains(name)) parsedCats.add(name);
      }

      final cartCount = CartService.getTotalCount(cartItems);
      final cartTotalAmount = CartService.getTotalAmount(cartItems);

      // Fetch Store Location
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
              _sellerLocation = loc;
            }
            break;
          }
        }
      } catch (_) {}

      // Keep skeleton effect visible for ~1.3 - 1.5 seconds on initial open
      if (!isPullToRefresh) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        const minSkeletonMs = 1300;
        if (elapsed < minSkeletonMs) {
          await Future.delayed(Duration(milliseconds: minSkeletonMs - elapsed));
        }
      }

      if (mounted) {
        setState(() {
          _products = prods;
          _rawCategories = parsedRawCats;
          _categories = parsedCats;
          _sellerSections = sections;
          _categorySections = catSections;
          _homeLayoutOrder = homeLayout;
          _cartBadgeCount = cartCount;
          _cartTotalAmount = cartTotalAmount;
          _messages = msgs;
          _sliders = sliders;
          _hasDraft = hasDraft;
          _draftSnippet = draftSnippet;
          if (actionButtons.isNotEmpty) {
            _actionButtonsConfig = actionButtons;
          }
          _isLoading = false;
        });
        _startAutoSlider();
      }
    } catch (e) {
      debugPrint('Error loading seller orders data: $e');
      // Fallback to cache if network fails
      try {
        final cachedProds = await AuthService.getCachedSellerProducts(widget.sellerUsername);
        final cachedCats = await AuthService.getCachedSellerCategories(widget.sellerUsername);
        final cachedSecs = await AuthService.getCachedSellerSections(widget.sellerUsername);
        final cachedLayout = AuthService.getCachedSellerHomeLayout(widget.sellerUsername);
        final initialCartItems = await CartService.getCartItems(widget.sellerUsername);
        final cachedButtons = AuthService.getCachedSellerActionButtons(widget.sellerUsername);
        final List<Map<String, dynamic>> parsedRawCats = [];
        final List<String> parsedCats = [];
        for (var c in cachedCats) {
          parsedRawCats.add(Map<String, dynamic>.from(c));
          final name = (c['name'] ?? c['category_name'] ?? '').toString().trim();
          if (name.isNotEmpty && !parsedCats.contains(name)) parsedCats.add(name);
        }
        if (mounted) {
          setState(() {
            _products = cachedProds;
            _rawCategories = parsedRawCats;
            _categories = parsedCats;
            _sellerSections = cachedSecs;
            if (cachedLayout != null && cachedLayout.isNotEmpty) {
              _homeLayoutOrder = cachedLayout;
            }
            if (cachedButtons != null && cachedButtons.isNotEmpty) {
              _actionButtonsConfig = cachedButtons;
            }
            _cartBadgeCount = CartService.getTotalCount(initialCartItems);
            _cartTotalAmount = CartService.getTotalAmount(initialCartItems);
            _isLoading = false;
          });
        }
      } catch (_) {}
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshCartState() async {
    try {
      final items = await CartService.getCartItems(widget.sellerUsername);
      if (mounted) {
        setState(() {
          _cartBadgeCount = CartService.getTotalCount(items);
          _cartTotalAmount = CartService.getTotalAmount(items);
        });
      }
    } catch (_) {}
  }

  Future<void> _openCategoryPage(String cName, Map<String, dynamic> cat) async {
    final catColor = (cat['color'] ?? '').toString().trim();
    final catImg = (cat['image_url'] ?? cat['image'] ?? '').toString().trim();
    final catIcon = (cat['icon_url'] ?? '').toString().trim();
    final catPoster = (cat['poster_url'] ?? '').toString().trim();
    final catItemBg = (cat['item_bg_color'] ?? '').toString().trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          sellerUsername: widget.sellerUsername,
          sellerName: widget.sellerName,
          sellerMobile: widget.sellerMobile,
          categoryName: cName,
          categoryColor: catColor,
          categoryImage: catImg,
          categoryIcon: catIcon,
          categoryPoster: catPoster,
          categoryItemBgColor: catItemBg,
          allProducts: _products,
          categories: _rawCategories,
        ),
      ),
    );

    _refreshCartState();
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
          AppToast.show(context, 'Calling Seller: +91 $mobile');
        }
      }
    } else {
      if (mounted) {
        AppToast.show(context, 'Seller mobile number is not available');
      }
    }
  }

  Widget _buildFestivalAnimationSection() {
    if (_festivalAnimation.isEmpty) {
      return const SizedBox.shrink();
    }

    final Color bg = _festivalAnimationBgColor.isNotEmpty
        ? HeaderThemeHelper.hexToColor(_festivalAnimationBgColor)
        : HeaderThemeHelper.hexToColor(_headerThemeConfig['header_bg_color'] ?? '#B91C1C');

    return Container(
      width: double.infinity,
      height: 72,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: bg,
      ),
      alignment: Alignment.center,
      child: buildSingleLottieItem(_festivalAnimation, fit: BoxFit.contain),
    );
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
        AppToast.show(context, 'Seller "${widget.sellerName}" removed');
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

  bool get hasActiveFilter => _selectedCategory != 'All' || _searchQuery.isNotEmpty || _priceSortOrder != 'none';

  void clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
      _priceSortOrder = 'none';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideBottomNav) {
      return _buildMainScaffold(context);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (hasActiveFilter) {
          clearFilters();
          return;
        }

        final exit = await _showExitDialog();
        if (exit) {
          SystemNavigator.pop();
        }
      },
      child: _buildMainScaffold(context),
    );
  }

  Widget _buildMainScaffold(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomerHomeSkeletonView(topPadding: topPadding),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            RefreshIndicator(
              color: const Color(0xFFDC2626),
              backgroundColor: Colors.white,
              edgeOffset: topPadding,
              displacement: 40,
              onRefresh: () async {
                await _loadData(isPullToRefresh: true);
              },
              child: CustomScrollView(
                controller: _ordersScrollController,
                physics: const StoreFluidScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Pinned Sticky Header: Top info slides out, Search bar & Category icons stick to top!
                  SliverPersistentHeader(
                  pinned: true,
                  delegate: _StoreHeaderDelegate(
                    topPadding: topPadding,
                    topInfoWidget: _buildHeaderTopInfo(),
                    stickyBuilder: (ctx, collapseRatio) => _buildHeaderStickySection(collapseRatio: collapseRatio),
                    decoration: HeaderThemeHelper.buildDecoration(_headerThemeConfig),
                    stickyDecoration: HeaderThemeHelper.buildStickyDecoration(_headerThemeConfig),
                    backgroundParticles: GroceryFloatingBackgroundParticles(
                      particleOpacity: (_headerThemeConfig['particle_opacity'] as num?)?.toDouble() ?? 0.0,
                    ),
                    lottieCarousel: HeaderLottieCarouselWidget(
                      sellerUsername: widget.sellerUsername,
                      config: _headerThemeConfig,
                    ),
                    shiningBeam: _headerThemeConfig['enable_shining'] != false
                        ? const ContinuousShiningGlassBeamWidget()
                        : const SizedBox.shrink(),
                  ),
                ),

                // Scrollable Area: Festival Animation, Slider, Categories & Products Grid (Dynamic Hierarchy)
                SliverToBoxAdapter(
                  child: _buildDynamicHomeContent(),
                ),
              ],
            ),
          ),

          // Floating "Back to top" Pill Button (Zepto / Blinkit style)
          Positioned(
            top: topPadding + 118.0 + 8.0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showBackToTopNotifier,
              builder: (context, showBackToTop, child) {
                return AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  offset: showBackToTop ? Offset.zero : const Offset(0, -0.6),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    opacity: showBackToTop ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !showBackToTop,
                      child: _buildBackToTopButton(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),

      bottomNavigationBar: widget.hideBottomNav
          ? null
          : Builder(
              builder: (context) {
                final bottomInset = MediaQuery.of(context).padding.bottom;
                final badgeString = _cartTotalAmount > 0
                    ? (_cartTotalAmount >= 100000
                        ? '₹${(_cartTotalAmount / 100000).toStringAsFixed(1)}L'
                        : (_cartTotalAmount >= 10000
                            ? '₹${(_cartTotalAmount / 1000).toStringAsFixed(1)}k'
                            : '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(0)}'))
                    : null;

                return SizedBox(
                  height: 64 + bottomInset,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 1. Curved White Bottom Bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 60 + bottomInset,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, -4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                            border: const Border(
                              top: BorderSide(color: Color(0xFFFEE2E2), width: 1.2),
                            ),
                          ),
                        ),
                      ),

                      // 2. Nav Items (Home is selected with elevated red circle)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottomInset,
                        height: 64,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildSellerOrdersNavItem(
                              index: 0,
                              icon: Icons.home_rounded,
                              label: 'Home',
                            ),
                            _buildSellerOrdersNavItem(
                              index: 1,
                              icon: Icons.receipt_long_rounded,
                              label: 'My Order',
                              badgeText: badgeString,
                            ),
                            _buildSellerOrdersNavItem(
                              index: 2,
                              icon: Icons.person_rounded,
                              label: 'Profile',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSellerOrdersNavItem({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
  }) {
    final isSelected = index == 0; // Currently on Home screen

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (index == 0) return;
          if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (ctx) => CustomerMainNavScreen(
                  customer: widget.customer,
                  initialTab: 1,
                  initialSeller: {
                    'username': widget.sellerUsername,
                    'name': widget.sellerName,
                    'mobile': widget.sellerMobile,
                  },
                ),
              ),
              (route) => false,
            );
          } else if (index == 2) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (ctx) => CustomerMainNavScreen(
                  customer: widget.customer,
                  initialTab: 2,
                  initialSeller: {
                    'username': widget.sellerUsername,
                    'name': widget.sellerName,
                    'mobile': widget.sellerMobile,
                  },
                ),
              ),
              (route) => false,
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: isSelected
              ? OverflowBox(
                  key: ValueKey('active_$index'),
                  minHeight: 0,
                  maxHeight: 120,
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(0, -12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Floating Pink Aura Ring + Vibrant Red Gradient Circle
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFE4E6), // Soft Pink Aura Ring
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 23,
                                ),
                                if (badgeText != null)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : OverflowBox(
                  key: ValueKey('inactive_$index'),
                  minHeight: 0,
                  maxHeight: 120,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icon,
                            size: 23,
                            color: const Color(0xFF64748B),
                          ),
                          if (badgeText != null)
                            Positioned(
                              top: -6,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  double _parseProductRate(Map<String, dynamic> p) {
    final val = p['rate'] ?? p['price'] ?? 0;
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return double.tryParse(s) ?? 0.0;
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final list = _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || cat == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCat;
    }).toList();

    if (_priceSortOrder == 'low_to_high') {
      list.sort((a, b) => _parseProductRate(a).compareTo(_parseProductRate(b)));
    } else if (_priceSortOrder == 'high_to_low') {
      list.sort((a, b) => _parseProductRate(b).compareTo(_parseProductRate(a)));
    }

    return list;
  }

  static final Map<String, Uint8List> _base64Cache = {};

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
        cacheWidth: 350,
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
        final bytes = _base64Cache.putIfAbsent(base64Str, () => base64Decode(base64Str));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 350,
          errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
        );
      } catch (_) {}
    }

    if (img.length <= 4 && img.isNotEmpty) {
      return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
    }

    return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
  }

  Widget _buildProductCard(
    Map<String, dynamic> p, {
    int columns = 2,
    Color? nameColor,
    Color? rateColor,
    Color? imageBgColor,
  }) {
    final name = (p['name'] ?? '').toString();
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
        allProducts: _products,
        onCartUpdated: () async {
          final items = await CartService.getCartItems(widget.sellerUsername);
          if (mounted) {
            setState(() {
              _cartBadgeCount = CartService.getTotalCount(items);
              _cartTotalAmount = CartService.getTotalAmount(items);
            });
          }
        },
      );
    }

    if (columns == 1) {
      return InkWell(
        onTap: handleProductTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 90,
              child: AspectRatio(
                aspectRatio: 0.88,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: imageBgColor ?? const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildProductImageWidget(img, emojiSize: 34),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$qty Qty',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.22,
                      color: nameColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rateColor ?? const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: handleProductTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(
                  btnText,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isCompact = columns == 3;

    return InkWell(
      onTap: handleProductTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Image Box with Stock Badge (Slightly taller portrait shape)
          AspectRatio(
            aspectRatio: 0.88,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: imageBgColor ?? const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildProductImageWidget(img, emojiSize: isCompact ? 32 : 38),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$qty Qty',
                      style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // 2. Product Name (Up to 3 lines, then ellipsis)
          Text(
            name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 11.5 : 12.5,
              height: 1.22,
              color: nameColor ?? const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          // 3. Rate & Unit
          Text(
            '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: rateColor ?? const Color(0xFF475569),
            ),
          ),

          const SizedBox(height: 4),

          // 4. Buy Now Button (Close to rate, dynamic height row, no outer borders)
          SizedBox(
            width: double.infinity,
            height: 27,
            child: ElevatedButton(
              onPressed: handleProductTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                btnText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateSortChips() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 10.0),
      child: Row(
        children: [
          _buildSingleSortChip(
            label: 'Default',
            value: 'none',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(width: 8),
          _buildSingleSortChip(
            label: 'Low to High',
            value: 'low_to_high',
            icon: Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 8),
          _buildSingleSortChip(
            label: 'High to Low',
            value: 'high_to_low',
            icon: Icons.arrow_downward_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSortChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _priceSortOrder == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _priceSortOrder = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 3.5),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
          _buildRateSortChips(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (int r = 0; r < filtered.length; r += 3) ...[
                  if (r > 0) const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildProductCard(filtered[r], columns: 3)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: r + 1 < filtered.length
                            ? _buildProductCard(filtered[r + 1], columns: 3)
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: r + 2 < filtered.length
                            ? _buildProductCard(filtered[r + 2], columns: 3)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    // Default 'All' Home Page View: Render Strictly By Seller Sections! NO DEFAULT "Store Products" HEADER!
    final List<Widget> sectionWidgets = [];
    final Set<dynamic> displayedProdIds = {};
    final effectiveSections = _buildEffectiveSectionsList(filtered);

    for (int i = 0; i < effectiveSections.length; i++) {
      final sec = effectiveSections[i];
      final bool isLastSection = i == effectiveSections.length - 1;
      sectionWidgets.addAll(_buildSingleStoreSection(
        sec,
        isLastSection: isLastSection,
        filtered: filtered,
        displayedProdIds: displayedProdIds,
      ));
    }

    return Column(
      children: sectionWidgets,
    );
  }

  List<Map<String, String>> _buildEffectiveSectionsList(List<Map<String, dynamic>> filtered) {
    final List<Map<String, String>> effectiveSections = [];
    final Set<String> addedSecNames = {};

    for (var sec in _sellerSections) {
      final sName = (sec['name'] ?? '').toString().trim();
      final sIcon = (sec['icon'] ?? '').toString().trim();
      final sBg = (sec['bg_color'] ?? '#FFFFFF').toString().trim();
      final sText = (sec['text_color'] ?? '').toString().trim();
      final sImgBg = (sec['image_bg_color'] ?? '#F8FAFC').toString().trim();
      final sCols = (sec['columns'] ?? 2).toString().trim();
      final sMaxLimit = (sec['max_items'] ?? 0).toString().trim();
      final sHideTitle = (sec['hide_title'] ?? 0).toString().trim();
      final sHideItemCount = (sec['hide_item_count'] ?? 0).toString().trim();
      final sHeadingImg = (sec['heading_image'] ?? '').toString().trim();
      if (sName.isNotEmpty && !addedSecNames.contains(sName.toLowerCase())) {
        addedSecNames.add(sName.toLowerCase());
        effectiveSections.add({
          'name': sName,
          'icon': sIcon,
          'bg_color': sBg.isNotEmpty ? sBg : '#FFFFFF',
          'text_color': sText.isNotEmpty ? sText : '#0F172A',
          'image_bg_color': sImgBg.isNotEmpty ? sImgBg : '#F8FAFC',
          'columns': sCols.isNotEmpty ? sCols : '2',
          'max_items': sMaxLimit,
          'hide_title': sHideTitle,
          'hide_item_count': sHideItemCount,
          'heading_image': sHeadingImg,
        });
      }
    }

    if (_sellerSections.isEmpty) {
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
            'max_items': '0',
          });
        }
      }
    }

    if (effectiveSections.isEmpty) {
      for (var p in filtered) {
        final pSec = (p['section'] ?? '').toString().trim();
        final pCat = (p['category'] ?? '').toString().trim();
        final tag = pSec.isNotEmpty ? pSec : pCat;
        if (tag.isNotEmpty && !addedSecNames.contains(tag.toLowerCase())) {
          addedSecNames.add(tag.toLowerCase());
          effectiveSections.add({'name': tag, 'icon': '🏷️', 'bg_color': '#FFFFFF', 'text_color': '#0F172A', 'columns': '2', 'max_items': '0'});
        }
      }
    }

    if (effectiveSections.isEmpty && filtered.isNotEmpty) {
      effectiveSections.add({'name': 'Items', 'icon': '🏷️', 'bg_color': '#FFFFFF', 'text_color': '#0F172A', 'columns': '2', 'max_items': '0'});
    }

    return effectiveSections;
  }

  List<Widget> _buildSingleStoreSection(
    Map<String, String> sec, {
    required bool isLastSection,
    required List<Map<String, dynamic>> filtered,
    required Set<dynamic> displayedProdIds,
    bool isChild = false,
  }) {
    final List<Widget> sectionWidgets = [];
    final secName = sec['name']!;
    final secIcon = sec['icon']!;

    // Find categories explicitly assigned to this specific section
    final matchingCategories = _rawCategories.where((cat) {
      final secStr = (cat['sections'] ?? '').toString().toLowerCase();
      if (secStr.isEmpty) return false;
      final secList = secStr.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      return secList.contains(secName.toLowerCase());
    }).toList();

    final matchingCategoryNames = matchingCategories
        .map((c) => (c['name'] ?? c['category_name'] ?? '').toString().trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    final matchingProducts = filtered.where((p) {
      if (displayedProdIds.contains(p['id'])) return false;
      final pSec = (p['section'] ?? '').toString().trim();
      final pCat = (p['category'] ?? '').toString().trim();

      bool isMatch = pSec.toLowerCase() == secName.toLowerCase() ||
          pCat.toLowerCase() == secName.toLowerCase() ||
          matchingCategoryNames.contains(pCat.toLowerCase());

      if (!isMatch && isLastSection) {
        isMatch = true;
      }
      return isMatch;
    }).toList();

    if (matchingProducts.isEmpty && matchingCategories.isEmpty) {
      return [];
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

    String secBgHex = '#FFFFFF';
    String secTextHex = '#EF4444';
    String secImgBgHex = '#F8FAFC';
    int secCols = int.tryParse((sec['columns'] ?? '2').toString()) ?? 2;
    int secMaxItems = int.tryParse((sec['max_items'] ?? '0').toString()) ?? 0;

    final secMatch = _sellerSections.firstWhere(
      (s) => (s['name'] ?? '').toString().trim().toLowerCase() == secName.toLowerCase(),
      orElse: () => {},
    );

    bool isFullWidth = false;
    bool isPosterFullWidth = false;
    bool hideTitle = false;
    bool hideItemCount = false;
    String secHeadingImg = '';
    if (secMatch.isNotEmpty) {
      final bCol = (secMatch['bg_color'] ?? '').toString().trim();
      final tCol = (secMatch['text_color'] ?? '').toString().trim();
      final imgCol = (secMatch['image_bg_color'] ?? '').toString().trim();
      secHeadingImg = (secMatch['heading_image'] ?? '').toString().trim();
      if (bCol.isNotEmpty) secBgHex = bCol;
      if (tCol.isNotEmpty && tCol != '#0F172A') secTextHex = tCol;
      if (imgCol.isNotEmpty) secImgBgHex = imgCol;
      if (secMatch['columns'] != null) {
        secCols = int.tryParse(secMatch['columns'].toString()) ?? secCols;
      }
      if (secMatch['max_items'] != null) {
        secMaxItems = int.tryParse(secMatch['max_items'].toString()) ?? secMaxItems;
      }
      isFullWidth = (secMatch['full_width'] == 1 || secMatch['full_width'] == '1' || secMatch['full_width'] == true);
      isPosterFullWidth = (secMatch['poster_full_width'] == 1 || secMatch['poster_full_width'] == '1' || secMatch['poster_full_width'] == true);
      hideTitle = (secMatch['hide_title'] == 1 || secMatch['hide_title'] == '1' || secMatch['hide_title'] == true);
      hideItemCount = (secMatch['hide_item_count'] == 1 || secMatch['hide_item_count'] == '1' || secMatch['hide_item_count'] == true);
    } else {
      final catMatch = _rawCategories.firstWhere(
        (c) => (c['name'] ?? c['category_name'] ?? '').toString().trim().toLowerCase() == secName.toLowerCase(),
        orElse: () => {},
      );
      if (catMatch.isNotEmpty) {
        final catItemBg = (catMatch['item_bg_color'] ?? '').toString().trim();
        if (catItemBg.isNotEmpty) secImgBgHex = catItemBg;
      }
      final bCol = (sec['bg_color'] ?? '').toString().trim();
      final tCol = (sec['text_color'] ?? '').toString().trim();
      final imgCol = (sec['image_bg_color'] ?? '').toString().trim();
      secHeadingImg = (sec['heading_image'] ?? '').toString().trim();
      if (bCol.isNotEmpty) secBgHex = bCol;
      if (tCol.isNotEmpty && tCol != '#0F172A') secTextHex = tCol;
      if (imgCol.isNotEmpty) secImgBgHex = imgCol;
      isFullWidth = (sec['full_width']?.toString() == '1' || sec['full_width']?.toString().toLowerCase() == 'true');
      isPosterFullWidth = (sec['poster_full_width']?.toString() == '1' || sec['poster_full_width']?.toString().toLowerCase() == 'true');
      hideTitle = (sec['hide_title']?.toString() == '1' || sec['hide_title']?.toString().toLowerCase() == 'true');
      hideItemCount = (sec['hide_item_count']?.toString() == '1' || sec['hide_item_count']?.toString().toLowerCase() == 'true');
    }

    final bool hideBothHeaders = hideTitle && hideItemCount;

    if (secCols != 1 && secCols != 2 && secCols != 3) {
      secCols = 2;
    }

    final Color secBgColor = hexToColor(secBgHex.isEmpty ? '#FFFFFF' : secBgHex);
    final Color secImgBgColor = hexToColor(secImgBgHex.isEmpty ? '#F8FAFC' : secImgBgHex);
    final Color ribbonColor = hexToColor(secTextHex.isEmpty ? '#EF4444' : secTextHex);
    final Color ribbonDarkColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), ribbonColor);
    final Color ribbonTextColor = ribbonColor.computeLuminance() > 0.6 ? const Color(0xFF0F172A) : Colors.white;
    final bool isDarkSec = secBgColor.computeLuminance() < 0.45;
    final Color prodNameColor = isDarkSec ? Colors.white : const Color(0xFF0F172A);
    final Color prodRateColor = isDarkSec ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF475569);

    final bool isExpanded = _expandedSectionNames.contains(secName.toLowerCase());
    final int displayCount = (secMaxItems > 0 && !isExpanded && matchingProducts.length > secMaxItems)
        ? secMaxItems
        : matchingProducts.length;

    // Render External Sliders ABOVE / OUTSIDE the section box
    if (externalSliders.isNotEmpty) {
      sectionWidgets.add(_buildSectionSliderBanner(externalSliders, isSectionPosterFullWidth: isPosterFullWidth));
    }

    sectionWidgets.add(
      Padding(
        padding: EdgeInsets.only(
          left: isFullWidth ? 0 : 12,
          right: isFullWidth ? 0 : 12,
          top: (isChild && externalSliders.isEmpty) ? 0 : 6,
          bottom: 6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: secBgColor,
            borderRadius: isFullWidth ? BorderRadius.zero : BorderRadius.circular(16),
            boxShadow: isFullWidth
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Full-Width Section Heading Image Banner
              if (secHeadingImg.isNotEmpty)
                ClipRRect(
                  borderRadius: isFullWidth ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildSectionHeadingImage(secHeadingImg),
                ),

              // Section Ribbon Tag Header
              if (!hideBothHeaders)
                Padding(
                  padding: EdgeInsets.only(
                    left: isFullWidth ? 12 : 14,
                    right: isFullWidth ? 12 : 14,
                    top: secHeadingImg.isNotEmpty ? 8 : (hideTitle ? 4 : 10),
                    bottom: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!hideTitle)
                        Text(
                          secName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDarkSec ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      if (!hideItemCount)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${matchingProducts.length} Items',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                        ),
                    ],
                  ),
                ),

              // Render Internal Sliders INSIDE the Section Container!
              if (internalSliders.isNotEmpty)
                _buildSectionSliderBanner(internalSliders, isSectionPosterFullWidth: isPosterFullWidth),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isFullWidth ? (secCols == 3 ? 8 : 10) : (secCols == 3 ? 10 : 14),
                  vertical: (hideBothHeaders && internalSliders.isEmpty && secHeadingImg.isEmpty) ? 12 : 6,
                ),
                child: Column(
                  children: [
                    for (int r = 0; r < displayCount; r += secCols) ...[
                      if (r > 0) SizedBox(height: secCols == 3 ? 14 : 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int c = 0; c < secCols; c++) ...[
                            if (c > 0) SizedBox(width: secCols == 3 ? 10 : 12),
                            Expanded(
                              child: r + c < displayCount
                                  ? _buildProductCard(
                                      matchingProducts[r + c],
                                      columns: secCols,
                                      nameColor: prodNameColor,
                                      rateColor: prodRateColor,
                                      imageBgColor: secImgBgColor,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // CUSTOMIZABLE "VIEW MORE" BUTTON AT BOTTOM CENTER OF SECTION
              if (secMaxItems > 0 && matchingProducts.length > secMaxItems) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final vmBgHex = (_actionButtonsConfig['view_more_bg'] ?? '#F59E0B').toString();
                    final vmOpacity = safeDouble(_actionButtonsConfig['view_more_opacity'], 1.0).clamp(0.05, 1.0);
                    final rawBg = hexToColor(vmBgHex);
                    final vmBgColor = rawBg.withValues(alpha: vmOpacity);
                    final vmLabelText = (_actionButtonsConfig['view_more_text'] ?? 'View More').toString().trim();
                    final vmTextName = vmLabelText.isNotEmpty ? vmLabelText : 'View More';
                    final vmFontSize = safeDouble(_actionButtonsConfig['view_more_size'], 13.0).clamp(10.0, 24.0);
                    final vmTextColorHex = (_actionButtonsConfig['view_more_text_color'] ?? '#0F172A').toString();
                    final vmTextColor = hexToColor(vmTextColorHex);
                    final double hPad = (vmFontSize * 1.6).clamp(14.0, 30.0);
                    final double vPad = (vmFontSize * 0.75).clamp(6.0, 16.0);

                    return Center(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedSectionNames.remove(secName.toLowerCase());
                            } else {
                              _expandedSectionNames.add(secName.toLowerCase());
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                          decoration: BoxDecoration(
                            color: vmBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: vmTextColor.withValues(alpha: (0.15 + 0.25 * (1.0 - vmOpacity)).clamp(0.12, 0.4)),
                              width: 0.8,
                            ),
                            boxShadow: vmOpacity > 0.2
                                ? [
                                    BoxShadow(
                                      color: rawBg.withValues(alpha: (0.35 * vmOpacity * vmOpacity).clamp(0.0, 0.35)),
                                      blurRadius: (8 * vmOpacity).toDouble(),
                                      offset: Offset(0, (3 * vmOpacity).toDouble()),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isExpanded
                                    ? 'Show Less'
                                    : '$vmTextName (${matchingProducts.length - secMaxItems} more items)',
                                style: TextStyle(
                                  color: vmTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: vmFontSize,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                isExpanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                size: (vmFontSize + 1).clamp(13.0, 20.0),
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );

    return sectionWidgets;
  }

  /// Dynamic Home Content Builder that strictly respects the seller's configured hierarchy!
  Widget _buildDynamicHomeContent() {
    if (_selectedCategory.isNotEmpty && _selectedCategory.toLowerCase() != 'all') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStoreProductsGrid(),
          const SizedBox(height: 80),
        ],
      );
    }

    final filtered = _filteredProducts;

    if (_homeLayoutOrder.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFestivalAnimationSection(),
          if (_sliders.isNotEmpty) ...[
            _buildSliderSection(),
            const SizedBox(height: 8),
          ],
          _buildCategorySections(placement: 'top'),
          _buildStoreProductsGrid(),
          _buildCategorySections(placement: 'bottom'),
          const SizedBox(height: 80),
        ],
      );
    }

    final List<Widget> dynamicWidgets = [];
    final Set<String> renderedProductSecNames = {};
    final Set<String> renderedCatSecIds = {};
    final effectiveSections = _buildEffectiveSectionsList(filtered);
    final Set<dynamic> displayedProdIds = {};

    for (int idx = 0; idx < _homeLayoutOrder.length; idx++) {
      final item = _homeLayoutOrder[idx];
      final bool isVisible = item['is_visible'] != false;
      if (!isVisible) continue;

      final bool isChild = (item['is_child'] == true && dynamicWidgets.isNotEmpty);
      final bool isOverlap = (isChild && item['child_overlap'] == true);

      // Check if next visible item is a child
      bool nextIsChild = false;
      for (int ni = idx + 1; ni < _homeLayoutOrder.length; ni++) {
        if (_homeLayoutOrder[ni]['is_visible'] != false) {
          nextIsChild = (_homeLayoutOrder[ni]['is_child'] == true);
          break;
        }
      }

      final String type = (item['type'] ?? '').toString();
      final String refId = (item['ref_id'] ?? '').toString().trim();

      if (type == 'festival_animation') {
        Widget fw = _buildFestivalAnimationSection();
        if (isOverlap) {
          fw = Transform.translate(
            offset: const Offset(0, -14.0),
            child: fw,
          );
        }
        dynamicWidgets.add(fw);
      } else if (type == 'main_slider') {
        if (_sliders.isNotEmpty) {
          Widget sw = _buildSliderSection();
          if (isOverlap) {
            sw = Transform.translate(
              offset: const Offset(0, -14.0),
              child: sw,
            );
          }
          dynamicWidgets.add(sw);
          // Only add gap below slider if the next visible section is NOT a child
          if (!nextIsChild) {
            dynamicWidgets.add(const SizedBox(height: 8));
          }
        }
      } else if (type == 'category_section') {
        final catSec = _categorySections.firstWhere(
          (cs) => ((cs['id'] ?? cs['title'] ?? '').toString().trim().toLowerCase() == refId.toLowerCase()),
          orElse: () => {},
        );
        if (catSec.isNotEmpty) {
          final isActive = catSec['is_active'] == true || catSec['is_active'] == 1 || catSec['is_active'] == '1' || catSec['is_active'] == null;
          if (isActive) {
            Widget cw = _buildSingleCategorySectionItem(catSec, isChild: isChild);
            if (isOverlap) {
              cw = Transform.translate(
                offset: const Offset(0, -14.0),
                child: cw,
              );
            }
            dynamicWidgets.add(cw);
            renderedCatSecIds.add(refId.toLowerCase());
          }
        }
      } else if (type == 'product_section') {
        final secMatch = effectiveSections.firstWhere(
          (s) => s['name']!.toLowerCase() == refId.toLowerCase(),
          orElse: () => {},
        );
        if (secMatch.isNotEmpty) {
          final secWidgets = _buildSingleStoreSection(
            secMatch,
            isLastSection: false,
            filtered: filtered,
            displayedProdIds: displayedProdIds,
            isChild: isChild,
          );
          if (isOverlap && secWidgets.isNotEmpty) {
            secWidgets[0] = Transform.translate(
              offset: const Offset(0, -14.0),
              child: secWidgets[0],
            );
          }
          dynamicWidgets.addAll(secWidgets);
          renderedProductSecNames.add(refId.toLowerCase());
        }
      }
    }

    // Safety fallback: append any newly created product sections that weren't in saved layout
    for (int i = 0; i < effectiveSections.length; i++) {
      final sec = effectiveSections[i];
      if (!renderedProductSecNames.contains(sec['name']!.toLowerCase())) {
        final secWidgets = _buildSingleStoreSection(
          sec,
          isLastSection: i == effectiveSections.length - 1,
          filtered: filtered,
          displayedProdIds: displayedProdIds,
        );
        dynamicWidgets.addAll(secWidgets);
      }
    }

    // Safety fallback: append any newly created category sections that weren't in saved layout
    for (var cs in _categorySections) {
      final csId = (cs['id'] ?? cs['title'] ?? '').toString().trim().toLowerCase();
      if (!renderedCatSecIds.contains(csId)) {
        final isActive = cs['is_active'] == true || cs['is_active'] == 1 || cs['is_active'] == '1' || cs['is_active'] == null;
        if (isActive) {
          dynamicWidgets.add(_buildSingleCategorySectionItem(cs));
        }
      }
    }

    dynamicWidgets.add(const SizedBox(height: 80));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dynamicWidgets,
    );
  }

  Widget _buildSectionSliderBanner(List<Map<String, dynamic>> slidersList, {bool isSectionPosterFullWidth = false}) {
    if (slidersList.isEmpty) return const SizedBox.shrink();
    final String keyStr = slidersList.map((s) => '${s['id']}_${s['position']}').join('_');
    return SectionSliderBannerWidget(
      key: ValueKey(keyStr),
      slidersList: slidersList,
      isSectionPosterFullWidth: isSectionPosterFullWidth,
    );
  }

  /// Seller Search Bar Customization & Transparency Dialog
  void _showManageSearchBarDialog() {
    final username = widget.sellerUsername;
    final cachedStyle = AuthService.getCachedSellerSearchBarStyle(username);
    Map<String, dynamic> currentConfig = AuthService.getCachedHeaderThemeConfig() ?? _headerThemeConfig;
    String bgColor = (cachedStyle?['search_bg_color'] ?? currentConfig['search_bg_color'] ?? '#FFFFFF').toString();
    double opacity = (((cachedStyle?['search_opacity'] ?? currentConfig['search_opacity']) as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    String textColor = (cachedStyle?['search_text_color'] ?? currentConfig['search_text_color'] ?? '#0F172A').toString();

    final List<TextEditingController> hintControllers = [];
    final cachedHints = AuthService.getCachedSellerSearchHints(username);
    if (cachedHints != null && cachedHints.isNotEmpty) {
      for (final h in cachedHints) {
        hintControllers.add(TextEditingController(text: h));
      }
    } else if (_searchHints.isNotEmpty) {
      for (final h in _searchHints) {
        hintControllers.add(TextEditingController(text: h));
      }
    }

    bool isLoadedFromNetwork = false;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoadedFromNetwork) {
            isLoadedFromNetwork = true;
            Future.microtask(() async {
              final freshConfig = await AuthService.getHeaderThemeConfig();
              final savedStyle = await AuthService.getSellerSearchBarStyle(username);
              final savedHints = await AuthService.getSellerSearchHints(username);
              if (ctx.mounted) {
                setModalState(() {
                  currentConfig = freshConfig;
                  bgColor = (savedStyle['search_bg_color'] ?? freshConfig['search_bg_color'] ?? '#FFFFFF').toString();
                  opacity = (((savedStyle['search_opacity'] ?? freshConfig['search_opacity']) as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
                  textColor = (savedStyle['search_text_color'] ?? freshConfig['search_text_color'] ?? '#0F172A').toString();
                  if (hintControllers.isEmpty || (hintControllers.length == 1 && hintControllers[0].text == 'Search products in store...')) {
                    if (savedHints.isNotEmpty) {
                      hintControllers.clear();
                      for (final h in savedHints) {
                        hintControllers.add(TextEditingController(text: h));
                      }
                    } else if (hintControllers.isEmpty) {
                      hintControllers.add(TextEditingController(text: 'Search products in store...'));
                    }
                  }
                });
              }
            });
          }

          final Color previewColor = HeaderThemeHelper.hexToColor(bgColor).withValues(alpha: opacity);
          final Color previewTextColor = HeaderThemeHelper.hexToColor(textColor);
          final String previewHint = hintControllers.map((c) => c.text.trim()).firstWhere(
                (t) => t.isNotEmpty,
                orElse: () => 'Search products in store...',
              );

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
                          Expanded(
                            child: Text(
                              previewHint,
                              style: TextStyle(color: previewTextColor.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Search Watermarks / Animated Placeholders Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Search Watermarks (घूमने वाले सर्च टेक्स्ट 💬)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'ये टेक्स्ट सर्च बार में एक-एक कर ऑटो चेंज होंगे',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  hintControllers.add(TextEditingController());
                                });
                              },
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              label: const Text('+ Add', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (hintControllers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No watermark texts added. Tap "+ Add" to add search suggestions!',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: hintControllers.length,
                            itemBuilder: (ctx, hIdx) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEDE9FE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${hIdx + 1}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: hintControllers[hIdx],
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: InputDecoration(
                                          hintText: "उदा. Search 'दूध', Search 'Snacks'...",
                                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          hintControllers[hIdx].dispose();
                                          hintControllers.removeAt(hIdx);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
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
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setModalState(() => isProcessing = true);
                            try {
                              final enteredHints = hintControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                              await AuthService.saveSellerSearchBarStyle(
                                sellerUsername: username,
                                hints: enteredHints,
                                bgColor: bgColor,
                                opacity: opacity,
                                textColor: textColor,
                              );

                              final updatedConfig = Map<String, dynamic>.from(currentConfig);
                              updatedConfig['search_bg_color'] = bgColor;
                              updatedConfig['search_opacity'] = opacity;
                              updatedConfig['search_text_color'] = textColor;

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() {
                                  _headerThemeConfig = updatedConfig;
                                  _searchHints = enteredHints;
                                  _searchHintIndexNotifier.value = 0;
                                });
                                _startSearchHintTimer();
                                AppToast.show(context, 'Search Bar Style & Watermarks saved successfully in database!');
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setModalState(() => isProcessing = false);
                                AppToast.show(context, 'Error saving style: $e');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Search Bar Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCategoryStrip({Color? categoryColor}) {
    final List<Map<String, dynamic>> items = _rawCategories.isNotEmpty
        ? _rawCategories
        : _categories.map((c) => {'name': c}).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final Color activeColor = categoryColor ?? HeaderThemeHelper.getCategoryIconColor(_headerThemeConfig);

    return Container(
      height: 54,
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: items.length,
        itemBuilder: (ctx, idx) {
          final cat = items[idx];
          final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
          if (cName.isEmpty) return const SizedBox.shrink();
          final cIcon = (cat['icon_url'] ?? '').toString().trim();
          final isSel = _selectedCategory.toLowerCase() == cName.toLowerCase();

          return GestureDetector(
            onTap: () => _openCategoryPage(cName, cat),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(2.5),
                    decoration: isSel
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor.withValues(alpha: 0.22),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          )
                        : const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                    child: CategoryIconHelper.buildHeaderCategoryIcon(
                      cIcon,
                      cName,
                      size: 22,
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cName,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      color: activeColor,
                      letterSpacing: 0.1,
                      shadows: activeColor.computeLuminance() > 0.4
                          ? const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 2,
                                offset: Offset(0.5, 0.5),
                              ),
                            ]
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSel) ...[
                    const SizedBox(height: 1.5),
                    Container(
                      width: 14,
                      height: 2,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: activeColor.withValues(alpha: 0.7), blurRadius: 3),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderTopInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. App Title "Daily Mart" + Action Icons Row (Exit + 3 Dots on opposite side)
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 10, top: 2, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Daily Mart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isSellerView)
                    RotationTransition(
                      turns: _refreshSpinController,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        tooltip: 'Refresh Storefront',
                        onPressed: _isManualRefreshing ? null : _handleManualRefresh,
                      ),
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                      tooltip: 'Exit / Switch Store',
                      onPressed: _exitToSellerList,
                    ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
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
                        _handleManualRefresh();
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (!widget.isSellerView) ...[
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
                      ],
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
                            Icon(Icons.palette_rounded, color: Color(0xFF0F172A), size: 20),
                            SizedBox(width: 10),
                            Text('Search Bar Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
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

        // 2. Greeting Row ("Good Afternoon, Raj") right below Daily Mart
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 1),
          child: Text(
            '${_getGreeting()}, ${widget.isSellerView ? (widget.sellerName.trim().isNotEmpty ? widget.sellerName.trim() : 'Seller') : (widget.customer.name.trim().isNotEmpty ? widget.customer.name.trim() : 'Customer')}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 3. Delivery Time & Status Row ("15 minutes", "12 X 7 Open")
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _sellerHeaderText1.isNotEmpty ? _sellerHeaderText1 : '15 minutes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _sellerHeaderText2.isNotEmpty ? _sellerHeaderText2 : '12 X 7 Open',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),

        // 4. Location / Address Selector Row ("Raniganj, Imamganj, Gaya v")
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 1, 16, 2),
          child: InkWell(
            onTap: widget.isSellerView ? null : _openCustomerAddressSelection,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.isSellerView
                        ? (_sellerLocation.isNotEmpty ? _sellerLocation : (widget.sellerName.isNotEmpty ? widget.sellerName : 'My Store'))
                        : (_customerAddressDisplay.isNotEmpty
                            ? _customerAddressDisplay
                            : (_sellerLocation.isNotEmpty ? _sellerLocation : widget.sellerName)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.isSellerView) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStickySection({double collapseRatio = 0.0}) {
    final normalCatColor = HeaderThemeHelper.getCategoryIconColor(_headerThemeConfig);
    final stickyCatColor = HeaderThemeHelper.getStickyCategoryIconColor(_headerThemeConfig);
    final activeCatColor = Color.lerp(normalCatColor, stickyCatColor, Curves.easeInOut.transform(collapseRatio.clamp(0.0, 1.0))) ?? normalCatColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 5. Search Bar (Full Width, rounded pill container!)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Container(
            height: 42,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#0F172A'),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: _searchHints.isEmpty ? 'Search products in ${widget.sellerName}...' : null,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#0F172A').withValues(alpha: 0.65),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6),
                        child: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#8B5CF6'),
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 0, bottom: 0),
                      border: InputBorder.none,
                    ),
                  ),
                  if (_searchHints.isNotEmpty && _searchController.text.isEmpty)
                    Positioned(
                      left: 38,
                      right: 14,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _searchHintIndexNotifier,
                          builder: (context, currentHintIdx, _) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 480),
                              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  children: <Widget>[
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                final isIncoming = child.key == ValueKey<int>(currentHintIdx);
                                final Animation<Offset> slideAnimation;
                                if (isIncoming) {
                                  slideAnimation = Tween<Offset>(
                                    begin: const Offset(0.0, 0.9),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ));
                                } else {
                                  slideAnimation = Tween<Offset>(
                                    begin: const Offset(0.0, -0.9),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInCubic,
                                  ));
                                }
                                return SlideTransition(
                                  position: slideAnimation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Align(
                                key: ValueKey<int>(currentHintIdx),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _searchHints[currentHintIdx % _searchHints.length],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: HeaderThemeHelper.hexToColor(_headerThemeConfig['search_text_color'] ?? '#0F172A').withValues(alpha: 0.65),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 6. Header Categories Strip (Outline icons + category name under search bar)
        _buildHeaderCategoryStrip(categoryColor: activeCatColor),
      ],
    );
  }

  Widget _buildCategorySections({String placement = 'top'}) {
    final activeSections = _categorySections.where((s) {
      final p = (s['placement'] ?? 'top').toString().toLowerCase().trim();
      final target = placement.toLowerCase().trim();
      final isActive = s['is_active'] == true || s['is_active'] == 1 || s['is_active'] == '1' || s['is_active'] == null;
      return isActive && p == target;
    }).toList();

    if (activeSections.isEmpty) {
      // Backward compatibility fallback for legacy 'home / top' categories when no custom category section is defined
      if (placement == 'top') {
        return _buildCircularCategorySection();
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: activeSections.map((sec) => _buildSingleCategorySectionItem(sec)).toList(),
    );
  }

  Widget _buildSingleCategorySectionItem(Map<String, dynamic> sec, {bool isChild = false}) {
    final String title = (sec['title'] ?? sec['name'] ?? '').toString().trim();
    final dynamic rawCats = sec['categories'];
    List<String> catNames = [];
    if (rawCats is List) {
      catNames = rawCats.map((e) => e.toString().trim().toLowerCase()).toList();
    } else if (rawCats is String && rawCats.isNotEmpty) {
      catNames = rawCats.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    }

    // Find matching category objects in _rawCategories
    final List<Map<String, dynamic>> matchingCats = _rawCategories.where((cat) {
      final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim().toLowerCase();
      return catNames.isEmpty || catNames.contains(cName);
    }).toList();

    if (matchingCats.isEmpty) return const SizedBox.shrink();

    // Layout options: 4, 3, or 'horizontal'
    final String layoutType = (sec['columns'] ?? sec['layout'] ?? '4').toString().toLowerCase().trim();
    final int crossAxisCount = int.tryParse(layoutType) ?? (layoutType == '3' ? 3 : 4);
    final bool isHorizontal = layoutType == 'horizontal' || layoutType == 'scroll' || layoutType == 'slider';

    // Section Background Color
    final String rawBg = (sec['bg_color'] ?? sec['background_color'] ?? '').toString().trim();
    Color? sectionBg;
    if (rawBg.isNotEmpty) {
      String hex = rawBg.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) sectionBg = Color(val);
    }

    // Section Title Text Color
    final String rawTextColor = (sec['text_color'] ?? '').toString().trim();
    Color titleColor = const Color(0xFF0F172A);
    if (rawTextColor.isNotEmpty) {
      String hex = rawTextColor.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) titleColor = Color(val);
    } else if (sectionBg != null) {
      titleColor = sectionBg.computeLuminance() > 0.5 ? const Color(0xFF0F172A) : Colors.white;
    }

    final bool isFullWidth = sec['is_full_width'] == true || sec['is_full_width'] == 1 || sec['is_full_width'] == '1';
    final bool hideItemCount = sec['hide_item_count'] == true || sec['hide_item_count'] == 1 || sec['hide_item_count'] == '1';
    final bool hideTitle = sec['hide_title'] == true || sec['hide_title'] == 1 || sec['hide_title'] == '1';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        left: isFullWidth ? 0 : 10,
        right: isFullWidth ? 0 : 10,
        top: isChild ? 0 : 6,
        bottom: 6,
      ),
      padding: EdgeInsets.symmetric(
        vertical: 10,
        horizontal: isFullWidth ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: sectionBg ?? Colors.white,
        borderRadius: isFullWidth ? BorderRadius.zero : BorderRadius.circular(16),
        border: isFullWidth ? null : Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: isFullWidth ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideTitle && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (!hideItemCount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: titleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${matchingCats.length} items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (isHorizontal)
            SizedBox(
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matchingCats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) => SizedBox(
                  width: 82,
                  child: _buildCategoryCardItem(matchingCats[idx]),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                childAspectRatio: crossAxisCount == 3 ? 0.85 : 0.70,
              ),
              itemCount: matchingCats.length,
              itemBuilder: (ctx, idx) => _buildCategoryCardItem(matchingCats[idx]),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCardItem(Map<String, dynamic> cat) {
    final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
    final cImg = (cat['image'] ?? cat['image_url'] ?? '').toString().trim();
    final isSel = _selectedCategory.toLowerCase() == cName.toLowerCase();
    final bool hideName = cat['hide_name'] == 1 || cat['hide_name'] == true || cat['hide_name'] == '1';
    final bool fullSizeImage = cat['full_size_image'] == 1 || cat['full_size_image'] == true || cat['full_size_image'] == '1';

    final String rawColor = (cat['color'] ?? '').toString().trim();
    Color catBgColor = const Color(0xFFF1F5F9);
    if (rawColor.isNotEmpty) {
      String hex = rawColor.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) catBgColor = Color(val);
    }

    final double luminance = catBgColor.computeLuminance();
    final Color textColor = luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white;

    if (fullSizeImage) {
      return GestureDetector(
        onTap: () => _openCategoryPage(cName, cat),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSel ? Border.all(color: const Color(0xFF0F172A), width: 2.0) : null,
            boxShadow: [
              BoxShadow(
                color: isSel
                    ? Colors.black.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSel ? 6 : 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCategoryImageWidget(cImg, emojiSize: 36, fit: BoxFit.cover),
                if (!hideName && cName.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        cName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: Colors.white,
                          height: 1.15,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (isSel)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openCategoryPage(cName, cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: catBgColor,
          borderRadius: BorderRadius.circular(14),
          border: isSel ? Border.all(color: luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white, width: 2.0) : null,
          boxShadow: [
            BoxShadow(
              color: isSel
                  ? Colors.black.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isSel ? 6 : 2,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: hideName ? 1 : 0,
                  child: SizedBox(
                    width: hideName ? double.infinity : 58,
                    height: hideName ? double.infinity : 58,
                    child: Center(
                      child: _buildCategoryImageWidget(cImg, emojiSize: hideName ? 40 : 32, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (!hideName && cName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Text(
                        cName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: textColor,
                          height: 1.15,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (isSel)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 10,
                    color: luminance > 0.5 ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularCategorySection() {
    // Legacy backward compatibility for categories assigned to "Home / Top"
    final List<Map<String, dynamic>> allCatItems = _rawCategories.where((cat) {
      final secStr = (cat['sections'] ?? '').toString().toLowerCase();
      if (secStr.isEmpty) return false;
      final secList = secStr.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
      return secList.contains('home / top') || secList.contains('home') || secList.contains('top');
    }).toList();

    if (allCatItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            childAspectRatio: 0.70,
          ),
          itemCount: allCatItems.length,
          itemBuilder: (ctx, idx) => _buildCategoryCardItem(allCatItems[idx]),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeadingImage(String rawImg) {
    final img = rawImg.trim();
    if (img.isEmpty) return const SizedBox.shrink();

    Widget imageWidget;
    if (img.startsWith('http://') || img.startsWith('https://')) {
      imageWidget = Image.network(
        img,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      String base64Str = img;
      if (img.startsWith('data:image')) {
        final parts = img.split(',');
        if (parts.length > 1) {
          base64Str = parts.last.trim();
        }
      }
      try {
        final bytes = _base64Cache.putIfAbsent(base64Str, () => base64Decode(base64Str));
        imageWidget = Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    return SizedBox(
      width: double.infinity,
      child: imageWidget,
    );
  }

  Widget _buildCategoryImageWidget(String rawImg, {double emojiSize = 34, BoxFit fit = BoxFit.contain}) {
    final img = rawImg.trim();
    if (img.isEmpty || img == '🏷️') {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: fit,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 200,
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
        final bytes = _base64Cache.putIfAbsent(base64Str, () => base64Decode(base64Str));
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 200,
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
    if (widget.particleOpacity <= 0.05) return const SizedBox.shrink();
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.25),
                      blurRadius: 6,
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        baseColor,
                        Colors.white.withValues(alpha: 0.95),
                        darkColor,
                        baseColor,
                        lightColor,
                        Colors.white.withValues(alpha: 0.95),
                        baseColor,
                      ],
                    ),
                  ),
                ),
              ),

              // Inner Solid Circle Mask so ring forms a sleek 3.5px rotating border
              Container(
                width: widget.isSelected ? 42.0 : 43.5,
                height: widget.isSelected ? 42.0 : 43.5,
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
  final bool isSectionPosterFullWidth;
  const SectionSliderBannerWidget({super.key, required this.slidersList, this.isSectionPosterFullWidth = false});

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
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
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
                final isFullWidth = (item['full_width'] == 1 || item['full_width'] == true || item['full_width'] == '1')
                    || widget.isSectionPosterFullWidth;
                final posterRadius = isFullWidth ? BorderRadius.zero : BorderRadius.circular(14);

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: isFullWidth ? 0 : 14),
                  child: ClipRRect(
                    borderRadius: posterRadius,
                    child: SellerSlidersScreen.buildBannerBackground(
                      bg: bg,
                      overlayDim: overlayDim,
                      removeWhiteBg: removeWhiteBg,
                      imgFit: imgFit,
                      borderRadius: posterRadius,
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
            if (widget.slidersList.length > 1)
              Positioned(
                bottom: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.slidersList.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 16 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

    return SizedBox(
      height: 125,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
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
              final bool isFullWidth = (item['full_width'] == 1 || item['full_width'] == true || item['full_width'] == '1');
              final bannerRadius = isFullWidth ? BorderRadius.zero : BorderRadius.circular(14);
              final bannerMargin = EdgeInsets.symmetric(horizontal: isFullWidth ? 0 : 14);

              return Container(
                margin: bannerMargin,
                decoration: BoxDecoration(
                  borderRadius: bannerRadius,
                  boxShadow: (bg == 'none' || bg == 'transparent' || bg.isEmpty || removeWhiteBg || isFullWidth)
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                clipBehavior: isFullWidth ? Clip.none : Clip.antiAlias,
                child: SellerSlidersScreen.buildBannerBackground(
                  bg: bg,
                  overlayDim: overlayDim,
                  removeWhiteBg: removeWhiteBg,
                  imgFit: imgFit,
                  borderRadius: bannerRadius,
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
          if (widget.sliders.length > 1)
            Positioned(
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.sliders.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == index ? 16 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: _currentPage == index
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ultra-fluid clamping scroll physics that guarantees the sticky header
/// never separates from the body content (zero white gap), while providing
/// high-momentum, friction-reduced smooth scrolling on fast flings.
class StoreFluidScrollPhysics extends ClampingScrollPhysics {
  const StoreFluidScrollPhysics({super.parent});

  @override
  StoreFluidScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return StoreFluidScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    if (position.outOfRange) {
      double? min;
      if (position.pixels < position.minScrollExtent) {
        min = position.minScrollExtent;
      }
      if (position.pixels > position.maxScrollExtent) {
        min = position.maxScrollExtent;
      }
      return ScrollSpringSimulation(spring, position.pixels, min!, velocity, tolerance: tolerance);
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity * 1.20,
      friction: 0.010,
      tolerance: tolerance,
    );
  }
}

class _StoreHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final Widget topInfoWidget;
  final Widget? stickyWidget;
  final Widget Function(BuildContext context, double collapseRatio)? stickyBuilder;
  final BoxDecoration decoration;
  final BoxDecoration stickyDecoration;
  final Widget backgroundParticles;
  final Widget lottieCarousel;
  final Widget shiningBeam;

  _StoreHeaderDelegate({
    required this.topPadding,
    required this.topInfoWidget,
    this.stickyWidget,
    this.stickyBuilder,
    required this.decoration,
    required this.stickyDecoration,
    required this.backgroundParticles,
    required this.lottieCarousel,
    required this.shiningBeam,
  });

  static const double _topInfoHeight = 128.0;
  static const double _stickyHeight = 118.0;

  @override
  double get minExtent => topPadding + _stickyHeight;

  @override
  double get maxExtent => topPadding + _topInfoHeight + _stickyHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double stickyTop = math.max(topPadding, topPadding + _topInfoHeight - shrinkOffset);
    final double collapseRatio = (shrinkOffset / _topInfoHeight).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: ClipRect(
        child: Container(
          decoration: decoration,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Floating Translucent Grocery Icons Background Particles
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - collapseRatio * 0.8).clamp(0.0, 1.0),
                  child: RepaintBoundary(child: backgroundParticles),
                ),
              ),

              // Flipkart Style Festive & Custom Seller Lottie Animation Overlay Carousel
              // Smoothly fade out as header collapses so the sticky scrolled background shows!
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - collapseRatio).clamp(0.0, 1.0),
                  child: RepaintBoundary(child: lottieCarousel),
                ),
              ),

              // Sticky / Scrolled Header Background Layer (Smoothly fades in as user scrolls!)
              if (collapseRatio > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: Curves.easeInOut.transform(collapseRatio),
                    child: Container(
                      decoration: stickyDecoration,
                    ),
                  ),
                ),

              // Continuous Metallic Shining Glass Light Beam
              Positioned.fill(child: RepaintBoundary(child: shiningBeam)),

              // Top Info (Daily Mart, Greeting, 15 minutes, Location) - Keep 100% solid and fully visible until scrolled away!
              if (shrinkOffset < _topInfoHeight)
                Positioned(
                  top: topPadding - shrinkOffset,
                  left: 0,
                  right: 0,
                  height: _topInfoHeight,
                  child: Opacity(
                    opacity: (1.0 - collapseRatio).clamp(0.0, 1.0),
                    child: SizedBox(
                      height: _topInfoHeight,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: topInfoWidget,
                      ),
                    ),
                  ),
                ),

              // Sticky Search Bar & Category Icons Strip (Stays pinned at top!)
              Positioned(
                top: stickyTop,
                left: 0,
                right: 0,
                height: _stickyHeight,
                child: SizedBox(
                  height: _stickyHeight,
                  child: stickyBuilder != null
                      ? stickyBuilder!(context, collapseRatio)
                      : (stickyWidget ?? const SizedBox.shrink()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StoreHeaderDelegate oldDelegate) => true;
}

/// Pure Flutter Smooth Animated Shimmer Provider
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1300),
  });

  static AppShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppShimmerState>();
  }

  @override
  State<AppShimmer> createState() => AppShimmerState();
}

class AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Listenable get listenable => _controller;

  double get percent => _controller.value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Shimmer Box with animated metallic reflection beam
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  const ShimmerBox.circular({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final shimmer = AppShimmer.of(context);

    if (shimmer == null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(8)),
          shape: shape,
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmer.listenable,
      builder: (context, child) {
        final p = shimmer.percent;
        final gradient = LinearGradient(
          begin: Alignment(-1.5 + (3.0 * p), -0.2),
          end: Alignment(-0.5 + (3.0 * p), 0.2),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFFFFFFF),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        );

        return Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(8)),
            shape: shape,
          ),
        );
      },
    );
  }
}

/// Blinkit / Zepto style Full Home Page Skeleton Loading Screen
class CustomerHomeSkeletonView extends StatelessWidget {
  final double topPadding;

  const CustomerHomeSkeletonView({
    super.key,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Banner Skeleton with Dark Theme & Shimmering Pills
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: topPadding + 6,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Title & Action Icons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 100,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Greeting & Time Badge
                    Row(
                      children: [
                        Container(
                          width: 85,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 140,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Location Pill
                    Container(
                      width: 160,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search Bar Pill (White Shimmering Container)
                    Container(
                      width: double.infinity,
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                          SizedBox(width: 10),
                          ShimmerBox(width: 130, height: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Header Category Icons Strip Skeleton
                    SizedBox(
                      height: 52,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          5,
                          (index) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 38,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
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

              const SizedBox(height: 12),

              // 2. Top Banner Slider Skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ShimmerBox(
                  width: double.infinity,
                  height: 120,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Category Grid Skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(width: 110, height: 16),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          4,
                          (index) => Column(
                            children: [
                              ShimmerBox(
                                width: 66,
                                height: 66,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              const SizedBox(height: 6),
                              const ShimmerBox(width: 50, height: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 4. Product Section Skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Title Ribbon
                      Row(
                        children: [
                          ShimmerBox(
                            width: 140,
                            height: 22,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 2-Column Product Cards Grid Skeleton
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildProductCardSkeleton()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildProductCardSkeleton()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildProductCardSkeleton()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildProductCardSkeleton()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCardSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image box
        AspectRatio(
          aspectRatio: 0.88,
          child: ShimmerBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 6),

        // Product Name lines
        const ShimmerBox(width: 110, height: 12),
        const SizedBox(height: 4),
        const ShimmerBox(width: 70, height: 10),
        const SizedBox(height: 4),

        // Rate
        const ShimmerBox(width: 60, height: 12),
        const SizedBox(height: 6),

        // Buy Now Button
        ShimmerBox(
          width: double.infinity,
          height: 27,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

