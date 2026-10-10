import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../utils/app_toast.dart';
import 'product_border_wrapper.dart';

void showProductDetailBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> product,
  required String sellerUsername,
  List<Map<String, dynamic>>? allProducts,
  VoidCallback? onCartUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProductDetailBottomSheet(
      product: product,
      sellerUsername: sellerUsername,
      allProducts: allProducts,
      onCartUpdated: onCartUpdated,
    ),
  );
}

/// Formats WhatsApp style markdown: *bold*, _italic_, ~strikethrough~
List<TextSpan> parseFormattedTextSpans(String text, TextStyle baseStyle) {
  final List<TextSpan> spans = [];
  // Regex matching *bold*, _italic_, and ~strike~
  final RegExp exp = RegExp(r'(\*[^\*]+\*)|(_[^_]+_)|(~[^~]+~)');
  int lastMatchEnd = 0;

  for (final Match match in exp.allMatches(text)) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: baseStyle,
      ));
    }

    final String matchedStr = match.group(0)!;
    if (matchedStr.startsWith('*') && matchedStr.endsWith('*') && matchedStr.length > 2) {
      spans.add(TextSpan(
        text: matchedStr.substring(1, matchedStr.length - 1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
      ));
    } else if (matchedStr.startsWith('_') && matchedStr.endsWith('_') && matchedStr.length > 2) {
      spans.add(TextSpan(
        text: matchedStr.substring(1, matchedStr.length - 1),
        style: baseStyle.copyWith(fontStyle: FontStyle.italic),
      ));
    } else if (matchedStr.startsWith('~') && matchedStr.endsWith('~') && matchedStr.length > 2) {
      spans.add(TextSpan(
        text: matchedStr.substring(1, matchedStr.length - 1),
        style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
      ));
    } else {
      spans.add(TextSpan(text: matchedStr, style: baseStyle));
    }

    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastMatchEnd),
      style: baseStyle,
    ));
  }

  return spans;
}

class ProductDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String sellerUsername;
  final List<Map<String, dynamic>>? allProducts;
  final VoidCallback? onCartUpdated;

  const ProductDetailBottomSheet({
    super.key,
    required this.product,
    required this.sellerUsername,
    this.allProducts,
    this.onCartUpdated,
  });

  @override
  State<ProductDetailBottomSheet> createState() => _ProductDetailBottomSheetState();
}

