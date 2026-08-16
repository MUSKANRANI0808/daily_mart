import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/cart_service.dart';

void showProductDetailBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> product,
  required String sellerUsername,
  VoidCallback? onCartUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProductDetailBottomSheet(
      product: product,
      sellerUsername: sellerUsername,
      onCartUpdated: onCartUpdated,
    ),
  );
}

class ProductDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String sellerUsername;
  final VoidCallback? onCartUpdated;

  const ProductDetailBottomSheet({
    super.key,
    required this.product,
    required this.sellerUsername,
    this.onCartUpdated,
  });

  @override
  State<ProductDetailBottomSheet> createState() => _ProductDetailBottomSheetState();
}

class _ProductDetailBottomSheetState extends State<ProductDetailBottomSheet> {
  late TextEditingController _qtyController;
  late String _baseUnit;
  late String _selectedUnit;
  late int _quantity;
  late double _baseRate;
  late List<String> _compatibleUnits;

  @override
  void initState() {
    super.initState();
    final defaultProductUnit = (widget.product['unit'] ?? 'Pcs').toString().trim();
    _baseUnit = defaultProductUnit.isNotEmpty ? defaultProductUnit : 'Pcs';
    _compatibleUnits = _getCompatibleUnits(_baseUnit);
    _selectedUnit = _compatibleUnits.contains(_baseUnit) ? _baseUnit : _compatibleUnits.first;
    _quantity = (widget.product['qty'] as num?)?.toInt() ?? 1;
    if (_quantity < 1) _quantity = 1;
    _baseRate = (widget.product['rate'] as num?)?.toDouble() ?? 0.0;
    _qtyController = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
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

    // Specific / Discrete Category (Pcs, Packet, Box, Dozen, Bottle, Can, etc.)
    // Show ONLY the seller's specific base unit!
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

  void _onUnitChanged(String newUnit) {
    if (newUnit == _selectedUnit) return;

    final oldIsSmall = _selectedUnit.toLowerCase() == 'gram' || _selectedUnit.toLowerCase() == 'ml';
    final newIsSmall = newUnit.toLowerCase() == 'gram' || newUnit.toLowerCase() == 'ml';

    int defaultNewQty = _quantity;
    if (!oldIsSmall && newIsSmall) {
      defaultNewQty = 500;
    } else if (oldIsSmall && !newIsSmall) {
      defaultNewQty = 1;
    }

    setState(() {
      _selectedUnit = newUnit;
      _quantity = defaultNewQty;
      _qtyController.text = _quantity.toString();
    });
  }

  /// Precise Unit Conversion Math
  double get _effectiveBaseQty {
    final b = _baseUnit.trim().toLowerCase();
    final s = _selectedUnit.trim().toLowerCase();
    final q = _quantity.toDouble();

    // Base is Kg
    if (b == 'kg') {
      if (s == 'gram' || s == 'gm' || s == 'g') {
        return q / 1000.0;
      }
      return q;
    }

    // Base is Gram / g / gm
    if (b == 'gram' || b == 'gm' || b == 'g') {
      if (s == 'kg') {
        return q * 1000.0;
      }
      return q;
    }

    // Base is L / Liter / Litre
    if (b == 'l' || b == 'liter' || b == 'litre') {
      if (s == 'ml') {
        return q / 1000.0;
      }
      return q;
    }

    // Base is Ml
    if (b == 'ml') {
      if (s == 'l' || s == 'liter' || s == 'litre') {
        return q * 1000.0;
      }
      return q;
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

  List<int> get _presetQuantities {
    final s = _selectedUnit.trim().toLowerCase();
    if (s == 'gram' || s == 'gm' || s == 'g' || s == 'ml') {
      return [50, 100, 250, 500, 1000];
    }
    return [1, 2, 5, 10, 50, 100];
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 54}) {
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

  @override
  Widget build(BuildContext context) {
    final name = (widget.product['name'] ?? '').toString();
    final desc = (widget.product['description'] ?? '').toString();
    final cat = (widget.product['category'] ?? '').toString();
    final imgUrl = (widget.product['image_url'] ?? '').toString().trim();
    final imgVal = (widget.product['image'] ?? '').toString().trim();
    final img = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');

    final totalStr = _calculatedTotal % 1 == 0 ? _calculatedTotal.toInt().toString() : _calculatedTotal.toStringAsFixed(2);
    final rateStr = _baseRate % 1 == 0 ? _baseRate.toInt().toString() : _baseRate.toStringAsFixed(2);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 25,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrollable Body Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. EDGE-TO-EDGE FULL BLEED HERO BANNER IMAGE (Matching Reference Design!)
                  Stack(
                    children: [
                      // Full-width Hero Image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        child: Container(
                          height: 250,
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          child: _buildProductImageWidget(img, emojiSize: 84),
                        ),
                      ),

                      // Gradient Overlay on Image Bottom for text contrast
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.70),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Handle Bar on Top
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      // Top Navigation Controls (Back/Close Left, Share/Heart Right)
                      Positioned(
                        top: 22,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back / Close Circle Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                              ),
                            ),

                            // Category Pill (Center/Right)
                            if (cat.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  cat.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),

                            // Floating Heart / Favorite Button
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFE11D48), size: 20),
                            ),
                          ],
                        ),
                      ),

                      // Overlaid Price Banner on Image Bottom
                      Positioned(
                        bottom: 14,
                        left: 20,
                        child: Row(
                          children: [
                            Text(
                              '₹$rateStr',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            Text(
                              ' / $_baseUnit',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 2. PRODUCT DETAILS SECTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Highlight Feature Badges Row (Rating | Delivery | Stock)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildInfoBadge('⭐ 4.8 (120+ Ratings)', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              _buildInfoBadge('⚡ 15-20 Min Express', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                              const SizedBox(width: 8),
                              _buildInfoBadge('📦 Fresh & Pure', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                            ],
                          ),
                        ),

                        // Description Box
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 18),

                        // 3. UNIT MEASUREMENT SELECTION
                        Row(
                          children: const [
                            Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF0F172A)),
                            SizedBox(width: 6),
                            Text(
                              'Select Measurement Unit:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _compatibleUnits.map((u) {
                            final isSelected = _selectedUnit.toLowerCase() == u.toLowerCase();
                            return GestureDetector(
                              onTap: () => _onUnitChanged(u),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      u,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // 4. QUANTITY PRESET CHIPS
                        Row(
                          children: const [
                            Icon(Icons.format_list_numbered_rounded, size: 18, color: Color(0xFF0F172A)),
                            SizedBox(width: 6),
                            Text(
                              'Select Quantity:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _presetQuantities.map((presetQty) {
                              final isSel = _quantity == presetQty;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => _updateQty(presetQty),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                        width: isSel ? 1.6 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      '$presetQty $_selectedUnit',
                                      style: TextStyle(
                                        color: isSel ? Colors.white : const Color(0xFF475569),
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 5. PRICE BREAKDOWN CARD
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Calculated Price:',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formulaText,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹$totalStr',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. MODERN STICKY BOTTOM ACTION BAR (Matching Reference Design!)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // Sleek Pill Counter Control [-] 01 [+]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Minus Circle
                      GestureDetector(
                        onTap: () => _updateQty(_quantity - 1),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.remove_rounded, color: Color(0xFF334155), size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Quantity Text / Input
                      SizedBox(
                        width: 38,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
                      const SizedBox(width: 10),

                      // Plus Circle
                      GestureDetector(
                        onTap: () => _updateQty(_quantity + 1),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Vibrant Gradient Add to Order List Button (Single Line Text)
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await CartService.addToCart(
                          sellerUsername: widget.sellerUsername,
                          product: {
                            ...widget.product,
                            'rate': _baseRate,
                          },
                          selectedUnit: _selectedUnit,
                          quantity: _quantity,
                        );

                        widget.onCartUpdated?.call();

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '✓ Added "$name" ($_quantity $_selectedUnit - ₹$totalStr) to Order List!',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Add to Cart (₹$totalStr)',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textCol,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
