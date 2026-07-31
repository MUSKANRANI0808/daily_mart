import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class AbstractPatternPainter extends CustomPainter {
  final String presetId;
  AbstractPatternPainter(this.presetId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final width = size.width;
    final height = size.height;

    switch (presetId) {
      case 'preset_1': // Purple Pink Bokeh Circles
        paint.color = Colors.white.withOpacity(0.09);
        canvas.drawCircle(Offset(width * 0.85, height * 0.8), 70, paint);
        canvas.drawCircle(Offset(width * 0.75, height * 0.4), 100, paint);
        canvas.drawCircle(Offset(width * 0.3, height * 0.2), 90, paint);
        canvas.drawCircle(Offset(width * 0.5, height * 0.7), 60, paint);
        break;
      case 'preset_2': // Ocean Waves
        paint.color = Colors.cyan.withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.9, height * 0.1), 120, paint);
        canvas.drawCircle(Offset(width * 0.1, height * 0.9), 110, paint);
        break;
      case 'preset_3': // Sunset Flare
        paint.color = Colors.amber.withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.2, height * 0.3), 80, paint);
        canvas.drawCircle(Offset(width * 0.8, height * 0.7), 130, paint);
        break;
      case 'preset_4': // Cyberpunk
        paint.color = const Color(0xFFA855F7).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.95, height * 0.5), 140, paint);
        canvas.drawCircle(Offset(width * 0.15, height * 0.8), 75, paint);
        break;
      case 'preset_5': // Emerald Mesh
        paint.color = const Color(0xFF34D399).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.7, height * 0.2), 110, paint);
        canvas.drawCircle(Offset(width * 0.2, height * 0.7), 90, paint);
        break;
      case 'preset_6': // Golden Luxury
        paint.color = const Color(0xFFFBBF24).withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.8, height * 0.3), 100, paint);
        canvas.drawCircle(Offset(width * 0.3, height * 0.8), 85, paint);
        break;
      case 'preset_7': // Neon Party
        paint.color = const Color(0xFFF43F5E).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.85, height * 0.7), 120, paint);
        canvas.drawCircle(Offset(width * 0.25, height * 0.3), 95, paint);
        break;
      case 'preset_8': // Royal Indigo
        paint.color = const Color(0xFFC084FC).withOpacity(0.15);
        canvas.drawCircle(Offset(width * 0.1, height * 0.2), 100, paint);
        canvas.drawCircle(Offset(width * 0.9, height * 0.8), 110, paint);
        break;
      case 'preset_9': // Cosmic Dark
        paint.color = const Color(0xFF38BDF8).withOpacity(0.12);
        canvas.drawCircle(Offset(width * 0.5, height * 0.2), 90, paint);
        canvas.drawCircle(Offset(width * 0.85, height * 0.7), 115, paint);
        break;
      case 'preset_10': // Coral Sunrise
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

class SellerSlidersScreen extends StatefulWidget {
  final UserModel seller;

  const SellerSlidersScreen({
    super.key,
    required this.seller,
  });

  static List<Map<String, dynamic>> get presetThemes => _SellerSlidersScreenState.presetThemes;
  static Color hexToColor(String code, {Color defaultColor = Colors.white}) => _SellerSlidersScreenState.hexToColor(code, defaultColor: defaultColor);
  static BoxDecoration buildTagDecoration(String shape, Color tagBg) => _SellerSlidersScreenState.buildTagDecoration(shape, tagBg);
  static Widget buildBannerBackground({required String bg, required Widget child, BorderRadius? borderRadius}) => _SellerSlidersScreenState.buildBannerBackground(bg: bg, child: child, borderRadius: borderRadius);

  @override
  State<SellerSlidersScreen> createState() => _SellerSlidersScreenState();
}

