import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/auth_service.dart';

class HeaderThemeHelper {
  static List<Map<String, String>> get festivalPresets => [
    {
      'id': 'daily_mart_express',
      'name': 'Daily Mart Express Order & Safe Pickup 🚀',
      'title': 'EXPRESS ORDER & SAFE PICKUP ⚡',
      'url': '',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
    },
    {
      'id': 'freedom_sale',
      'name': 'Freedom & Grand Sale Carnival 🎈',
      'title': 'FREEDOM SALE 🇮🇳',
      'url': '',
      'color1': '#0F172A',
      'color2': '#1E3A8A',
      'color3': '#D97706',
    },
    {
      'id': 'diwali_lights',
      'name': 'Diwali Fireworks & Festive Lights 🪔',
      'title': 'DIWALI FESTIVAL DHAMAKA 🪔',
      'url': '',
      'color1': '#450A0A',
      'color2': '#78350F',
      'color3': '#B45309',
    },
    {
      'id': 'grocery_shopping',
      'name': 'Flipkart Style Grocery Carnival 🛒',
      'title': 'GROCERY SHOPPING FESTIVAL 🛍️',
      'url': '',
      'color1': '#064E3B',
      'color2': '#047857',
      'color3': '#10B981',
    },
    {
      'id': 'express_flash',
      'name': 'Express Flash Deals ⚡',
      'title': 'FLASH EXPRESS SALE ⚡',
      'url': '',
      'color1': '#111827',
      'color2': '#4C1D95',
      'color3': '#0EA5E9',
    },
    {
      'id': 'monsoon_rain',
      'name': 'Monsoon Fresh Rain Deals 🌧️',
      'title': 'MONSOON FRESH SALE 🌧️',
      'url': '',
      'color1': '#0C4A6E',
      'color2': '#0284C7',
      'color3': '#38BDF8',
    },
    {
      'id': 'new_year',
      'name': 'Grand Celebration & Party 🎆',
      'title': 'MEGA CELEBRATION SALE 🎆',
      'url': '',
      'color1': '#311B92',
      'color2': '#6A1B9A',
      'color3': '#AD1457',
    },
  ];

