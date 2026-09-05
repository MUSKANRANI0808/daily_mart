import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/cart_service.dart';
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

class _ProductDetailBottomSheetState extends State<ProductDetailBottomSheet> {
  late Map<String, dynamic> _currentProduct;
  late TextEditingController _qtyController;
  late String _baseUnit;
  late String _selectedUnit;
  late int _quantity;
  late double _baseRate;
  late List<String> _compatibleUnits;

  @override
  void initState() {
    super.initState();
    _initProductData(widget.product);
  }

  void _initProductData(Map<String, dynamic> prod) {
    _currentProduct = prod;
    final defaultProductUnit = (prod['unit'] ?? 'Pcs').toString().trim();
    _baseUnit = defaultProductUnit.isNotEmpty ? defaultProductUnit : 'Pcs';
    _compatibleUnits = _getCompatibleUnits(_baseUnit);
    _selectedUnit = _compatibleUnits.contains(_baseUnit) ? _baseUnit : _compatibleUnits.first;
    _quantity = (prod['qty'] as num?)?.toInt() ?? 1;
    if (_quantity < 1) _quantity = 1;
    _baseRate = (prod['rate'] as num?)?.toDouble() ?? 0.0;
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

  void _onUnitChanged(String newUnit) {
    if (newUnit == _selectedUnit) return;

    final oldIsSmall = _selectedUnit.toLowerCase() == 'gram' || _selectedUnit.toLowerCase() == 'ml';
    final newIsSmall = newUnit.toLowerCase() == 'gram' || newUnit.toLowerCase() == 'ml';

    int defaultNewQty = _quantity;
    if (!oldIsSmall && newIsSmall) {
      defaultNewQty = _quantity * 500;
    } else if (oldIsSmall && !newIsSmall) {
      defaultNewQty = (_quantity / 500).round();
      if (defaultNewQty < 1) defaultNewQty = 1;
    }

    setState(() {
      _selectedUnit = newUnit;
      _quantity = defaultNewQty;
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

  List<int> get _presetQuantities {
    final s = _selectedUnit.trim().toLowerCase();
    if (s == 'gram' || s == 'gm' || s == 'g' || s == 'ml') {
      return [50, 100, 250, 500, 1000];
    }
    return [1, 2, 5, 10, 50];
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

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 50}) {
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
    final name = (_currentProduct['name'] ?? '').toString();
    final desc = (_currentProduct['description'] ?? '').toString();
    final cat = (_currentProduct['category'] ?? '').toString();
    final imgUrl = (_currentProduct['image_url'] ?? '').toString().trim();
    final imgVal = (_currentProduct['image'] ?? '').toString().trim();
    final img = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');

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
                  // 1. HERO PRODUCT IMAGE CONTAINER (Sleek Rounded Card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Stack(
                      children: [
                        // Image Box
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 190,
                            width: double.infinity,
                            color: const Color(0xFFF8FAFC),
                            child: ProductBorderWrapper(
                              sellerUsername: widget.sellerUsername,
                              borderRadius: BorderRadius.circular(20),
                              child: _buildProductImageWidget(img, emojiSize: 68),
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
                  ),

                  // 2. PRODUCT NAME & RATE HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Rate & Rating Sub-row
                        Row(
                          children: [
                            Text(
                              '₹$rateStr',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              ' / $_baseUnit',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 14),
                                  SizedBox(width: 3),
                                  Text(
                                    '4.8',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Optional Clean Description Line
                        if (desc.isNotEmpty && desc.toLowerCase() != name.toLowerCase()) ...[
                          const SizedBox(height: 8),
                          Text(
                            desc,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  const SizedBox(height: 14),

                  // 3. COMPACT MEASUREMENT & QUANTITY OPTIONS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Unit Selector (If compatible units > 1)
                        if (_compatibleUnits.length > 1) ...[
                          const Text(
                            'Select Unit:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: _compatibleUnits.map((u) {
                              final isSelected = _selectedUnit.toLowerCase() == u.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => _onUnitChanged(u),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      u,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Preset Quantity Selector
                        const Text(
                          'Select Quantity:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
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
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      '$presetQty $_selectedUnit',
                                      style: TextStyle(
                                        color: isSel ? Colors.white : const Color(0xFF334155),
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Price Calculation Strip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formulaText,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Total: ₹$totalStr',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
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

                    // Related Items Horizontal Scroll Carousel (Matching Home Page Card Structure!)
                    SizedBox(
                      height: 195,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: relatedList.length,
                        itemBuilder: (ctx, idx) {
                          final relProd = relatedList[idx];
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

                          return Container(
                            width: 135,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _initProductData(relProd);
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Related Product Image Box
                                    Container(
                                      height: 85,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _buildProductImageWidget(rImg, emojiSize: 36),
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // 2. Item Name
                                    Text(
                                      rName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),

                                    // 3. Rate & Unit in Subtle Gray
                                    Text(
                                      '₹$rRateStr / $rUnit',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 6),

                                    // 4. Seller Custom Button / Buy Now Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 28,
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
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('✓ Added "$rName" to order list!', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                backgroundColor: const Color(0xFF10B981),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
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
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 5. STICKY BOTTOM ACTION BAR (Clean counter + Add to Cart Button)
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

                      // Quantity Input
                      SizedBox(
                        width: 36,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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

                // Vibrant Gradient Add to Order List Button
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
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
                            ..._currentProduct,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
}