class _SellerSlidersScreenState extends State<SellerSlidersScreen> {
  List<Map<String, dynamic>> _sliders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSliders();
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
  }) {
    final preset = presetThemes.firstWhere(
      (p) => p['id'] == bg,
      orElse: () => {},
    );

    if (preset.isNotEmpty) {
      final List<Color> colors = List<Color>.from(preset['colors']);
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          painter: AbstractPatternPainter(bg),
          child: child,
        ),
      );
    }

    DecorationImage? decImg;
    if (bg.startsWith('data:image')) {
      try {
        final base64Str = bg.split(',').last;
        decImg = DecorationImage(
          image: MemoryImage(base64Decode(base64Str)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
        );
      } catch (_) {}
    } else if (bg.startsWith('http')) {
      decImg = DecorationImage(
        image: NetworkImage(bg),
        fit: BoxFit.cover,
        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
      );
    } else if (bg.isNotEmpty && !bg.startsWith('preset_')) {
      try {
        final file = File(bg);
        if (file.existsSync()) {
          decImg = DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
          );
        }
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: decImg == null
            ? const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)])
            : null,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        image: decImg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _loadSliders() async {
    setState(() => _isLoading = true);
    final list = await AuthService.getSellerSliders(widget.seller.username ?? '');
    if (mounted) {
      setState(() {
        _sliders = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddSliderDialog({Map<String, dynamic>? existingSlider}) async {
    final isEditing = existingSlider != null;
    final tagCtrl = TextEditingController(text: existingSlider?['tag'] ?? 'SEASON OFFER 🏷️');
    final titleCtrl = TextEditingController(text: existingSlider?['title'] ?? '');
    final descCtrl = TextEditingController(text: existingSlider?['description'] ?? '');
    String selectedImageData = existingSlider?['bg_image_url'] ?? 'preset_1';
    bool isPickingImage = false;

    String selectedTagBgColor = existingSlider?['tag_bg_color'] ?? '#10B981';
    String selectedTagShape = existingSlider?['tag_shape'] ?? 'pill';
    String selectedTitleColor = existingSlider?['title_color'] ?? '#FFFFFF';
    String selectedDescColor = existingSlider?['desc_color'] ?? '#E2E8F0';

    final tagBgColors = [
      {'name': 'Green', 'hex': '#10B981'},
      {'name': 'Red', 'hex': '#EF4444'},
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Gold', 'hex': '#F59E0B'},
      {'name': 'Purple', 'hex': '#8B5CF6'},
      {'name': 'Black', 'hex': '#0F172A'},
      {'name': 'Orange', 'hex': '#F97316'},
      {'name': 'Neon Lime', 'hex': '#84CC16'},
      {'name': 'Hot Pink', 'hex': '#EC4899'},
      {'name': 'Teal Cyan', 'hex': '#06B6D4'},
    ];

    final tagShapes = [
      {'label': 'Pill (Oval)', 'val': 'pill'},
      {'label': 'Circle (Round)', 'val': 'circle'},
      {'label': 'Square Box', 'val': 'square'},
      {'label': 'Rounded Card', 'val': 'rounded'},
      {'label': 'Badge Tag', 'val': 'badge'},
      {'label': 'Outline Border', 'val': 'outline'},
      {'label': 'Ribbon Flag', 'val': 'ribbon'},
      {'label': 'Diagonal Cut', 'val': 'stadium'},
    ];

    final titleColors = [
      {'name': 'Pure White', 'hex': '#FFFFFF'},
      {'name': 'Pitch Black', 'hex': '#000000'},
      {'name': 'Dark Charcoal', 'hex': '#0F172A'},
      {'name': 'Gold Yellow', 'hex': '#FDE047'},
      {'name': 'Electric Cyan', 'hex': '#22D3EE'},
      {'name': 'Mint Green', 'hex': '#6EE7B7'},
      {'name': 'Neon Lime', 'hex': '#A3E635'},
      {'name': 'Soft Pink', 'hex': '#F472B6'},
      {'name': 'Crimson Red', 'hex': '#F87171'},
      {'name': 'Vibrant Orange', 'hex': '#FB923C'},
      {'name': 'Royal Blue', 'hex': '#60A5FA'},
      {'name': 'Lavender', 'hex': '#C084FC'},
    ];

    final descColors = [
      {'name': 'Soft White', 'hex': '#E2E8F0'},
      {'name': 'Pure White', 'hex': '#FFFFFF'},
      {'name': 'Pitch Black', 'hex': '#000000'},
      {'name': 'Slate Gray', 'hex': '#334155'},
      {'name': 'Light Yellow', 'hex': '#FEF08A'},
      {'name': 'Sky Blue', 'hex': '#BAE6FD'},
      {'name': 'Pastel Mint', 'hex': '#A7F3D0'},
      {'name': 'Pastel Pink', 'hex': '#FBCFE8'},
      {'name': 'Peach Orange', 'hex': '#FFEDD5'},
      {'name': 'Light Gray', 'hex': '#94A3B8'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickGalleryImage() async {
              try {
                setDialogState(() => isPickingImage = true);
                final picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 65,
                  maxWidth: 800,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
                  setDialogState(() {
                    selectedImageData = base64Str;
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to pick image: $e')),
                  );
                }
              } finally {
                setDialogState(() => isPickingImage = false);
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Title & Close Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Edit Banner Slider' : 'Design Custom Slider',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Scrollable Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Offer Tag Text
                            const Text('Offer Tag Text *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: tagCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. SEASON OFFER 🏷️',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 1. Tag Background Color Selector
                            const Text('1. Offer Tag Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: tagBgColors.map((c) {
                                  final isSelected = selectedTagBgColor == c['hex'];
                                  final color = hexToColor(c['hex']!);
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedTagBgColor = c['hex']!),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                                      ),
                                      child: Text(
                                        c['name']!,
                                        style: TextStyle(
                                          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 2. Tag Shape Selector (8 Unique Shapes)
                            const Text('2. Offer Tag Shape (Round, Square, Ribbon...)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tagShapes.map((s) {
                                final isSelected = selectedTagShape == s['val'];
                                final tagBg = hexToColor(selectedTagBgColor);
                                return GestureDetector(
                                  onTap: () => setDialogState(() => selectedTagShape = s['val']!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: buildTagDecoration(s['val']!, isSelected ? tagBg : Colors.grey.shade300),
                                    child: Text(
                                      s['label']!,
                                      style: TextStyle(
                                        color: s['val'] == 'outline'
                                            ? (isSelected ? tagBg : Colors.black87)
                                            : (isSelected
                                                ? (tagBg.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                                : Colors.black87),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // Heading Text
                            const Text('Heading / Title *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: titleCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. Enjoy Fresh Delivery Today!',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 3. Heading Color Selector
                            const Text('3. Heading Text Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: titleColors.map((c) {
                                  final isSelected = selectedTitleColor == c['hex'];
                                  final color = hexToColor(c['hex']!);
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedTitleColor = c['hex']!),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: isSelected ? Border.all(color: const Color(0xFF8B5CF6), width: 1.8) : Border.all(color: Colors.black12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 13,
                                            height: 13,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: color == Colors.black ? Colors.white : Colors.black26, width: 1),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            c['name']!,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Paragraph Description Text
                            const Text('Paragraph / Description *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: descCtrl,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'e.g. Premium quality items delivered fast to your doorstep.',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 4. Paragraph Color Selector
                            const Text('4. Paragraph Text Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: descColors.map((c) {
                                  final isSelected = selectedDescColor == c['hex'];
                                  final color = hexToColor(c['hex']!);
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedDescColor = c['hex']!),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: isSelected ? Border.all(color: const Color(0xFF8B5CF6), width: 1.8) : Border.all(color: Colors.black12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 13,
                                            height: 13,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: color == Colors.black ? Colors.white : Colors.black26, width: 1),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            c['name']!,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFF334155),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5. 10 Default Preset Abstract Background Designs (Circles, Waves, Gradients)
                            const Text('5. Default Abstract Cards (10 Designs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 65,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: presetThemes.length,
                                separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                                itemBuilder: (ctx, idx) {
                                  final p = presetThemes[idx];
                                  final isSelected = selectedImageData == p['id'];
                                  final colors = List<Color>.from(p['colors']);
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedImageData = p['id']),
                                    child: Container(
                                      width: 110,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: colors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: isSelected ? Border.all(color: Colors.white, width: 2.5) : Border.all(color: Colors.black12),
                                        boxShadow: isSelected
                                            ? [BoxShadow(color: colors.last.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 3))]
                                            : null,
                                      ),
                                      child: CustomPaint(
                                        painter: AbstractPatternPainter(p['id']),
                                        child: Center(
                                          child: Text(
                                            p['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                              shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),

                            // OR Choose Custom Photo from Phone Gallery
                            Row(
                              children: const [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('OR Upload Photo from Phone', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Recommended Size Guide Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE047)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.aspect_ratio_rounded, size: 16, color: Color(0xFFD97706)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Recommended Size: 800 x 400 px (Ratio 2:1)',
                                      style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            selectedImageData.isNotEmpty && !selectedImageData.startsWith('preset_')
                                ? Stack(
                                    children: [
                                      Container(
                                        height: 110,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: MemoryImage(base64Decode(selectedImageData.split(',').last)),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.black54,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                            onPressed: () {
                                              setDialogState(() => selectedImageData = 'preset_1');
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : InkWell(
                                    onTap: isPickingImage ? null : pickGalleryImage,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          isPickingImage
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)))
                                              : const Icon(Icons.photo_library_rounded, color: Color(0xFF8B5CF6)),
                                          const SizedBox(width: 8),
                                          Text(
                                            isPickingImage ? 'Opening Gallery...' : 'Choose Image from Gallery 🖼️',
                                            style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Fixed Action Buttons Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final tag = tagCtrl.text.trim();
                            final title = titleCtrl.text.trim();
                            final desc = descCtrl.text.trim();

                            if (title.isEmpty || desc.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter heading and description.')),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            bool success = false;
                            if (isEditing) {
                              success = await AuthService.updateSellerSlider(
                                sliderId: existingSlider['id'],
                                sellerUsername: widget.seller.username ?? '',
                                tag: tag.isEmpty ? 'OFFER 🏷️' : tag,
                                title: title,
                                description: desc,
                                bgImageUrl: selectedImageData,
                                tagBgColor: selectedTagBgColor,
                                tagShape: selectedTagShape,
                                titleColor: selectedTitleColor,
                                descColor: selectedDescColor,
                              );
                            } else {
                              success = await AuthService.addSellerSlider(
                                sellerUsername: widget.seller.username ?? '',
                                tag: tag.isEmpty ? 'OFFER 🏷️' : tag,
                                title: title,
                                description: desc,
                                bgImageUrl: selectedImageData,
                                tagBgColor: selectedTagBgColor,
                                tagShape: selectedTagShape,
                                titleColor: selectedTitleColor,
                                descColor: selectedDescColor,
                              );
                            }

                            if (success) {
                              await _loadSliders();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isEditing ? 'Slider updated successfully!' : 'Custom Styled Slider added!')),
                                );
                              }
                            }
                          },
                          child: Text(isEditing ? 'Update Banner' : 'Save Banner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSlider(dynamic sliderId) async {
    final success = await AuthService.deleteSellerSlider(sliderId, widget.seller.username ?? '');
    if (success) {
      await _loadSliders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner Slider deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Manage Banner Sliders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC4B5FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.palette_rounded, color: Color(0xFF7C3AED)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Create Custom Promo Banners & Sliders',
                                style: TextStyle(color: Color(0xFF5B21B6), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '🎨 10 Preset Abstract Card Designs included!\n📐 Recommended Image Size: 800 x 400 px (Ratio 2:1)',
                          style: TextStyle(color: Color(0xFF6D28D9), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Banners (${_sliders.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddSliderDialog,
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        label: const Text('Add Slider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _sliders.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.style_outlined, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('No banners added yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black54)),
                              SizedBox(height: 4),
                              Text('Tap "+ Add Slider" to choose from 10 abstract design cards or gallery image & create banner!', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sliders.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 16),
                          itemBuilder: (ctx, idx) {
                            final slider = _sliders[idx];
                            final tag = slider['tag'] ?? 'OFFER 🏷️';
                            final title = slider['title'] ?? '';
                            final desc = slider['description'] ?? '';
                            final bg = slider['bg_image_url'] ?? 'preset_1';
                            final tagBg = hexToColor(slider['tag_bg_color'] ?? '#10B981');
                            final tagShape = slider['tag_shape'] ?? 'pill';
                            final titleCol = hexToColor(slider['title_color'] ?? '#FFFFFF');
                            final descCol = hexToColor(slider['desc_color'] ?? '#E2E8F0');

                            return Stack(
                              children: [
                                buildBannerBackground(
                                  bg: bg,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                        const SizedBox(height: 10),
                                        Padding(
                                          padding: const EdgeInsets.only(right: 76),
                                          child: Text(
                                            title,
                                            style: TextStyle(color: titleCol, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          desc,
                                          style: TextStyle(color: descCol, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit Button
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(0xFF3B82F6),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                          onPressed: () => _showAddSliderDialog(existingSlider: slider),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete Button
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.red.shade600,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                          onPressed: () => _deleteSlider(slider['id']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}
