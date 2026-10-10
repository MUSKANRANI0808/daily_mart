import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/cart_service.dart';
import '../../utils/category_icon_helper.dart';
import '../../widgets/product_detail_bottom_sheet.dart';
import '../seller/seller_order_cart_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String sellerUsername;
  final String sellerName;
  final String sellerMobile;
  final String categoryName;
  final String categoryColor;
  final String categoryImage;
  final String categoryIcon;
  final String categoryPoster;
  final String categoryItemBgColor;
  final List<Map<String, dynamic>> allProducts;
  final List<Map<String, dynamic>> categories;

  const CategoryProductsScreen({
    super.key,
    required this.sellerUsername,
    required this.sellerName,
    required this.sellerMobile,
    required this.categoryName,
    this.categoryColor = '#DCFCE7',
    this.categoryImage = '',
    this.categoryIcon = '',
    this.categoryPoster = '',
    this.categoryItemBgColor = '#F8FAFC',
    required this.allProducts,
    this.categories = const [],
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late String _currentCategory;
  late String _currentColor;
  late String _currentImage;
  late String _currentIcon;
  late String _currentPoster;
  late String _currentItemBgColor;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _priceSortOrder = 'none'; // 'none', 'low_to_high', 'high_to_low'

  int _cartBadgeCount = 0;
  double _cartTotalAmount = 0.0;
  bool _isLoadingCart = false;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.categoryName;
    _currentColor = widget.categoryColor.isNotEmpty ? widget.categoryColor : '#DCFCE7';
    _currentImage = widget.categoryImage;
    _currentIcon = widget.categoryIcon;
    _currentPoster = widget.categoryPoster;

    String initialItemBg = widget.categoryItemBgColor.trim();
    if (initialItemBg.isEmpty || initialItemBg == '#F8FAFC') {
      for (var c in widget.categories) {
        final cName = (c['name'] ?? c['category_name'] ?? '').toString().trim();
        if (cName.toLowerCase() == widget.categoryName.trim().toLowerCase()) {
          final found = (c['item_bg_color'] ?? '').toString().trim();
          if (found.isNotEmpty) {
            initialItemBg = found;
            break;
          }
        }
      }
    }
    _currentItemBgColor = initialItemBg.isNotEmpty ? initialItemBg : '#F8FAFC';

    _loadCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() => _isLoadingCart = true);
    try {
      final items = await CartService.getCartItems(widget.sellerUsername);
      if (mounted) {
        setState(() {
          _cartBadgeCount = CartService.getTotalCount(items);
          _cartTotalAmount = CartService.getTotalAmount(items);
          _isLoadingCart = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCart = false);
    }
  }

  void _switchCategory(Map<String, dynamic> cat) {
    final name = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
    if (name.isEmpty) return;
    final color = (cat['color'] ?? '').toString().trim();
    final img = (cat['image_url'] ?? cat['image'] ?? '').toString().trim();
    final icon = (cat['icon_url'] ?? '').toString().trim();
    final poster = (cat['poster_url'] ?? '').toString().trim();
    final itemBg = (cat['item_bg_color'] ?? '').toString().trim();

    setState(() {
      _currentCategory = name;
      _currentColor = color.isNotEmpty ? color : '#DCFCE7';
      _currentImage = img;
      _currentIcon = icon;
      _currentPoster = poster;
      _currentItemBgColor = itemBg.isNotEmpty ? itemBg : '#F8FAFC';
      _searchController.clear();
      _searchQuery = '';
      _priceSortOrder = 'none';
    });
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final catName = _currentCategory.trim().toLowerCase();

    final list = widget.allProducts.where((p) {
      final pCat = (p['category'] ?? '').toString().trim().toLowerCase();
      // Match by category name
      if (pCat != catName) return false;

      // Filter by search query if present
      if (query.isNotEmpty) {
        final pName = (p['name'] ?? '').toString().toLowerCase();
        final pDesc = (p['description'] ?? '').toString().toLowerCase();
        if (!pName.contains(query) && !pDesc.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort by price
    if (_priceSortOrder == 'low_to_high') {
      list.sort((a, b) {
        final rA = (a['rate'] as num?)?.toDouble() ?? 0.0;
        final rB = (b['rate'] as num?)?.toDouble() ?? 0.0;
        return rA.compareTo(rB);
      });
    } else if (_priceSortOrder == 'high_to_low') {
      list.sort((a, b) {
        final rA = (a['rate'] as num?)?.toDouble() ?? 0.0;
        final rB = (b['rate'] as num?)?.toDouble() ?? 0.0;
        return rB.compareTo(rA);
      });
    }

    return list;
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerOrderCartScreen(
          seller: UserModel(
            id: widget.sellerUsername,
            name: widget.sellerName,
            mobile: widget.sellerMobile,
            username: widget.sellerUsername,
            role: UserRole.seller,
          ),
        ),
      ),
    );
    _loadCart();
  }

  Color _parseBgColor(String hexStr) {
    try {
      String clean = hexStr.replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    } catch (_) {}
    return const Color(0xFFDCFCE7);
  }

  Widget _buildCategoryImage(String rawImg, {double size = 38}) {
    final img = rawImg.trim();
    if (img.isEmpty || img == '🏷️') {
      return CategoryIconHelper.buildHeaderCategoryIcon(_currentIcon, _currentCategory, size: size, color: const Color(0xFF0F172A));
    }
    if (img.startsWith('data:image')) {
      try {
        final commaIdx = img.indexOf(',');
        final base64Data = commaIdx != -1 ? img.substring(commaIdx + 1) : img;
        return Image.memory(
          base64Decode(base64Data),
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Text('📦', style: TextStyle(fontSize: size * 0.7)),
        );
      } catch (_) {}
    }
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Text('📦', style: TextStyle(fontSize: size * 0.7)),
      );
    }
    return Text(img, style: TextStyle(fontSize: size * 0.75));
  }

  static List<String> parsePosterList(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return [];
    if (clean.startsWith('[') && clean.endsWith(']')) {
      try {
        final decoded = jsonDecode(clean);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return [clean];
  }

  Widget _buildCategoryPosterBanner(String poster) {
    final images = parsePosterList(poster);
    if (images.isEmpty) return const SizedBox.shrink();
    return CategoryPosterSliderWidget(images: images);
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 36}) {
    final img = rawImg.trim();
    if (img.isEmpty || img == '🏷️') {
      return Center(child: Text('📦', style: TextStyle(fontSize: emojiSize)));
    }
    if (img.startsWith('data:image')) {
      try {
        final commaIdx = img.indexOf(',');
        final base64Data = commaIdx != -1 ? img.substring(commaIdx + 1) : img;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
        );
      } catch (_) {}
    }
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(child: Text('📦', style: TextStyle(fontSize: emojiSize))),
      );
    }
    return Center(child: Text(img, style: TextStyle(fontSize: emojiSize)));
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
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
        allProducts: widget.allProducts,
        onCartUpdated: _loadCart,
      );
    }

    Color itemImageBg = const Color(0xFFF8FAFC);
    try {
      String hex = _currentItemBgColor.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) itemImageBg = Color(val);
    } catch (_) {}

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
                    color: itemImageBg,
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
          const SizedBox(height: 5),

          // 2. Product Name (Up to 3 lines, then ellipsis)
          Text(
            name,
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
            '₹${rate % 1 == 0 ? rate.toInt() : rate.toStringAsFixed(2)} / $unit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),

          const SizedBox(height: 4),

          // 4. Buy Now Button (Close to rate, dynamic height row)
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

  @override
  Widget build(BuildContext context) {
    final catBg = _parseBgColor(_currentColor);
    final products = _filteredProducts;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0.5,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: catBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _buildCategoryImage(_currentImage, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentCategory,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'in ${widget.sellerName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Cart Button with live Badge Count
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF0F172A), size: 24),
                onPressed: _openCart,
              ),
              if (_cartBadgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_cartBadgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // 1. Category Poster Banner (Full Width above search bar - Scrolls away naturally)
          if (_currentPoster.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildCategoryPosterBanner(_currentPoster),
            ),

          // 2. Sticky Search Bar, Category Filter Chips & Sort Bar (Remains Fixed at Top!)
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyFilterHeaderDelegate(
              height: widget.categories.isNotEmpty ? 143.0 : 99.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Bar inside Category (Pure White theme)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search products in $_currentCategory...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Horizontal Category Switcher (Pure White theme for unselected pills)
                  if (widget.categories.isNotEmpty)
                    Container(
                      height: 44,
                      color: Colors.white,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: widget.categories.length,
                        itemBuilder: (ctx, idx) {
                          final cat = widget.categories[idx];
                          final name = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
                          if (name.isEmpty) return const SizedBox.shrink();
                          final isSel = name.toLowerCase() == _currentCategory.toLowerCase();

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => _switchCategory(cat),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                    width: 1.2,
                                  ),
                                  boxShadow: isSel
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Sort & Count Bar (Pure White theme)
                  Container(
                    height: 38,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${products.length} Items Available',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const Spacer(),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildSortChip('Default', 'none'),
                              const SizedBox(width: 6),
                              _buildSortChip('Price: Low', 'low_to_high'),
                              const SizedBox(width: 6),
                              _buildSortChip('Price: High', 'high_to_low'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Products Grid / List
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: catBg,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _buildCategoryImage(_currentImage, size: 44),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items in "$_currentCategory"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This store has no products listed under this category yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                        label: const Text('Back to Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, rowIdx) {
                    final startIndex = rowIdx * 3;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildProductCard(products[startIndex])),
                          const SizedBox(width: 10),
                          Expanded(
                            child: startIndex + 1 < products.length
                                ? _buildProductCard(products[startIndex + 1])
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: startIndex + 2 < products.length
                                ? _buildProductCard(products[startIndex + 2])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: (products.length / 3).ceil(),
                ),
              ),
            ),
        ],
      ),

      // 5. Floating Bottom Cart Bar
      bottomNavigationBar: _cartBadgeCount > 0
          ? Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_cartBadgeCount Items in Cart',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₹${_cartTotalAmount % 1 == 0 ? _cartTotalAmount.toInt() : _cartTotalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _openCart,
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'View Cart',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSel = _priceSortOrder == value;
    return InkWell(
      onTap: () => setState(() => _priceSortOrder = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
            width: 1.1,
          ),
          boxShadow: isSel
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

/// Sticky Filter Header Delegate for Category Products Screen
/// Keeps search bar, category switcher, and sort filters pinned at top while poster scrolls away.
class _StickyFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyFilterHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterHeaderDelegate oldDelegate) {
    return true;
  }
}

