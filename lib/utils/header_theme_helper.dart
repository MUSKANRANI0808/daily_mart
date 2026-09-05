import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class HeaderThemeHelper {
  static List<Map<String, String>> get festivalPresets => [
    {
      'id': 'daily_mart_express',
      'name': 'Daily Mart Express Order & Safe Pickup 🚀',
      'title': 'EXPRESS ORDER & SAFE PICKUP ⚡',
      'url': 'assets/lottie/daily_mart_exclusive.json',
      'color1': '#0F172A',
      'color2': '#1E1B4B',
      'color3': '#312E81',
    },
    {
      'id': 'freedom_sale',
      'name': 'Freedom & Grand Sale Carnival 🎈',
      'title': 'FREEDOM SALE 🇮🇳',
      'url': 'assets/lottie/freedom_sale.json',
      'color1': '#0F172A',
      'color2': '#1E3A8A',
      'color3': '#D97706',
    },
    {
      'id': 'diwali_lights',
      'name': 'Diwali Fireworks & Festive Lights 🪔',
      'title': 'DIWALI FESTIVAL DHAMAKA 🪔',
      'url': 'assets/lottie/diwali_lights.json',
      'color1': '#450A0A',
      'color2': '#78350F',
      'color3': '#B45309',
    },
    {
      'id': 'grocery_shopping',
      'name': 'Flipkart Style Grocery Carnival 🛒',
      'title': 'GROCERY SHOPPING FESTIVAL 🛍️',
      'url': 'assets/lottie/grocery_shopping.json',
      'color1': '#064E3B',
      'color2': '#047857',
      'color3': '#10B981',
    },
    {
      'id': 'express_flash',
      'name': 'Express Flash Deals ⚡',
      'title': 'FLASH EXPRESS SALE ⚡',
      'url': 'assets/lottie/express_flash.json',
      'color1': '#111827',
      'color2': '#4C1D95',
      'color3': '#0EA5E9',
    },
    {
      'id': 'monsoon_rain',
      'name': 'Monsoon Fresh Rain Deals 🌧️',
      'title': 'MONSOON FRESH SALE 🌧️',
      'url': 'assets/lottie/monsoon_rain.json',
      'color1': '#0C4A6E',
      'color2': '#0284C7',
      'color3': '#38BDF8',
    },
    {
      'id': 'new_year',
      'name': 'Grand Celebration & Party 🎆',
      'title': 'MEGA CELEBRATION SALE 🎆',
      'url': 'assets/lottie/new_year.json',
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

  static BoxDecoration buildDecoration(Map<String, dynamic> config) {
    final c1 = hexToColor(config['color1']?.toString() ?? '#0F172A');
    final c2 = hexToColor(config['color2']?.toString() ?? '#1E1B4B');
    final c3Str = config['color3']?.toString() ?? '';
    final c3 = c3Str.isNotEmpty ? hexToColor(c3Str) : c2;

    final dir = (config['direction'] ?? 'diagonal').toString().toLowerCase();
    final shading = (config['shading'] ?? 'dark').toString().toLowerCase();

    List<Color> colors = [c1, c2, c3];
    if (shading == 'light') {
      colors = colors.map((c) => Color.alphaBlend(Colors.white.withValues(alpha: 0.18), c)).toList();
    } else if (shading == 'ultra_dark') {
      colors = colors.map((c) => Color.alphaBlend(Colors.black.withValues(alpha: 0.40), c)).toList();
    }

    if (dir == 'horizontal') {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      );
    } else if (dir == 'vertical') {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (dir == 'radial') {
      return BoxDecoration(
        gradient: RadialGradient(
          colors: colors,
          center: Alignment.center,
          radius: 1.2,
        ),
      );
    } else {
      // 'diagonal'
      return BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    }
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
Widget buildSingleLottieItem(String rawData, {BoxFit fit = BoxFit.cover}) {
  final clean = rawData.trim();
  if (clean.isEmpty) return const SizedBox.shrink();

  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return Lottie.network(
      clean,
      fit: fit,
      errorBuilder: (_, __, ___) => Lottie.asset(
        'assets/lottie/daily_mart_exclusive.json',
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  if (clean.startsWith('assets/')) {
    return Lottie.asset(
      clean,
      fit: fit,
      errorBuilder: (_, __, ___) => Lottie.asset(
        'assets/lottie/daily_mart_exclusive.json',
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  if (clean.contains('{') && clean.contains('}')) {
    try {
      return Lottie.string(
        clean,
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

    if (lottieUrl.isEmpty || lottieUrl.contains('lottiefiles.com')) {
      lottieUrl = 'assets/lottie/daily_mart_exclusive.json';
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
  final List<String>? overrideAnimations;

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
  List<String> _animations = [];
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
        widget.sellerUsername != oldWidget.sellerUsername) {
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

  void _setupCarousel(List<String> anims) {
    if (!mounted) return;
    _timer?.cancel();

    setState(() {
      _animations = anims;
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

    // Fallback to default festival animation if no custom animations uploaded
    if (_animations.isEmpty) {
      return FestivalLottieHeaderWidget(config: widget.config);
    }

    // Single Animation
    if (_animations.length == 1) {
      return IgnorePointer(
        child: Opacity(
          opacity: lottieOpacity.clamp(0.1, 1.0),
          child: SizedBox.expand(
            child: buildSingleLottieItem(_animations.first),
          ),
        ),
      );
    }

    // Multi-Animation Auto-Sliding PageView Carousel
    return IgnorePointer(
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

            // Subtle Sliding Indicator Dots
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
}
