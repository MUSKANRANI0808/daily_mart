import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/image_border_helper.dart';
import '../../utils/header_theme_helper.dart';
import '../../utils/json_picker.dart';
import '../../widgets/product_border_wrapper.dart';
import 'seller_products_screen.dart';

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

class SellerMastersScreen extends StatefulWidget {
  final UserModel seller;

  const SellerMastersScreen({super.key, required this.seller});

  @override
  State<SellerMastersScreen> createState() => _SellerMastersScreenState();
}

class _SellerMastersScreenState extends State<SellerMastersScreen> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _sellerCategories = [];
  List<Map<String, dynamic>> _sellerSections = [];
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

  Color hexToColor(String code, {Color defaultColor = Colors.white}) {
    try {
      String cleanHex = code.replaceAll('#', '').trim();
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex';
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  Future<void> _loadData() async {
    final username = _sellerUsername;

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
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

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
    }
  }

  // --- 1. CATEGORY MASTER DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
  void _showManageCategoriesDialog() {
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

                  const Text('Category Name & Image *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Existing Categories:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
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

  // --- 2. SECTION MASTER DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
  void _showManageSectionsDialog() {
    final secNameController = TextEditingController();
    String secIcon = '🏷️';
    String secBgColor = '#FFFFFF';
    String secTextColor = '#0F172A';
    int secColumns = 2;
    int secMaxItems = 0;

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
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section Customization Options
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Section Display Layout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
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
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tap to Choose Color ($secBgColor)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const Icon(Icons.color_lens_rounded, color: Color(0xFF8B5CF6), size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('Section Ribbon Tag Text Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '#EC4899', '#8B5CF6', '#10B981', '#3B82F6', '#F97316', '#EF4444', '#0F172A', '#0284C7'
                            ].map((hex) {
                              final isSel = secTextColor.toLowerCase() == hex.toLowerCase();
                              final c = hexToColor(hex);
                              return InkWell(
                                onTap: () => setModalState(() => secTextColor = hex),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSel ? Colors.black : Colors.white, width: isSel ? 2.5 : 1),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Existing Sections:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: _sellerSections.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'No store sections yet.\nCreate ribbon sections above.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
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
                              final sTextColor = safeString(sMap['text_color'], '#EC4899');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Text(sIcon, style: const TextStyle(fontSize: 20)),
                                  title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A))),
                                  subtitle: Text('Ribbon: $sTextColor', style: TextStyle(fontSize: 11, color: hexToColor(sTextColor))),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                    onPressed: () async {
                                      await AuthService.deleteSellerSection(sId, username, sName);
                                      final updatedSecs = await AuthService.getSellerSections(username);
                                      setModalState(() {
                                        _sellerSections = updatedSecs;
                                      });
                                      setState(() {
                                        _sellerSections = updatedSecs;
                                      });
                                    },
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

  // --- 3. UNIT MASTER DIALOG (EXACT ORIGINAL LOGIC & DESIGN FROM 3-DOT MENU) ---
  void _showManageUnitsDialog({Function(String)? onUnitCreated}) {
    final unitController = TextEditingController();

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
                final username = _sellerUsername;
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

  // --- 4. SEARCH BAR STYLE DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
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
          final Color previewColor = hexToColor(bgColor).withValues(alpha: opacity);
          final Color previewTextColor = hexToColor(textColor);

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

                  const Text('Search Bar Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#FFFFFF', '#F1F5F9', '#0F172A', '#8B5CF6', '#10B981', '#3B82F6', '#F97316', '#FEF3C7', '#ECFDF5', '#FEE2E2'
                      ].map((hex) {
                        final isSel = bgColor.toLowerCase() == hex.toLowerCase();
                        final c = hexToColor(hex);
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

                  const Text('Search Text & Icon Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      '#0F172A', '#FFFFFF', '#8B5CF6', '#2563EB', '#10B981'
                    ].map((hex) {
                      final isSel = textColor.toLowerCase() == hex.toLowerCase();
                      final c = hexToColor(hex);
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
                      final updatedMap = Map<String, dynamic>.from(currentConfig);
                      updatedMap['search_bg_color'] = bgColor;
                      updatedMap['search_opacity'] = opacity;
                      updatedMap['search_text_color'] = textColor;

                      Navigator.pop(ctx);
                      await AuthService.saveHeaderThemeConfig(updatedMap);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Search Bar Style 🎨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 5. DOWNLOAD EXCEL (EXACT ORIGINAL LOGIC) ---
  void _downloadProductsToExcel() {
    final StringBuffer csvBuf = StringBuffer();
    csvBuf.write('\uFEFF');
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

  // --- 6. UPLOAD EXCEL (EXACT ORIGINAL LOGIC & PREVIEW MODAL) ---
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

  // --- 7. ADD SINGLE PRODUCT DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
  void _showAddEditProductDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Product 📦', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Short Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sale Rate (₹)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty) {
                await AuthService.addSellerProduct(
                  sellerUsername: _sellerUsername,
                  name: name,
                  description: descCtrl.text.trim(),
                  rate: rate,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                await _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Save Product', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 8. PRODUCT BORDER FRAME MASTER DIALOG ---
  void _showManageProductBorderDialog() {
    String currentBorder = AuthService.getCachedSellerProductBorderImage(_sellerUsername) ?? '';
    final urlController = TextEditingController(text: currentBorder.startsWith('http') ? currentBorder : '');
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          Future<void> _processAndSetImage(Uint8List bytes) async {
            setModalState(() {
              isProcessing = true;
            });
            try {
              final transparentPngBase64 = await ImageBorderHelper.makeWhiteBackgroundTransparent(bytes);
              setModalState(() {
                currentBorder = transparentPngBase64;
                isProcessing = false;
              });
            } catch (_) {
              setModalState(() {
                currentBorder = 'data:image/png;base64,${base64Encode(bytes)}';
                isProcessing = false;
              });
            }
          }

          Future<void> _pickBorderImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                await _processAndSetImage(bytes);
              }
            } catch (_) {}
          }

          Future<void> _removeWhiteFromCurrentBorder() async {
            if (currentBorder.isEmpty) return;
            setModalState(() {
              isProcessing = true;
            });

            try {
              Uint8List? inputBytes;
              if (currentBorder.startsWith('http://') || currentBorder.startsWith('https://')) {
                final res = await http.get(Uri.parse(currentBorder)).timeout(const Duration(seconds: 8));
                if (res.statusCode == 200) {
                  inputBytes = res.bodyBytes;
                }
              } else {
                String base64Str = currentBorder;
                if (currentBorder.contains(',')) {
                  base64Str = currentBorder.split(',').last.trim();
                }
                inputBytes = base64Decode(base64Str);
              }

              if (inputBytes != null) {
                final transparentPngBase64 = await ImageBorderHelper.makeWhiteBackgroundTransparent(inputBytes);
                setModalState(() {
                  currentBorder = transparentPngBase64;
                  isProcessing = false;
                });
              } else {
                setModalState(() => isProcessing = false);
              }
            } catch (_) {
              setModalState(() => isProcessing = false);
            }
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
                        backgroundColor: Color(0xFFFCE7F3),
                        child: Icon(Icons.border_outer_rounded, color: Color(0xFFEC4899), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Product Border Frame 🖼️',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload any border image (JPG or PNG). White background is automatically removed to make a transparent PNG border frame!',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload / Select Options
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : _pickBorderImage,
                          icon: isProcessing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(
                            isProcessing ? 'Processing PNG...' : 'Pick Border Image 📁',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (currentBorder.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  setModalState(() {
                                    currentBorder = '';
                                    urlController.clear();
                                  });
                                },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          label: const Text('Clear', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // URL alternative input
                  TextField(
                    controller: urlController,
                    onChanged: (val) {
                      setModalState(() {
                        currentBorder = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Or Paste Image URL',
                      hintText: 'https://example.com/border.png',
                      isDense: true,
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Auto Remove White BG Action Button
                  if (currentBorder.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isProcessing ? null : _removeWhiteFromCurrentBorder,
                        icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 18),
                        label: const Text(
                          'Auto-Remove White Background ✨ (Make Center Transparent)',
                          style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8B5CF6)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Live Preview Card
                  const Text('Live Preview (Product inside Border):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ProductBorderWrapper(
                          borderImage: currentBorder,
                          borderRadius: BorderRadius.circular(16),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🧼', style: TextStyle(fontSize: 36)),
                                SizedBox(height: 4),
                                Text('Sabun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('₹5 / Pcs', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              await AuthService.saveSellerProductBorderImage(username, currentBorder);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(currentBorder.isNotEmpty ? '✓ Transparent PNG product border saved! 🎉' : '✓ Product border removed!'),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Border Settings 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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

  // --- 9. HEADER LOTTIE ANIMATIONS MASTER DIALOG ---
  void _showManageHeaderAnimationsDialog() {
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          List<String> animationsList = AuthService.getCachedSellerHeaderAnimations(username) ?? [];
          bool isProcessing = false;

          final jsonCodeController = TextEditingController();

          Future<void> _pickLottieJsonFile() async {
            try {
              setModalState(() => isProcessing = true);
              final String? jsonStr = await JsonPickerHelper.pickJsonString();

              if (jsonStr != null && jsonStr.trim().isNotEmpty) {
                final cleanJson = jsonStr.trim();
                try {
                  jsonDecode(cleanJson);
                  setModalState(() {
                    animationsList.add(cleanJson);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Lottie JSON animation added successfully! 🎉'),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected file is not a valid Lottie JSON format ❌'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upload error: $e ❌'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } finally {
              setModalState(() => isProcessing = false);
            }
          }

          void _addJsonTextAnimation() {
            final text = jsonCodeController.text.trim();
            if (text.isEmpty) return;
            try {
              jsonDecode(text);
              setModalState(() {
                animationsList.add(text);
                jsonCodeController.clear();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Pasted Lottie JSON animation added! 🎉'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pasted text is not valid Lottie JSON ❌'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }

          void _addUrlAnimation() {
            final url = urlController.text.trim();
            if (url.isEmpty) return;
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid http/https Lottie JSON URL ❌'), backgroundColor: Colors.red),
              );
              return;
            }
            setModalState(() {
              animationsList.add(url);
              urlController.clear();
            });
          }

          void _addPresetAnimation(String presetUrl) {
            if (animationsList.contains(presetUrl)) return;
            setModalState(() {
              animationsList.add(presetUrl);
            });
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
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.movie_filter_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Header Lottie Animations 🎬',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Upload custom JSON animations to auto-slide in header!',
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

                  // Upload Button & Info
                  const Text('Add Animation (.json file or URL) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : _pickLottieJsonFile,
                      icon: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                      label: Text(
                        isProcessing ? 'Reading JSON file...' : 'Upload Lottie JSON (.json) 📤',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // URL Input Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: urlController,
                          decoration: InputDecoration(
                            hintText: 'Or paste Lottie JSON URL (https://...)',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addUrlAnimation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: const Text('Add ➕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Paste JSON Code Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: jsonCodeController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Or paste JSON code content ({"v":"5..."})',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addJsonTextAnimation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: const Text('Add JSON 📋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Preset Animations Chips
                  const Text('Quick Add Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      {
                        'label': '🚀 Daily Mart Express',
                        'url': 'assets/lottie/daily_mart_exclusive.json',
                      },
                      {
                        'label': '🇮🇳 Freedom Sale',
                        'url': 'assets/lottie/freedom_sale.json',
                      },
                      {
                        'label': '🪔 Diwali Lights',
                        'url': 'assets/lottie/diwali_lights.json',
                      },
                      {
                        'label': '🥦 Grocery Shopping',
                        'url': 'assets/lottie/grocery_shopping.json',
                      },
                      {
                        'label': '⚡ Flash Sale',
                        'url': 'assets/lottie/express_flash.json',
                      },
                      {
                        'label': '🌧️ Monsoon Rain',
                        'url': 'assets/lottie/monsoon_rain.json',
                      },
                      {
                        'label': '🎉 New Year',
                        'url': 'assets/lottie/new_year.json',
                      },
                    ].map((preset) {
                      final isAdded = animationsList.contains(preset['url']);
                      return ActionChip(
                        avatar: Icon(
                          isAdded ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          size: 16,
                          color: isAdded ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                        ),
                        label: Text(
                          preset['label']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isAdded ? const Color(0xFF047857) : const Color(0xFF4C1D95),
                          ),
                        ),
                        backgroundColor: isAdded ? const Color(0xFFD1FAE5) : const Color(0xFFF3E8FF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () => _addPresetAnimation(preset['url']!),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Uploaded Animations List
                  Text(
                    'Configured Animations (${animationsList.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  if (animationsList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'No animations added yet. Upload JSON files or select presets above! 🎬',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: animationsList.length,
                        itemBuilder: (context, idx) {
                          final animData = animationsList[idx];
                          return Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                            ),
                            child: Stack(
                              children: [
                                // Animation Preview
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: buildSingleLottieItem(animData, fit: BoxFit.cover),
                                  ),
                                ),

                                // Index Badge
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),

                                // Delete Button
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        animationsList.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
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

                  // Live Header Preview Box
                  const Text('Live Header Auto-Slide Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: HeaderLottieCarouselWidget(
                        overrideAnimations: animationsList,
                        config: const {
                          'color1': '#0F172A',
                          'color2': '#1E1B4B',
                          'color3': '#312E81',
                          'lottie_opacity': 0.9,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        await AuthService.saveSellerHeaderAnimations(username, animationsList);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Header Lottie Animations saved successfully! (${animationsList.length} total) 🎉'),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Animations 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Master Hub',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Control Center ⚡',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage your products catalog, categories, sections, units & excel bulk tools in one place.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerProductsScreen(seller: widget.seller),
                        ),
                      );
                    },
                  ),
                  _buildMasterCard(
                    title: 'Category Master 📁',
                    subtitle: 'Manage categories',
                    icon: Icons.category_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: _showManageCategoriesDialog,
                  ),
                  _buildMasterCard(
                    title: 'Section Master 🏷️',
                    subtitle: 'Ribbons & colors',
                    icon: Icons.view_carousel_rounded,
                    color: const Color(0xFFEC4899),
                    onTap: _showManageSectionsDialog,
                  ),
                  _buildMasterCard(
                    title: 'Unit Master 📏',
                    subtitle: 'Measurement units',
                    icon: Icons.straighten_rounded,
                    color: const Color(0xFF10B981),
                    onTap: _showManageUnitsDialog,
                  ),
                  _buildMasterCard(
                    title: 'Product Border 🖼️',
                    subtitle: 'Upload PNG overlay',
                    icon: Icons.border_outer_rounded,
                    color: const Color(0xFFEC4899),
                    onTap: _showManageProductBorderDialog,
                  ),
                  _buildMasterCard(
                    title: 'Header Animations 🎬',
                    subtitle: 'Upload Lottie JSONs',
                    icon: Icons.movie_filter_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: _showManageHeaderAnimationsDialog,
                  ),
                  _buildMasterCard(
                    title: 'Search Bar Style 🔍',
                    subtitle: 'Customize top bar',
                    icon: Icons.palette_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: _showManageSearchBarDialog,
                  ),
                  _buildMasterCard(
                    title: 'Download Excel 📊',
                    subtitle: 'Export catalog CSV',
                    icon: Icons.file_download_rounded,
                    color: const Color(0xFF10B981),
                    onTap: _downloadProductsToExcel,
                  ),
                  _buildMasterCard(
                    title: 'Upload Excel 📥',
                    subtitle: 'Bulk upload items',
                    icon: Icons.file_upload_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: _uploadProductsFromExcel,
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
