import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'seller_products_screen.dart';

class SellerMastersScreen extends StatefulWidget {
  final UserModel seller;

  const SellerMastersScreen({super.key, required this.seller});

  @override
  State<SellerMastersScreen> createState() => _SellerMastersScreenState();
}

class _SellerMastersScreenState extends State<SellerMastersScreen> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _sellerCategories = [];
  List<Map<String, dynamic>> _sellerUnits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _sellerUsername {
    final u = (widget.seller.username ?? '').trim();
    if (u.isNotEmpty) return u;
    final m = (widget.seller.mobile ?? '').trim();
    if (m.isNotEmpty) return m;
    return (widget.seller.name ?? 'seller').trim();
  }

  Future<void> _loadData() async {
    final username = _sellerUsername;

    // Fast Instant Local Cache
    final cachedProds = await AuthService.getCachedSellerProducts(username);
    final cachedCats = await AuthService.getCachedSellerCategories(username);

    if (cachedProds.isNotEmpty || cachedCats.isNotEmpty) {
      if (mounted) {
        setState(() {
          _allProducts = cachedProds;
          _sellerCategories = cachedCats;
          _isLoading = false;
        });
      }
    }

    // VPS Live Refresh
    final products = await AuthService.getSellerProducts(username);
    final units = await AuthService.getSellerUnits(username);
    final categories = await AuthService.getSellerCategories(username);

    if (mounted) {
      setState(() {
        _allProducts = products;
        _sellerUnits = units;
        _sellerCategories = categories;
        _isLoading = false;
      });
    }
  }

  void _openMasterAction(String? action) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerProductsScreen(
          seller: widget.seller,
          initialAction: action,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Store Master Hub 🗃️',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Master Data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Master Banner Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Store Control Center ⚡',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Manage your products catalog, categories, sections, units & excel bulk tools in one place.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics_rounded, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${_allProducts.length} Products | ${_sellerUnits.length} Units | ${_sellerCategories.length} Categories',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Master Cards Grid (2-Columns Layout matching drawing #44)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  _buildMasterCard(
                    title: 'Products Catalog 📦',
                    subtitle: 'View & search all items',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _openMasterAction(null),
                  ),
                  _buildMasterCard(
                    title: 'Category Master 📁',
                    subtitle: 'Manage categories',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () => _openMasterAction('category'),
                  ),
                  _buildMasterCard(
                    title: 'Section Master 🏷️',
                    subtitle: 'Ribbons & colors',
                    icon: Icons.view_carousel_rounded,
                    color: const Color(0xFFEC4899),
                    onTap: () => _openMasterAction('section'),
                  ),
                  _buildMasterCard(
                    title: 'Unit Master 📏',
                    subtitle: 'Measurement units',
                    icon: Icons.straighten_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => _openMasterAction('unit'),
                  ),
                  _buildMasterCard(
                    title: 'Search Bar Style 🔍',
                    subtitle: 'Customize top bar',
                    icon: Icons.palette_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => _openMasterAction('search_bar_style'),
                  ),
                  _buildMasterCard(
                    title: 'Download Excel 📊',
                    subtitle: 'Export catalog CSV',
                    icon: Icons.file_download_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => _openMasterAction('download_excel'),
                  ),
                  _buildMasterCard(
                    title: 'Upload Excel 📥',
                    subtitle: 'Bulk upload items',
                    icon: Icons.file_upload_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () => _openMasterAction('upload_excel'),
                  ),
                  _buildMasterCard(
                    title: 'Add New Product 📦',
                    subtitle: 'Create single item',
                    icon: Icons.add_box_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () => _openMasterAction('add_product'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
