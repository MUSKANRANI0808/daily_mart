import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../utils/csv_exporter.dart';

int safeInt(dynamic val, [int defaultValue = 0]) {
  if (val == null) return defaultValue;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? defaultValue;
}

double safeDouble(dynamic val, [double defaultValue = 0.0]) {
  if (val == null) return defaultValue;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? defaultValue;
}

String safeString(dynamic val, [String defaultValue = '']) {
  if (val == null) return defaultValue;
  return val.toString();
}

class SellerProductsScreen extends StatefulWidget {
  final UserModel seller;
  final String? initialAction;

  const SellerProductsScreen({
    super.key,
    required this.seller,
    this.initialAction,
  });

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _sellerUnits = [];
  List<Map<String, dynamic>> _sellerCategories = [];
  List<Map<String, dynamic>> _sellerSections = [];
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  bool _isTableView = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAction(widget.initialAction!);
      });
    }
  }

  void _handleAction(String action) {
    if (action == 'category') {
      _showManageCategoriesDialog();
    } else if (action == 'section') {
      _showManageSectionsDialog();
    } else if (action == 'unit') {
      _showManageUnitsDialog();
    } else if (action == 'search_bar_style') {
      _showManageSearchBarDialog();
    } else if (action == 'download_excel') {
      _downloadProductsToExcel();
    } else if (action == 'upload_excel') {
      _uploadProductsFromExcel();
    } else if (action == 'add_product') {
      _showAddEditProductDialog();
    }
  }

  String get _sellerUsername {
    final u = (widget.seller.username ?? '').trim();
    if (u.isNotEmpty) return u;
    final m = (widget.seller.mobile ?? '').trim();
    if (m.isNotEmpty) return m;
    return (widget.seller.name ?? 'seller').trim();
  }

  static Color hexToColor(String code, {Color defaultColor = Colors.white}) {
    if (code.trim().isEmpty) return defaultColor;
    String hex = code.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse('0x$hex'));
    } catch (_) {
      return defaultColor;
    }
  }

  Future<void> _loadData() async {
    final username = _sellerUsername;

    // 1. INSTANT LOCAL CACHE DISPLAY (0.01 Seconds - Zero Loading Delay!)
    final cachedProds = await AuthService.getCachedSellerProducts(username);
    final cachedCats = await AuthService.getCachedSellerCategories(username);
    final cachedSecs = await AuthService.getCachedSellerSections(username);

    if (cachedProds.isNotEmpty || cachedCats.isNotEmpty || cachedSecs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _allProducts = cachedProds;
          _sellerCategories = cachedCats;
          _sellerSections = cachedSecs;
          _isLoading = false;
        });
        _applyFilter();
      }
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    // 2. BACKGROUND VPS DATABASE REFRESH (Silent Sync)
    final products = await AuthService.getSellerProducts(username);
    final units = await AuthService.getSellerUnits(username);
    final categories = await AuthService.getSellerCategories(username);
    final sections = await AuthService.getSellerSections(username);

    if (mounted) {
      setState(() {
        _allProducts = products;
        _sellerUnits = units;
        _sellerCategories = categories;
        _sellerSections = sections;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final name = safeString(p['name']).toLowerCase();
        final desc = safeString(p['description']).toLowerCase();
        final unit = safeString(p['unit']).toLowerCase();
        final cat = safeString(p['category']).toLowerCase();
        final sec = safeString(p['section']).toLowerCase();

        final matchesQuery = query.isEmpty || name.contains(query) || desc.contains(query) || unit.contains(query) || cat.contains(query) || sec.contains(query);
        final matchesCategory = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter.toLowerCase() || sec == _selectedCategoryFilter.toLowerCase();

        return matchesQuery && matchesCategory;
      }).toList();
    });
  }

  /// Open Manage Categories Dialog (Category Name + Image Picker)
  void _showManageCategoriesDialog({Function(String)? onCategoryCreated}) {
    final catNameController = TextEditingController();
    String catImageUrl = '🏷️';
    String selectedRingColor = '#8B5CF6';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          Future<void> _pickCategoryImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                setModalState(() {
                  catImageUrl = base64Str;
                });
              }
            } catch (_) {}
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.category_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Store Categories 📁',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Add, edit or delete product categories & images',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Add New Category Row
                  const Text('Category Name & Image *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  // Ring Accent Color Picker (Placed at top for easy color selection)
                  Row(
                    children: [
                      const Text('Ring Color: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '#8B5CF6', '#10B981', '#F97316', '#0284C7', '#EC4899', '#F59E0B', '#EF4444', '#06B6D4'
                            ].map((hex) {
                              final isSel = selectedRingColor.toLowerCase() == hex.toLowerCase();
                              final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                              return InkWell(
                                onTap: () => setModalState(() => selectedRingColor = hex),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSel ? Colors.black : Colors.white, width: isSel ? 2.5 : 1),
                                    boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)] : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Image Selector Box
                      GestureDetector(
                        onTap: _pickCategoryImage,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                          ),
                          child: catImageUrl.startsWith('data:image')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(catImageUrl.split(',').last),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    catImageUrl,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Category Name Input Field
                      Expanded(
                        child: TextField(
                          controller: catNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter category (e.g. Snacks, Oils)',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      ElevatedButton(
                        onPressed: () async {
                          final cName = catNameController.text.trim();
                          if (cName.isEmpty) return;

                          catNameController.clear();
                          await AuthService.addSellerCategory(username, cName, catImageUrl, color: selectedRingColor);
                          final updatedCats = await AuthService.getSellerCategories(username);

                          setModalState(() {
                            _sellerCategories = updatedCats;
                            catImageUrl = '🏷️';
                          });
                          setState(() {
                            _sellerCategories = updatedCats;
                          });

                          if (onCategoryCreated != null) {
                            onCategoryCreated(cName);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Saved Store Categories List
                  const Text('Your Saved Categories:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: _sellerCategories.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'No store categories yet.\nAdd custom categories above.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _sellerCategories.length,
                            itemBuilder: (context, idx) {
                              final cMap = _sellerCategories[idx];
                              final cId = safeInt(cMap['id']);
                              final cName = safeString(cMap['name']);
                              final cImg = safeString(cMap['image_url'], '🏷️');
                              final cColorStr = safeString(cMap['color'], '#8B5CF6');
                              Color cRingColor = const Color(0xFF8B5CF6);
                              if (cColorStr.isNotEmpty) {
                                String hex = cColorStr.replaceAll('#', '');
                                if (hex.length == 6) hex = 'FF$hex';
                                final val = int.tryParse(hex, radix: 16);
                                if (val != null) cRingColor = Color(val);
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cRingColor, width: 2.5),
                                    ),
                                    child: ClipOval(
                                      child: cImg.startsWith('data:image')
                                          ? Image.memory(base64Decode(cImg.split(',').last), fit: BoxFit.cover)
                                          : Center(child: Text(cImg, style: const TextStyle(fontSize: 16))),
                                    ),
                                  ),
                                  title: Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 18),
                                        onPressed: () {
                                          _showEditCategoryPrompt(ctx, cId, cName, cImg, cColorStr, setModalState);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                        onPressed: () async {
                                          await AuthService.deleteSellerCategory(cId, username, cName);
                                          final updatedCats = await AuthService.getSellerCategories(username);
                                          setModalState(() {
                                            _sellerCategories = updatedCats;
                                          });
                                          setState(() {
                                            _sellerCategories = updatedCats;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditCategoryPrompt(BuildContext parentCtx, int catId, String currentName, String currentImg, String currentColor, StateSetter parentSetModalState) {
    final editController = TextEditingController(text: currentName);
    String editImg = currentImg;
    String editColor = currentColor.isEmpty ? '#8B5CF6' : currentColor;

    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> _pickNewImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                setDialogState(() {
                  editImg = base64Str;
                });
              }
            } catch (_) {}
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Edit Category Details 📁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _pickNewImage,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                    ),
                    child: editImg.startsWith('data:image')
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(base64Decode(editImg.split(',').last), fit: BoxFit.cover),
                          )
                        : Center(child: Text(editImg, style: const TextStyle(fontSize: 24))),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Tap box to change image/icon', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                TextField(
                  controller: editController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Category Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Ring Color: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['#8B5CF6', '#10B981', '#F97316', '#0284C7', '#EC4899', '#F59E0B', '#EF4444', '#06B6D4'].map((hex) {
                            final isSel = editColor.toLowerCase() == hex.toLowerCase();
                            final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                            return InkWell(
                              onTap: () => setDialogState(() => editColor = hex),
                              child: Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isSel ? Colors.black : Colors.white, width: isSel ? 2 : 1),
                                  boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)] : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                onPressed: () async {
                  final newName = editController.text.trim();
                  if (newName.isNotEmpty) {
                    final username = _sellerUsername;
                    Navigator.pop(ctx);
                    await AuthService.updateSellerCategory(catId, username, newName, editImg, color: editColor);
                    final updatedCats = await AuthService.getSellerCategories(username);
                    parentSetModalState(() {
                      _sellerCategories = updatedCats;
                    });
                    setState(() {
                      _sellerCategories = updatedCats;
                    });
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Open Manage Store Sections Dialog
  void _showManageSectionsDialog({Function(String)? onSectionCreated}) {
    final secNameController = TextEditingController();
    String secIcon = '🏷️';
    String secBgColor = '#FFFFFF';
    String secTextColor = '#0F172A';
    int secColumns = 2;
    int secMaxItems = 0; // 0 = All Items

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.view_carousel_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Manage Store Sections 🏷️',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Center(child: Text(secIcon, style: const TextStyle(fontSize: 22))),
                        ),
                        onSelected: (val) {
                          setModalState(() => secIcon = val);
                        },
                        itemBuilder: (ctx) => ['🔥', '🌾', '🌶️', '🍿', '🥤', '🥛', '🍞', '🥩', '🧹', '🍬', '📦', '🏷️', '🍫', '🧼', '⚡', '⭐'].map((emoji) {
                          return PopupMenuItem(
                            value: emoji,
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: secNameController,
                          decoration: InputDecoration(
                            hintText: 'Enter Section (e.g. Best Sellers, Snacks)',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final sName = secNameController.text.trim();
                          if (sName.isEmpty) return;
                          secNameController.clear();

                          await AuthService.addSellerSection(username, sName, secIcon, secBgColor, secTextColor, secColumns, secMaxItems);
                          final updatedSecs = await AuthService.getSellerSections(username);

                          setModalState(() {
                            _sellerSections = updatedSecs;
                            secIcon = '🏷️';
                            secBgColor = '#FFFFFF';
                            secTextColor = '#0F172A';
                            secColumns = 2;
                            secMaxItems = 0;
                          });
                          setState(() {
                            _sellerSections = updatedSecs;
                          });

                          if (onSectionCreated != null) {
                            onSectionCreated(sName);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 1. Products Grid Layout (1, 2 or 3 Columns) Selector
                  const Text('Section Products Grid Layout (Columns):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => secColumns = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: secColumns == 1 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.view_agenda_rounded, size: 15, color: secColumns == 1 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '1 Column 📱',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: secColumns == 1 ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => secColumns = 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: secColumns == 2 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.grid_view_rounded, size: 15, color: secColumns == 2 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '2 Columns 🟩',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: secColumns == 2 ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => secColumns = 3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: secColumns == 3 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps_rounded, size: 15, color: secColumns == 3 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '3 Columns 🧱',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: secColumns == 3 ? Colors.white : const Color(0xFF475569),
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

                  const SizedBox(height: 10),

                  // 2. Background Color Palette Selector
                  const Text('Section Card Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: secBgColor,
                        onColorSelected: (newHex) {
                          setModalState(() => secBgColor = newHex);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hexToColor(secBgColor),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hexToColor(secBgColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Background: ${secBgColor.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: hexToColor(secBgColor).computeLuminance() > 0.5 ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                ),
                                Text(
                                  'Tap to choose card background color',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: hexToColor(secBgColor).computeLuminance() > 0.5 ? const Color(0xFF64748B) : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.palette_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Background Color 🎨',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. Section Name Text / Ribbon Tag Color Palette Selector
                  const Text('Section Ribbon Tag & Title Color (Default: Red):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: secTextColor,
                        onColorSelected: (newHex) {
                          setModalState(() => secTextColor = newHex);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hexToColor(secTextColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Text Color: ${secTextColor.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: hexToColor(secTextColor),
                                  ),
                                ),
                                const Text(
                                  'Tap to choose text color for title & header',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_color_text_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Text Color ✏️',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Section Display Products Limit (View More Limit)
                  const Text('Max Products Limit To Display (View More Limit):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0, 4, 6, 8, 10, 12, 16, 20].map((limit) {
                        final isSel = secMaxItems == limit;
                        final label = limit == 0 ? 'All Items 📦' : '$limit Items 🔢';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSel ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFFF59E0B), // Yellow theme highlight
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (sel) {
                              setModalState(() => secMaxItems = limit);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text('Your Saved Sections:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: _sellerSections.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No custom sections yet. Add your first section above!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _sellerSections.length,
                            itemBuilder: (context, idx) {
                              final sMap = _sellerSections[idx];
                              final sId = safeInt(sMap['id']);
                              final sName = safeString(sMap['name']);
                              final sIcon = safeString(sMap['icon'], '🏷️');
                              final sBgHex = safeString(sMap['bg_color'], '#FFFFFF');
                              final sTextHex = safeString(sMap['text_color'], '#0F172A');
                              final sCols = safeInt(sMap['columns'], 2);
                              final sMaxLimit = safeInt(sMap['max_items'], 0);
                              final sBgCol = hexToColor(sBgHex);
                              final sTextCol = hexToColor(sTextHex);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sBgCol,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Icon Emoji
                                    Text(sIcon, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 8),

                                    // Color Preview Circles
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: sBgCol,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.black26),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: sTextCol,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Section Name & Subtitle Badges (Flexibly Expanded!)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            sName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: sTextCol,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '$sCols Col${sCols > 1 ? 's' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: sTextCol.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  sMaxLimit > 0 ? '$sMaxLimit Max 🔢' : 'All 📦',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Buttons (Edit & Delete)
                                    InkWell(
                                      onTap: () {
                                        _showEditSectionDialog(sMap, () async {
                                          final updatedSecs = await AuthService.getSellerSections(username);
                                          setModalState(() {
                                            _sellerSections = updatedSecs;
                                          });
                                          setState(() {
                                            _sellerSections = updatedSecs;
                                          });
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () async {
                                        await AuthService.deleteSellerSection(sId, username, sName);
                                        final updatedSecs = await AuthService.getSellerSections(username);
                                        setModalState(() {
                                          _sellerSections = updatedSecs;
                                        });
                                        setState(() {
                                          _sellerSections = updatedSecs;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Open Edit Section Dialog
  void _showEditSectionDialog(Map<String, dynamic> section, VoidCallback onUpdated) {
    final sId = safeInt(section['id']);
    final sNameCtrl = TextEditingController(text: safeString(section['name']));
    String editIcon = safeString(section['icon'], '🏷️');
    String editBgColor = safeString(section['bg_color'], '#FFFFFF');
    String editTextColor = safeString(section['text_color'], '#0F172A');
    int editColumns = safeInt(section['columns'], 2);
    int editMaxItems = safeInt(section['max_items'], 0);

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 22),
                SizedBox(width: 8),
                Text('Edit Section 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Section Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Center(child: Text(editIcon, style: const TextStyle(fontSize: 20))),
                        ),
                        onSelected: (val) {
                          setDlgState(() => editIcon = val);
                        },
                        itemBuilder: (ctx) => ['🔥', '🌾', '🌶️', '🍿', '🥤', '🥛', '🍞', '🥩', '🧹', '🍬', '📦', '🏷️', '🍫', '🧼', '⚡', '⭐'].map((emoji) {
                          return PopupMenuItem(
                            value: emoji,
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: sNameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Section name',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Grid Layout Columns Selector
                  const Text('Products Grid Layout (Columns):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDlgState(() => editColumns = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: editColumns == 1 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.view_agenda_rounded, size: 14, color: editColumns == 1 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '1 Col',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: editColumns == 1 ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDlgState(() => editColumns = 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: editColumns == 2 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.grid_view_rounded, size: 14, color: editColumns == 2 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '2 Cols',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: editColumns == 2 ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDlgState(() => editColumns = 3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: editColumns == 3 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps_rounded, size: 14, color: editColumns == 3 ? Colors.white : const Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '3 Cols',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: editColumns == 3 ? Colors.white : const Color(0xFF475569),
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

                  const SizedBox(height: 10),

                  // 2. Background Color
                  const Text('Card Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: editBgColor,
                        onColorSelected: (newHex) {
                          setDlgState(() => editBgColor = newHex);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hexToColor(editBgColor),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hexToColor(editBgColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Background: ${editBgColor.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: hexToColor(editBgColor).computeLuminance() > 0.5 ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                ),
                                Text(
                                  'Tap to choose card background color',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: hexToColor(editBgColor).computeLuminance() > 0.5 ? const Color(0xFF64748B) : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.palette_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Background Color 🎨',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. Section Name Text / Ribbon Tag Color Palette Selector
                  const Text('Section Ribbon Tag & Title Color (Default: Red):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: editTextColor,
                        onColorSelected: (newHex) {
                          setDlgState(() => editTextColor = newHex);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hexToColor(editTextColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Text Color: ${editTextColor.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: hexToColor(editTextColor),
                                  ),
                                ),
                                const Text(
                                  'Tap to choose text color for title & header',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_color_text_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Text Color ✏️',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Max Products Limit To Display (View More Limit)
                  const Text('Max Products Limit To Display (View More Limit):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0, 4, 6, 8, 10, 12, 16, 20].map((limit) {
                        final isSel = editMaxItems == limit;
                        final label = limit == 0 ? 'All Items 📦' : '$limit Items 🔢';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSel ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFFF59E0B), // Yellow theme highlight
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (sel) {
                              setDlgState(() => editMaxItems = limit);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final newName = sNameCtrl.text.trim();
                  if (newName.isEmpty) return;
                  Navigator.pop(dlgCtx);
                  await AuthService.updateSellerSection(sId, _sellerUsername, newName, editIcon, editBgColor, editTextColor, editColumns, editMaxItems);
                  onUpdated();
                },
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Open Manage Custom Units Dialog
  void _showManageUnitsDialog({Function(String)? onUnitCreated}) {
    final unitController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = widget.seller.username ?? '';

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header Title
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFEDE9FE),
                        child: Icon(Icons.straighten_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Store Units 🏷️',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Add, edit or delete custom store units',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Add New Unit Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: InputDecoration(
                            hintText: 'Enter unit name (e.g. 100g, 1 Kg, 1 L, 1 Pcs)',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final uName = unitController.text.trim();
                          if (uName.isEmpty) return;

                          unitController.clear();
                          await AuthService.addSellerUnit(username, uName);
                          final updatedUnits = await AuthService.getSellerUnits(username);

                          setModalState(() {
                            _sellerUnits = updatedUnits;
                          });
                          setState(() {
                            _sellerUnits = updatedUnits;
                          });

                          if (onUnitCreated != null) {
                            onUnitCreated(uName);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Add Unit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Custom Units List
                  const Text('Your Created Units:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: _sellerUnits.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Text(
                                'No units created yet. Type above and click "Add Unit" to create your first store unit!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _sellerUnits.length,
                            itemBuilder: (context, idx) {
                              final uMap = _sellerUnits[idx];
                              final uId = safeInt(uMap['id']);
                              final uName = safeString(uMap['unit_name']);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(uName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 18),
                                        onPressed: () {
                                          _showEditUnitPrompt(ctx, uId, uName, setModalState);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                        onPressed: () async {
                                          await AuthService.deleteSellerUnit(uId, username, uName);
                                          final updatedUnits = await AuthService.getSellerUnits(username);
                                          setModalState(() {
                                            _sellerUnits = updatedUnits;
                                          });
                                          setState(() {
                                            _sellerUnits = updatedUnits;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditUnitPrompt(BuildContext parentCtx, int unitId, String currentName, StateSetter parentSetModalState) {
    final editController = TextEditingController(text: currentName);
    showDialog(
      context: parentCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Unit Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () async {
              final newName = editController.text.trim();
              if (newName.isNotEmpty) {
                final username = widget.seller.username ?? '';
                Navigator.pop(ctx);
                await AuthService.updateSellerUnit(unitId, username, newName);
                final updatedUnits = await AuthService.getSellerUnits(username);
                parentSetModalState(() {
                  _sellerUnits = updatedUnits;
                });
                setState(() {
                  _sellerUnits = updatedUnits;
                });
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddEditProductDialog({Map<String, dynamic>? productToEdit}) {
    final isEditing = productToEdit != null;
    final nameController = TextEditingController(text: isEditing ? safeString(productToEdit['name']) : '');
    final descController = TextEditingController(text: isEditing ? safeString(productToEdit['description']) : '');
    final qtyController = TextEditingController(
      text: isEditing ? safeInt(productToEdit['qty'], 1).toString() : '1',
    );
    final rateController = TextEditingController(
      text: isEditing ? safeDouble(productToEdit['rate'], 0.0).toString() : '',
    );
    final buttonTextController = TextEditingController(
      text: isEditing ? safeString(productToEdit['button_text'], 'Buy Now') : 'Buy Now',
    );

    List<String> availableUnitNames = _sellerUnits.map((u) => safeString(u['unit_name'])).where((s) => s.isNotEmpty).toList();
    List<String> availableCategoryNames = _sellerCategories.map((c) => safeString(c['name'])).where((s) => s.isNotEmpty).toList();
    List<String> availableSectionNames = _sellerSections.map((s) => safeString(s['name'])).where((s) => s.isNotEmpty).toList();

    String selectedUnit = isEditing
        ? safeString(productToEdit['unit'])
        : (availableUnitNames.isNotEmpty ? availableUnitNames.first : '');

    String selectedCategory = isEditing
        ? safeString(productToEdit['category'])
        : (availableCategoryNames.isNotEmpty ? availableCategoryNames.first : '');

    String secFromProd = isEditing ? safeString(productToEdit['section']) : '';
    if (secFromProd.isEmpty && isEditing) {
      final catFromProd = safeString(productToEdit['category']);
      if (catFromProd.isNotEmpty && availableSectionNames.contains(catFromProd)) {
        secFromProd = catFromProd;
      }
    }

    String selectedSection = isEditing
        ? secFromProd
        : (availableSectionNames.isNotEmpty ? availableSectionNames.first : '');

    String prodImageUrl = isEditing ? safeString(productToEdit['image_url'] ?? productToEdit['image'], '📦') : '📦';

    if (selectedUnit.isNotEmpty && !availableUnitNames.contains(selectedUnit)) {
      availableUnitNames.insert(0, selectedUnit);
    }
    if (selectedCategory.isNotEmpty && !availableCategoryNames.contains(selectedCategory)) {
      availableCategoryNames.insert(0, selectedCategory);
    }
    if (selectedSection.isNotEmpty && !availableSectionNames.contains(selectedSection)) {
      availableSectionNames.insert(0, selectedSection);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFEDE9FE),
                        child: Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
                          color: const Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Store Product' : 'Add New Store Product',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Save product details to your store catalog',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Product Image Picker Section
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 320, maxHeight: 320);
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                              setModalState(() {
                                prodImageUrl = base64Str;
                              });
                            }
                          } catch (_) {}
                        },
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                          ),
                          child: prodImageUrl.startsWith('data:image')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    base64Decode(prodImageUrl.split(',').last),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    prodImageUrl.length <= 4 ? prodImageUrl : '📦',
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                try {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40, maxWidth: 320, maxHeight: 320);
                                  if (picked != null) {
                                    final bytes = await picked.readAsBytes();
                                    final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                    setModalState(() {
                                      prodImageUrl = base64Str;
                                    });
                                  }
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.photo_library_rounded, size: 16, color: Colors.white),
                              label: const Text('Pick Image from Gallery', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            const Text('Or pick preset icon below:', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['🍿', '🛢️', '🌶️', '🌾', '🥤', '🥛', '🍞', '🥩', '🧹', '🍬', '📦', '🏷️', '🍫', '🧼'].map((emoji) {
                        final isSel = prodImageUrl == emoji;
                        return InkWell(
                          onTap: () => setModalState(() => prodImageUrl = emoji),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFDDD6FE) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product Name Input
                  const Text('Product Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Chana, Mustard Oil, Sugar, Jeera',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product Description Input
                  const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Desi Chana, Best Quality',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Product Category Selection Header + Shortcut Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Product Category (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      InkWell(
                        onTap: () {
                          _showManageCategoriesDialog(
                            onCategoryCreated: (newCat) {
                              setModalState(() {
                                availableCategoryNames = _sellerCategories.map((c) => safeString(c['name'])).where((s) => s.isNotEmpty).toList();
                                selectedCategory = newCat;
                              });
                            },
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0284C7), size: 16),
                            SizedBox(width: 4),
                            Text('+ Create Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  availableCategoryNames.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: availableCategoryNames.map((cName) {
                            final isSel = selectedCategory == cName;
                            return ChoiceChip(
                              label: Text(cName),
                              selected: isSel,
                              selectedColor: const Color(0xFF0284C7),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                setModalState(() => selectedCategory = val ? cName : '');
                              },
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 14),

                  // Store Section Selection Header + Shortcut Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Store Section (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      InkWell(
                        onTap: () {
                          _showManageSectionsDialog(
                            onSectionCreated: (newSec) {
                              setModalState(() {
                                availableSectionNames = _sellerSections.map((s) => safeString(s['name'])).where((s) => s.isNotEmpty).toList();
                                selectedSection = newSec;
                              });
                            },
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8B5CF6), size: 16),
                            SizedBox(width: 4),
                            Text('+ Create Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  availableSectionNames.isEmpty
                      ? InkWell(
                          onTap: () {
                            _showManageSectionsDialog(
                              onSectionCreated: (newSec) {
                                setModalState(() {
                                  availableSectionNames = _sellerSections.map((s) => safeString(s['name'])).where((s) => s.isNotEmpty).toList();
                                  selectedSection = newSec;
                                });
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFD8B4FE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: Color(0xFF7E22CE)),
                                SizedBox(width: 4),
                                Text('No section created yet. Click to create!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7E22CE))),
                              ],
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: availableSectionNames.map((sName) {
                            final isSel = selectedSection == sName;
                            return ChoiceChip(
                              label: Text(sName),
                              selected: isSel,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                setModalState(() => selectedSection = val ? sName : '');
                              },
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 14),

                  // Unit Selection Header + Shortcut "+ Add Unit" Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Unit / Measurement *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      InkWell(
                        onTap: () {
                          _showManageUnitsDialog(
                            onUnitCreated: (newUnit) {
                              setModalState(() {
                                availableUnitNames = _sellerUnits.map((u) => safeString(u['unit_name'])).where((s) => s.isNotEmpty).toList();
                                selectedUnit = newUnit;
                              });
                            },
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8B5CF6), size: 16),
                            SizedBox(width: 4),
                            Text('+ Create New Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  availableUnitNames.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('No units available. Please create a unit.', style: TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                              ),
                            ],
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: availableUnitNames.map((u) {
                            final isSel = selectedUnit == u;
                            return ChoiceChip(
                              label: Text(u),
                              selected: isSel,
                              selectedColor: const Color(0xFF8B5CF6),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedUnit = u);
                              },
                            );
                          }).toList(),
                        ),
                  // Quantity & Price Row
                  Row(
                    children: [
                      // Qty Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity (Qty) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '1',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Rate Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rate / Price (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: rateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 15),
                                hintText: '0.00',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Custom Action Button Text (e.g. Buy Now, Shop Now, Order Now)
                  const Text('Card Action Button Text (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  const Text('Customize the action button shown to customer (e.g. Buy Now, Shop Now, Add)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: buttonTextController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Buy Now, Shop Now, Order Now',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      final pName = nameController.text.trim();
                      final pDesc = descController.text.trim();
                      final pQty = int.tryParse(qtyController.text.trim()) ?? 1;
                      final pRateStr = rateController.text.trim();
                      final pRate = double.tryParse(pRateStr) ?? 0.0;
                      final pBtnText = buttonTextController.text.trim().isNotEmpty ? buttonTextController.text.trim() : 'Buy Now';

                      if (pName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter Product Name.')),
                        );
                        return;
                      }

                      if (selectedUnit.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or create a Unit for the product.')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);

                      final username = widget.seller.username ?? '';
                      if (isEditing) {
                        final pId = safeInt(productToEdit['id']);
                        await AuthService.updateSellerProduct(
                          id: pId,
                          sellerUsername: username,
                          name: pName,
                          description: pDesc,
                          unit: selectedUnit,
                          category: selectedCategory,
                          section: selectedSection,
                          qty: pQty,
                          rate: pRate,
                          imageUrl: prodImageUrl,
                          buttonText: pBtnText,
                        );
                      } else {
                        await AuthService.addSellerProduct(
                          sellerUsername: username,
                          name: pName,
                          description: pDesc,
                          unit: selectedUnit,
                          category: selectedCategory,
                          section: selectedSection,
                          qty: pQty,
                          rate: pRate,
                          imageUrl: prodImageUrl,
                          buttonText: pBtnText,
                        );
                      }

                      await _loadData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isEditing ? Icons.check_circle_rounded : Icons.add_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'Save Product Changes' : 'Add Product to Catalog',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteProduct(Map<String, dynamic> product) {
    final pId = safeInt(product['id']);
    final pName = safeString(product['name'], 'Product');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to delete "$pName" from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              await AuthService.deleteSellerProduct(pId, widget.seller.username ?? '');
              await _loadData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageWidget(String rawImg, {double emojiSize = 40, BoxFit fit = BoxFit.cover}) {
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

  Color _hexToColor(String code, {Color defaultColor = Colors.white}) {
    try {
      String cleanHex = code.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  /// Seller Search Bar Customization & Transparency Dialog
  void _showManageSearchBarDialog() async {
    final currentConfig = await AuthService.getHeaderThemeConfig();
    String bgColor = (currentConfig['search_bg_color'] ?? '#FFFFFF').toString();
    double opacity = ((currentConfig['search_opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    String textColor = (currentConfig['search_text_color'] ?? '#0F172A').toString();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final Color previewColor = _hexToColor(bgColor).withValues(alpha: opacity);
          final Color previewTextColor = _hexToColor(textColor);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Manage Search Bar Style 🔍',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real-time Header Preview Box
                  const Text('Live Header Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF312E81)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: previewTextColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Search products in store...',
                            style: TextStyle(color: previewTextColor.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Background Color Selection
                  const Text('Search Bar Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#FFFFFF', '#F1F5F9', '#0F172A', '#8B5CF6', '#10B981', '#3B82F6', '#F97316', '#FEF3C7', '#ECFDF5', '#FEE2E2'
                      ].map((hex) {
                        final isSel = bgColor.toLowerCase() == hex.toLowerCase();
                        final c = _hexToColor(hex);
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              bgColor = hex;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 2.8 : 1),
                              boxShadow: isSel ? [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 6)] : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Transparency Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Transparency / Opacity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(opacity * 100).toInt()}% ${opacity == 1.0 ? '(Solid)' : opacity == 0.0 ? '(Transparent)' : '(Glass)'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: opacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: const Color(0xFF8B5CF6),
                    inactiveColor: const Color(0xFFE2E8F0),
                    onChanged: (val) {
                      setModalState(() {
                        opacity = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Text & Icon Color
                  const Text('Search Text & Icon Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      '#0F172A', '#FFFFFF', '#8B5CF6', '#2563EB', '#10B981'
                    ].map((hex) {
                      final isSel = textColor.toLowerCase() == hex.toLowerCase();
                      final c = _hexToColor(hex);
                      return InkWell(
                        onTap: () => setModalState(() => textColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                          ),
                          child: isSel ? const Icon(Icons.check, size: 16, color: Colors.amber) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final updatedConfig = Map<String, dynamic>.from(currentConfig);
                      updatedConfig['search_bg_color'] = bgColor;
                      updatedConfig['search_opacity'] = opacity;
                      updatedConfig['search_text_color'] = textColor;

                      await AuthService.saveHeaderThemeConfig(updatedConfig);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Save Search Bar Style', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Products Catalog 📦',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Add Product',
            onPressed: () => _showAddEditProductDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Products',
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            tooltip: 'Masters Menu ⚙️',
            onSelected: (value) => _handleAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'category',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, color: Color(0xFF0284C7), size: 20),
                    SizedBox(width: 10),
                    Text('Category Master 📁', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'section',
                child: Row(
                  children: [
                    Icon(Icons.view_carousel_rounded, color: Color(0xFF8B5CF6), size: 20),
                    SizedBox(width: 10),
                    Text('Section Master 🏷️', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unit',
                child: Row(
                  children: [
                    Icon(Icons.straighten_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 10),
                    Text('Unit Master 📏', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search_bar_style',
                child: Row(
                  children: [
                    Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 20),
                    SizedBox(width: 10),
                    Text('Search Bar Style 🔍', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'download_excel',
                child: Row(
                  children: [
                    Icon(Icons.file_download_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 10),
                    Text('Download Excel 📊', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'upload_excel',
                child: Row(
                  children: [
                    Icon(Icons.file_upload_rounded, color: Color(0xFF0284C7), size: 20),
                    SizedBox(width: 10),
                    Text('Upload Excel 📥', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'add_product',
                child: Row(
                  children: [
                    Icon(Icons.add_box_rounded, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 10),
                    Text('Add New Product 📦', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search & Unit Manager Header Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilter();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search products by name or description...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditProductDialog(),
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_filteredProducts.length} Products | ${_sellerUnits.length} Units | ${_sellerCategories.length} Categories',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showManageCategoriesDialog(),
                      child: const Text(
                        '📁 Categories',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showManageUnitsDialog(),
                      child: const Text(
                        '🏷️ Units',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ],
                ),
                if (_sellerCategories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _selectedCategoryFilter == 'All',
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: _selectedCategoryFilter == 'All' ? Colors.white : const Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedCategoryFilter = 'All';
                              });
                              _applyFilter();
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        ..._sellerCategories.map((c) {
                          final cName = safeString(c['name']);
                          final isSel = _selectedCategoryFilter.toLowerCase() == cName.toLowerCase();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cName),
                              selected: isSel,
                              selectedColor: const Color(0xFF0284C7),
                              backgroundColor: const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : const Color(0xFF334155),
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                fontSize: 11.5,
                              ),
                              onSelected: (val) {
                                setState(() {
                                  _selectedCategoryFilter = val ? cName : 'All';
                                });
                                _applyFilter();
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // View Mode Switcher Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Text(
                  '${_filteredProducts.length} Items Found',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isTableView = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _isTableView ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.table_chart_rounded, size: 14, color: _isTableView ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Table View 📊',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isTableView ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _isTableView = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: !_isTableView ? const Color(0xFF0F172A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.grid_view_rounded, size: 14, color: !_isTableView ? Colors.white : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Cards View 🪟',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: !_isTableView ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Product List Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircleAvatar(
                                radius: 36,
                                backgroundColor: Color(0xFFEDE9FE),
                                child: Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF8B5CF6)),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Products Found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No product matches "$_searchQuery". Try searching something else.'
                                    : 'Start adding items to your store catalog so customers can select products in 1-click!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditProductDialog(),
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                label: const Text('Add Your First Product', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _isTableView
                        ? _buildProductTableView()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, idx) {
                              final p = _filteredProducts[idx];
                              final name = safeString(p['name']);
                              final desc = safeString(p['description']);
                              final unit = safeString(p['unit'], 'Pcs');
                              final qty = safeInt(p['qty'], 1);
                              final rate = safeDouble(p['rate'], 0.0);
                              final pSec = safeString(p['section']);
                              final pCat = safeString(p['category']);

                              final imgUrl = safeString(p['image_url']).trim();
                              final imgVal = safeString(p['image']).trim();
                              final img = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // 1. Compact Thumbnail (28x28)
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: _buildProductImageWidget(img, emojiSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. Name & Category/Section Tag Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            desc.isNotEmpty ? '$name ($desc)' : name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (pSec.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3E8FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '🏷️ $pSec',
                                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                                                  ),
                                                )
                                              else if (pCat.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE0F2FE),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '📁 $pCat',
                                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // 3. Unit Badge e.g. [BOX]
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(
                                        qty > 1 ? '$unit x$qty' : unit,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 4. Rate / Price e.g. ₹62
                                    Text(
                                      '₹${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    // 5. Edit Button
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 16),
                                      onPressed: () => _showAddEditProductDialog(productToEdit: p),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      tooltip: 'Edit',
                                    ),

                                    // 6. Delete Button
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                      onPressed: () => _confirmDeleteProduct(p),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditProductDialog(),
        backgroundColor: const Color(0xFF8B5CF6),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildProductTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 60,
              horizontalMargin: 14,
              columnSpacing: 18,
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Product Item 📦')),
                DataColumn(label: Text('Short Description')),
                DataColumn(label: Text('Long Description')),
                DataColumn(label: Text('Category 📁')),
                DataColumn(label: Text('Section 🏷️')),
                DataColumn(label: Text('Unit 📏')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Sale Rate (₹)')),
                DataColumn(label: Text('Purchase Rate (₹)')),
                DataColumn(label: Text('Profit Margin')),
                DataColumn(label: Text('Actions ⚙️')),
              ],
              rows: List.generate(_filteredProducts.length, (idx) {
                final p = _filteredProducts[idx];
                final name = safeString(p['name']);
                final desc = safeString(p['description']);
                final longDesc = safeString(p['long_description'] ?? p['details']);
                final cat = safeString(p['category']);
                final sec = safeString(p['section']);
                final unit = safeString(p['unit'], 'Pcs');
                final qty = safeInt(p['qty'], 1);
                final saleRate = safeDouble(p['rate'], 0.0);
                final purRate = safeDouble(p['purchase_rate'] ?? p['purchase_price'], 0.0);
                final margin = saleRate - purRate;

                final imgUrl = safeString(p['image_url']).trim();
                final imgVal = safeString(p['image']).trim();
                final img = imgUrl.isNotEmpty ? imgUrl : (imgVal.isNotEmpty ? imgVal : '📦');

                final isEven = idx % 2 == 0;

                return DataRow(
                  color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                  cells: [
                    DataCell(Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
                    DataCell(
                      InkWell(
                        onTap: () => _showAddEditProductDialog(productToEdit: p),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildProductImageWidget(img, emojiSize: 16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        desc.isNotEmpty ? desc : '-',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        longDesc.isNotEmpty ? longDesc : '-',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(cat.isNotEmpty ? cat : 'General', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Text(sec.isNotEmpty ? sec : 'General', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(unit, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ),
                    DataCell(Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    DataCell(
                      Text(
                        '₹${saleRate.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF059669)),
                      ),
                    ),
                    DataCell(
                      Text(
                        purRate > 0 ? '₹${purRate.toStringAsFixed(2)}' : '-',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    DataCell(
                      Text(
                        purRate > 0 ? '+₹${margin.toStringAsFixed(2)}' : '-',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: margin >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 18),
                            tooltip: 'Edit Product',
                            onPressed: () => _showAddEditProductDialog(productToEdit: p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            tooltip: 'Delete Product',
                            onPressed: () => _confirmDeleteProduct(p),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  /// Download Products list as Excel / CSV file
  void _downloadProductsToExcel() {
    final StringBuffer csvBuf = StringBuffer();
    // UTF-8 BOM for Excel compatibility (so Excel opens Hindi/English cleanly)
    csvBuf.write('\uFEFF');

    // 9 Columns requested by user:
    // Item name, Short Discription, Long Disdription, Category, Section, Unit, Qty, Sale Rate, Purchage Rate
    csvBuf.writeln('Item name,Short Discription,Long Disdription,Category,Section,Unit,Qty,Sale Rate,Purchage Rate');

    if (_allProducts.isNotEmpty) {
      for (var p in _allProducts) {
        final itemName = _csvEscape(p['name'] ?? '');
        final shortDesc = _csvEscape(p['description'] ?? '');
        final longDesc = _csvEscape(p['long_description'] ?? p['details'] ?? '');
        final category = _csvEscape(p['category'] ?? '');
        final section = _csvEscape(p['section'] ?? '');
        final unit = _csvEscape(p['unit'] ?? 'Pcs');
        final qty = (p['qty'] ?? 1).toString();
        final saleRate = (double.tryParse((p['rate'] ?? p['sale_rate'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2);
        final purRate = (double.tryParse((p['purchase_rate'] ?? p['purchase_price'] ?? 0).toString()) ?? 0.0).toStringAsFixed(2);

        csvBuf.writeln('$itemName,$shortDesc,$longDesc,$category,$section,$unit,$qty,$saleRate,$purRate');
      }
    } else {
      // Template rows for easy filling if seller has no products yet
      csvBuf.writeln('Nimak (Namak),Fresh Iodized Salt,High quality iodized salt for everyday cooking,Grocery,Daily Use,Kg,1,20.00,15.00');
      csvBuf.writeln('Sabun,Bathing Soap,Pure herbal bathing soap bar,Grocery,Daily Use,Pcs,1,5.00,3.50');
      csvBuf.writeln('Kurkure,Masala Munch,Crispy spicy corn puffs packet,Snacks,Popular,Pcs,1,5.00,4.00');
    }

    final now = DateTime.now();
    final timeStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'DailyMart_Products_$timeStr.csv';

    downloadCsvFile(csvBuf.toString(), fileName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Excel file downloaded successfully: $fileName 📊'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _csvEscape(dynamic value) {
    String str = (value ?? '').toString().replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"$str"';
    }
    return str;
  }

  /// Upload Products from Excel / CSV file
  Future<void> _uploadProductsFromExcel() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();
      final csvString = utf8.decode(bytes, allowMalformed: true);

      if (csvString.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file is empty or could not be read ❌'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      // Convert CSV content to rows
      final List<List<dynamic>> rows = const CsvDecoder().convert(csvString);

      if (rows.isEmpty || rows.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No product data rows found in Excel file ❌'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      // Read Header Row (Row 0)
      final List<String> headers = rows[0].map((h) => h.toString().trim().toLowerCase()).toList();

      int nameIdx = headers.indexWhere((h) => h.contains('item name') || h.contains('item_name') || h == 'name' || h.contains('product'));
      int shortDescIdx = headers.indexWhere((h) => h.contains('short') || h == 'description' || h.contains('sub'));
      int longDescIdx = headers.indexWhere((h) => h.contains('long') || h.contains('details') || h.contains('full'));
      int catIdx = headers.indexWhere((h) => h.contains('category') || h == 'cat');
      int secIdx = headers.indexWhere((h) => h.contains('section') || h == 'sec');
      int unitIdx = headers.indexWhere((h) => h.contains('unit'));
      int qtyIdx = headers.indexWhere((h) => h.contains('qty') || h.contains('quantity') || h.contains('stock'));
      int saleRateIdx = headers.indexWhere((h) => h.contains('sale') || h.contains('rate') || h.contains('price') || h.contains('mrp'));
      int purRateIdx = headers.indexWhere((h) => h.contains('purch') || h.contains('cost') || h.contains('buy'));

      // Smart fallback indexing if headers match standard order:
      // Item name, Short Discription, Long Disdription, Category, Section, Unit, Qty, Sale Rate, Purchage Rate
      if (nameIdx == -1 && headers.isNotEmpty) nameIdx = 0;
      if (shortDescIdx == -1 && headers.length > 1) shortDescIdx = 1;
      if (longDescIdx == -1 && headers.length > 2) longDescIdx = 2;
      if (catIdx == -1 && headers.length > 3) catIdx = 3;
      if (secIdx == -1 && headers.length > 4) secIdx = 4;
      if (unitIdx == -1 && headers.length > 5) unitIdx = 5;
      if (qtyIdx == -1 && headers.length > 6) qtyIdx = 6;
      if (saleRateIdx == -1 && headers.length > 7) saleRateIdx = 7;
      if (purRateIdx == -1 && headers.length > 8) purRateIdx = 8;

      final List<Map<String, dynamic>> parsedProducts = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final String itemName = (nameIdx >= 0 && nameIdx < row.length) ? row[nameIdx].toString().trim() : '';
        if (itemName.isEmpty || itemName.toLowerCase() == 'item name') continue;

        final String shortDesc = (shortDescIdx >= 0 && shortDescIdx < row.length) ? row[shortDescIdx].toString().trim() : '';
        final String longDesc = (longDescIdx >= 0 && longDescIdx < row.length) ? row[longDescIdx].toString().trim() : '';
        final String category = (catIdx >= 0 && catIdx < row.length) ? row[catIdx].toString().trim() : '';
        final String section = (secIdx >= 0 && secIdx < row.length) ? row[secIdx].toString().trim() : '';
        final String unit = (unitIdx >= 0 && unitIdx < row.length && row[unitIdx].toString().trim().isNotEmpty) ? row[unitIdx].toString().trim() : 'Pcs';
        final int qty = (qtyIdx >= 0 && qtyIdx < row.length) ? (int.tryParse(row[qtyIdx].toString().trim()) ?? 1) : 1;
        final double saleRate = (saleRateIdx >= 0 && saleRateIdx < row.length) ? (double.tryParse(row[saleRateIdx].toString().trim()) ?? 0.0) : 0.0;
        final double purRate = (purRateIdx >= 0 && purRateIdx < row.length) ? (double.tryParse(row[purRateIdx].toString().trim()) ?? 0.0) : 0.0;

        parsedProducts.add({
          'name': itemName,
          'description': shortDesc,
          'long_description': longDesc,
          'category': category,
          'section': section,
          'unit': unit,
          'qty': qty <= 0 ? 1 : qty,
          'rate': saleRate,
          'purchase_rate': purRate,
        });
      }

      if (parsedProducts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid product records found in Excel file ❌'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      // Show Upload Confirmation Preview Modal
      _showUploadPreviewModal(parsedProducts);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading Excel file: $e ❌'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  /// Show Upload Preview & Confirmation Dialog
  void _showUploadPreviewModal(List<Map<String, dynamic>> parsedProducts) {
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.file_upload_rounded, color: Color(0xFF0284C7), size: 26),
                        const SizedBox(width: 10),
                        Text(
                          'Upload Products (${parsedProducts.length}) 📊',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Found ${parsedProducts.length} product(s) in Excel file. Preview first few items below:',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),

                // Preview List Container
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: parsedProducts.length > 5 ? 5 : parsedProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = parsedProducts[idx];
                      return ListTile(
                        dense: true,
                        title: Text(
                          p['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        subtitle: Text(
                          'Cat: ${p['category'].toString().isEmpty ? 'General' : p['category']} | Sec: ${p['section'].toString().isEmpty ? 'General' : p['section']} | Unit: ${p['unit']}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${p['rate']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                            ),
                            if (safeDouble(p['purchase_rate']) > 0)
                              Text(
                                'Buy: ₹${p['purchase_rate']}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (parsedProducts.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+ ${parsedProducts.length - 5} more items ready to upload...',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                    ),
                  ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            setModalState(() => isUploading = true);
                            final count = await AuthService.bulkAddSellerProducts(
                              sellerUsername: widget.seller.username ?? '',
                              productsList: parsedProducts,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);

                            await _loadData();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully uploaded $count products! 🎉'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: isUploading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Uploading Products...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          )
                        : Text(
                            'Upload ${parsedProducts.length} Products Now 🚀',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
