import 'package:flutter/material.dart';

class HeaderThemeHelper {
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

        return Positioned.fill(
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
        );
      },
    );
  }
}
