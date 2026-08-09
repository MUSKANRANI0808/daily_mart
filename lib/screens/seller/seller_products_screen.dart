import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

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

  const SellerProductsScreen({
    super.key,
    required this.seller,
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
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final username = widget.seller.username ?? '';
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

        final matchesQuery = query.isEmpty || name.contains(query) || desc.contains(query) || unit.contains(query) || cat.contains(query);
        final matchesCategory = _selectedCategoryFilter == 'All' || cat == _selectedCategoryFilter.toLowerCase();

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
          final username = widget.seller.username ?? '';

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

                  Row(
                    children: [
                      // Thumbnail Image Picker Button
                      InkWell(
                        onTap: _pickCategoryImage,
                        child: Container(
                          width: 46,
                          height: 46,
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

                  const SizedBox(height: 10),
                  // Ring Accent Color Picker
                  Row(
                    children: [
                      const Text('Ring Color: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Text(
                                'No categories created yet. Type above and click "Add"!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: cImg.startsWith('data:image')
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.memory(base64Decode(cImg.split(',').last), fit: BoxFit.cover),
                                          )
                                        : Center(child: Text(cImg, style: const TextStyle(fontSize: 16))),
                                  ),
                                  title: Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 18),
                                        onPressed: () {
                                          _showEditCategoryPrompt(ctx, cId, cName, cImg, safeString(cMap['color'], '#8B5CF6'), setModalState);
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
                    final username = widget.seller.username ?? '';
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

    List<String> availableUnitNames = _sellerUnits.map((u) => safeString(u['unit_name'])).where((s) => s.isNotEmpty).toList();
    List<String> availableCategoryNames = _sellerCategories.map((c) => safeString(c['name'])).where((s) => s.isNotEmpty).toList();

    String selectedUnit = isEditing
        ? safeString(productToEdit['unit'])
        : (availableUnitNames.isNotEmpty ? availableUnitNames.first : '');

    String selectedCategory = isEditing
        ? safeString(productToEdit['category'])
        : (availableCategoryNames.isNotEmpty ? availableCategoryNames.first : '');

    String prodImageUrl = isEditing ? safeString(productToEdit['image_url'] ?? productToEdit['image'], '📦') : '📦';

    if (selectedUnit.isNotEmpty && !availableUnitNames.contains(selectedUnit)) {
      availableUnitNames.insert(0, selectedUnit);
    }
    if (selectedCategory.isNotEmpty && !availableCategoryNames.contains(selectedCategory)) {
      availableCategoryNames.insert(0, selectedCategory);
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
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
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
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
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
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'No units created yet. Please tap "+ Create New Unit" above to add your store units.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _showManageUnitsDialog(
                                    onUnitCreated: (newUnit) {
                                      setModalState(() {
                                        availableUnitNames = _sellerUnits.map((u) => safeString(u['unit_name'])).where((s) => s.isNotEmpty).toList();
                                        selectedUnit = newUnit;
                                      });
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('+ Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 20),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      final pName = nameController.text.trim();
                      final pDesc = descController.text.trim();
                      final pQty = int.tryParse(qtyController.text.trim()) ?? 1;
                      final pRateStr = rateController.text.trim();
                      final pRate = double.tryParse(pRateStr) ?? 0.0;

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
                          qty: pQty,
                          rate: pRate,
                          imageUrl: prodImageUrl,
                        );
                      } else {
                        await AuthService.addSellerProduct(
                          sellerUsername: username,
                          name: pName,
                          description: pDesc,
                          unit: selectedUnit,
                          category: selectedCategory,
                          qty: pQty,
                          rate: pRate,
                          imageUrl: prodImageUrl,
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
            icon: const Icon(Icons.category_rounded, color: Colors.white),
            tooltip: 'Manage Categories',
            onPressed: () => _showManageCategoriesDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.straighten_rounded, color: Colors.white),
            tooltip: 'Manage Units',
            onPressed: () => _showManageUnitsDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Products',
            onPressed: _loadData,
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, idx) {
                          final p = _filteredProducts[idx];
                          final name = safeString(p['name']);
                          final desc = safeString(p['description']);
                          final unit = safeString(p['unit'], 'Pcs');
                          final qty = safeInt(p['qty'], 1);
                          final rate = safeDouble(p['rate'], 0.0);

                          final img = safeString(p['image_url'] ?? p['image'], '📦');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Row 1: Full-width Product Name & Description at TOP
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE9FE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: img.startsWith('data:image')
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(img.split(',').last),
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                img.length <= 4 ? img : (name.isNotEmpty ? name[0].toUpperCase() : '📦'),
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        desc.isNotEmpty ? '$name ($desc)' : name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Row 2: Slim details row [Unit Badge] | [Price] | [Edit & Delete Icons]
                                Row(
                                  children: [
                                    // Unit Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Text(
                                        qty > 1 ? '$unit (x$qty)' : unit,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Price / Rate
                                    Text(
                                      '₹${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                    const Spacer(),

                                    // Action Icons (Edit & Delete side by side)
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 18),
                                      onPressed: () => _showAddEditProductDialog(productToEdit: p),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      tooltip: 'Edit Product',
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      onPressed: () => _confirmDeleteProduct(p),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      tooltip: 'Delete Product',
                                    ),
                                  ],
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
}