/// Dynamic Category Poster Banner / Slider Widget
/// Displays a static full-width banner if 1 image, or an auto-sliding PageView carousel if > 1 image.
class CategoryPosterSliderWidget extends StatefulWidget {
  final List<String> images;
  const CategoryPosterSliderWidget({super.key, required this.images});

  @override
  State<CategoryPosterSliderWidget> createState() => _CategoryPosterSliderWidgetState();
}

class _CategoryPosterSliderWidgetState extends State<CategoryPosterSliderWidget> {
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
    if (widget.images.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_currentPage + 1) % widget.images.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(covariant CategoryPosterSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length || oldWidget.images != widget.images) {
      _currentPage = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSingleImage(String clean) {
    final img = clean.trim();
    if (img.startsWith('data:image')) {
      try {
        final commaIdx = img.indexOf(',');
        final base64Data = commaIdx != -1 ? img.substring(commaIdx + 1) : img;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 140,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    } else if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 140,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    // If only 1 image -> Static full-width banner
    if (widget.images.length == 1) {
      return Container(
        width: double.infinity,
        height: 140,
        color: const Color(0xFFF1F5F9),
        child: _buildSingleImage(widget.images.first),
      );
    }

    // Multiple images -> Slider with dots
    return Container(
      width: double.infinity,
      height: 140,
      color: const Color(0xFFF1F5F9),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (idx) {
              setState(() => _currentPage = idx);
            },
            itemBuilder: (ctx, i) {
              return _buildSingleImage(widget.images[i]);
            },
          ),
          // Dot Indicators
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.images.length, (idx) {
                  final isSel = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSel ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