  static Color hexToColor(String code, {Color defaultColor = const Color(0xFF0F172A)}) {
    try {
      String cleanHex = code.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  static List<Map<String, dynamic>> get presets => [
    {
      'id': 'midnight_navy',
      'name': 'Midnight Navy (Default)',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
      'direction': 'diagonal',
      'shading': 'dark',
      'icon': '🌙',
    },
    {
      'id': 'royal_purple',
      'name': 'Royal Purple Sapphire',
      'color1': '#2E1065',
      'color2': '#581C87',
      'color3': '#7E22CE',
      'direction': 'diagonal',
      'shading': 'dark',
      'icon': '🟣',
    },
    {
      'id': 'emerald_forest',
      'name': 'Emerald Deep Forest',
      'color1': '#064E3B',
      'color2': '#047857',
      'color3': '#059669',
      'direction': 'horizontal',
      'shading': 'medium',
      'icon': '🌲',
    },
    {
      'id': 'ocean_cyan',
      'name': 'Ocean Deep Cyan',
      'color1': '#0C4A6E',
      'color2': '#0284C7',
      'color3': '#0369A1',
      'direction': 'vertical',
      'shading': 'medium',
      'icon': '🌊',
    },
    {
      'id': 'sunset_crimson',
      'name': 'Sunset Crimson Flare',
      'color1': '#881337',
      'color2': '#BE123C',
      'color3': '#E11D48',
      'direction': 'diagonal',
      'shading': 'dark',
      'icon': '🌅',
    },
    {
      'id': 'golden_luxe',
      'name': 'Golden Luxe Amber',
      'color1': '#451A03',
      'color2': '#78350F',
      'color3': '#D97706',
      'direction': 'radial',
      'shading': 'dark',
      'icon': '👑',
    },
    {
      'id': 'cyberpunk_dark',
      'name': 'Cosmic Cyberpunk',
      'color1': '#18181B',
      'color2': '#6D28D9',
      'color3': '#A855F7',
      'direction': 'diagonal',
      'shading': 'ultra_dark',
      'icon': '🌌',
    },
    {
      'id': 'ruby_velvet',
      'name': 'Ruby Velvet Rose',
      'color1': '#4C0519',
      'color2': '#9F1239',
      'color3': '#E11D48',
      'direction': 'horizontal',
      'shading': 'dark',
      'icon': '🍷',
    },
    {
      'id': 'satin_silver',
      'name': 'Satin Metallic Silver',
      'color1': '#1E293B',
      'color2': '#334155',
      'color3': '#475569',
      'direction': 'vertical',
      'shading': 'medium',
      'icon': '💎',
    },
    {
      'id': 'neon_mint',
      'name': 'Neon Emerald Mint',
      'color1': '#022C22',
      'color2': '#047857',
      'color3': '#10B981',
      'direction': 'radial',
      'shading': 'dark',
      'icon': '⚡',
    },
    {
      'id': 'custom',
      'name': 'Custom Gradient Mode',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
      'direction': 'diagonal',
      'shading': 'medium',
      'icon': '🎨',
    },
  ];

  static DecorationImage? buildDecorationImage(String? imageSource) {
    if (imageSource == null) return null;
    final clean = imageSource.trim();
    if (clean.isEmpty || clean == 'null' || clean == 'undefined') return null;

    final ImageProvider provider;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      provider = NetworkImage(clean);
    } else if (clean.startsWith('assets/')) {
      provider = AssetImage(clean);
    } else {
      try {
        String base64Str = clean;
        if (clean.contains(',')) {
          base64Str = clean.split(',').last.trim();
        }
        final bytes = base64Decode(base64Str);
        provider = MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    return DecorationImage(
      image: provider,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      onError: (exception, stackTrace) {},
    );
  }

  static BoxDecoration buildDecoration(Map<String, dynamic> config) {
    final c1 = hexToColor(config['color1']?.toString() ?? '#0F172A');
    final c2 = hexToColor(config['color2']?.toString() ?? '#1E1B4B');
    final c3Str = config['color3']?.toString();

    List<Color> colors = [c1, c2];
    if (c3Str != null && c3Str.trim().isNotEmpty && c3Str.trim() != config['color2']?.toString().trim()) {
      final c3 = hexToColor(c3Str);
      if (c3 != c2 && c3 != c1) {
        colors = [c1, c2, c3];
      }
    }

    final dir = (config['direction'] ?? 'diagonal').toString().toLowerCase();
    final shading = (config['shading'] ?? 'dark').toString().toLowerCase();

    if (shading == 'light') {
      colors = colors.map((c) => Color.alphaBlend(Colors.white.withValues(alpha: 0.18), c)).toList();
    } else if (shading == 'ultra_dark') {
      colors = colors.map((c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.40), c)).toList();
    }

    Gradient gradient;
    if (dir == 'horizontal') {
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    } else if (dir == 'vertical') {
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else if (dir == 'radial') {
      gradient = RadialGradient(
        colors: colors,
        center: Alignment.center,
        radius: 1.2,
      );
    } else {
      // 'diagonal'
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final String? bgImgStr = config['bg_image']?.toString() ??
        config['background_image']?.toString() ??
        config['header_bg_image']?.toString();

    final DecorationImage? decImg = buildDecorationImage(bgImgStr);

    return BoxDecoration(
      gradient: gradient,
      image: decImg,
    );
  }

  static BoxDecoration buildStickyDecoration(Map<String, dynamic> config) {
    final c1Str = config['sticky_color1']?.toString() ?? config['color1']?.toString() ?? '#0F172A';
    final c2Str = config['sticky_color2']?.toString() ?? config['color2']?.toString() ?? '#1E1B4B';
    final c1 = hexToColor(c1Str);
    final c2 = hexToColor(c2Str);
    final List<Color> colors = [c1, c2];

    final dir = (config['sticky_direction'] ?? config['direction'] ?? 'horizontal').toString().toLowerCase();

    Gradient gradient;
    if (dir == 'horizontal') {
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    } else if (dir == 'vertical') {
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else if (dir == 'radial') {
      gradient = RadialGradient(
        colors: colors,
        center: Alignment.center,
        radius: 1.2,
      );
    } else {
      gradient = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return BoxDecoration(
      gradient: gradient,
    );
  }

  /// Get Category Icon & Text Color for Full Header
  static Color getCategoryIconColor(Map<String, dynamic> config) {
    final hex = config['category_icon_color'] ?? config['icon_color'] ?? '#FFFFFF';
    return hexToColor(hex.toString());
  }

  /// Get Category Icon & Text Color for Sticky Scrolled Header
  static Color getStickyCategoryIconColor(Map<String, dynamic> config) {
    final hex = config['sticky_category_icon_color'] ?? config['sticky_icon_color'] ?? config['category_icon_color'] ?? '#FFFFFF';
    return hexToColor(hex.toString());
  }
}

/// Continuous Animated Metallic Glass Beam Overlay Widget
class ContinuousShiningGlassBeamWidget extends StatefulWidget {
  const ContinuousShiningGlassBeamWidget({super.key});

  @override
  State<ContinuousShiningGlassBeamWidget> createState() => _ContinuousShiningGlassBeamWidgetState();
}

class _ContinuousShiningGlassBeamWidgetState extends State<ContinuousShiningGlassBeamWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2600),
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

        return IgnorePointer(
          child: SizedBox.expand(
            child: FractionallySizedBox(
              widthFactor: 0.45,
              alignment: Alignment(alignX, 0),
              child: Transform(
                transform: Matrix4.skewX(-0.35),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper method to build single Lottie animation from URL, Asset, JSON string or Base64 memory
Widget buildSingleLottieItem(dynamic rawData, {BoxFit fit = BoxFit.cover}) {
  String clean = '';
  if (rawData is Map) {
    clean = (rawData['animation'] ?? rawData['url'] ?? rawData['data'] ?? '').toString().trim();
  } else if (rawData is String) {
    final str = rawData.trim();
    if (str.startsWith('{') && str.endsWith('}')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map && (decoded.containsKey('animation') || decoded.containsKey('url') || decoded.containsKey('data'))) {
          clean = (decoded['animation'] ?? decoded['url'] ?? decoded['data'] ?? '').toString().trim();
        } else {
          clean = str;
        }
      } catch (_) {
        clean = str;
      }
    } else {
      clean = str;
    }
  } else {
    clean = (rawData ?? '').toString().trim();
  }

  if (clean.isEmpty || clean.startsWith('assets/') || clean.contains('daily_mart_exclusive.json')) {
    return const SizedBox.shrink();
  }

  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return Lottie.network(
      clean,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  if (clean.contains('{') && clean.contains('}')) {
    try {
      final bytes = Uint8List.fromList(utf8.encode(clean));
      return Lottie.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } catch (_) {}
  }

  try {
    String base64Str = clean;
    if (clean.contains(',')) {
      base64Str = clean.split(',').last.trim();
    }
    final bytes = base64Decode(base64Str);
    return Lottie.memory(
      bytes,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  } catch (_) {}

  return const SizedBox.shrink();
}

/// Dynamic Festival Lottie Vector Animation Overlay Widget
class FestivalLottieHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> config;
  const FestivalLottieHeaderWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    String lottieUrl = (config['lottie_url'] ?? '').toString().trim();
    final double lottieOpacity = (config['lottie_opacity'] as num?)?.toDouble() ?? 0.85;

    if (lottieUrl.isEmpty || lottieUrl.contains('daily_mart_exclusive.json') || lottieUrl.contains('lottiefiles.com')) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Opacity(
        opacity: lottieOpacity.clamp(0.1, 1.0),
        child: SizedBox.expand(
          child: buildSingleLottieItem(lottieUrl),
        ),
      ),
    );
  }
}

/// Dynamic Auto-Sliding Header Lottie Animations Carousel Widget
class HeaderLottieCarouselWidget extends StatefulWidget {
  final String? sellerUsername;
  final Map<String, dynamic> config;
  final List<dynamic>? overrideAnimations;

  const HeaderLottieCarouselWidget({
    super.key,
    this.sellerUsername,
    required this.config,
    this.overrideAnimations,
  });

  @override
  State<HeaderLottieCarouselWidget> createState() => _HeaderLottieCarouselWidgetState();
}

class _HeaderLottieCarouselWidgetState extends State<HeaderLottieCarouselWidget> {
  List<dynamic> _animations = [];
  PageController? _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadAnimations();
  }

  @override
  void didUpdateWidget(covariant HeaderLottieCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overrideAnimations != oldWidget.overrideAnimations ||
        widget.sellerUsername != oldWidget.sellerUsername ||
        widget.config != oldWidget.config) {
      _loadAnimations();
    }
  }

  Future<void> _loadAnimations() async {
    if (widget.overrideAnimations != null) {
      _setupCarousel(widget.overrideAnimations!);
      return;
    }

    final sUsername = widget.sellerUsername;
    if (sUsername != null && sUsername.isNotEmpty) {
      final cached = AuthService.getCachedSellerHeaderAnimations(sUsername);
      if (cached != null && cached.isNotEmpty) {
        _setupCarousel(cached);
      }

      final fresh = await AuthService.getSellerHeaderAnimations(sUsername);
      if (mounted) {
        _setupCarousel(fresh);
      }
      return;
    }

    _setupCarousel([]);
  }

  void _setupCarousel(List<dynamic> anims) {
    if (!mounted) return;
    _timer?.cancel();

    final validAnims = anims.where((a) {
      if (a == null) return false;
      final String str = a is Map ? (a['url'] ?? a['data'] ?? '').toString() : a.toString();
      final clean = str.trim();
      return clean.isNotEmpty && !clean.startsWith('assets/') && !clean.contains('daily_mart_exclusive.json');
    }).toList();

    setState(() {
      _animations = validAnims;
      _currentPage = 0;
    });

    if (_animations.length > 1) {
      _pageController?.dispose();
      _pageController = PageController(initialPage: 0);
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted || _animations.length <= 1 || _pageController == null || !_pageController!.hasClients) return;
        _currentPage = (_currentPage + 1) % _animations.length;
        _pageController!.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double lottieOpacity = (widget.config['lottie_opacity'] as num?)?.toDouble() ?? 0.85;

    if (_animations.isEmpty) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: HeaderThemeHelper.buildDecoration(widget.config),
      );
    }

    final currentItem = _animations[_currentPage % _animations.length];
    final Map<String, dynamic> currentSlideConfig = Map<String, dynamic>.from(widget.config);
    if (currentItem is Map) {
      if (currentItem['color1'] != null) currentSlideConfig['color1'] = currentItem['color1'];
      if (currentItem['color2'] != null) currentSlideConfig['color2'] = currentItem['color2'];
      if (currentItem['direction'] != null) currentSlideConfig['direction'] = currentItem['direction'];
      if (currentItem.containsKey('bg_image')) {
        currentSlideConfig['bg_image'] = currentItem['bg_image'];
      }
      if (currentItem.containsKey('background_image')) {
        currentSlideConfig['background_image'] = currentItem['background_image'];
      }
    } else if (currentItem is String && currentItem.trim().startsWith('{') && currentItem.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(currentItem.trim());
        if (decoded is Map) {
          if (decoded['color1'] != null) currentSlideConfig['color1'] = decoded['color1'];
          if (decoded['color2'] != null) currentSlideConfig['color2'] = decoded['color2'];
          if (decoded['direction'] != null) currentSlideConfig['direction'] = decoded['direction'];
          if (decoded.containsKey('bg_image')) {
            currentSlideConfig['bg_image'] = decoded['bg_image'];
          }
          if (decoded.containsKey('background_image')) {
            currentSlideConfig['background_image'] = decoded['background_image'];
          }
        }
      } catch (_) {}
    }

    Widget carouselBody;
    if (_animations.length == 1) {
      carouselBody = IgnorePointer(
        child: Opacity(
          opacity: lottieOpacity.clamp(0.1, 1.0),
          child: SizedBox.expand(
            child: buildSingleLottieItem(_animations.first),
          ),
        ),
      );
    } else {
      carouselBody = IgnorePointer(
        child: Opacity(
          opacity: lottieOpacity.clamp(0.1, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentPage = index;
                    });
                  }
                },
                itemCount: _animations.length,
                itemBuilder: (ctx, index) {
                  return buildSingleLottieItem(_animations[index]);
                },
              ),

              // Sliding Indicator Dots
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_animations.length, (idx) {
                    final isSel = idx == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isSel ? 18 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: HeaderThemeHelper.buildDecoration(currentSlideConfig),
      child: carouselBody,
    );
  }
}