class _ProductDetailBottomSheetState extends State<ProductDetailBottomSheet> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _currentProduct;
  late TextEditingController _qtyController;
  late String _defaultBaseUnit;
  late double _defaultBaseRate;
  late String _baseUnit;
  late String _selectedUnit;
  late int _quantity;
  late double _baseRate;
  late List<String> _compatibleUnits;
  List<Map<String, dynamic>> _variants = [];
  int _selectedVariantIndex = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Color _relatedItemBgColor = const Color(0xFFF8FAFC);

  Color _parseHexColor(String hexString, {Color defaultColor = const Color(0xFFF8FAFC)}) {
    try {
      String cleanHex = hexString.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      if (cleanHex.length == 8) return Color(int.parse('0x$cleanHex'));
    } catch (_) {}
    return defaultColor;
  }

  void _loadRelatedItemBg() async {
    final cached = AuthService.getCachedSellerRelatedItemBg(widget.sellerUsername);
    if (cached != null && cached.isNotEmpty) {
      _relatedItemBgColor = _parseHexColor(cached);
    }
    try {
      final fresh = await AuthService.getSellerRelatedItemBg(widget.sellerUsername);
      if (fresh.isNotEmpty && mounted) {
        setState(() {
          _relatedItemBgColor = _parseHexColor(fresh);
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '1');
    _initProductData(widget.product);
    _loadRelatedItemBg();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.linear,
    );
  }

  List<Map<String, dynamic>> _parseVariants(dynamic rawVariants) {
    if (rawVariants == null) return [];
    try {
      List<dynamic> list = [];
      if (rawVariants is String) {
        final trimmed = rawVariants.trim();
        if (trimmed.isEmpty) return [];
        final decoded = jsonDecode(trimmed);
        if (decoded is List) list = decoded;
      } else if (rawVariants is List) {
        list = rawVariants;
      }
      final result = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is Map) {
          final name = (item['name'] ?? item['variant_name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final pRate = double.tryParse((item['purchase_rate'] ?? item['p_rate'] ?? 0).toString()) ?? 0.0;
          final sRate = double.tryParse((item['rate'] ?? item['sale_rate'] ?? item['s_rate'] ?? 0).toString()) ?? 0.0;
          final vImg = (item['image_url'] ?? item['image'] ?? '').toString().trim();
          result.add({
            'name': name,
            'purchase_rate': pRate,
            'rate': sRate,
            'image_url': vImg,
          });
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  void _initProductData(Map<String, dynamic> prod) {
    _currentProduct = prod;
    final defaultProductUnit = (prod['unit'] ?? 'Pcs').toString().trim();
    _defaultBaseUnit = defaultProductUnit.isNotEmpty ? defaultProductUnit : 'Pcs';
    _defaultBaseRate = (prod['rate'] as num?)?.toDouble() ?? 0.0;
    _variants = _parseVariants(prod['variants']);

    _selectedVariantIndex = -1;
    _baseUnit = _defaultBaseUnit;
    _compatibleUnits = _getCompatibleUnits(_baseUnit);
    _selectedUnit = _compatibleUnits.contains(_baseUnit) ? _baseUnit : _compatibleUnits.first;
    _quantity = (prod['qty'] as num?)?.toInt() ?? 1;
    if (_quantity < 1) _quantity = 1;
    _baseRate = _defaultBaseRate;

    // If base product rate is 0 and variants exist, auto-select the first variant
    if (_defaultBaseRate <= 0 && _variants.isNotEmpty) {
      _selectedVariantIndex = 0;
      final firstVar = _variants.first;
      final vName = (firstVar['name'] ?? '').toString().trim();
      _baseUnit = vName.isNotEmpty ? vName : _defaultBaseUnit;
      _selectedUnit = _baseUnit;
      _compatibleUnits = [_baseUnit];
      _baseRate = (firstVar['rate'] as num?)?.toDouble() ?? 0.0;
    }

    _qtyController.text = _quantity.toString();

    if (_variants.isEmpty) {
      _ensureVariantsLoaded(prod);
    }
  }

  Future<void> _ensureVariantsLoaded(Map<String, dynamic> prod) async {
    final targetId = (prod['id'] ?? '').toString().trim();
    final targetName = (prod['name'] ?? '').toString().trim().toLowerCase();

    List<Map<String, dynamic>> checkList(List<Map<String, dynamic>> list) {
      for (final item in list) {
        final itemId = (item['id'] ?? '').toString().trim();
        final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
        final match = (targetId.isNotEmpty && itemId == targetId) ||
            (targetName.isNotEmpty && itemName == targetName);
        if (match) {
          final parsed = _parseVariants(item['variants']);
          if (parsed.isNotEmpty) return parsed;
        }
      }
      return [];
    }

    List<Map<String, dynamic>> found = [];
    try {
      final cached = await AuthService.getCachedSellerProducts(widget.sellerUsername);
      found = checkList(cached);
    } catch (_) {}
    if (found.isEmpty) {
      try {
        final fresh = await AuthService.getSellerProducts(widget.sellerUsername);
        found = checkList(fresh);
      } catch (_) {}
    }

    if (found.isNotEmpty && mounted) {
      setState(() {
        _variants = found;
        if (_defaultBaseRate <= 0 && _selectedVariantIndex == -1) {
          _onVariantSelected(0);
        }
      });
    }
  }

  void _onVariantSelected(int index) {
    setState(() {
      if (index < 0 || index >= _variants.length) {
        _selectedVariantIndex = -1;
        _baseUnit = _defaultBaseUnit;
        _baseRate = _defaultBaseRate;
        _compatibleUnits = _getCompatibleUnits(_baseUnit);
        _selectedUnit = _compatibleUnits.contains(_baseUnit) ? _baseUnit : _compatibleUnits.first;
      } else {
        _selectedVariantIndex = index;
        final v = _variants[index];
        final vName = (v['name'] ?? '').toString().trim();
        final vRate = (v['rate'] as num?)?.toDouble() ?? 0.0;
        _baseUnit = vName.isNotEmpty ? vName : _defaultBaseUnit;
        _selectedUnit = _baseUnit;
        _baseRate = vRate;
        _compatibleUnits = [_baseUnit];
      }
      _quantity = 1;
      _qtyController.text = '1';
      _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  /// Filter compatible units based on seller's base unit
  List<String> _getCompatibleUnits(String baseUnitRaw) {
    final u = baseUnitRaw.trim().toLowerCase();

    // Weight Category: Kg, Gram, gm, g
    if (u == 'kg' || u == 'gram' || u == 'gm' || u == 'g') {
      return ['Kg', 'Gram'];
    }

    // Volume / Liquid Category: L, Liter, Litre, Ml, ml
    if (u == 'l' || u == 'liter' || u == 'litre' || u == 'ml') {
      return ['L', 'Ml'];
    }

    // Discrete Category (Pcs, Packet, Box, Dozen, Bottle, Can, etc.)
    return [baseUnitRaw.trim().isNotEmpty ? baseUnitRaw.trim() : 'Pcs'];
  }

  void _updateQty(int newQty) {
    if (newQty < 1) return;
    setState(() {
      _quantity = newQty;
      _qtyController.text = _quantity.toString();
      _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));
    });
  }

  double get _effectiveBaseQty {
    final b = _baseUnit.trim().toLowerCase();
    final s = _selectedUnit.trim().toLowerCase();
    double q = _quantity.toDouble();

    if ((b == 'kg') && (s == 'gram' || s == 'gm' || s == 'g')) {
      return q / 1000.0;
    }

    if ((b == 'l' || b == 'liter' || b == 'litre') && s == 'ml') {
      return q / 1000.0;
    }

    return q;
  }

  double get _calculatedTotal => _baseRate * _effectiveBaseQty;

  String get _formulaText {
    final b = _baseUnit.trim();
    final s = _selectedUnit.trim();
    final rateStr = _baseRate % 1 == 0 ? _baseRate.toInt().toString() : _baseRate.toStringAsFixed(2);

    if (b.toLowerCase() == 'kg' && (s.toLowerCase() == 'gram' || s.toLowerCase() == 'gm' || s.toLowerCase() == 'g')) {
      final baseEquiv = _effectiveBaseQty % 1 == 0 ? _effectiveBaseQty.toInt().toString() : _effectiveBaseQty.toStringAsFixed(3);
      return '₹$rateStr / $b × $_quantity $s ($baseEquiv $b)';
    }

    if ((b.toLowerCase() == 'l' || b.toLowerCase() == 'liter') && s.toLowerCase() == 'ml') {
      final baseEquiv = _effectiveBaseQty % 1 == 0 ? _effectiveBaseQty.toInt().toString() : _effectiveBaseQty.toStringAsFixed(3);
      return '₹$rateStr / $b × $_quantity $s ($baseEquiv $b)';
    }

    return '₹$rateStr × $_quantity $s';
  }

  List<Map<String, dynamic>> get _relatedProducts {
    final cat = (_currentProduct['category'] ?? '').toString().trim().toLowerCase();
    final currentId = (_currentProduct['id'] ?? _currentProduct['name'] ?? '').toString().trim().toLowerCase();

    if (widget.allProducts == null || widget.allProducts!.isEmpty) return [];

    return widget.allProducts!.where((p) {
      final pCat = (p['category'] ?? '').toString().trim().toLowerCase();
      final pId = (p['id'] ?? p['name'] ?? '').toString().trim().toLowerCase();

      final matchesCat = cat.isNotEmpty && pCat == cat;
      final isDifferent = pId != currentId;
      return matchesCat && isDifferent;
    }).toList();
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 50, BoxFit fit = BoxFit.contain}) {
    final img = rawImg.trim();
    if (img.isEmpty) {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }

    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: fit,
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
          fit: fit,
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

  @override
  Widget build(BuildContext context) {
    final name = (_currentProduct['name'] ?? '').toString();
    final desc = (_currentProduct['description'] ?? '').toString();
    final cat = (_currentProduct['category'] ?? '').toString();
    final imgUrl = (_currentProduct['image_url'] ?? '').toString().trim();
    final imgVal = (_currentProduct['image'] ?? '').toString().trim();
    final baseImg = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');
    final selectedVariantImg = (_selectedVariantIndex >= 0 && _selectedVariantIndex < _variants.length)
        ? (_variants[_selectedVariantIndex]['image_url'] ?? '').toString().trim()
        : '';
    final img = selectedVariantImg.isNotEmpty ? selectedVariantImg : baseImg;

    final totalStr = _calculatedTotal % 1 == 0 ? _calculatedTotal.toInt().toString() : _calculatedTotal.toStringAsFixed(2);
    final rateStr = _baseRate % 1 == 0 ? _baseRate.toInt().toString() : _baseRate.toStringAsFixed(2);
    final relatedList = _relatedProducts;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle Bar
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable Body Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO PRODUCT IMAGE CONTAINER (Full Width Edge-to-Edge Card with Border Frame)
                  Stack(
                    children: [
                      // Image Box (Full Width Edge-to-Edge)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: Container(
                          height: 420,
                          width: double.infinity,
                          color: const Color(0xFFF8FAFC),
                          child: ProductBorderWrapper(
                            sellerUsername: widget.sellerUsername,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            padding: const EdgeInsets.only(top: 60, bottom: 25, left: 20, right: 20),
                            child: _buildProductImageWidget(img, emojiSize: 140, fit: BoxFit.contain),
                          ),
                        ),
                      ),

                        // Back Button (Top Left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                            ),
                          ),
                        ),

                        // Category Badge Pill (Top Right)
                        if (cat.isNotEmpty)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                cat.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                  // 2. PRODUCT NAME & RATE HEADER (Modern Top-Brand Professional Look)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Pill + Rating Tag + Stock Status
                        Row(
                          children: [
                            if (cat.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  cat.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            if (cat.isNotEmpty) const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 13),
                                  SizedBox(width: 2.5),
                                  Text(
                                    '4.8',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 3),
                                  Text('In Stock', style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.25,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Rate Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹$rateStr',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ $_baseUnit',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        // Simple Plain Description (Supports WhatsApp formatting *bold*, _italic_, ~strike~)
                        if (desc.isNotEmpty && desc.toLowerCase() != name.toLowerCase()) ...[
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              children: parseFormattedTextSpans(
                                desc,
                                const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                  height: 1.35,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  const SizedBox(height: 10),

                  // 3. MODERN COMPACT MEASUREMENT & QUANTITY OPTIONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Variables Selector (If product has variables)
                        if (_variants.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.layers_rounded, size: 14, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 5),
                              const Text(
                                'Select Variable:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFC7D2FE)),
                                ),
                                child: Text(
                                  '${_variants.length} Options',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                // Default / Base rate option (if base rate > 0)
                                if (_defaultBaseRate > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: Builder(
                                      builder: (context) {
                                        final isSelected = _selectedVariantIndex == -1;
                                        final defRateStr = _defaultBaseRate % 1 == 0
                                            ? _defaultBaseRate.toInt().toString()
                                            : _defaultBaseRate.toStringAsFixed(2);
                                        return GestureDetector(
                                          onTap: () => _onVariantSelected(-1),
                                          child: IntrinsicWidth(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(minWidth: 78),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                                  borderRadius: BorderRadius.circular(11),
                                                  border: Border.all(
                                                    color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                                                    width: isSelected ? 2.0 : 1.2,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 3),
                                                          ),
                                                        ]
                                                      : [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.04),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ],
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    // Top Dark Blue Strip (Dot + Unit Name in White)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: isSelected
                                                              ? const [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]
                                                              : const [Color(0xFF1E3A8A), Color(0xFF334155)],
                                                          begin: Alignment.centerLeft,
                                                          end: Alignment.centerRight,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            isSelected
                                                                ? Icons.radio_button_checked_rounded
                                                                : Icons.circle_outlined,
                                                            size: 13,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(width: 5),
                                                          Text(
                                                            _defaultBaseUnit,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w800,
                                                              color: Colors.white,
                                                              letterSpacing: 0.2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Bottom Rate Area
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                      alignment: Alignment.center,
                                                      child: Text(
                                                        '₹$defRateStr',
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w900,
                                                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                                        ),
                                                      ),
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
                                // Product Variables
                                ...List.generate(_variants.length, (idx) {
                                  final v = _variants[idx];
                                  final vName = (v['name'] ?? '').toString().trim();
                                  final vRate = (v['rate'] as num?)?.toDouble() ?? 0.0;
                                  final vRateStr = vRate % 1 == 0 ? vRate.toInt().toString() : vRate.toStringAsFixed(2);
                                  final isSelected = _selectedVariantIndex == idx;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: GestureDetector(
                                      onTap: () => _onVariantSelected(idx),
                                      child: IntrinsicWidth(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(minWidth: 78),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                              borderRadius: BorderRadius.circular(11),
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                                                width: isSelected ? 2.0 : 1.2,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ]
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.04),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 1),
                                                      ),
                                                    ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                // Top Dark Blue Strip (Dot + Unit Name in White)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: isSelected
                                                          ? const [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]
                                                          : const [Color(0xFF1E3A8A), Color(0xFF334155)],
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        isSelected
                                                            ? Icons.radio_button_checked_rounded
                                                            : Icons.circle_outlined,
                                                        size: 13,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        vName,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800,
                                                          color: Colors.white,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Bottom Rate Area
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '₹$vRateStr',
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w900,
                                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Animated Vibrant Forward Moving Multi-Color Gradient Strip
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final val = _pulseAnimation.value;
                            // Shifts the gradient forward continuously from Left to Right
                            final double xOffset = -2.0 + (val * 4.0);

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  gradient: LinearGradient(
                                    colors: const [
                                      Color(0xFF1D4ED8), // Deep Royal Blue
                                      Color(0xFF3B82F6), // Bright Blue
                                      Color(0xFF60A5FA), // Light Ocean Blue
                                      Color(0xFF0284C7), // Vivid Sky Blue
                                      Color(0xFF1E40AF), // Deep Blue
                                      Color(0xFF3B82F6), // Bright Blue
                                      Color(0xFF1D4ED8), // Deep Royal Blue
                                    ],
                                    begin: Alignment(xOffset - 2.0, 0.0),
                                    end: Alignment(xOffset + 2.0, 0.0),
                                  ),
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left: Bill Icon + Formula directly on strip in Crisp White
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formulaText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              // Right: Total Amount in Crisp White
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  const Text(
                                    'Total: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '₹$totalStr',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. RELATED PRODUCTS FROM SAME CATEGORY ("More in [Category]")
                  if (relatedList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 6),
                          Text(
                            'More in ${cat.isNotEmpty ? cat : 'Category'}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Spacer(),
                          Text(
                            '${relatedList.length} items',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Related Items 3-Column Dynamic-Height Row Layout
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (int i = 0; i < relatedList.length; i += 3) ...[
                            if (i > 0) const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildRelatedProductCard(relatedList[i])),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: i + 1 < relatedList.length
                                      ? _buildRelatedProductCard(relatedList[i + 1])
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: i + 2 < relatedList.length
                                      ? _buildRelatedProductCard(relatedList[i + 2])
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 5. STICKY BOTTOM ACTION BAR (Clean counter + Add to Cart Button with Price Pill & SafeArea)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: const Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                children: [
                  // Sleek Pill Counter Control [-] 01 [+]
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus
                        InkWell(
                          onTap: () => _updateQty(_quantity - 1),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Icon(Icons.remove_rounded, color: Color(0xFF334155), size: 16),
                          ),
                        ),
                        SizedBox(
                          width: 42,
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null && parsed >= 1) {
                                setState(() {
                                  _quantity = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        // Plus (Round Circle)
                        InkWell(
                          onTap: () => _updateQty(_quantity + 1),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Vibrant Yellow Add to Order List Button with Price Pill
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFBBF24), // Vibrant Warm Yellow
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 3,
                          shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () async {
                          final selectedVariant = (_selectedVariantIndex >= 0 && _selectedVariantIndex < _variants.length)
                              ? _variants[_selectedVariantIndex]
                              : null;
                          await CartService.addToCart(
                            sellerUsername: widget.sellerUsername,
                            product: {
                              ..._currentProduct,
                              'unit': _baseUnit,
                              'rate': _baseRate,
                              'image_url': img,
                              'image': img,
                              if (selectedVariant != null && selectedVariant['purchase_rate'] != null)
                                'purchase_rate': selectedVariant['purchase_rate'],
                            },
                            selectedUnit: _selectedUnit,
                            quantity: _quantity,
                          );

                          widget.onCartUpdated?.call();

                          if (mounted) {
                            Navigator.pop(context);
                            AppToast.show(context, 'Added "$name" ($_quantity $_selectedUnit - ₹$totalStr) to Order List!');
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shopping_bag_rounded, color: Color(0xFF0F172A), size: 17),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Add to Cart',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '|  ₹$totalStr',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
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
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProductCard(Map<String, dynamic> relProd) {
    final rName = (relProd['name'] ?? '').toString();
    final rRate = (relProd['rate'] as num?)?.toDouble() ?? 0.0;
    final rRateStr = rRate % 1 == 0 ? rRate.toInt().toString() : rRate.toStringAsFixed(2);
    final rUnit = (relProd['unit'] ?? 'Pcs').toString();
    final rImgUrl = (relProd['image_url'] ?? '').toString().trim();
    final rImgVal = (relProd['image'] ?? '').toString().trim();
    final rImg = rImgUrl.isNotEmpty ? rImgUrl : (rImgVal.isNotEmpty ? rImgVal : '📦');
    final rBtnText = (relProd['button_text'] ?? '').toString().trim().isNotEmpty
        ? (relProd['button_text'] ?? '').toString().trim()
        : 'Buy Now';

    return InkWell(
      onTap: () {
        setState(() {
          _initProductData(relProd);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Related Product Image Box (Slightly taller portrait shape)
          AspectRatio(
            aspectRatio: 0.88,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _relatedItemBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildProductImageWidget(rImg, emojiSize: 34, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 2. Item Name (up to 3 rows, then ellipsis if still longer)
          Text(
            rName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              height: 1.22,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),

          // 3. Rate & Unit
          Text(
            '₹$rRateStr / $rUnit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              color: Color(0xFF475569),
            ),
          ),

          const SizedBox(height: 4),

          // 4. Seller Custom Button / Buy Now Button (Sits right below rate, never overflows)
          SizedBox(
            width: double.infinity,
            height: 27,
            child: ElevatedButton(
              onPressed: () async {
                await CartService.addToCart(
                  sellerUsername: widget.sellerUsername,
                  product: relProd,
                  selectedUnit: rUnit,
                  quantity: 1,
                );
                widget.onCartUpdated?.call();
                if (context.mounted) {
                  AppToast.show(context, 'Added "$rName" to order list!');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB), // Royal Blue
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                rBtnText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
