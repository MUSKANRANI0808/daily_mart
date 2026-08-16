import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullColorPickerDialog extends StatefulWidget {
  final String initialHex;
  final Function(String selectedHex) onColorSelected;

  const FullColorPickerDialog({
    super.key,
    required this.initialHex,
    required this.onColorSelected,
  });

  static void show(
    BuildContext context, {
    required String initialHex,
    required Function(String selectedHex) onColorSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => FullColorPickerDialog(
        initialHex: initialHex,
        onColorSelected: onColorSelected,
      ),
    );
  }

  @override
  State<FullColorPickerDialog> createState() => _FullColorPickerDialogState();
}

class _FullColorPickerDialogState extends State<FullColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;
  bool _isInternalTextUpdate = false;

  @override
  void initState() {
    super.initState();
    final initialColor = _parseHexColor(widget.initialHex);
    final hsv = HSVColor.fromColor(initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;

    _hexController = TextEditingController(text: _formatHex(initialColor));
    _hexController.addListener(_onHexInputChanged);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color _parseHexColor(String hexString) {
    try {
      String hex = hexString.replaceAll('#', '').trim();
      if (hex.length == 3) {
        hex = hex.split('').map((c) => '$c$c').join('');
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      final val = int.parse(hex, radix: 16);
      return Color(val);
    } catch (_) {
      return Colors.white;
    }
  }

  String _formatHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  void _onHexInputChanged() {
    if (_isInternalTextUpdate) return;
    final text = _hexController.text.trim();
    String hex = text.replaceAll('#', '');
    if (hex.length == 6) {
      final newColor = _parseHexColor(hex);
      final hsv = HSVColor.fromColor(newColor);
      setState(() {
        _hue = hsv.hue;
        _saturation = hsv.saturation;
        _value = hsv.value;
      });
    }
  }

  void _updateFromHSV(double h, double s, double v) {
    setState(() {
      _hue = h;
      _saturation = s;
      _value = v;
      _isInternalTextUpdate = true;
      _hexController.text = _formatHex(_currentColor);
      _isInternalTextUpdate = false;
    });
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    // CMYK Math
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;
    final k = 1.0 - [rNorm, gNorm, bNorm].reduce(math.max);
    final c = k >= 1.0 ? 0.0 : (1.0 - rNorm - k) / (1.0 - k);
    final m = k >= 1.0 ? 0.0 : (1.0 - gNorm - k) / (1.0 - k);
    final y = k >= 1.0 ? 0.0 : (1.0 - bNorm - k) / (1.0 - k);

    final rgbStr = '$r, $g, $b';
    final cmykStr = '${(c * 100).round()}%, ${(m * 100).round()}%, ${(y * 100).round()}%, ${(k * 100).round()}%';
    final hsvStr = '${_hue.round()}°, ${(_saturation * 100).round()}%, ${(_value * 100).round()}%';

    final hsl = HSLColor.fromColor(color);
    final hslStr = '${hsl.hue.round()}°, ${(hsl.saturation * 100).round()}%, ${(hsl.lightness * 100).round()}%';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Choose Color / Code 🎨',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Box: Preview Left + Saturation/Value Box Right
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  // Left Solid Color Preview Box
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),

                  // Right Saturation-Value 2D Gradient Box
                  Expanded(
                    flex: 2,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        return GestureDetector(
                          onPanDown: (details) => _handleSatValTouch(details.localPosition, width, height),
                          onPanUpdate: (details) => _handleSatValTouch(details.localPosition, width, height),
                          child: Stack(
                            children: [
                              // Hue Base Layer
                              Container(
                                decoration: BoxDecoration(
                                  color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                              // Horizontal White Gradient
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Colors.transparent],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                              // Vertical Black Gradient
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                              // Draggable Target Handle Circle
                              Positioned(
                                left: (_saturation * width - 10).clamp(0.0, width - 20),
                                top: ((1.0 - _value) * height - 10).clamp(0.0, height - 20),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black45, blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Middle: Rainbow Hue Slider Bar
            SizedBox(
              height: 24,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;

                  return GestureDetector(
                    onPanDown: (details) => _handleHueTouch(details.localPosition.dx, width),
                    onPanUpdate: (details) => _handleHueTouch(details.localPosition.dx, width),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: ((_hue / 360.0) * width - 12).clamp(0.0, width - 24),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // HEX Input Box with Label & Copy Icon
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'HEX',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _hexController.text.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied ${_hexController.text} to clipboard!'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Metric Badges: RGB, CMYK, HSV, HSL
            Row(
              children: [
                Expanded(child: _buildMetricCard('RGB', rgbStr)),
                const SizedBox(width: 6),
                Expanded(child: _buildMetricCard('CMYK', cmykStr)),
                const SizedBox(width: 6),
                Expanded(child: _buildMetricCard('HSV', hsvStr)),
                const SizedBox(width: 6),
                Expanded(child: _buildMetricCard('HSL', hslStr)),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final selectedHex = _formatHex(_currentColor);
                    widget.onColorSelected(selectedHex);
                    Navigator.pop(context);
                  },
                  child: const Text('Select Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSatValTouch(Offset localPos, double width, double height) {
    final s = (localPos.dx / width).clamp(0.0, 1.0);
    final v = (1.0 - (localPos.dy / height)).clamp(0.0, 1.0);
    _updateFromHSV(_hue, s, v);
  }

  void _handleHueTouch(double dx, double width) {
    final h = ((dx / width) * 360.0).clamp(0.0, 360.0);
    _updateFromHSV(h, _saturation, _value);
  }
}
