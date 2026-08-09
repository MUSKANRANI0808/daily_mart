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
  late String _selectedUnit;
  late int _quantity;
  late double _baseRate;

  final List<String> _defaultUnits = [
    'Pcs',
    'Kg',
    'Gram',
    'L',
    'Packet',
    'Box',
    'Dozen',
    'Bottle',
    'Can',
  ];

  @override
  void initState() {
    super.initState();
    final defaultProductUnit = (widget.product['unit'] ?? 'Pcs').toString().trim();
    _selectedUnit = defaultProductUnit.isNotEmpty ? defaultProductUnit : 'Pcs';
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

  void _updateQty(int newQty) {
    if (newQty < 1) return;
    setState(() {
      _quantity = newQty;
      _qtyController.text = _quantity.toString();
      _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));
    });
  }

  double get _calculatedTotal => _baseRate * _quantity;

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

    final availableUnits = List<String>.from(_defaultUnits);
    if (_selectedUnit.isNotEmpty && !availableUnits.contains(_selectedUnit)) {
      availableUnits.insert(0, _selectedUnit);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Big Enlarged Product Image Preview Box
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildProductImageWidget(img, emojiSize: 64),
                    ),
                  ),

                  // Category Badge Pill
                  if (cat.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          cat.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Close Button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Product Name & Base Rate Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '₹${_baseRate % 1 == 0 ? _baseRate.toInt() : _baseRate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                      Text(
                        ' / $_selectedUnit',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 28, indent: 20, endIndent: 20),

            // Unit Selection Section (Clickable Unit Chips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.straighten_rounded, size: 16, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 6),
                      Text(
                        'Select Unit / Measurement:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availableUnits.map((u) {
                      final isSelected = _selectedUnit.toLowerCase() == u.toLowerCase();
                      return ChoiceChip(
                        label: Text(u),
                        selected: isSelected,
                        selectedColor: const Color(0xFF8B5CF6),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedUnit = u;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quantity Selection Counter & Quick Presets Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 6),
                      Text(
                        'Select Quantity:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Minus Button
                      InkWell(
                        onTap: () => _updateQty(_quantity - 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Quantity Input Field
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
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
                      const SizedBox(width: 12),

                      // Plus Button
                      InkWell(
                        onTap: () => _updateQty(_quantity + 1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick Quantity Preset Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1, 2, 5, 10, 50, 100].map((presetQty) {
                        final isSel = _quantity == presetQty;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ActionChip(
                            label: Text('$presetQty Qty'),
                            backgroundColor: isSel ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
                            side: BorderSide(
                              color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
                              width: isSel ? 1.5 : 1,
                            ),
                            labelStyle: TextStyle(
                              color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFF475569),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 11.5,
                            ),
                            onPressed: () => _updateQty(presetQty),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Calculated Amount Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Calculated Price:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_baseRate % 1 == 0 ? _baseRate.toInt() : _baseRate} × $_quantity $_selectedUnit',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                      ),
                    ],
                  ),
                  Text(
                    '₹${_calculatedTotal % 1 == 0 ? _calculatedTotal.toInt() : _calculatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Add to Order List Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await CartService.addToCart(
                    sellerUsername: widget.sellerUsername,
                    product: widget.product,
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
                                '✓ Added "$name" ($_quantity $_selectedUnit - ₹${_calculatedTotal.toInt()}) to Order List!',
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
                icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                label: Text(
                  'Add to Order List (₹${_calculatedTotal % 1 == 0 ? _calculatedTotal.toInt() : _calculatedTotal.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
