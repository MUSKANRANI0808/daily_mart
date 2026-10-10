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
import '../../utils/category_icon_helper.dart';
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
  List<Map<String, dynamic>> _sellerCategorySections = [];
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
    final catSections = await AuthService.getSellerCategorySections(username);

    if (mounted) {
      setState(() {
        _allProducts = products;
        _sellerUnits = units;
        _sellerCategories = categories;
        _sellerSections = sections;
        _sellerCategorySections = catSections;
        _isLoading = false;
      });
    }
  }

  static List<String> _parsePosterList(String raw) {
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

  static String _encodePosterList(List<String> list) {
    final clean = list.map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    if (clean.isEmpty) return '';
    if (clean.length == 1) return clean.first;
    return jsonEncode(clean);
  }

  static Widget _buildPosterThumbnail(String imgStr, {double width = 64, double height = 44}) {
    final clean = imgStr.trim();
    if (clean.startsWith('data:image')) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Data = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 18, color: Colors.grey)),
        );
      } catch (_) {}
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        fit: BoxFit.cover,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 18, color: Colors.grey)),
      );
    }
    return const Center(child: Icon(Icons.image, size: 18, color: Colors.grey));
  }

  Widget _buildSectionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. CATEGORY MASTER DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
  void _showManageCategoriesDialog() {
    final catNameController = TextEditingController();
    String catImageUrl = '🏷️';
    String catIconUrl = '';
    List<String> catPosterImages = [];
    String selectedRingColor = '#8B5CF6';
    String selectedItemBgColor = '#F8FAFC';
    List<String> selectedCatSections = [];
    bool hideName = false;
    bool fullSizeImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          bool isProcessingCatImg = false;
          bool isProcessingCatPoster = false;

          Future<void> _pickCategoryImage() async {
            setModalState(() => isProcessingCatImg = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final pngBase64 = await ImageBorderHelper.convertToPng(bytes, makeWhiteTransparent: true);
                setModalState(() {
                  catImageUrl = pngBase64;
                });
              }
            } catch (_) {
            } finally {
              setModalState(() => isProcessingCatImg = false);
            }
          }

          Future<void> _pickCategoryPoster() async {
            setModalState(() => isProcessingCatPoster = true);
            try {
              final picker = ImagePicker();
              final pickedList = await picker.pickMultiImage(maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
              if (pickedList.isNotEmpty) {
                for (var f in pickedList) {
                  final bytes = await f.readAsBytes();
                  final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  catPosterImages.add(base64Str);
                }
                setModalState(() {});
              } else {
                final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  setModalState(() {
                    catPosterImages.add(base64Str);
                  });
                }
              }
            } catch (_) {
            } finally {
              setModalState(() => isProcessingCatPoster = false);
            }
          }

          Future<void> _pickCategoryIcon() async {
            final selected = await CategoryIconHelper.showIconPickerDialog(context, currentIcon: catIconUrl);
            if (selected != null) {
              setModalState(() {
                catIconUrl = selected;
              });
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
                              'Set Photo (Circular) & Icon (Header Strip)',
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

                  const Text('Category Details (Photo, Icon & Name) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Expanded(
                        child: Text('Card Background Color (कार्ड बैकग्राउंड):', style: TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          FullColorPickerDialog.show(
                            context,
                            initialHex: selectedRingColor,
                            onColorSelected: (newHex) {
                              setModalState(() => selectedRingColor = newHex);
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette_outlined, size: 12, color: Color(0xFF0284C7)),
                              SizedBox(width: 3),
                              Text('Custom', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#DCFCE7', '#FEF3C7', '#E0F2FE', '#FFEDD5', '#FCE7F3', '#F3E8FF', '#CCFBF1', '#ECFCCB', '#F1F5F9',
                        '#10B981', '#0284C7', '#8B5CF6', '#F97316', '#EC4899', '#EF4444', '#F59E0B', '#06B6D4', '#1E293B',
                      ].map((hex) {
                        final isSel = selectedRingColor.toLowerCase() == hex.toLowerCase();
                        final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        return InkWell(
                          onTap: () => setModalState(() => selectedRingColor = hex),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? Colors.black : const Color(0xFFCBD5E1), width: isSel ? 2.5 : 1),
                              boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 5)] : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Item Image Background Color Picker
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Item Image Box Color (प्रोडक्ट इमेज बैकग्राउंड):', style: TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          FullColorPickerDialog.show(
                            context,
                            initialHex: selectedItemBgColor,
                            onColorSelected: (newHex) {
                              setModalState(() => selectedItemBgColor = newHex);
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette_outlined, size: 12, color: Color(0xFF0284C7)),
                              SizedBox(width: 3),
                              Text('Custom', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#FFFFFF', '#F8FAFC', '#DCFCE7', '#FEF3C7', '#E0F2FE', '#FFEDD5', '#FCE7F3', '#F3E8FF', '#CCFBF1', '#ECFCCB', '#F1F5F9',
                        '#10B981', '#0284C7', '#8B5CF6', '#F97316', '#EC4899', '#EF4444', '#F59E0B', '#06B6D4', '#1E293B',
                      ].map((hex) {
                        final isSel = selectedItemBgColor.toLowerCase() == hex.toLowerCase();
                        final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        return InkWell(
                          onTap: () => setModalState(() => selectedItemBgColor = hex),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? Colors.black : const Color(0xFFCBD5E1), width: isSel ? 2.5 : 1),
                              boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 5)] : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Select Section(s) Multi-select Chips
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Show in Section(s) (किस सेक्शन में दिखेगा):',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedCatSections.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedCatSections.length} Selected',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildSectionChip(
                          label: '🏠 Home / Top',
                          isSelected: selectedCatSections.any((s) => s.toLowerCase() == 'home / top'),
                          onTap: () {
                            setModalState(() {
                              if (selectedCatSections.any((s) => s.toLowerCase() == 'home / top')) {
                                selectedCatSections.removeWhere((s) => s.toLowerCase() == 'home / top');
                              } else {
                                selectedCatSections.add('Home / Top');
                              }
                            });
                          },
                        ),
                        ..._sellerSections.map((sec) {
                          final sName = (sec['name'] ?? '').toString().trim();
                          final sIcon = (sec['icon'] ?? '🏷️').toString().trim();
                          if (sName.isEmpty) return const SizedBox.shrink();
                          final isSel = selectedCatSections.any((s) => s.toLowerCase() == sName.toLowerCase());
                          return _buildSectionChip(
                            label: '$sIcon $sName',
                            isSelected: isSel,
                            onTap: () {
                              setModalState(() {
                                if (isSel) {
                                  selectedCatSections.removeWhere((s) => s.toLowerCase() == sName.toLowerCase());
                                } else {
                                  selectedCatSections.add(sName);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 1. Photo Picker (Circular Avatar)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Photo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 3),
                          GestureDetector(
                            onTap: isProcessingCatImg ? null : _pickCategoryImage,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                              ),
                              child: isProcessingCatImg
                                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))))
                                  : catImageUrl.startsWith('data:image')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(
                                            base64Decode(catImageUrl.split(',').last),
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                          ),
                                        )
                                      : catImageUrl.startsWith('http')
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.network(
                                                catImageUrl,
                                                fit: BoxFit.contain,
                                                gaplessPlayback: true,
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                catImageUrl,
                                                style: const TextStyle(fontSize: 20),
                                              ),
                                            ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // 2. Icon Picker (Top Header Strip Icon)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Icon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 3),
                          GestureDetector(
                            onTap: _pickCategoryIcon,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                              ),
                              child: Center(
                                child: CategoryIconHelper.buildHeaderCategoryIcon(
                                  catIconUrl,
                                  catNameController.text.trim().isEmpty ? 'Category' : catNameController.text.trim(),
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // 3. Category Name Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Category Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 3),
                            TextField(
                              controller: catNameController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                hintText: 'e.g. Snacks, Beauty',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // 4. Add Button
                      ElevatedButton(
                        onPressed: () async {
                          final cName = catNameController.text.trim();
                          if (cName.isEmpty) return;

                          catNameController.clear();
                          final finalPosterStr = _encodePosterList(catPosterImages);
                          await AuthService.addSellerCategory(
                            username,
                            cName,
                            catImageUrl,
                            color: selectedRingColor,
                            iconUrl: catIconUrl,
                            posterUrl: finalPosterStr,
                            itemBgColor: selectedItemBgColor,
                            sections: selectedCatSections.join(', '),
                            hideName: hideName,
                            fullSizeImage: fullSizeImage,
                          );
                          final updatedCats = await AuthService.getSellerCategories(username);

                          setModalState(() {
                            _sellerCategories = updatedCats;
                            catImageUrl = '🏷️';
                            catIconUrl = '';
                            catPosterImages.clear();
                            selectedRingColor = '#8B5CF6';
                            selectedItemBgColor = '#F8FAFC';
                            selectedCatSections.clear();
                            hideName = false;
                            fullSizeImage = false;
                          });
                          setState(() {
                            _sellerCategories = updatedCats;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Quick Options for new category
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => hideName = !hideName),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: hideName,
                                    activeColor: const Color(0xFF0284C7),
                                    onChanged: (v) => setModalState(() => hideName = v ?? false),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text('Hide Name (नाम छुपाएं)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => fullSizeImage = !fullSizeImage),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: fullSizeImage,
                                    activeColor: const Color(0xFF0284C7),
                                    onChanged: (v) => setModalState(() => fullSizeImage = v ?? false),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text('Full Size Img (पूरी फोटो)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Poster Banner / Slider Picker (1 or more images)
                  if (catPosterImages.isEmpty) ...[
                    InkWell(
                      onTap: isProcessingCatPoster ? null : _pickCategoryPoster,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isProcessingCatPoster
                                  ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))))
                                  : const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF0284C7), size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category Poster / Slider Banner 🖼️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A))),
                                  SizedBox(height: 2),
                                  Text(
                                    '+ Upload 1 or more images (1 से ज्यादा होने पर Slider बनेगा)',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                catPosterImages.length > 1
                                    ? '⚡ ${catPosterImages.length} Images (Slider Mode Active 🔄)'
                                    : '🖼️ 1 Image Banner (Static Mode)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => setModalState(() => catPosterImages.clear()),
                                child: const Text('Clear All', style: TextStyle(fontSize: 10.5, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                ...catPosterImages.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final img = entry.value;
                                  return Container(
                                    width: 68,
                                    height: 48,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: _buildPosterThumbnail(img, width: 68, height: 48),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => setModalState(() => catPosterImages.removeAt(idx)),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          left: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#${idx + 1}',
                                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                // Add more button
                                InkWell(
                                  onTap: isProcessingCatPoster ? null : _pickCategoryPoster,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 52,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF22C55E), style: BorderStyle.solid),
                                    ),
                                    child: isProcessingCatPoster
                                        ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A))))
                                        : const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_rounded, size: 18, color: Color(0xFF16A34A)),
                                              Text('Add', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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
                  ],
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
                              final cIcon = safeString(cMap['icon_url']);
                              final cPoster = safeString(cMap['poster_url']);
                              final cColorStr = safeString(cMap['color'], '#8B5CF6');
                              final cItemBgStr = safeString(cMap['item_bg_color'], '#F8FAFC');
                              Color cRingColor = const Color(0xFF8B5CF6);
                              if (cColorStr.isNotEmpty) {
                                String hex = cColorStr.replaceAll('#', '');
                                if (hex.length == 6) hex = 'FF$hex';
                                final val = int.tryParse(hex, radix: 16);
                                if (val != null) cRingColor = Color(val);
                              }
                              Color cItemBg = const Color(0xFFF8FAFC);
                              if (cItemBgStr.isNotEmpty) {
                                String hex = cItemBgStr.replaceAll('#', '');
                                if (hex.length == 6) hex = 'FF$hex';
                                final val = int.tryParse(hex, radix: 16);
                                if (val != null) cItemBg = Color(val);
                              }
                              final bool cHideName = (cMap['hide_name'] == 1 || cMap['hide_name'] == true || cMap['hide_name'] == '1');
                              final bool cFullSize = (cMap['full_size_image'] == 1 || cMap['full_size_image'] == true || cMap['full_size_image'] == '1');
                              final String sectionsStr = (cMap['sections'] ?? '').toString().trim();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Clean single Category Thumbnail
                                    Container(
                                      width: 40,
                                      height: 40,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: cRingColor,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: cImg.startsWith('data:image')
                                            ? Image.memory(base64Decode(cImg.split(',').last), fit: BoxFit.cover)
                                            : Center(child: Text(cImg.isEmpty ? '🏷️' : cImg, style: const TextStyle(fontSize: 18))),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Category Title & compact meta chips
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            cName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              if (sectionsStr.isNotEmpty)
                                                Text(
                                                  sectionsStr,
                                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (cHideName)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                                  ),
                                                  child: const Text('Hidden', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                                ),
                                              if (cFullSize)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE0F2FE),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFBAE6FD)),
                                                  ),
                                                  child: const Text('Full Img', style: TextStyle(fontSize: 8.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Compact Edit Button
                                    InkWell(
                                      onTap: () {
                                        _showEditCategoryPrompt(
                                          ctx,
                                          cId,
                                          cName,
                                          cImg,
                                          cColorStr,
                                          cIcon,
                                          cPoster,
                                          cItemBgStr,
                                          sectionsStr,
                                          setModalState,
                                          initialHideName: cHideName,
                                          initialFullSizeImage: cFullSize,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Compact Delete Button
                                    InkWell(
                                      onTap: () async {
                                        await AuthService.deleteSellerCategory(cId, username, cName);
                                        final updatedCats = await AuthService.getSellerCategories(username);
                                        setModalState(() {
                                          _sellerCategories = updatedCats;
                                        });
                                        setState(() {
                                          _sellerCategories = updatedCats;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
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

  void _showEditCategoryPrompt(BuildContext parentCtx, int catId, String currentName, String currentImg, String currentColor, String currentIcon, String currentPoster, String currentItemBgColor, String currentSections, StateSetter parentSetModalState, {bool initialHideName = false, bool initialFullSizeImage = false}) {
    final editController = TextEditingController(text: currentName);
    String editImg = currentImg;
    String editColor = currentColor.isEmpty ? '#DCFCE7' : currentColor;
    String editIcon = currentIcon;
    List<String> editPosterImages = _parsePosterList(currentPoster);
    String editItemBgColor = currentItemBgColor.isEmpty ? '#F8FAFC' : currentItemBgColor;
    List<String> editCatSections = currentSections.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    bool editHideName = initialHideName;
    bool editFullSizeImage = initialFullSizeImage;
    bool isProcessingImg = false;
    bool isProcessingPoster = false;

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> _pickNewImage() async {
            setDialogState(() => isProcessingImg = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final pngBase64 = await ImageBorderHelper.convertToPng(bytes, makeWhiteTransparent: true);
                setDialogState(() {
                  editImg = pngBase64;
                });
              }
            } catch (_) {
            } finally {
              setDialogState(() => isProcessingImg = false);
            }
          }

          Future<void> _removeWhiteFromCurrent() async {
            if (editImg.isEmpty || editImg == '🏷️') return;
            setDialogState(() => isProcessingImg = true);
            try {
              final cleaned = await ImageBorderHelper.removeWhiteFromExistingImage(editImg);
              if (cleaned != null) {
                setDialogState(() {
                  editImg = cleaned;
                });
              }
            } catch (_) {
            } finally {
              setDialogState(() => isProcessingImg = false);
            }
          }

          Future<void> _pickNewIcon() async {
            final selected = await CategoryIconHelper.showIconPickerDialog(context, currentIcon: editIcon);
            if (selected != null) {
              setDialogState(() {
                editIcon = selected;
              });
            }
          }

          Future<void> _pickNewPoster() async {
            setDialogState(() => isProcessingPoster = true);
            try {
              final picker = ImagePicker();
              final pickedList = await picker.pickMultiImage(maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
              if (pickedList.isNotEmpty) {
                for (var f in pickedList) {
                  final bytes = await f.readAsBytes();
                  final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  editPosterImages.add(base64Str);
                }
                setDialogState(() {});
              } else {
                final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
                if (picked != null) {
                  final bytes = await picked.readAsBytes();
                  final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  setDialogState(() {
                    editPosterImages.add(base64Str);
                  });
                }
              }
            } catch (_) {
            } finally {
              setDialogState(() => isProcessingPoster = false);
            }
          }

          // Parse background color for live preview
          Color parsedBg = const Color(0xFFDCFCE7);
          try {
            String hex = editColor.replaceAll('#', '');
            if (hex.length == 6) hex = 'FF$hex';
            final val = int.tryParse(hex, radix: 16);
            if (val != null) parsedBg = Color(val);
          } catch (_) {}

          Color parsedItemBg = const Color(0xFFF8FAFC);
          try {
            String hex = editItemBgColor.replaceAll('#', '');
            if (hex.length == 6) hex = 'FF$hex';
            final val = int.tryParse(hex, radix: 16);
            if (val != null) parsedItemBg = Color(val);
          } catch (_) {}

          final double luminance = parsedBg.computeLuminance();
          final Color previewTextColor = luminance > 0.5 ? const Color(0xFF0F172A) : Colors.white;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Row
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.edit_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Category Details 📁',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Update name, photo, icon, card & item box colors',
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
                const Divider(height: 18),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live Card Preview (Category Card + Item Image Box)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Live Store Preview (कार्ड और आइटम बॉक्स)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 1. Store Category Card Preview
                                    Column(
                                      children: [
                                        Container(
                                          width: 82,
                                          height: 114,
                                          padding: editFullSizeImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: editFullSizeImage ? Colors.transparent : parsedBg,
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1.5),
                                              ),
                                            ],
                                          ),
                                          child: editFullSizeImage
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      isProcessingImg
                                                          ? const Center(
                                                              child: SizedBox(
                                                                width: 22,
                                                                height: 22,
                                                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                                                              ),
                                                            )
                                                          : editImg.startsWith('data:image')
                                                              ? Image.memory(
                                                                  base64Decode(editImg.split(',').last),
                                                                  fit: BoxFit.cover,
                                                                  gaplessPlayback: true,
                                                                )
                                                              : editImg.startsWith('http')
                                                                  ? Image.network(
                                                                      editImg,
                                                                      fit: BoxFit.cover,
                                                                      gaplessPlayback: true,
                                                                    )
                                                                  : Center(child: Text(editImg.isEmpty ? '🏷️' : editImg, style: const TextStyle(fontSize: 34))),
                                                      if (!editHideName)
                                                        Positioned(
                                                          bottom: 0,
                                                          left: 0,
                                                          right: 0,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                begin: Alignment.bottomCenter,
                                                                end: Alignment.topCenter,
                                                                colors: [
                                                                  Colors.black.withValues(alpha: 0.75),
                                                                  Colors.transparent,
                                                                ],
                                                              ),
                                                            ),
                                                            child: Text(
                                                              editController.text.trim().isEmpty ? 'Category' : editController.text.trim(),
                                                              style: const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.white,
                                                                height: 1.1,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      flex: editHideName ? 1 : 0,
                                                      child: SizedBox(
                                                        width: editHideName ? double.infinity : 58,
                                                        height: editHideName ? double.infinity : 58,
                                                        child: Center(
                                                          child: isProcessingImg
                                                              ? const SizedBox(
                                                                  width: 22,
                                                                  height: 22,
                                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                                                                )
                                                              : editImg.startsWith('data:image')
                                                                  ? Image.memory(
                                                                      base64Decode(editImg.split(',').last),
                                                                      fit: BoxFit.contain,
                                                                      gaplessPlayback: true,
                                                                    )
                                                                  : editImg.startsWith('http')
                                                                      ? Image.network(
                                                                          editImg,
                                                                          fit: BoxFit.contain,
                                                                          gaplessPlayback: true,
                                                                        )
                                                                      : Text(editImg.isEmpty ? '🏷️' : editImg, style: TextStyle(fontSize: editHideName ? 40 : 32)),
                                                        ),
                                                      ),
                                                    ),
                                                    if (!editHideName) ...[
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        editController.text.trim().isEmpty ? 'Category' : editController.text.trim(),
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.bold,
                                                          color: previewTextColor,
                                                          height: 1.15,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text('Category Card', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(width: 18),
                                    // 2. Product Item Box Preview (Live item_bg_color)
                                    Column(
                                      children: [
                                        Container(
                                          width: 82,
                                          height: 114,
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.04),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1.5),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: parsedItemBg,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                                ),
                                                child: const Center(
                                                  child: Text('📦', style: TextStyle(fontSize: 28)),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text('Item Name', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              const Text('₹50 / Pcs', style: TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text('Item Image Box', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Photo & Icon Selector Boxes
                        Row(
                          children: [
                            // 1. Photo Picker
                            Expanded(
                              child: InkWell(
                                onTap: isProcessingImg ? null : _pickNewImage,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: isProcessingImg
                                            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))))
                                            : ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: editImg.startsWith('data:image')
                                                    ? Image.memory(
                                                        base64Decode(editImg.split(',').last),
                                                        fit: BoxFit.contain,
                                                        gaplessPlayback: true,
                                                      )
                                                    : editImg.startsWith('http')
                                                        ? Image.network(
                                                            editImg,
                                                            fit: BoxFit.contain,
                                                            gaplessPlayback: true,
                                                          )
                                                        : Center(child: Text(editImg.isEmpty ? '🏷️' : editImg, style: const TextStyle(fontSize: 22))),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Card Photo 📷', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text(
                                              isProcessingImg ? 'Converting...' : 'Tap to change',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isProcessingImg ? const Color(0xFFF59E0B) : const Color(0xFF0284C7),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 2. Icon Picker
                            Expanded(
                              child: InkWell(
                                onTap: _pickNewIcon,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: CategoryIconHelper.buildHeaderCategoryIcon(
                                            editIcon,
                                            editController.text.trim().isEmpty ? 'Category' : editController.text.trim(),
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Header Icon ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            SizedBox(height: 2),
                                            Text('Tap to pick icon', style: TextStyle(fontSize: 10.5, color: Color(0xFFF87171), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Quick action button to auto-remove white background from currently selected/uploaded photo
                        if (editImg.isNotEmpty && editImg != '🏷️') ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: isProcessingImg ? null : _removeWhiteFromCurrent,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF93C5FD), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isProcessingImg)
                                    const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                    )
                                  else
                                    const Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isProcessingImg
                                          ? 'Removing white background & making PNG...'
                                          : 'Auto-Remove White Background (PNG बनाएँ)',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Category Poster Banner / Slider Picker & Preview
                        const Text(
                          'Category Poster / Slider Banner (पेज बैनर - Search bar के ऊपर) 🖼️',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        if (editPosterImages.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      editPosterImages.length > 1
                                          ? '⚡ ${editPosterImages.length} Images (Slider Mode Active 🔄)'
                                          : '🖼️ 1 Image Banner (Static Mode)',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                    ),
                                    const Spacer(),
                                    InkWell(
                                      onTap: () => setDialogState(() => editPosterImages.clear()),
                                      child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      ...editPosterImages.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final img = entry.value;
                                        return Container(
                                          width: 80,
                                          height: 55,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(9),
                                                child: _buildPosterThumbnail(img, width: 80, height: 55),
                                              ),
                                              Positioned(
                                                top: 2,
                                                right: 2,
                                                child: InkWell(
                                                  onTap: () => setDialogState(() => editPosterImages.removeAt(idx)),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFEF4444),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 2,
                                                left: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '#${idx + 1}',
                                                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      // Add More Button
                                      InkWell(
                                        onTap: isProcessingPoster ? null : _pickNewPoster,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 60,
                                          height: 55,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFF22C55E), style: BorderStyle.solid),
                                          ),
                                          child: isProcessingPoster
                                              ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A))))
                                              : const Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_photo_alternate_rounded, size: 20, color: Color(0xFF16A34A)),
                                                    SizedBox(height: 2),
                                                    Text('+ Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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
                        ] else ...[
                          InkWell(
                            onTap: isProcessingPoster ? null : _pickNewPoster,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                children: [
                                  if (isProcessingPoster)
                                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)))
                                  else
                                    const Icon(Icons.add_photo_alternate_outlined, size: 28, color: Color(0xFF0284C7)),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '+ Upload Category Poster / Banner (1 या 1 से ज्यादा इमेज)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '1 से ज्यादा इमेज होने पर Category page पर Slider के रूप में दिखेगा',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Category Name Field
                        const Text(
                          'Category Name (कैटेगरी का नाम) *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: editController,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            hintText: 'e.g. Snacks, Fresh Dairy, More',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display Options (Hide Name & Full Size Image)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0284C7)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Display Options (दिखने के विकल्प)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 1. Hide Category Name
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                activeColor: const Color(0xFF0284C7),
                                title: const Text(
                                  'Hide Category Name (नाम छुपाएं)',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                                ),
                                subtitle: const Text(
                                  'इस कैटेगरी का नाम स्टोर पर नहीं दिखेगा, सिर्फ फोटो दिखेगी',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                                value: editHideName,
                                onChanged: (val) {
                                  setDialogState(() {
                                    editHideName = val;
                                  });
                                },
                              ),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              // 2. Full Size Image
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                activeColor: const Color(0xFF0284C7),
                                title: const Text(
                                  'Image Full Size (पूरी चौड़ाई में फोटो)',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                                ),
                                subtitle: const Text(
                                  'फोटो पूरे कार्ड में फिट होगी, कोई एक्स्ट्रा बैकग्राउंड नहीं दिखेगा',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                                value: editFullSizeImage,
                                onChanged: (val) {
                                  setDialogState(() {
                                    editFullSizeImage = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Card Background Color Row & Color Chips
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Card Background Color (कार्ड बैकग्राउंड):',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                FullColorPickerDialog.show(
                                  parentCtx,
                                  initialHex: editColor,
                                  onColorSelected: (newHex) {
                                    setDialogState(() => editColor = newHex);
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF0284C7), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.palette_outlined, size: 14, color: Color(0xFF0284C7)),
                                    SizedBox(width: 4),
                                    Text('Custom 🎨', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Horizontal Color Picker
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              '#DCFCE7', '#FEF3C7', '#E0F2FE', '#FFEDD5', '#FCE7F3', '#F3E8FF', '#CCFBF1', '#ECFCCB', '#F1F5F9',
                              '#10B981', '#0284C7', '#8B5CF6', '#F97316', '#EC4899', '#EF4444', '#F59E0B', '#06B6D4', '#1E293B',
                            ].map((hex) {
                              final isSel = editColor.toLowerCase() == hex.toLowerCase();
                              final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                              return InkWell(
                                onTap: () => setDialogState(() => editColor = hex),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? Colors.black : const Color(0xFFCBD5E1),
                                      width: isSel ? 2.5 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: isSel
                                      ? Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 16,
                                            color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Item Image Background Color Row & Color Chips
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Item Image Background Color (प्रोडक्ट इमेज बैकग्राउंड):',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                FullColorPickerDialog.show(
                                  parentCtx,
                                  initialHex: editItemBgColor,
                                  onColorSelected: (newHex) {
                                    setDialogState(() => editItemBgColor = newHex);
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF0284C7), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.palette_outlined, size: 14, color: Color(0xFF0284C7)),
                                    SizedBox(width: 4),
                                    Text('Custom 🎨', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Horizontal Color Picker for Item Image Bg
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              '#FFFFFF', '#F8FAFC', '#DCFCE7', '#FEF3C7', '#E0F2FE', '#FFEDD5', '#FCE7F3', '#F3E8FF', '#CCFBF1', '#ECFCCB', '#F1F5F9',
                              '#10B981', '#0284C7', '#8B5CF6', '#F97316', '#EC4899', '#EF4444', '#F59E0B', '#06B6D4', '#1E293B',
                            ].map((hex) {
                              final isSel = editItemBgColor.toLowerCase() == hex.toLowerCase();
                              final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                              return InkWell(
                                onTap: () => setDialogState(() => editItemBgColor = hex),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: c,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? Colors.black : const Color(0xFFCBD5E1),
                                      width: isSel ? 2.5 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: isSel
                                      ? Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 16,
                                            color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Select Section(s) Multi-select Chips
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Show in Section(s) (किस सेक्शन में दिखेगा):',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (editCatSections.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${editCatSections.length} Selected',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Category jis section me dikhani hai use chunein (Ek se zyada select kar sakte hain):',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildSectionChip(
                                label: '🏠 Home / Top',
                                isSelected: editCatSections.any((s) => s.toLowerCase() == 'home / top'),
                                onTap: () {
                                  setDialogState(() {
                                    if (editCatSections.any((s) => s.toLowerCase() == 'home / top')) {
                                      editCatSections.removeWhere((s) => s.toLowerCase() == 'home / top');
                                    } else {
                                      editCatSections.add('Home / Top');
                                    }
                                  });
                                },
                              ),
                              ..._sellerSections.map((sec) {
                                final sName = (sec['name'] ?? '').toString().trim();
                                final sIcon = (sec['icon'] ?? '🏷️').toString().trim();
                                if (sName.isEmpty) return const SizedBox.shrink();
                                final isSel = editCatSections.any((s) => s.toLowerCase() == sName.toLowerCase());
                                return _buildSectionChip(
                                  label: '$sIcon $sName',
                                  isSelected: isSel,
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSel) {
                                        editCatSections.removeWhere((s) => s.toLowerCase() == sName.toLowerCase());
                                      } else {
                                        editCatSections.add(sName);
                                      }
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final newName = editController.text.trim();
                          if (newName.isNotEmpty) {
                            final username = _sellerUsername;
                            Navigator.pop(ctx);
                            final finalPosterStr = _encodePosterList(editPosterImages);
                            await AuthService.updateSellerCategory(
                              catId,
                              username,
                              newName,
                              editImg,
                              color: editColor,
                              iconUrl: editIcon,
                              posterUrl: finalPosterStr,
                              itemBgColor: editItemBgColor,
                              sections: editCatSections.join(', '),
                              hideName: editHideName,
                              fullSizeImage: editFullSizeImage,
                              oldCategoryName: currentName,
                            );
                            final updatedCats = await AuthService.getSellerCategories(username);
                            parentSetModalState(() {
                              _sellerCategories = updatedCats;
                            });
                            setState(() {
                              _sellerCategories = updatedCats;
                            });
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Save Changes (अपडेट करें)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeadingPreview(String imgStr, {double height = 65}) {
    final clean = imgStr.trim();
    if (clean.isEmpty) return const SizedBox.shrink();
    if (clean.startsWith('http')) {
      return Image.network(
        clean,
        height: height,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.red)),
      );
    }
    try {
      final commaIdx = clean.indexOf(',');
      final base64Data = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
      return Image.memory(
        base64Decode(base64Data),
        height: height,
        width: double.infinity,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.red)),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.red));
    }
  }

  /// Dedicated Edit Section Modal with Full Width & Poster Full Width Options
  void _showEditSectionModal(Map<String, dynamic> secMap, VoidCallback onUpdated) {
    final sId = safeInt(secMap['id']);
    final sNameController = TextEditingController(text: safeString(secMap['name']));
    String sIcon = safeString(secMap['icon'], '🏷️');
    String sBgColor = safeString(secMap['bg_color'], '#FFFFFF');
    String sTextColor = safeString(secMap['text_color'], '#0F172A');
    String sImgBgColor = safeString(secMap['image_bg_color'], '#F8FAFC');
    String sHeadingImage = safeString(secMap['heading_image']);
    int sColumns = safeInt(secMap['columns'], 2);
    int sMaxItems = safeInt(secMap['max_items'], 0);
    bool sFullWidth = (secMap['full_width'] == 1 || secMap['full_width'] == true || secMap['full_width'] == '1');
    bool sPosterFullWidth = (secMap['poster_full_width'] == 1 || secMap['poster_full_width'] == true || secMap['poster_full_width'] == '1');
    bool sHideTitle = (secMap['hide_title'] == 1 || secMap['hide_title'] == true || secMap['hide_title'] == '1');
    bool sHideItemCount = (secMap['hide_item_count'] == 1 || secMap['hide_item_count'] == true || secMap['hide_item_count'] == '1');
    bool isProcessingHeadingImg = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setEditState) {
          final username = _sellerUsername;

          Future<void> _pickHeadingImage({required bool makeTransparent}) async {
            setEditState(() => isProcessingHeadingImg = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final isPng = picked.name.toLowerCase().endsWith('.png') ||
                    (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47);

                if (makeTransparent) {
                  final pngBase64 = await ImageBorderHelper.convertToPng(bytes, makeWhiteTransparent: true).timeout(
                    const Duration(seconds: 4),
                    onTimeout: () => isPng ? 'data:image/png;base64,${base64Encode(bytes)}' : 'data:image/jpeg;base64,${base64Encode(bytes)}',
                  );
                  setEditState(() {
                    sHeadingImage = pngBase64;
                  });
                } else {
                  final mimeType = isPng ? 'image/png' : 'image/jpeg';
                  final base64Str = 'data:$mimeType;base64,${base64Encode(bytes)}';
                  setEditState(() {
                    sHeadingImage = base64Str;
                  });
                }
              }
            } catch (_) {
            } finally {
              setEditState(() => isProcessingHeadingImg = false);
            }
          }

          Future<void> _removeWhiteFromHeading() async {
            if (sHeadingImage.isEmpty) return;
            setEditState(() => isProcessingHeadingImg = true);
            try {
              final cleaned = await ImageBorderHelper.removeWhiteFromExistingImage(sHeadingImage).timeout(
                const Duration(seconds: 4),
                onTimeout: () => sHeadingImage,
              );
              if (cleaned != null) {
                setEditState(() {
                  sHeadingImage = cleaned;
                });
              }
            } catch (_) {
            } finally {
              setEditState(() => isProcessingHeadingImg = false);
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
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.edit_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Edit Store Section ✏️',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section Name
                  TextField(
                    controller: sNameController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF64748B), size: 20),
                      hintText: 'Enter Section Name',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Layout (1, 2, 3 Columns)
                  const Text('Section Display Layout:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [1, 2, 3].map((cols) {
                        final isSel = sColumns == cols;
                        final label = cols == 1 ? '1 Column 📱' : cols == 2 ? '2 Columns 🟩' : '3 Columns 🧱';
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setEditState(() => sColumns = cols),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF8B5CF6) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Max Products to Display on Home Page (View More Setting)
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
                        Row(
                          children: [
                            const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Home Page Product Limit (दिखने वाले प्रोडक्ट):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sMaxItems > 0 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sMaxItems > 0 ? '$sMaxItems Items' : 'All Items (सब)',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sMaxItems > 0
                              ? 'Home page par pehle $sMaxItems products dikhenge, baki ke liye "View More" button aayega.'
                              : '0 / All set karne par saare products bina kisi limit ke dikhenge.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        // Quick Presets
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [0, 4, 6, 8, 10, 12, 16, 20, 24].map((cnt) {
                              final isSel = sMaxItems == cnt;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => setEditState(() => sMaxItems = cnt),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSel ? const Color(0xFF8B5CF6) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      cnt == 0 ? 'All' : '$cnt',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                        color: isSel ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Manual Increment/Decrement Buttons
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: Color(0xFF8B5CF6)),
                              onPressed: () {
                                if (sMaxItems > 0) {
                                  setEditState(() => sMaxItems = (sMaxItems - 1).clamp(0, 500));
                                }
                              },
                              tooltip: 'Ghatayein (-1)',
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Center(
                                  child: Text(
                                    sMaxItems == 0 ? 'No Limit (All Products)' : '$sMaxItems Products on Home',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Color(0xFF8B5CF6)),
                              onPressed: () {
                                setEditState(() => sMaxItems = sMaxItems + (sMaxItems == 0 ? 6 : 2));
                              },
                              tooltip: 'Badhayein (+2)',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Card Background Color
                  const Text('Section Card Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: sBgColor,
                        onColorSelected: (newHex) => setEditState(() => sBgColor = newHex),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hexToColor(sBgColor),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tap to Choose Color ($sBgColor)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const Icon(Icons.color_lens_rounded, color: Color(0xFF8B5CF6), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product Image Background Color (New Feature)
                  const Text('Product Image Background Color (इमेज बैकग्राउंड कलर):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () {
                      FullColorPickerDialog.show(
                        context,
                        initialHex: sImgBgColor,
                        onColorSelected: (newHex) => setEditState(() => sImgBgColor = newHex),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hexToColor(sImgBgColor),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Choose Image BG ($sImgBgColor)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const Icon(Icons.photo_size_select_actual_rounded, color: Color(0xFF8B5CF6), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#F8FAFC', '#FFFFFF', '#F1F5F9', '#FEF2F2', '#FFF7ED', '#FEFCE8', '#F0FDF4', '#EFF6FF', '#FAF5FF', '#0F172A'
                      ].map((hex) {
                        final isSel = sImgBgColor.toLowerCase() == hex.toLowerCase();
                        return InkWell(
                          onTap: () => setEditState(() => sImgBgColor = hex),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: hexToColor(hex),
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 2.5 : 1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section Heading Image (हेडिंग इमेज)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.panorama_rounded, size: 18, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Section Heading Image (हेडिंग इमेज):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                              ),
                            ),
                            if (sHeadingImage.isNotEmpty)
                              InkWell(
                                onTap: () => setEditState(() => sHeadingImage = ''),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Text('Clear 🗑️', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'सेक्शन के सबसे ऊपर फुल-विड्थ में हेडिंग इमेज दिखेगी',
                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),

                        if (sHeadingImage.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 65,
                              color: Colors.white,
                              child: Stack(
                                children: [
                                  Center(
                                    child: _buildSectionHeadingPreview(sHeadingImage, height: 65),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: InkWell(
                                      onTap: () => setEditState(() => sHeadingImage = ''),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: isProcessingHeadingImg ? null : _removeWhiteFromHeading,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: isProcessingHeadingImg
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.auto_fix_high_rounded, size: 15),
                            label: const Text('Remove White BG (व्हाइट बैकग्राउंड हटाएं)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                        ],

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessingHeadingImg ? null : () => _pickHeadingImage(makeTransparent: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF334155),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFCBD5E1))),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.image_rounded, size: 15, color: Color(0xFF2563EB)),
                                label: const Text('Normal Image 🖼️', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isProcessingHeadingImg ? null : () => _pickHeadingImage(makeTransparent: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFECFDF5),
                                  foregroundColor: const Color(0xFF065F46),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF6EE7B7))),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: isProcessingHeadingImg
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.auto_fix_normal_rounded, size: 15, color: Color(0xFF059669)),
                                label: const Text('PNG (Remove White)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section Full Width Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: sFullWidth ? const Color(0xFFEDE9FE) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sFullWidth ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Set Section Full Width (सेक्शन फुल विड्थ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('सेक्शन के दोनों किनारों के मार्जिन हटाकर पूरी स्क्रीन पर फैलाएं', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Switch(
                          value: sFullWidth,
                          activeThumbColor: const Color(0xFF7C3AED),
                          activeTrackColor: const Color(0xFFDDD6FE),
                          onChanged: (val) => setEditState(() => sFullWidth = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Poster Full Width Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: sPosterFullWidth ? const Color(0xFFD1FAE5) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sPosterFullWidth ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Set Poster Full Width (पोस्टर फुल विड्थ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('इस सेक्शन के बैनर/पोस्टर को स्क्रीन के दोनों किनारों तक फैलाएं', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Switch(
                          value: sPosterFullWidth,
                          activeThumbColor: const Color(0xFF059669),
                          activeTrackColor: const Color(0xFFA7F3D0),
                          onChanged: (val) => setEditState(() => sPosterFullWidth = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Hide Section Name Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: sHideTitle ? const Color(0xFFFEE2E2) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sHideTitle ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hide Section Name (सेक्शन नाम छुपाएं)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(
                                sHideTitle ? 'वर्तमान में नाम छुपा हुआ है (Hidden)' : 'होम स्क्रीन पर सेक्शन का नाम रिबन टैग में दिखेगा',
                                style: TextStyle(fontSize: 10.5, color: sHideTitle ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: sHideTitle,
                          activeThumbColor: const Color(0xFFEF4444),
                          activeTrackColor: const Color(0xFFFECACA),
                          onChanged: (val) => setEditState(() => sHideTitle = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Hide Item Count Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: sHideItemCount ? const Color(0xFFFEF3C7) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sHideItemCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hide Item Count (आइटम काउंट छुपाएं)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(
                                sHideItemCount ? 'वर्तमान में आइटम संख्या छुपी हुई है (Hidden)' : 'होम स्क्रीन पर आइटम संख्या (e.g. 6 Items) दिखेगी',
                                style: TextStyle(fontSize: 10.5, color: sHideItemCount ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: sHideItemCount,
                          activeThumbColor: const Color(0xFFF59E0B),
                          activeTrackColor: const Color(0xFFFDE68A),
                          onChanged: (val) => setEditState(() => sHideItemCount = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () async {
                      final newName = sNameController.text.trim();
                      if (newName.isEmpty) return;
                      await AuthService.updateSellerSection(
                        sId,
                        username,
                        newName,
                        sIcon,
                        sBgColor,
                        sTextColor,
                        sColumns,
                        sMaxItems,
                        sFullWidth ? 1 : 0,
                        sPosterFullWidth ? 1 : 0,
                        sHideTitle ? 1 : 0,
                        sHideItemCount ? 1 : 0,
                        sImgBgColor,
                        sHeadingImage,
                      );
                      Navigator.pop(ctx);
                      onUpdated();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Update Section (सेव करें)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 1.5 CATEGORY SECTION MASTER (SHOW CATEGORIES ONLY, NO PRODUCTS) ---
  Widget _buildCategorySectionBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  void _showManageCategorySectionsDialog() async {
    final username = _sellerUsername;
    List<Map<String, dynamic>> catSections = await AuthService.getSellerCategorySections(username);
    if (mounted) {
      setState(() {
        _sellerCategorySections = catSections;
      });
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category Section Master 🗂️',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Show selected categories only (no products)',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // "Create New Category Section" Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showAddOrEditCategorySectionModal(
                        catSections: catSections,
                        onSaved: (updated) {
                          setModalState(() {
                            catSections = updated;
                            _sellerCategorySections = updated;
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Create New Category Section',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),

                // List of existing category sections
                Expanded(
                  child: catSections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grid_off_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              const Text(
                                'No Category Sections Yet',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap button above to create your first category section',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: catSections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final item = catSections[idx];
                            final title = (item['title'] ?? item['name'] ?? 'Section ${idx + 1}').toString();
                            final dynamic rawCats = item['categories'];
                            List<String> catList = [];
                            if (rawCats is List) {
                              catList = rawCats.map((e) => e.toString()).toList();
                            } else if (rawCats is String && rawCats.isNotEmpty) {
                              catList = rawCats.split(',').map((e) => e.trim()).toList();
                            }
                            final layout = (item['columns'] ?? item['layout'] ?? '4').toString();
                            final placement = (item['placement'] ?? 'top').toString();
                            final bool isActive = item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1' || item['is_active'] == null;
                            final bgColor = (item['bg_color'] ?? '#FFFFFF').toString();
                            final textColor = (item['text_color'] ?? '#0F172A').toString();
                            final bool isFullWidth = item['is_full_width'] == true || item['is_full_width'] == 1 || item['is_full_width'] == '1';
                            final bool hideItemCount = item['hide_item_count'] == true || item['hide_item_count'] == 1 || item['hide_item_count'] == '1';
                            final bool hideTitle = item['hide_title'] == true || item['hide_title'] == 1 || item['hide_title'] == '1';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
                                  width: isActive ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '#${idx + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF8B5CF6)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: isActive,
                                        activeColor: const Color(0xFF8B5CF6),
                                        onChanged: (val) async {
                                          item['is_active'] = val ? 1 : 0;
                                          final updated = List<Map<String, dynamic>>.from(catSections);
                                          await AuthService.saveSellerCategorySections(username, updated);
                                          setModalState(() {
                                            catSections = updated;
                                            _sellerCategorySections = updated;
                                          });
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _buildCategorySectionBadge(Icons.category_rounded, '${catList.length} Categories', const Color(0xFF0284C7)),
                                      _buildCategorySectionBadge(Icons.view_column_rounded, layout == 'horizontal' ? 'Horizontal Scroll' : '$layout Columns', const Color(0xFF10B981)),
                                      _buildCategorySectionBadge(Icons.vertical_align_top_rounded, placement == 'top' ? 'Top (Below Slider)' : 'Bottom', const Color(0xFFF59E0B)),
                                      if (isFullWidth)
                                        _buildCategorySectionBadge(Icons.fullscreen_rounded, 'Full Width', const Color(0xFF6366F1)),
                                      if (hideItemCount)
                                        _buildCategorySectionBadge(Icons.visibility_off_outlined, 'Count Hidden', const Color(0xFF64748B)),
                                      if (hideTitle)
                                        _buildCategorySectionBadge(Icons.title, 'Title Hidden', const Color(0xFF64748B)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: hexToColor(bgColor),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Text(
                                          'Text Preview',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: hexToColor(textColor),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (catList.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      catList.join(' • '),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          _showAddOrEditCategorySectionModal(
                                            catSections: catSections,
                                            existingItem: item,
                                            existingIndex: idx,
                                            onSaved: (updated) {
                                              setModalState(() {
                                                catSections = updated;
                                                _sellerCategorySections = updated;
                                              });
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF0284C7)),
                                        label: const Text('Edit', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (dCtx) => AlertDialog(
                                              title: const Text('Delete Category Section?'),
                                              content: Text('Are you sure you want to delete "$title"?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(dCtx, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            catSections.removeAt(idx);
                                            final updated = List<Map<String, dynamic>>.from(catSections);
                                            await AuthService.saveSellerCategorySections(username, updated);
                                            setModalState(() {
                                              catSections = updated;
                                              _sellerCategorySections = updated;
                                            });
                                            if (mounted) setState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                                        label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
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
          );
        },
      ),
    );
  }

  void _showAddOrEditCategorySectionModal({
    required List<Map<String, dynamic>> catSections,
    Map<String, dynamic>? existingItem,
    int? existingIndex,
    required Function(List<Map<String, dynamic>>) onSaved,
  }) {
    final titleController = TextEditingController(text: existingItem?['title'] ?? existingItem?['name'] ?? '');

    // Parse selected categories
    List<String> selectedCategories = [];
    if (existingItem != null) {
      final dynamic raw = existingItem['categories'];
      if (raw is List) {
        selectedCategories = raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      } else if (raw is String && raw.isNotEmpty) {
        selectedCategories = raw.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    String selectedLayout = (existingItem?['columns'] ?? existingItem?['layout'] ?? '4').toString();
    if (selectedLayout != '3' && selectedLayout != '4' && selectedLayout != 'horizontal') {
      selectedLayout = '4';
    }

    String selectedPlacement = (existingItem?['placement'] ?? 'top').toString().toLowerCase();
    if (selectedPlacement != 'top' && selectedPlacement != 'bottom') {
      selectedPlacement = 'top';
    }

    String selectedBgColor = (existingItem?['bg_color'] ?? '#FFFFFF').toString();
    String selectedTextColor = (existingItem?['text_color'] ?? '#0F172A').toString();
    bool isActive = existingItem != null ? (existingItem['is_active'] == true || existingItem['is_active'] == 1 || existingItem['is_active'] == '1') : true;
    bool isFullWidth = existingItem != null ? (existingItem['is_full_width'] == true || existingItem['is_full_width'] == 1 || existingItem['is_full_width'] == '1') : false;
    bool hideItemCount = existingItem != null ? (existingItem['hide_item_count'] == true || existingItem['hide_item_count'] == 1 || existingItem['hide_item_count'] == '1') : false;
    bool hideTitle = existingItem != null ? (existingItem['hide_title'] == true || existingItem['hide_title'] == 1 || existingItem['hide_title'] == '1') : false;

    final List<String> bgPresets = ['#FFFFFF', '#F8FAFC', '#F1F5F9', '#EFF6FF', '#F0FDF4', '#FEF3C7', '#FDF2F8', '#0F172A'];
    final List<String> textPresets = ['#0F172A', '#1E293B', '#334155', '#475569', '#2563EB', '#059669', '#D97706', '#FFFFFF'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSubModalState) {
          final allCats = _sellerCategories;

          return Container(
            height: MediaQuery.of(context).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        existingItem != null ? Icons.edit_note_rounded : Icons.add_to_photos_rounded,
                        color: const Color(0xFF8B5CF6),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          existingItem != null ? 'Edit Category Section' : 'Add Category Section',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Form Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Title
                        const Text(
                          'Section Title / Heading (शीर्षक)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Shop by Category, Trending Categories',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Categories Selection (Multi-select)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Categories (${selectedCategories.length} selected)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setSubModalState(() {
                                      selectedCategories = allCats.map((c) => (c['name'] ?? c['category_name'] ?? '').toString().trim()).where((s) => s.isNotEmpty).toList();
                                    });
                                  },
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
                                  child: const Text('Select All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                                ),
                                const Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
                                TextButton(
                                  onPressed: () {
                                    setSubModalState(() {
                                      selectedCategories.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
                                  child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: allCats.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No categories found. Please add categories first in Category Master.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: allCats.map((cat) {
                                    final cName = (cat['name'] ?? cat['category_name'] ?? '').toString().trim();
                                    final isSelected = selectedCategories.any((s) => s.toLowerCase() == cName.toLowerCase());

                                    return FilterChip(
                                      selected: isSelected,
                                      showCheckmark: true,
                                      checkmarkColor: Colors.white,
                                      selectedColor: const Color(0xFF8B5CF6),
                                      backgroundColor: Colors.white,
                                      label: Text(
                                        cName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      onSelected: (val) {
                                        setSubModalState(() {
                                          if (val) {
                                            if (!selectedCategories.any((s) => s.toLowerCase() == cName.toLowerCase())) {
                                              selectedCategories.add(cName);
                                            }
                                          } else {
                                            selectedCategories.removeWhere((s) => s.toLowerCase() == cName.toLowerCase());
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                        ),

                        const SizedBox(height: 18),

                        // Layout Selector (4 cols, 3 cols, horizontal)
                        const Text(
                          'Layout Mode (दिखाने का तरीका)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoiceChip(
                                label: '4 Columns',
                                icon: Icons.grid_view_rounded,
                                isSelected: selectedLayout == '4',
                                onTap: () => setSubModalState(() => selectedLayout = '4'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildChoiceChip(
                                label: '3 Columns',
                                icon: Icons.grid_on_rounded,
                                isSelected: selectedLayout == '3',
                                onTap: () => setSubModalState(() => selectedLayout = '3'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildChoiceChip(
                                label: 'Horizontal',
                                icon: Icons.view_carousel_rounded,
                                isSelected: selectedLayout == 'horizontal',
                                onTap: () => setSubModalState(() => selectedLayout = 'horizontal'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Placement (Top vs Bottom)
                        const Text(
                          'Storefront Placement (कहाँ दिखेगा)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildChoiceChip(
                                label: 'Top (Below Sliders)',
                                icon: Icons.vertical_align_top_rounded,
                                isSelected: selectedPlacement == 'top',
                                onTap: () => setSubModalState(() => selectedPlacement = 'top'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildChoiceChip(
                                label: 'Bottom (After Products)',
                                icon: Icons.vertical_align_bottom_rounded,
                                isSelected: selectedPlacement == 'bottom',
                                onTap: () => setSubModalState(() => selectedPlacement = 'bottom'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Section Background Color
                        const Text(
                          'Section Background Color',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: bgPresets.map((cHex) {
                            final isSel = selectedBgColor.toLowerCase() == cHex.toLowerCase();
                            return GestureDetector(
                              onTap: () => setSubModalState(() => selectedBgColor = cHex),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: hexToColor(cHex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                                    width: isSel ? 3 : 1,
                                  ),
                                ),
                                child: isSel ? Icon(Icons.check, size: 16, color: hexToColor(cHex).computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),

                        // Section Text Color
                        const Text(
                          'Section Heading Text Color',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: textPresets.map((cHex) {
                            final isSel = selectedTextColor.toLowerCase() == cHex.toLowerCase();
                            return GestureDetector(
                              onTap: () => setSubModalState(() => selectedTextColor = cHex),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: hexToColor(cHex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                                    width: isSel ? 3 : 1,
                                  ),
                                ),
                                child: isSel ? Icon(Icons.check, size: 16, color: hexToColor(cHex).computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),

                        // Display & Styling Options
                        const Text(
                          'Display Options (दिखावट सेटिंग्स)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                dense: true,
                                title: const Text('Full Width Section', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                subtitle: const Text('स्क्रीन की पूरी चौड़ाई में दिखाएं (किनारों के मार्जिन व बॉर्डर हटाकर)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                value: isFullWidth,
                                activeColor: const Color(0xFF8B5CF6),
                                onChanged: (val) => setSubModalState(() => isFullWidth = val),
                              ),
                              const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFE2E8F0)),
                              SwitchListTile.adaptive(
                                dense: true,
                                title: const Text('Hide Item Count Badge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                subtitle: const Text('शीर्षक के पास "8 items" संख्या बैज को छुपायें', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                value: hideItemCount,
                                activeColor: const Color(0xFF8B5CF6),
                                onChanged: (val) => setSubModalState(() => hideItemCount = val),
                              ),
                              const Divider(height: 1, indent: 14, endIndent: 14, color: Color(0xFFE2E8F0)),
                              SwitchListTile.adaptive(
                                dense: true,
                                title: const Text('Hide Section Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                subtitle: const Text('सेक्शन का शीर्षक छुपायें (केवल कैटेगरीज दिखाई देंगी)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                value: hideTitle,
                                activeColor: const Color(0xFF8B5CF6),
                                onChanged: (val) => setSubModalState(() => hideTitle = val),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Active / Inactive Switch
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            title: const Text(
                              'Section Active / Visible',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                            subtitle: const Text(
                              'दुकान पर चालू रखें',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            value: isActive,
                            activeColor: const Color(0xFF8B5CF6),
                            onChanged: (val) => setSubModalState(() => isActive = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Save Button Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter section title'), backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      if (selectedCategories.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select at least 1 category'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      final newSection = <String, dynamic>{
                        'id': existingItem?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                        'title': title,
                        'categories': selectedCategories,
                        'columns': selectedLayout,
                        'placement': selectedPlacement,
                        'bg_color': selectedBgColor,
                        'text_color': selectedTextColor,
                        'is_full_width': isFullWidth ? 1 : 0,
                        'hide_item_count': hideItemCount ? 1 : 0,
                        'hide_title': hideTitle ? 1 : 0,
                        'is_active': isActive ? 1 : 0,
                      };

                      final updatedList = List<Map<String, dynamic>>.from(catSections);
                      if (existingIndex != null && existingIndex >= 0 && existingIndex < updatedList.length) {
                        updatedList[existingIndex] = newSection;
                      } else {
                        updatedList.add(newSection);
                      }

                      await AuthService.saveSellerCategorySections(_sellerUsername, updatedList);
                      onSaved(updatedList);
                      if (mounted) {
                        setState(() {
                          _sellerCategorySections = updatedList;
                        });
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(existingItem != null ? 'Category Section updated successfully!' : 'Category Section created successfully!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      existingItem != null ? 'Update Section' : 'Save Section',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8B5CF6).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF64748B)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. SECTION MASTER DIALOG (EXACT ORIGINAL LOGIC & DESIGN) ---
  void _showManageSectionsDialog() {
    final secNameController = TextEditingController();
    String secIcon = '';
    String secBgColor = '#FFFFFF';
    String secTextColor = '#0F172A';
    String secImgBgColor = '#F8FAFC';
    String secHeadingImage = '';
    int secColumns = 2;
    int secMaxItems = 0;
    bool secFullWidth = false;
    bool secPosterFullWidth = false;
    bool secHideTitle = false;
    bool secHideItemCount = false;
    bool isProcessingSecHeading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          Future<void> _pickSecHeadingImage({required bool makeTransparent}) async {
            setModalState(() => isProcessingSecHeading = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final isPng = picked.name.toLowerCase().endsWith('.png') ||
                    (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47);

                if (makeTransparent) {
                  final pngBase64 = await ImageBorderHelper.convertToPng(bytes, makeWhiteTransparent: true).timeout(
                    const Duration(seconds: 4),
                    onTimeout: () => isPng ? 'data:image/png;base64,${base64Encode(bytes)}' : 'data:image/jpeg;base64,${base64Encode(bytes)}',
                  );
                  setModalState(() {
                    secHeadingImage = pngBase64;
                  });
                } else {
                  final mimeType = isPng ? 'image/png' : 'image/jpeg';
                  final base64Str = 'data:$mimeType;base64,${base64Encode(bytes)}';
                  setModalState(() {
                    secHeadingImage = base64Str;
                  });
                }
              }
            } catch (_) {
            } finally {
              setModalState(() => isProcessingSecHeading = false);
            }
          }

          Future<void> _removeWhiteFromSecHeading() async {
            if (secHeadingImage.isEmpty) return;
            setModalState(() => isProcessingSecHeading = true);
            try {
              final cleaned = await ImageBorderHelper.removeWhiteFromExistingImage(secHeadingImage).timeout(
                const Duration(seconds: 4),
                onTimeout: () => secHeadingImage,
              );
              if (cleaned != null) {
                setModalState(() {
                  secHeadingImage = cleaned;
                });
              }
            } catch (_) {
            } finally {
              setModalState(() => isProcessingSecHeading = false);
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
                      Expanded(
                        child: TextField(
                          controller: secNameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF64748B), size: 20),
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

                          await AuthService.addSellerSection(
                            username,
                            sName,
                            secIcon,
                            secBgColor,
                            secTextColor,
                            secColumns,
                            secMaxItems,
                            secFullWidth ? 1 : 0,
                            secPosterFullWidth ? 1 : 0,
                            secHideTitle ? 1 : 0,
                            secHideItemCount ? 1 : 0,
                            secImgBgColor,
                            secHeadingImage,
                          );
                          final updatedSecs = await AuthService.getSellerSections(username);

                          setModalState(() {
                            _sellerSections = updatedSecs;
                            secIcon = '';
                            secBgColor = '#FFFFFF';
                            secTextColor = '#0F172A';
                            secImgBgColor = '#F8FAFC';
                            secHeadingImage = '';
                            secColumns = 2;
                            secMaxItems = 0;
                            secFullWidth = false;
                            secPosterFullWidth = false;
                            secHideTitle = false;
                            secHideItemCount = false;
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

                        // Max Products to Display on Home Page (View More Setting)
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
                              Row(
                                children: [
                                  const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Home Page Product Limit (दिखने वाले प्रोडक्ट):',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: secMaxItems > 0 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      secMaxItems > 0 ? '$secMaxItems Items' : 'All Items (सब)',
                                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                secMaxItems > 0
                                    ? 'Home page par pehle $secMaxItems products dikhenge, baki ke liye "View More" button aayega.'
                                    : '0 / All set karne par saare products bina kisi limit ke dikhenge.',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 10),
                              // Quick Presets
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [0, 4, 6, 8, 10, 12, 16, 20, 24].map((cnt) {
                                    final isSel = secMaxItems == cnt;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () => setModalState(() => secMaxItems = cnt),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSel ? const Color(0xFF8B5CF6) : Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1)),
                                          ),
                                          child: Text(
                                            cnt == 0 ? 'All' : '$cnt',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                              color: isSel ? Colors.white : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Manual Increment/Decrement Buttons
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: Color(0xFF8B5CF6)),
                                    onPressed: () {
                                      if (secMaxItems > 0) {
                                        setModalState(() => secMaxItems = (secMaxItems - 1).clamp(0, 500));
                                      }
                                    },
                                    tooltip: 'Ghatayein (-1)',
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          secMaxItems == 0 ? 'No Limit (All Products)' : '$secMaxItems Products on Home',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Color(0xFF8B5CF6)),
                                    onPressed: () {
                                      setModalState(() => secMaxItems = secMaxItems + (secMaxItems == 0 ? 6 : 2));
                                    },
                                    tooltip: 'Badhayein (+2)',
                                  ),
                                ],
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
                        const Text('Product Image Background Color (इमेज बैकग्राउंड कलर):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            FullColorPickerDialog.show(
                              context,
                              initialHex: secImgBgColor,
                              onColorSelected: (newHex) {
                                setModalState(() => secImgBgColor = newHex);
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: hexToColor(secImgBgColor),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Choose Image BG ($secImgBgColor)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const Icon(Icons.photo_size_select_actual_rounded, color: Color(0xFF8B5CF6), size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              '#F8FAFC', '#FFFFFF', '#F1F5F9', '#FEF2F2', '#FFF7ED', '#FEFCE8', '#F0FDF4', '#EFF6FF', '#FAF5FF', '#0F172A'
                            ].map((hex) {
                              final isSel = secImgBgColor.toLowerCase() == hex.toLowerCase();
                              return InkWell(
                                onTap: () => setModalState(() => secImgBgColor = hex),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: hexToColor(hex),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1), width: isSel ? 2.5 : 1),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Section Heading Image (हेडिंग इमेज)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.panorama_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      'Heading Image (हेडिंग इमेज - ऑप्शनल):',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  if (secHeadingImage.isNotEmpty)
                                    InkWell(
                                      onTap: () => setModalState(() => secHeadingImage = ''),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text('Clear 🗑️', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'सेक्शन के सबसे ऊपर फुल-विड्थ में हेडिंग इमेज दिखेगी',
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 8),

                              if (secHeadingImage.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: double.infinity,
                                    height: 55,
                                    color: const Color(0xFFF8FAFC),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: _buildSectionHeadingPreview(secHeadingImage, height: 55),
                                        ),
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: InkWell(
                                            onTap: () => setModalState(() => secHeadingImage = ''),
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: isProcessingSecHeading ? null : _removeWhiteFromSecHeading,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF059669),
                                    side: const BorderSide(color: Color(0xFF10B981)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: isProcessingSecHeading
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.auto_fix_high_rounded, size: 15),
                                  label: const Text('Remove White BG (व्हाइट बैकग्राउंड हटाएं)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 8),
                              ],

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isProcessingSecHeading ? null : () => _pickSecHeadingImage(makeTransparent: false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        foregroundColor: const Color(0xFF334155),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFCBD5E1))),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.image_rounded, size: 15, color: Color(0xFF2563EB)),
                                      label: const Text('Normal Image 🖼️', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isProcessingSecHeading ? null : () => _pickSecHeadingImage(makeTransparent: true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFECFDF5),
                                        foregroundColor: const Color(0xFF065F46),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF6EE7B7))),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: isProcessingSecHeading
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.auto_fix_normal_rounded, size: 15, color: Color(0xFF059669)),
                                      label: const Text('PNG (Remove White)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Full Width Setting Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Set Full Width (फुल विड्थ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Right-Left margin hatakar poori screen par dikhega', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: secFullWidth,
                                activeThumbColor: const Color(0xFF7C3AED),
                                activeTrackColor: const Color(0xFFDDD6FE),
                                onChanged: (val) {
                                  setModalState(() => secFullWidth = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Poster Full Width Setting Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Set Poster Full Width (पोस्टर फुल विड्थ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Is section ke poster/banner ko dono kinaron tak dikhana', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: secPosterFullWidth,
                                activeThumbColor: const Color(0xFF059669),
                                activeTrackColor: const Color(0xFFA7F3D0),
                                onChanged: (val) {
                                  setModalState(() => secPosterFullWidth = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Hide Section Name Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: secHideTitle ? const Color(0xFFFEE2E2) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: secHideTitle ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Hide Section Name (सेक्शन नाम छुपाएं)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('होम स्क्रीन पर इस सेक्शन का नाम (Ribbon Tag) न दिखाएं', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: secHideTitle,
                                activeThumbColor: const Color(0xFFEF4444),
                                activeTrackColor: const Color(0xFFFECACA),
                                onChanged: (val) {
                                  setModalState(() => secHideTitle = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Hide Item Count Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: secHideItemCount ? const Color(0xFFFEF3C7) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: secHideItemCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Hide Item Count (आइटम काउंट छुपाएं)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('होम स्क्रीन पर आइटम की संख्या (e.g. 6 Items) न दिखाएं', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Switch(
                                value: secHideItemCount,
                                activeThumbColor: const Color(0xFFF59E0B),
                                activeTrackColor: const Color(0xFFFDE68A),
                                onChanged: (val) {
                                  setModalState(() => secHideItemCount = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Existing Sections:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),

                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
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
                              final sImgBg = safeString(sMap['image_bg_color'], '#F8FAFC');
                              final sHeadingImg = safeString(sMap['heading_image']);
                              final bool isFullWidth = (sMap['full_width'] == 1 || sMap['full_width'] == true || sMap['full_width'] == '1');
                              final bool isPosterFullWidth = (sMap['poster_full_width'] == 1 || sMap['poster_full_width'] == true || sMap['poster_full_width'] == '1');
                              final bool isHideTitle = (sMap['hide_title'] == 1 || sMap['hide_title'] == true || sMap['hide_title'] == '1');
                              final bool isHideCount = (sMap['hide_item_count'] == 1 || sMap['hide_item_count'] == true || sMap['hide_item_count'] == '1');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top row: Name + Edit + Delete
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Layout: ${safeInt(sMap['columns'], 2)} Col • Img BG: $sImgBg${sHeadingImg.isNotEmpty ? ' • 🖼️ Heading' : ''}',
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Edit Button (Pencil Icon)
                                        InkWell(
                                          onTap: () {
                                            _showEditSectionModal(sMap, () async {
                                              final updatedSecs = await AuthService.getSellerSections(username);
                                              setModalState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                              setState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF93C5FD)),
                                            ),
                                            child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Delete Button (Trash Icon)
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
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFFCA5A5)),
                                            ),
                                            child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Row 1: Section Full Width & Poster Full Width Chips
                                    Row(
                                      children: [
                                        // Section Full Width Chip
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final newFullWidth = !isFullWidth;
                                              await AuthService.toggleSellerSectionFullWidth(sId, username, sName, newFullWidth);
                                              final updatedSecs = await AuthService.getSellerSections(username);
                                              setModalState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                              setState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: isFullWidth ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isFullWidth ? const Color(0xFF8B5CF6) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isFullWidth ? Icons.fullscreen_rounded : Icons.fullscreen_exit_rounded,
                                                    size: 15,
                                                    color: isFullWidth ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isFullWidth ? 'Sec: Full' : 'Sec: Normal',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isFullWidth ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Poster Full Width Chip
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final newPosterFullWidth = !isPosterFullWidth;
                                              await AuthService.toggleSellerSectionPosterFullWidth(sId, username, sName, newPosterFullWidth);
                                              final updatedSecs = await AuthService.getSellerSections(username);
                                              setModalState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                              setState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: isPosterFullWidth ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isPosterFullWidth ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isPosterFullWidth ? Icons.burst_mode_rounded : Icons.image_outlined,
                                                    size: 14,
                                                    color: isPosterFullWidth ? const Color(0xFF047857) : const Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isPosterFullWidth ? 'Poster: Full' : 'Poster: Normal',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isPosterFullWidth ? const Color(0xFF047857) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Row 2: Hide/Show Section Name & Item Count Chips
                                    Row(
                                      children: [
                                        // Name Toggle Chip
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final newHideTitle = !isHideTitle;
                                              await AuthService.toggleSellerSectionHideTitle(sId, username, sName, newHideTitle);
                                              final updatedSecs = await AuthService.getSellerSections(username);
                                              setModalState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                              setState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: isHideTitle ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isHideTitle ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isHideTitle ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                                    size: 14,
                                                    color: isHideTitle ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isHideTitle ? 'Name: Hidden' : 'Name: Visible',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isHideTitle ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Count Toggle Chip
                                        Expanded(
                                          child: InkWell(
                                            onTap: () async {
                                              final newHideCount = !isHideCount;
                                              await AuthService.toggleSellerSectionHideItemCount(sId, username, sName, newHideCount);
                                              final updatedSecs = await AuthService.getSellerSections(username);
                                              setModalState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                              setState(() {
                                                _sellerSections = updatedSecs;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: isHideCount ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isHideCount ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isHideCount ? Icons.label_off_rounded : Icons.numbers_rounded,
                                                    size: 14,
                                                    color: isHideCount ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    isHideCount ? 'Count: Hidden' : 'Count: Visible',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isHideCount ? const Color(0xFFD97706) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (sHeadingImg.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          width: double.infinity,
                                          height: 38,
                                          color: Colors.white,
                                          child: _buildSectionHeadingPreview(sHeadingImg, height: 38),
                                        ),
                                      ),
                                    ],
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

  // --- 4. SEARCH BAR STYLE DIALOG (EXACT ORIGINAL LOGIC & DESIGN WITH WATERMARK LIST) ---
  void _showManageSearchBarDialog() {
    final username = _sellerUsername;
    final cachedStyle = AuthService.getCachedSellerSearchBarStyle(username);
    Map<String, dynamic> currentConfig = AuthService.getCachedHeaderThemeConfig() ?? {};
    String bgColor = (cachedStyle?['search_bg_color'] ?? currentConfig['search_bg_color'] ?? '#FFFFFF').toString();
    double opacity = (((cachedStyle?['search_opacity'] ?? currentConfig['search_opacity']) as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
    String textColor = (cachedStyle?['search_text_color'] ?? currentConfig['search_text_color'] ?? '#0F172A').toString();

    final List<TextEditingController> hintControllers = [];
    final cachedHints = AuthService.getCachedSellerSearchHints(username);
    if (cachedHints != null && cachedHints.isNotEmpty) {
      for (final h in cachedHints) {
        hintControllers.add(TextEditingController(text: h));
      }
    }

    bool isLoadedFromNetwork = false;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoadedFromNetwork) {
            isLoadedFromNetwork = true;
            Future.microtask(() async {
              final freshConfig = await AuthService.getHeaderThemeConfig();
              final savedStyle = await AuthService.getSellerSearchBarStyle(username);
              final savedHints = await AuthService.getSellerSearchHints(username);
              if (ctx.mounted) {
                setModalState(() {
                  currentConfig = freshConfig;
                  bgColor = (savedStyle['search_bg_color'] ?? freshConfig['search_bg_color'] ?? '#FFFFFF').toString();
                  opacity = (((savedStyle['search_opacity'] ?? freshConfig['search_opacity']) as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0);
                  textColor = (savedStyle['search_text_color'] ?? freshConfig['search_text_color'] ?? '#0F172A').toString();
                  if (hintControllers.isEmpty || (hintControllers.length == 1 && hintControllers[0].text == 'Search products in store...')) {
                    if (savedHints.isNotEmpty) {
                      hintControllers.clear();
                      for (final h in savedHints) {
                        hintControllers.add(TextEditingController(text: h));
                      }
                    } else if (hintControllers.isEmpty) {
                      hintControllers.add(TextEditingController(text: 'Search products in store...'));
                    }
                  }
                });
              }
            });
          }

          final Color previewColor = hexToColor(bgColor).withValues(alpha: opacity);
          final Color previewTextColor = hexToColor(textColor);
          final String previewHint = hintControllers.map((c) => c.text.trim()).firstWhere(
                (t) => t.isNotEmpty,
                orElse: () => 'Search products in store...',
              );

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
                          Expanded(
                            child: Text(
                              previewHint,
                              style: TextStyle(color: previewTextColor.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dynamic Search Watermarks / Animated Placeholders Section
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Search Watermarks (घूमने वाले सर्च टेक्स्ट 💬)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'ये टेक्स्ट सर्च बार में एक-एक कर ऑटो चेंज होंगे',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  hintControllers.add(TextEditingController());
                                });
                              },
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              label: const Text('+ Add', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (hintControllers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No watermark texts added. Tap "+ Add" to add search suggestions!',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: hintControllers.length,
                            itemBuilder: (ctx, hIdx) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEDE9FE),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${hIdx + 1}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: hintControllers[hIdx],
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: InputDecoration(
                                          hintText: "उदा. Search 'दूध', Search 'Snacks'...",
                                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          hintControllers[hIdx].dispose();
                                          hintControllers.removeAt(hIdx);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFCA5A5)),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
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
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setModalState(() => isProcessing = true);
                            try {
                              final enteredHints = hintControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                              await AuthService.saveSellerSearchBarStyle(
                                sellerUsername: username,
                                hints: enteredHints,
                                bgColor: bgColor,
                                opacity: opacity,
                                textColor: textColor,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Search Bar Style & Watermarks saved successfully in database! 🎉'),
                                    backgroundColor: Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (err) {
                              setModalState(() => isProcessing = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Save error: $err ❌'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Saving Search Bar Style...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          )
                        : const Text(
                            'Save Search Bar Style 🎨',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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

  // --- 4B. ACTION BUTTONS STYLE DIALOG (BACK TO TOP & VIEW MORE) ---
  void _showManageActionButtonsDialog() {
    final username = _sellerUsername;
    final cachedButtons = AuthService.getCachedSellerActionButtons(username) ?? {};

    String backToTopBg = (cachedButtons['back_to_top_bg'] ?? '#1E293B').toString();
    double backToTopOpacity = safeDouble(cachedButtons['back_to_top_opacity'], 1.0).clamp(0.05, 1.0);
    String backToTopText = (cachedButtons['back_to_top_text'] ?? 'Back to top').toString();
    double backToTopSize = safeDouble(cachedButtons['back_to_top_size'], 12.5).clamp(9.0, 24.0);
    String backToTopTextColor = (cachedButtons['back_to_top_text_color'] ?? '#FFFFFF').toString();

    String viewMoreBg = (cachedButtons['view_more_bg'] ?? '#F59E0B').toString();
    double viewMoreOpacity = safeDouble(cachedButtons['view_more_opacity'], 1.0).clamp(0.05, 1.0);
    String viewMoreText = (cachedButtons['view_more_text'] ?? 'View More').toString();
    double viewMoreSize = safeDouble(cachedButtons['view_more_size'], 13.0).clamp(10.0, 24.0);
    String viewMoreTextColor = (cachedButtons['view_more_text_color'] ?? '#0F172A').toString();

    final backToTopTextController = TextEditingController(text: backToTopText);
    final viewMoreTextController = TextEditingController(text: viewMoreText);

    int activeTabIndex = 0; // 0: Back to top, 1: View More
    bool isLoadedFromNetwork = false;
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoadedFromNetwork) {
            isLoadedFromNetwork = true;
            Future.microtask(() async {
              final fresh = await AuthService.getSellerActionButtons(username);
              if (ctx.mounted && fresh.isNotEmpty) {
                setModalState(() {
                  backToTopBg = (fresh['back_to_top_bg'] ?? backToTopBg).toString();
                  backToTopOpacity = safeDouble(fresh['back_to_top_opacity'], backToTopOpacity).clamp(0.05, 1.0);
                  backToTopText = (fresh['back_to_top_text'] ?? backToTopText).toString();
                  backToTopSize = safeDouble(fresh['back_to_top_size'], backToTopSize).clamp(9.0, 24.0);
                  backToTopTextColor = (fresh['back_to_top_text_color'] ?? backToTopTextColor).toString();
                  backToTopTextController.text = backToTopText;

                  viewMoreBg = (fresh['view_more_bg'] ?? viewMoreBg).toString();
                  viewMoreOpacity = safeDouble(fresh['view_more_opacity'], viewMoreOpacity).clamp(0.05, 1.0);
                  viewMoreText = (fresh['view_more_text'] ?? viewMoreText).toString();
                  viewMoreSize = safeDouble(fresh['view_more_size'], viewMoreSize).clamp(10.0, 24.0);
                  viewMoreTextColor = (fresh['view_more_text_color'] ?? viewMoreTextColor).toString();
                  viewMoreTextController.text = viewMoreText;
                });
              }
            });
          }

          final Color bttRawBg = hexToColor(backToTopBg);
          final Color bttBgColor = bttRawBg.withValues(alpha: backToTopOpacity);
          final Color bttTextColor = hexToColor(backToTopTextColor);
          final String bttCurrentText = backToTopTextController.text.trim().isNotEmpty
              ? backToTopTextController.text.trim()
              : 'Back to top';

          final Color vmRawBg = hexToColor(viewMoreBg);
          final Color vmBgColor = vmRawBg.withValues(alpha: viewMoreOpacity);
          final Color vmTextColor = hexToColor(viewMoreTextColor);
          final String vmCurrentText = viewMoreTextController.text.trim().isNotEmpty
              ? viewMoreTextController.text.trim()
              : 'View More';

          const List<String> presetColors = [
            '#1E293B', '#0F172A', '#F59E0B', '#DC2626', '#10B981', '#3B82F6', '#8B5CF6', '#EC4899', '#6366F1', '#14B8A6'
          ];
          const List<String> textPresetColors = [
            '#FFFFFF', '#0F172A', '#F8FAFC', '#FEF3C7', '#FEF2F2', '#3B82F6', '#10B981'
          ];

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 18,
              right: 18,
              top: 14,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                  const SizedBox(height: 12),

                  // Header
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.smart_button_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Action Buttons Customizer 🔘',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Back to top & View More buttons styling',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  const SizedBox(height: 12),

                  // LIVE PREVIEW CONTAINER (Clean, structured & zero overflow!)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Bar (No overflow!)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          color: const Color(0xFFF1F5F9),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility_rounded, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  activeTabIndex == 0 ? 'Live Preview: Back to top' : 'Live Preview: View More',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                ),
                                child: Text(
                                  '${((activeTabIndex == 0 ? backToTopOpacity : viewMoreOpacity) * 100).toInt()}% Opacity',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Simulation Area with Visual Background (Aar-paar dikhne ke liye!)
                        SizedBox(
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background Store Mock (Colorful cards so transparency shines through!)
                              Positioned.fill(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFEF3C7), Color(0xFFE0E7FF), Color(0xFFDCFCE7)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(Icons.shopping_bag_outlined, size: 38, color: Colors.orange.shade400),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(Icons.local_offer_outlined, size: 38, color: Colors.blue.shade400),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Button Centered on Top of Background
                              if (activeTabIndex == 0) ...[
                                // Back to top button
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (backToTopSize * 1.1).clamp(10.0, 20.0),
                                    vertical: (backToTopSize * 0.55).clamp(5.0, 12.0),
                                  ),
                                  decoration: BoxDecoration(
                                    color: bttBgColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: bttTextColor.withValues(alpha: (0.16 + 0.25 * (1.0 - backToTopOpacity)).clamp(0.12, 0.45)),
                                      width: 0.9,
                                    ),
                                    boxShadow: backToTopOpacity > 0.25
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: (0.22 * backToTopOpacity * backToTopOpacity).clamp(0.0, 0.22)),
                                              blurRadius: (8 * backToTopOpacity).toDouble(),
                                              offset: Offset(0, (3 * backToTopOpacity).toDouble()),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: (backToTopSize * 1.4).clamp(14.0, 26.0),
                                        height: (backToTopSize * 1.4).clamp(14.0, 26.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: bttTextColor, width: 1.2),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.arrow_upward_rounded,
                                            size: (backToTopSize * 0.9).clamp(10.0, 18.0),
                                            color: bttTextColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        bttCurrentText,
                                        style: TextStyle(
                                          color: bttTextColor,
                                          fontSize: backToTopSize,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // View More button
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (viewMoreSize * 1.6).clamp(14.0, 28.0),
                                    vertical: (viewMoreSize * 0.75).clamp(6.0, 14.0),
                                  ),
                                  decoration: BoxDecoration(
                                    color: vmBgColor,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: vmTextColor.withValues(alpha: (0.15 + 0.25 * (1.0 - viewMoreOpacity)).clamp(0.12, 0.4)),
                                      width: 0.9,
                                    ),
                                    boxShadow: viewMoreOpacity > 0.25
                                        ? [
                                            BoxShadow(
                                              color: vmRawBg.withValues(alpha: (0.35 * viewMoreOpacity * viewMoreOpacity).clamp(0.0, 0.35)),
                                              blurRadius: (8 * viewMoreOpacity).toDouble(),
                                              offset: Offset(0, (3 * viewMoreOpacity).toDouble()),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$vmCurrentText (2 more items)',
                                        style: TextStyle(
                                          color: vmTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: viewMoreSize,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // TAB SWITCHER: [ Back to top ] | [ View More ]
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => activeTabIndex = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTabIndex == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: activeTabIndex == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '🔝 Back to top Button',
                                  style: TextStyle(
                                    fontWeight: activeTabIndex == 0 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: activeTabIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => activeTabIndex = 1),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: activeTabIndex == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: activeTabIndex == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '🛍️ View More Button',
                                  style: TextStyle(
                                    fontWeight: activeTabIndex == 1 ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: activeTabIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // TAB CONTENT
                  if (activeTabIndex == 0) ...[
                    // BACK TO TOP CONTROLS
                    // 1. Text Name
                    const Text('Button Text Name:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: backToTopTextController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. Back to top, Upar Jayein',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        suffixIcon: backToTopTextController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  backToTopTextController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Background Color
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        TextButton.icon(
                          onPressed: () {
                            FullColorPickerDialog.show(
                              context,
                              initialHex: backToTopBg,
                              onColorSelected: (newHex) => setModalState(() => backToTopBg = newHex),
                            );
                          },
                          icon: const Icon(Icons.colorize_rounded, size: 15, color: Color(0xFF2563EB)),
                          label: const Text('Custom Picker', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: presetColors.map((hex) {
                          final isSel = backToTopBg.toLowerCase() == hex.toLowerCase();
                          final c = hexToColor(hex);
                          return InkWell(
                            onTap: () => setModalState(() => backToTopBg = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                                boxShadow: isSel ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 6)] : null,
                              ),
                              child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Transparency / Opacity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transparency / Opacity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                          child: Text('${(backToTopOpacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                    Slider(
                      value: backToTopOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      activeColor: const Color(0xFF2563EB),
                      inactiveColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => setModalState(() => backToTopOpacity = val),
                    ),
                    const SizedBox(height: 8),

                    // 4. Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Button & Font Size:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                          child: Text('${backToTopSize.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF2563EB))),
                        ),
                      ],
                    ),
                    Slider(
                      value: backToTopSize,
                      min: 9.0,
                      max: 22.0,
                      divisions: 26,
                      activeColor: const Color(0xFF2563EB),
                      inactiveColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => setModalState(() => backToTopSize = val),
                    ),
                    const SizedBox(height: 8),

                    // 5. Text Color
                    const Text('Text & Icon Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: textPresetColors.map((hex) {
                          final isSel = backToTopTextColor.toLowerCase() == hex.toLowerCase();
                          final c = hexToColor(hex);
                          return InkWell(
                            onTap: () => setModalState(() => backToTopTextColor = hex),
                            child: Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                              ),
                              child: isSel ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    // VIEW MORE CONTROLS
                    // 1. Text Name
                    const Text('Button Text Name:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 5),
                    TextField(
                      controller: viewMoreTextController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. View More, Aur Dekhein, See All',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
                        suffixIcon: viewMoreTextController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  viewMoreTextController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Background Color
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Background Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        TextButton.icon(
                          onPressed: () {
                            FullColorPickerDialog.show(
                              context,
                              initialHex: viewMoreBg,
                              onColorSelected: (newHex) => setModalState(() => viewMoreBg = newHex),
                            );
                          },
                          icon: const Icon(Icons.colorize_rounded, size: 15, color: Color(0xFFF59E0B)),
                          label: const Text('Custom Picker', style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: presetColors.map((hex) {
                          final isSel = viewMoreBg.toLowerCase() == hex.toLowerCase();
                          final c = hexToColor(hex);
                          return InkWell(
                            onTap: () => setModalState(() => viewMoreBg = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                                boxShadow: isSel ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 6)] : null,
                              ),
                              child: isSel ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Transparency / Opacity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Transparency / Opacity:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: Text('${(viewMoreOpacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFB45309))),
                        ),
                      ],
                    ),
                    Slider(
                      value: viewMoreOpacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 18,
                      activeColor: const Color(0xFFF59E0B),
                      inactiveColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => setModalState(() => viewMoreOpacity = val),
                    ),
                    const SizedBox(height: 8),

                    // 4. Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Button & Font Size:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                          child: Text('${viewMoreSize.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFB45309))),
                        ),
                      ],
                    ),
                    Slider(
                      value: viewMoreSize,
                      min: 10.0,
                      max: 24.0,
                      divisions: 28,
                      activeColor: const Color(0xFFF59E0B),
                      inactiveColor: const Color(0xFFCBD5E1),
                      onChanged: (val) => setModalState(() => viewMoreSize = val),
                    ),
                    const SizedBox(height: 8),

                    // 5. Text Color
                    const Text('Text Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: textPresetColors.map((hex) {
                          final isSel = viewMoreTextColor.toLowerCase() == hex.toLowerCase();
                          final c = hexToColor(hex);
                          return InkWell(
                            onTap: () => setModalState(() => viewMoreTextColor = hex),
                            child: Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: isSel ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1), width: isSel ? 3 : 1),
                              ),
                              child: isSel ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // SAVE BUTTON
                  ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            setModalState(() => isProcessing = true);
                            try {
                              final payload = <String, dynamic>{
                                'back_to_top_bg': backToTopBg,
                                'back_to_top_opacity': backToTopOpacity,
                                'back_to_top_text': backToTopTextController.text.trim().isNotEmpty
                                    ? backToTopTextController.text.trim()
                                    : 'Back to top',
                                'back_to_top_size': backToTopSize,
                                'back_to_top_text_color': backToTopTextColor,
                                'view_more_bg': viewMoreBg,
                                'view_more_opacity': viewMoreOpacity,
                                'view_more_text': viewMoreTextController.text.trim().isNotEmpty
                                    ? viewMoreTextController.text.trim()
                                    : 'View More',
                                'view_more_size': viewMoreSize,
                                'view_more_text_color': viewMoreTextColor,
                              };

                              await AuthService.saveSellerActionButtons(
                                sellerUsername: username,
                                buttonsConfig: payload,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Buttons Style (Back to top & View More) saved in database & local cache! 🎉'),
                                    backgroundColor: Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (err) {
                              setModalState(() => isProcessing = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Save error: $err ❌'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                              SizedBox(width: 10),
                              Text('Saving Buttons Style...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          )
                        : const Text(
                            'Save Action Buttons Style 🔘',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
    bool isProcessingImage = false;
    bool isSavingBorder = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;

          Future<void> _processAndSetImage(Uint8List bytes) async {
            setModalState(() {
              isProcessingImage = true;
            });
            try {
              final transparentPngBase64 = await ImageBorderHelper.makeWhiteBackgroundTransparent(bytes);
              setModalState(() {
                currentBorder = transparentPngBase64;
                isProcessingImage = false;
              });
            } catch (_) {
              setModalState(() {
                currentBorder = 'data:image/png;base64,${base64Encode(bytes)}';
                isProcessingImage = false;
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
              isProcessingImage = true;
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
                  isProcessingImage = false;
                });
              } else {
                setModalState(() => isProcessingImage = false);
              }
            } catch (_) {
              setModalState(() => isProcessingImage = false);
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
                          onPressed: (isProcessingImage || isSavingBorder) ? null : _pickBorderImage,
                          icon: isProcessingImage
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(
                            isProcessingImage ? 'Processing PNG...' : 'Pick Border Image 📁',
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
                          onPressed: (isProcessingImage || isSavingBorder)
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
                        onPressed: (isProcessingImage || isSavingBorder) ? null : _removeWhiteFromCurrentBorder,
                        icon: isProcessingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)))
                            : const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF8B5CF6), size: 18),
                        label: Text(
                          isProcessingImage ? 'Processing PNG...' : 'Auto-Remove White Background ✨ (Make Center Transparent)',
                          style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
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
                      onPressed: (isProcessingImage || isSavingBorder)
                          ? null
                          : () async {
                              setModalState(() => isSavingBorder = true);
                              try {
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
                              } catch (err) {
                                setModalState(() => isSavingBorder = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $err ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSavingBorder
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving Border Settings...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save Border Settings 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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
    final username = _sellerUsername;
    final urlController = TextEditingController();
    final jsonCodeController = TextEditingController();
    
    // Instant memory cache load (0.01s - ZERO DELAY!)
    final cachedRaw = AuthService.getCachedSellerHeaderAnimations(username) ?? [];
    final cachedHeaderTheme = AuthService.getCachedHeaderThemeConfig();
    Map<String, dynamic> headerTheme = cachedHeaderTheme != null
        ? Map<String, dynamic>.from(cachedHeaderTheme)
        : {
            'color1': '#0F172A',
            'color2': '#1E1B4B',
            'color3': '#312E81',
          };

    List<Map<String, dynamic>> animationsList = cachedRaw.map((item) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        if (m['direction'] == null) {
          m['direction'] = headerTheme['direction']?.toString() ?? 'horizontal';
        }
        if (m['sticky_color1'] == null) {
          m['sticky_color1'] = headerTheme['sticky_color1']?.toString() ?? headerTheme['color1']?.toString() ?? '#0F172A';
        }
        if (m['sticky_color2'] == null) {
          m['sticky_color2'] = headerTheme['sticky_color2']?.toString() ?? headerTheme['color2']?.toString() ?? '#1E1B4B';
        }
        if (m['sticky_direction'] == null) {
          m['sticky_direction'] = headerTheme['sticky_direction']?.toString() ?? 'horizontal';
        }
        return m;
      }
      return <String, dynamic>{
        'url': item.toString(),
        'color1': headerTheme['color1']?.toString() ?? '#0F172A',
        'color2': headerTheme['color2']?.toString() ?? '#1E1B4B',
        'color3': headerTheme['color3']?.toString() ?? '#312E81',
        'direction': headerTheme['direction']?.toString() ?? 'horizontal',
        'sticky_color1': headerTheme['sticky_color1']?.toString() ?? '#0F172A',
        'sticky_color2': headerTheme['sticky_color2']?.toString() ?? '#1E1B4B',
        'sticky_direction': headerTheme['sticky_direction']?.toString() ?? 'horizontal',
        if (headerTheme['bg_image'] != null) 'bg_image': headerTheme['bg_image'],
      };
    }).toList();

    int selectedIndex = 0;
    int activeColorTab = 0; // 0: Full Header Colors, 1: Scrolled Sticky Colors
    int previewMode = 0; // 0: Full Header Preview, 1: Scrolled Sticky Preview
    bool isProcessing = false;
    bool isPickingBgImage = false;
    bool isLoadedFromNetwork = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoadedFromNetwork) {
            isLoadedFromNetwork = true;
            Future.microtask(() async {
              final rawList = await AuthService.getSellerHeaderAnimations(username);
              final freshConfig = await AuthService.getHeaderThemeConfig();
              if (ctx.mounted) {
                setModalState(() {
                  headerTheme = Map<String, dynamic>.from(freshConfig);
                  if (rawList.isNotEmpty) {
                    animationsList = rawList.map((item) {
                      if (item is Map) {
                        final m = Map<String, dynamic>.from(item);
                        if (m['direction'] == null) {
                          m['direction'] = freshConfig['direction']?.toString() ?? 'horizontal';
                        }
                        if (m['sticky_color1'] == null) {
                          m['sticky_color1'] = freshConfig['sticky_color1']?.toString() ?? freshConfig['color1']?.toString() ?? '#0F172A';
                        }
                        if (m['sticky_color2'] == null) {
                          m['sticky_color2'] = freshConfig['sticky_color2']?.toString() ?? freshConfig['color2']?.toString() ?? '#1E1B4B';
                        }
                        if (m['sticky_direction'] == null) {
                          m['sticky_direction'] = freshConfig['sticky_direction']?.toString() ?? 'horizontal';
                        }
                        return m;
                      }
                      return <String, dynamic>{
                        'url': item.toString(),
                        'color1': freshConfig['color1']?.toString() ?? '#0F172A',
                        'color2': freshConfig['color2']?.toString() ?? '#1E1B4B',
                        'color3': freshConfig['color3']?.toString() ?? '#312E81',
                        'direction': freshConfig['direction']?.toString() ?? 'horizontal',
                        'sticky_color1': freshConfig['sticky_color1']?.toString() ?? '#0F172A',
                        'sticky_color2': freshConfig['sticky_color2']?.toString() ?? '#1E1B4B',
                        'sticky_direction': freshConfig['sticky_direction']?.toString() ?? 'horizontal',
                        if (freshConfig['bg_image'] != null) 'bg_image': freshConfig['bg_image'],
                      };
                    }).toList();
                  }
                });
              }
            });
          }

          if (selectedIndex >= animationsList.length && animationsList.isNotEmpty) {
            selectedIndex = animationsList.length - 1;
          }

          Future<void> _pickLottieJsonFile() async {
            try {
              setModalState(() => isProcessing = true);
              final String? jsonStr = await JsonPickerHelper.pickJsonString();

              if (jsonStr != null && jsonStr.trim().isNotEmpty) {
                final cleanJson = jsonStr.trim();
                try {
                  jsonDecode(cleanJson);
                  setModalState(() {
                    animationsList.add({
                      'url': cleanJson,
                      'color1': headerTheme['color1']?.toString() ?? '#0F172A',
                      'color2': headerTheme['color2']?.toString() ?? '#1E1B4B',
                      'direction': headerTheme['direction']?.toString() ?? 'horizontal',
                      if (headerTheme['bg_image'] != null) 'bg_image': headerTheme['bg_image'],
                    });
                    selectedIndex = animationsList.length - 1;
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
                      const SnackBar(
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
                animationsList.add({
                  'url': text,
                  'color1': headerTheme['color1']?.toString() ?? '#0F172A',
                  'color2': headerTheme['color2']?.toString() ?? '#1E1B4B',
                  'direction': headerTheme['direction']?.toString() ?? 'horizontal',
                  if (headerTheme['bg_image'] != null) 'bg_image': headerTheme['bg_image'],
                });
                selectedIndex = animationsList.length - 1;
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
              animationsList.add({
                'url': url,
                'color1': headerTheme['color1']?.toString() ?? '#0F172A',
                'color2': headerTheme['color2']?.toString() ?? '#1E1B4B',
                'direction': headerTheme['direction']?.toString() ?? 'horizontal',
                if (headerTheme['bg_image'] != null) 'bg_image': headerTheme['bg_image'],
              });
              selectedIndex = animationsList.length - 1;
              urlController.clear();
            });
          }

          final Map<String, dynamic> activeAnimMap = animationsList.isNotEmpty && selectedIndex < animationsList.length
              ? animationsList[selectedIndex]
              : headerTheme;

          Future<void> _pickHeaderBgImage() async {
            setModalState(() => isPickingBgImage = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1080,
                maxHeight: 1080,
                imageQuality: 80,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                setModalState(() {
                  activeAnimMap['bg_image'] = base64Str;
                  if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                    animationsList[selectedIndex]['bg_image'] = base64Str;
                  }
                  headerTheme['bg_image'] = base64Str;
                  isPickingBgImage = false;
                });
              } else {
                setModalState(() => isPickingBgImage = false);
              }
            } catch (_) {
              setModalState(() => isPickingBgImage = false);
            }
          }

          Widget _buildHeaderBgThumbnail(String src) {
            final clean = src.trim();
            if (clean.startsWith('http://') || clean.startsWith('https://')) {
              return Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.red)),
              );
            }
            try {
              String base64Str = clean;
              if (clean.contains(',')) {
                base64Str = clean.split(',').last.trim();
              }
              final bytes = base64Decode(base64Str);
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.red)),
              );
            } catch (_) {
              return const Center(child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.red));
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
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.movie_filter_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Header Theme & Animations 🎬🎨',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Set background color for each animation individually!',
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

                  // Configured Animations List (Cards #1, #2...)
                  Text(
                    'Configured Animations (${animationsList.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '👇 Click on any card below (#1, #2) to set its background color!',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
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
                          'No animations added yet. Upload JSON file or paste code above! 🎬',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 115,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: animationsList.length,
                        itemBuilder: (context, idx) {
                          final animMap = animationsList[idx];
                          final isSelected = idx == selectedIndex;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedIndex = idx;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 115,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: HeaderThemeHelper.buildDecoration(animMap).copyWith(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 3.0 : 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)]
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  // Animation Preview
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: buildSingleLottieItem(animMap['url'] ?? animMap, fit: BoxFit.cover),
                                    ),
                                  ),

                                  // Index & Selection Badge
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF10B981) : Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isSelected ? '#${idx + 1} ACTIVE' : '#${idx + 1}',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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
                                          if (selectedIndex >= animationsList.length && animationsList.isNotEmpty) {
                                            selectedIndex = animationsList.length - 1;
                                          }
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
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Header Background Color & Photo Pickers
                  () {
                    final currentBgImg = (activeAnimMap['bg_image'] ?? activeAnimMap['background_image'] ?? '').toString().trim();
                    final c1 = HeaderThemeHelper.hexToColor(activeAnimMap['color1']?.toString() ?? '#0F172A');
                    final c2 = HeaderThemeHelper.hexToColor(activeAnimMap['color2']?.toString() ?? '#1E1B4B');
                    final currentDir = (activeAnimMap['direction'] ?? headerTheme['direction'] ?? 'horizontal').toString().toLowerCase();

                    final sc1 = HeaderThemeHelper.hexToColor(activeAnimMap['sticky_color1']?.toString() ?? activeAnimMap['color1']?.toString() ?? '#0F172A');
                    final sc2 = HeaderThemeHelper.hexToColor(activeAnimMap['sticky_color2']?.toString() ?? activeAnimMap['color2']?.toString() ?? '#1E1B4B');
                    final currentStickyDir = (activeAnimMap['sticky_direction'] ?? headerTheme['sticky_direction'] ?? 'horizontal').toString().toLowerCase();

                    final catIconHex = (activeAnimMap['category_icon_color'] ?? headerTheme['category_icon_color'] ?? '#FFFFFF').toString();
                    final catIconColor = HeaderThemeHelper.hexToColor(catIconHex);

                    final stickyCatIconHex = (activeAnimMap['sticky_category_icon_color'] ?? activeAnimMap['category_icon_color'] ?? headerTheme['sticky_category_icon_color'] ?? '#FFFFFF').toString();
                    final stickyCatIconColor = HeaderThemeHelper.hexToColor(stickyCatIconHex);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  animationsList.isNotEmpty ? 'Animation #${selectedIndex + 1}' : 'Header Theme',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Background Colors & Photo 🎨🖼️',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Tab Selector between 1. Full Header Colors and 2. Scrolled Sticky Colors
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(() {
                                      activeColorTab = 0;
                                      previewMode = 0;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: activeColorTab == 0 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: activeColorTab == 0
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.phone_android_rounded, size: 13, color: activeColorTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '1. Full Header (डिफ़ॉल्ट)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: activeColorTab == 0 ? FontWeight.bold : FontWeight.w600,
                                                color: activeColorTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(() {
                                      activeColorTab = 1;
                                      previewMode = 1;
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: activeColorTab == 1 ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: activeColorTab == 1
                                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.push_pin_rounded, size: 13, color: activeColorTab == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '2. Sticky (स्क्रोल)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: activeColorTab == 1 ? FontWeight.bold : FontWeight.w600,
                                                color: activeColorTab == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                              ),
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

                          // TAB 0: FULL HEADER DEFAULT COLORS
                          if (activeColorTab == 0) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      FullColorPickerDialog.show(
                                        context,
                                        initialHex: activeAnimMap['color1']?.toString() ?? '#0F172A',
                                        onColorSelected: (selectedHex) {
                                          setModalState(() {
                                            activeAnimMap['color1'] = selectedHex;
                                            activeAnimMap.remove('color3');
                                            headerTheme['color1'] = selectedHex;
                                            headerTheme.remove('color3');
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: c1,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Color 1 (Full)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                                Text(activeAnimMap['color1']?.toString() ?? '#0F172A', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      FullColorPickerDialog.show(
                                        context,
                                        initialHex: activeAnimMap['color2']?.toString() ?? '#1E1B4B',
                                        onColorSelected: (selectedHex) {
                                          setModalState(() {
                                            activeAnimMap['color2'] = selectedHex;
                                            activeAnimMap.remove('color3');
                                            headerTheme['color2'] = selectedHex;
                                            headerTheme.remove('color3');
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: c2,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Color 2 (Full)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                                Text(activeAnimMap['color2']?.toString() ?? '#1E1B4B', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Category Icon & Text Color Picker
                            GestureDetector(
                              onTap: () {
                                FullColorPickerDialog.show(
                                  context,
                                  initialHex: activeAnimMap['category_icon_color']?.toString() ?? headerTheme['category_icon_color']?.toString() ?? '#FFFFFF',
                                  onColorSelected: (selectedHex) {
                                    setModalState(() {
                                      activeAnimMap['category_icon_color'] = selectedHex;
                                      if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                        animationsList[selectedIndex]['category_icon_color'] = selectedHex;
                                      }
                                      headerTheme['category_icon_color'] = selectedHex;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: catIconColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.black26),
                                      ),
                                      child: Icon(Icons.category_rounded, size: 13, color: catIconColor.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Category Icon & Text Color (आइकॉन व नाम रंग)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                          Text(catIconHex, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.colorize_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Gradient Direction Selector
                            Row(
                              children: [
                                const Icon(Icons.gradient_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Direction (फुल हेडर)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    currentDir == 'horizontal'
                                        ? 'Horizontal (बाएं ➡️ दाएं)'
                                        : currentDir == 'vertical'
                                            ? 'Vertical (ऊपर ⬇️ नीचे)'
                                            : 'Diagonal (तिरछा ↗️)',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                // Horizontal
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['direction'] = 'horizontal';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['direction'] = 'horizontal';
                                        }
                                        headerTheme['direction'] = 'horizontal';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentDir == 'horizontal' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentDir == 'horizontal' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentDir == 'horizontal' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.centerLeft, end: Alignment.centerRight),
                                              border: Border.all(color: currentDir == 'horizontal' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Horizontal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentDir == 'horizontal' ? Colors.white : const Color(0xFF334155))),
                                          Text('बाएं ➡️ दाएं', style: TextStyle(fontSize: 9, color: currentDir == 'horizontal' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Vertical
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['direction'] = 'vertical';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['direction'] = 'vertical';
                                        }
                                        headerTheme['direction'] = 'vertical';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentDir == 'vertical' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentDir == 'vertical' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentDir == 'vertical' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                              border: Border.all(color: currentDir == 'vertical' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Vertical', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentDir == 'vertical' ? Colors.white : const Color(0xFF334155))),
                                          Text('ऊपर ⬇️ नीचे', style: TextStyle(fontSize: 9, color: currentDir == 'vertical' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Diagonal
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['direction'] = 'diagonal';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['direction'] = 'diagonal';
                                        }
                                        headerTheme['direction'] = 'diagonal';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentDir == 'diagonal' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentDir == 'diagonal' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentDir == 'diagonal' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                              border: Border.all(color: currentDir == 'diagonal' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Diagonal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentDir == 'diagonal' ? Colors.white : const Color(0xFF334155))),
                                          Text('तिरछा ↗️', style: TextStyle(fontSize: 9, color: currentDir == 'diagonal' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 10),

                            // Background Photo Picker Section
                            Row(
                              children: [
                                const Icon(Icons.image_outlined, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Background Image (Optional)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                const Spacer(),
                                if (currentBgImg.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap.remove('bg_image');
                                        activeAnimMap.remove('background_image');
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex].remove('bg_image');
                                          animationsList[selectedIndex].remove('background_image');
                                        }
                                        headerTheme.remove('bg_image');
                                        headerTheme.remove('background_image');
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFEF4444)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Remove Photo',
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (currentBgImg.isNotEmpty) ...[
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 75,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: _buildHeaderBgThumbnail(currentBgImg),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '✓ Background Image Active',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Displays behind animation on header.',
                                          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: isPickingBgImage ? null : _pickHeaderBgImage,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEDE9FE),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isPickingBgImage ? 'Selecting...' : 'Change Photo 🖼️',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              InkWell(
                                onTap: isPickingBgImage ? null : _pickHeaderBgImage,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isPickingBgImage)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                                        )
                                      else
                                        const Icon(Icons.add_photo_alternate_rounded, size: 18, color: Color(0xFF8B5CF6)),
                                      const SizedBox(width: 8),
                                      Text(
                                        isPickingBgImage ? 'Selecting Photo...' : 'Select Background Image (Gallery) 🖼️',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            // TAB 1: SCROLLED STICKY HEADER COLORS
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.push_pin_rounded, size: 16, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'यह कलर कॉम्बिनेशन तब दिखेगा जब स्क्रीन स्क्रोल होगी और सर्च बार टॉप पर सेट हो जाएगा 📌',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600, height: 1.25),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      FullColorPickerDialog.show(
                                        context,
                                        initialHex: activeAnimMap['sticky_color1']?.toString() ?? activeAnimMap['color1']?.toString() ?? '#0F172A',
                                        onColorSelected: (selectedHex) {
                                          setModalState(() {
                                            activeAnimMap['sticky_color1'] = selectedHex;
                                            if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                              animationsList[selectedIndex]['sticky_color1'] = selectedHex;
                                            }
                                            headerTheme['sticky_color1'] = selectedHex;
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: sc1,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Sticky Color 1', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                                Text(activeAnimMap['sticky_color1']?.toString() ?? activeAnimMap['color1']?.toString() ?? '#0F172A', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      FullColorPickerDialog.show(
                                        context,
                                        initialHex: activeAnimMap['sticky_color2']?.toString() ?? activeAnimMap['color2']?.toString() ?? '#1E1B4B',
                                        onColorSelected: (selectedHex) {
                                          setModalState(() {
                                            activeAnimMap['sticky_color2'] = selectedHex;
                                            if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                              animationsList[selectedIndex]['sticky_color2'] = selectedHex;
                                            }
                                            headerTheme['sticky_color2'] = selectedHex;
                                          });
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: sc2,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Sticky Color 2', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                                Text(activeAnimMap['sticky_color2']?.toString() ?? activeAnimMap['color2']?.toString() ?? '#1E1B4B', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Sticky Category Icon & Text Color Picker
                            GestureDetector(
                              onTap: () {
                                FullColorPickerDialog.show(
                                  context,
                                  initialHex: activeAnimMap['sticky_category_icon_color']?.toString() ?? activeAnimMap['category_icon_color']?.toString() ?? headerTheme['sticky_category_icon_color']?.toString() ?? '#FFFFFF',
                                  onColorSelected: (selectedHex) {
                                    setModalState(() {
                                      activeAnimMap['sticky_category_icon_color'] = selectedHex;
                                      if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                        animationsList[selectedIndex]['sticky_category_icon_color'] = selectedHex;
                                      }
                                      headerTheme['sticky_category_icon_color'] = selectedHex;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: stickyCatIconColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.black26),
                                      ),
                                      child: Icon(Icons.category_rounded, size: 13, color: stickyCatIconColor.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Sticky Category Icon & Text Color (स्क्रोल आइकॉन व नाम रंग)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                          Text(stickyCatIconHex, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.colorize_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Sticky Direction Selector
                            Row(
                              children: [
                                const Icon(Icons.gradient_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Direction (स्क्रोल हेडर)',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                const Spacer(),
                                Flexible(
                                  child: Text(
                                    currentStickyDir == 'horizontal'
                                        ? 'Horizontal (बाएं ➡️ दाएं)'
                                        : currentStickyDir == 'vertical'
                                            ? 'Vertical (ऊपर ⬇️ नीचे)'
                                            : 'Diagonal (तिरछा ↗️)',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                // Horizontal
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['sticky_direction'] = 'horizontal';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['sticky_direction'] = 'horizontal';
                                        }
                                        headerTheme['sticky_direction'] = 'horizontal';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentStickyDir == 'horizontal' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentStickyDir == 'horizontal' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentStickyDir == 'horizontal' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [sc1, sc2], begin: Alignment.centerLeft, end: Alignment.centerRight),
                                              border: Border.all(color: currentStickyDir == 'horizontal' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Horizontal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentStickyDir == 'horizontal' ? Colors.white : const Color(0xFF334155))),
                                          Text('बाएं ➡️ दाएं', style: TextStyle(fontSize: 9, color: currentStickyDir == 'horizontal' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Vertical
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['sticky_direction'] = 'vertical';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['sticky_direction'] = 'vertical';
                                        }
                                        headerTheme['sticky_direction'] = 'vertical';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentStickyDir == 'vertical' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentStickyDir == 'vertical' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentStickyDir == 'vertical' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [sc1, sc2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                              border: Border.all(color: currentStickyDir == 'vertical' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Vertical', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentStickyDir == 'vertical' ? Colors.white : const Color(0xFF334155))),
                                          Text('ऊपर ⬇️ नीचे', style: TextStyle(fontSize: 9, color: currentStickyDir == 'vertical' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Diagonal
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        activeAnimMap['sticky_direction'] = 'diagonal';
                                        if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                          animationsList[selectedIndex]['sticky_direction'] = 'diagonal';
                                        }
                                        headerTheme['sticky_direction'] = 'diagonal';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: currentStickyDir == 'diagonal' ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: currentStickyDir == 'diagonal' ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                          width: currentStickyDir == 'diagonal' ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              gradient: LinearGradient(colors: [sc1, sc2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                              border: Border.all(color: currentStickyDir == 'diagonal' ? Colors.white38 : Colors.black12),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Diagonal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: currentStickyDir == 'diagonal' ? Colors.white : const Color(0xFF334155))),
                                          Text('तिरछा ↗️', style: TextStyle(fontSize: 9, color: currentStickyDir == 'diagonal' ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }(),
                  const SizedBox(height: 16),

                  // Live Header Preview Box with Selected Gradient Background & Animation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        previewMode == 0 ? 'Live Full Header Preview 📱:' : 'Live Scrolled Sticky Preview 📌:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                      ),
                      // Toggle Preview State
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setModalState(() => previewMode = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: previewMode == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('📱 Full', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: previewMode == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() => previewMode = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: previewMode == 1 ? const Color(0xFF8B5CF6) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('📌 Sticky', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: previewMode == 1 ? Colors.white : const Color(0xFF64748B))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 110,
                    decoration: (previewMode == 1
                            ? HeaderThemeHelper.buildStickyDecoration(activeAnimMap)
                            : HeaderThemeHelper.buildDecoration(activeAnimMap))
                        .copyWith(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: previewMode == 1
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 32,
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(width: 10),
                                        Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                                        SizedBox(width: 6),
                                        Text('Search products...', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  () {
                                    final previewStickyCatColor = HeaderThemeHelper.getStickyCategoryIconColor(activeAnimMap);
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Text('Grocery 🛒', style: TextStyle(color: previewStickyCatColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                        Text('Dairy 🥛', style: TextStyle(color: previewStickyCatColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                        Text('Snacks 🍪', style: TextStyle(color: previewStickyCatColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    );
                                  }(),
                                ],
                              ),
                            )
                          : HeaderLottieCarouselWidget(
                              overrideAnimations: animationsList,
                              config: activeAnimMap,
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
                              setModalState(() => isProcessing = true);
                              try {
                                final List<String> serialized = animationsList.map((item) => jsonEncode(item)).toList();
                                await AuthService.saveSellerHeaderAnimations(username, serialized);
                                if (animationsList.isNotEmpty && selectedIndex < animationsList.length) {
                                  headerTheme['color1'] = animationsList[selectedIndex]['color1'];
                                  headerTheme['color2'] = animationsList[selectedIndex]['color2'];
                                  headerTheme['direction'] = animationsList[selectedIndex]['direction'] ?? activeAnimMap['direction'] ?? 'horizontal';
                                  headerTheme['sticky_color1'] = animationsList[selectedIndex]['sticky_color1'] ?? activeAnimMap['sticky_color1'] ?? headerTheme['sticky_color1'] ?? '#0F172A';
                                  headerTheme['sticky_color2'] = animationsList[selectedIndex]['sticky_color2'] ?? activeAnimMap['sticky_color2'] ?? headerTheme['sticky_color2'] ?? '#1E1B4B';
                                  headerTheme['sticky_direction'] = animationsList[selectedIndex]['sticky_direction'] ?? activeAnimMap['sticky_direction'] ?? headerTheme['sticky_direction'] ?? 'horizontal';
                                  headerTheme['category_icon_color'] = animationsList[selectedIndex]['category_icon_color'] ?? activeAnimMap['category_icon_color'] ?? headerTheme['category_icon_color'] ?? '#FFFFFF';
                                  headerTheme['sticky_category_icon_color'] = animationsList[selectedIndex]['sticky_category_icon_color'] ?? activeAnimMap['sticky_category_icon_color'] ?? headerTheme['sticky_category_icon_color'] ?? '#FFFFFF';
                                  headerTheme.remove('color3');
                                  if (animationsList[selectedIndex]['bg_image'] != null &&
                                      animationsList[selectedIndex]['bg_image'].toString().trim().isNotEmpty) {
                                    headerTheme['bg_image'] = animationsList[selectedIndex]['bg_image'];
                                  } else {
                                    headerTheme.remove('bg_image');
                                  }
                                } else {
                                  headerTheme['color1'] = activeAnimMap['color1'] ?? '#0F172A';
                                  headerTheme['color2'] = activeAnimMap['color2'] ?? '#1E1B4B';
                                  headerTheme['direction'] = activeAnimMap['direction'] ?? 'horizontal';
                                  headerTheme['sticky_color1'] = activeAnimMap['sticky_color1'] ?? headerTheme['sticky_color1'] ?? '#0F172A';
                                  headerTheme['sticky_color2'] = activeAnimMap['sticky_color2'] ?? headerTheme['sticky_color2'] ?? '#1E1B4B';
                                  headerTheme['sticky_direction'] = activeAnimMap['sticky_direction'] ?? headerTheme['sticky_direction'] ?? 'horizontal';
                                  headerTheme['category_icon_color'] = activeAnimMap['category_icon_color'] ?? headerTheme['category_icon_color'] ?? '#FFFFFF';
                                  headerTheme['sticky_category_icon_color'] = activeAnimMap['sticky_category_icon_color'] ?? headerTheme['sticky_category_icon_color'] ?? '#FFFFFF';
                                  headerTheme.remove('color3');
                                  if (activeAnimMap['bg_image'] != null &&
                                      activeAnimMap['bg_image'].toString().trim().isNotEmpty) {
                                    headerTheme['bg_image'] = activeAnimMap['bg_image'];
                                  } else {
                                    headerTheme.remove('bg_image');
                                  }
                                }
                                await AuthService.saveHeaderThemeConfig(headerTheme);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Header Theme & Background Image saved successfully! 🎉'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isProcessing = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $err ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving Theme & Animations...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save Theme & Animations 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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

  // --- 11. WELCOME / FIRST ORDER POPUP IMAGE MASTER DIALOG ---
  void _showManageWelcomePopupDialog() {
    final username = _sellerUsername;
    String currentPopup = AuthService.getCachedSellerWelcomePopupImage(username) ?? '';
    final urlController = TextEditingController(text: currentPopup.startsWith('http') ? currentPopup : '');
    bool isPickingImage = false;
    bool isSavingPopup = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> _pickPopupImage() async {
            setModalState(() => isPickingImage = true);
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 900,
                maxHeight: 900,
                imageQuality: 75,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
                setModalState(() {
                  currentPopup = base64Str;
                  urlController.clear();
                  isPickingImage = false;
                });
              } else {
                setModalState(() => isPickingImage = false);
              }
            } catch (_) {
              setModalState(() => isPickingImage = false);
            }
          }

          Widget _buildImagePreview() {
            if (currentPopup.isEmpty) {
              return Container(
                height: 170,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 42, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No popup image set yet.\nPick an image or paste a URL.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget imgWidget;
            if (currentPopup.startsWith('http://') || currentPopup.startsWith('https://')) {
              imgWidget = Image.network(
                currentPopup,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.red),
                ),
              );
            } else {
              try {
                String cleanBase = currentPopup;
                if (cleanBase.contains(',')) {
                  cleanBase = cleanBase.split(',').last.trim();
                }
                final bytes = base64Decode(cleanBase);
                imgWidget = Image.memory(bytes, fit: BoxFit.contain);
              } catch (_) {
                imgWidget = const Center(
                  child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.red),
                );
              }
            }

            return Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: imgWidget,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            );
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
                        backgroundColor: Color(0xFFFFEDD5),
                        child: Icon(Icons.campaign_rounded, color: Color(0xFFEA580C), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'New Customer Welcome Popup 🎁',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Text(
                      'Yeh image naye customers ko app open karte hi screen par bounce hoke pop-up me dikhegi. Cross (❌) dabane par hat jayegi, aur tab tak har baar open karne par aayegi jab tak customer ka ek order deliver nahi ho jata.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload / Select Options
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (isPickingImage || isSavingPopup) ? null : _pickPopupImage,
                          icon: isPickingImage
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(
                            isPickingImage ? 'Selecting...' : 'Pick Image 📁',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (currentPopup.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: (isPickingImage || isSavingPopup)
                              ? null
                              : () {
                                  setModalState(() {
                                    currentPopup = '';
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
                        currentPopup = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Or Paste Image URL',
                      hintText: 'https://example.com/offer.png',
                      isDense: true,
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Preview Card
                  const Text('Popup Preview (Jaisa Customer ko dikhega):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  _buildImagePreview(),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (isPickingImage || isSavingPopup)
                          ? null
                          : () async {
                              setModalState(() => isSavingPopup = true);
                              try {
                                await AuthService.saveSellerWelcomePopupImage(username, currentPopup);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(currentPopup.isNotEmpty
                                          ? '✓ Welcome popup image saved successfully! 🎉'
                                          : '✓ Welcome popup removed!'),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSavingPopup = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $err ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSavingPopup
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving Popup...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save Welcome Popup 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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

  void _showManageHeaderTextDialog() async {
    final username = _sellerUsername;
    final currentTexts = await AuthService.getSellerHeaderText(username);
    final text1Controller = TextEditingController(text: currentTexts['text1'] ?? '');
    final text2Controller = TextEditingController(text: currentTexts['text2'] ?? '');
    bool isSaving = false;

    if (!mounted) return;

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
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.title_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Header Custom Texts 📢',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: const Text(
                      'Yahan jo 2 lines likhenge, wo customer ke order page ke top header me Good Morning aur address ke beech me dikhegi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0369A1), height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text Field 1
                  TextField(
                    controller: text1Controller,
                    decoration: InputDecoration(
                      labelText: 'Header Text Line 1',
                      hintText: 'e.g. ⚡ Fastest Delivery in 10 Mins',
                      prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Text Field 2
                  TextField(
                    controller: text2Controller,
                    decoration: InputDecoration(
                      labelText: 'Header Text Line 2',
                      hintText: 'e.g. 🏷️ Fresh Vegetables & Fruits at best rates',
                      prefixIcon: const Icon(Icons.subtitles_rounded, color: Color(0xFF0284C7)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                await AuthService.saveSellerHeaderText(
                                  username,
                                  text1Controller.text.trim(),
                                  text2Controller.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Header custom texts saved successfully! 🎉'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $err ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving Texts...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save Header Texts 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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

  void _showManageFestivalAnimationDialog() async {
    final username = _sellerUsername;
    String currentAnim = AuthService.getCachedSellerFestivalAnimation(username) ?? '';
    String selectedBgColor = AuthService.getCachedSellerFestivalBgColor(username) ?? '';
    final urlController = TextEditingController();
    bool isSaving = false;
    bool isPickingFile = false;
    bool isLoaded = false;

    if (currentAnim.isNotEmpty && (currentAnim.startsWith('http://') || currentAnim.startsWith('https://'))) {
      urlController.text = currentAnim;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoaded) {
            isLoaded = true;
            Future.microtask(() async {
              final conf = await AuthService.getSellerFestivalAnimationConfig(username);
              final netAnim = (conf['animation'] ?? '').trim();
              final netBg = (conf['bg_color'] ?? '').trim();
              if (ctx.mounted) {
                setModalState(() {
                  if (netAnim.isNotEmpty) {
                    currentAnim = netAnim;
                    if (currentAnim.startsWith('http://') || currentAnim.startsWith('https://')) {
                      urlController.text = currentAnim;
                    }
                  }
                  if (netBg.isNotEmpty) {
                    selectedBgColor = netBg;
                  }
                });
              }
            });
          }

          final bool hasAnimation = currentAnim.trim().isNotEmpty;

          Widget buildColorChip({
            required String label,
            required Color color,
            String hex = '',
            required bool isSelected,
            required VoidCallback onTap,
            bool isNone = false,
          }) {
            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isNone ? Colors.white : color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEC4899) : Colors.grey.shade300,
                    width: isSelected ? 2.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                            blurRadius: 5,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNone)
                      const Icon(Icons.block_rounded, size: 12, color: Colors.grey)
                    else
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isNone || color == Colors.white
                            ? const Color(0xFF1E293B)
                            : (color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
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
                        child: Icon(Icons.celebration_rounded, color: Color(0xFFEC4899), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Festival Animation 🎆',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                      if (hasAnimation)
                        IconButton(
                          tooltip: 'Remove Animation',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: () {
                            setModalState(() {
                              currentAnim = '';
                              urlController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBCFE8)),
                    ),
                    child: const Text(
                      'Animation upload karein aur background color select karein. Yeh header aur banner ke beech compact strip me live dikhegi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9D174D), height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Animation Live Preview Box
                  Container(
                    width: double.infinity,
                    height: 75,
                    decoration: BoxDecoration(
                      color: selectedBgColor.isNotEmpty
                          ? HeaderThemeHelper.hexToColor(selectedBgColor)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasAnimation ? const Color(0xFFEC4899) : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasAnimation
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: buildSingleLottieItem(currentAnim, fit: BoxFit.contain),
                              ),
                              Positioned(
                                top: 4,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_fill_rounded, color: Color(0xFFEC4899), size: 10),
                                      SizedBox(width: 3),
                                      Text('Live Preview', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.movie_creation_outlined, size: 22, color: Colors.grey.shade400),
                              const SizedBox(height: 2),
                              Text(
                                'No Animation Active (Compact Strip)',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Background Color Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_rounded, size: 16, color: Color(0xFFEC4899)),
                          const SizedBox(width: 6),
                          const Text(
                            'Background Color:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const Spacer(),
                          if (selectedBgColor.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedBgColor = '';
                                });
                              },
                              child: Text(
                                'Reset (None)',
                                style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            buildColorChip(
                              label: 'None',
                              color: Colors.transparent,
                              isSelected: selectedBgColor.isEmpty,
                              onTap: () => setModalState(() => selectedBgColor = ''),
                              isNone: true,
                            ),
                            buildColorChip(
                              label: 'Header Red',
                              color: const Color(0xFF8B0000),
                              hex: '#8B0000',
                              isSelected: selectedBgColor.toUpperCase() == '#8B0000',
                              onTap: () => setModalState(() => selectedBgColor = '#8B0000'),
                            ),
                            buildColorChip(
                              label: 'Crimson',
                              color: const Color(0xFF991B1B),
                              hex: '#991B1B',
                              isSelected: selectedBgColor.toUpperCase() == '#991B1B',
                              onTap: () => setModalState(() => selectedBgColor = '#991B1B'),
                            ),
                            buildColorChip(
                              label: 'Navy',
                              color: const Color(0xFF0F172A),
                              hex: '#0F172A',
                              isSelected: selectedBgColor.toUpperCase() == '#0F172A',
                              onTap: () => setModalState(() => selectedBgColor = '#0F172A'),
                            ),
                            buildColorChip(
                              label: 'Indigo',
                              color: const Color(0xFF1E1B4B),
                              hex: '#1E1B4B',
                              isSelected: selectedBgColor.toUpperCase() == '#1E1B4B',
                              onTap: () => setModalState(() => selectedBgColor = '#1E1B4B'),
                            ),
                            buildColorChip(
                              label: 'Orange',
                              color: const Color(0xFFEA580C),
                              hex: '#EA580C',
                              isSelected: selectedBgColor.toUpperCase() == '#EA580C',
                              onTap: () => setModalState(() => selectedBgColor = '#EA580C'),
                            ),
                            buildColorChip(
                              label: 'Gold',
                              color: const Color(0xFFD97706),
                              hex: '#D97706',
                              isSelected: selectedBgColor.toUpperCase() == '#D97706',
                              onTap: () => setModalState(() => selectedBgColor = '#D97706'),
                            ),
                            buildColorChip(
                              label: 'Pink',
                              color: const Color(0xFFDB2777),
                              hex: '#DB2777',
                              isSelected: selectedBgColor.toUpperCase() == '#DB2777',
                              onTap: () => setModalState(() => selectedBgColor = '#DB2777'),
                            ),
                            buildColorChip(
                              label: 'Purple',
                              color: const Color(0xFF7C3AED),
                              hex: '#7C3AED',
                              isSelected: selectedBgColor.toUpperCase() == '#7C3AED',
                              onTap: () => setModalState(() => selectedBgColor = '#7C3AED'),
                            ),
                            buildColorChip(
                              label: 'Emerald',
                              color: const Color(0xFF059669),
                              hex: '#059669',
                              isSelected: selectedBgColor.toUpperCase() == '#059669',
                              onTap: () => setModalState(() => selectedBgColor = '#059669'),
                            ),
                            buildColorChip(
                              label: 'White',
                              color: Colors.white,
                              hex: '#FFFFFF',
                              isSelected: selectedBgColor.toUpperCase() == '#FFFFFF',
                              onTap: () => setModalState(() => selectedBgColor = '#FFFFFF'),
                            ),
                            GestureDetector(
                              onTap: () {
                                FullColorPickerDialog.show(
                                  context,
                                  initialHex: selectedBgColor.isNotEmpty ? selectedBgColor : '#8B0000',
                                  onColorSelected: (newHex) {
                                    setModalState(() {
                                      selectedBgColor = newHex;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.colorize_rounded, size: 14, color: Color(0xFF0284C7)),
                                    SizedBox(width: 4),
                                    Text('Custom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Upload Button (JSON File)
                  OutlinedButton.icon(
                    onPressed: isPickingFile
                        ? null
                        : () async {
                            setModalState(() => isPickingFile = true);
                            try {
                              final pickedStr = await JsonPickerHelper.pickJsonString();
                              if (pickedStr != null && pickedStr.trim().isNotEmpty) {
                                final cleanJson = pickedStr.trim();
                                jsonDecode(cleanJson); // Validate JSON
                                setModalState(() {
                                  currentAnim = cleanJson;
                                  urlController.clear();
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Lottie JSON animation loaded! 🎉'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Invalid JSON format: $e ❌'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              setModalState(() => isPickingFile = false);
                            }
                          },
                    icon: isPickingFile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEC4899)),
                          )
                        : const Icon(Icons.file_upload_outlined, color: Color(0xFFEC4899)),
                    label: Text(
                      isPickingFile ? 'Selecting File...' : 'Upload Lottie JSON File 📂',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEC4899)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // URL / JSON String input
                  TextField(
                    controller: urlController,
                    onChanged: (val) {
                      setModalState(() {
                        currentAnim = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Or Paste Lottie JSON / URL',
                      hintText: 'https://assets.lottiefiles.com/... or raw JSON',
                      prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFFEC4899)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                await AuthService.saveSellerFestivalAnimation(
                                  username,
                                  currentAnim.trim(),
                                  bgColor: selectedBgColor.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        currentAnim.trim().isEmpty
                                            ? '✓ Festival animation removed! 🗑️'
                                            : '✓ Festival animation & background saved! 🎆',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $err ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving Animation...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save to Database 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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

  // --- 13. RELATED ITEMS THEME MASTER DIALOG ---
  void _showManageRelatedItemsThemeDialog() async {
    final username = _sellerUsername;
    String selectedBgColor = AuthService.getCachedSellerRelatedItemBg(username) ?? '#F8FAFC';
    bool isLoaded = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!isLoaded) {
            isLoaded = true;
            Future.microtask(() async {
              final fresh = await AuthService.getSellerRelatedItemBg(username);
              if (ctx.mounted) {
                setModalState(() {
                  selectedBgColor = fresh;
                });
              }
            });
          }

          final Color previewBgColor = hexToColor(selectedBgColor, defaultColor: const Color(0xFFF8FAFC));

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.format_paint_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Related Items Theme 🎨',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Product Detail Page: More Items Color',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info explanation container
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer jab kisi product par click karta hai, toh neeche aane wale "More in [Category]" ke sabhi items ke image box ka background color yahan se customize hoga.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Live Preview Title & Pill
                  Row(
                    children: [
                      const Text(
                        'Live Preview:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: previewBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                        ),
                        child: Text(
                          selectedBgColor.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: previewBgColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Live Preview Box matching customer product sheet
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "More in Snacks" header preview
                        Row(
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 5),
                            const Text(
                              'More in Snacks',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Text(
                              '3 items preview',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 3 preview cards in row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRelatedPreviewItemCard('Namkeen Sev', '₹46 / GM', '📦', previewBgColor),
                            const SizedBox(width: 8),
                            _buildRelatedPreviewItemCard('Instant Noodles', '₹16 / PKT', '📦', previewBgColor),
                            const SizedBox(width: 8),
                            _buildRelatedPreviewItemCard('Popcorn', '₹30 / PKT', '📦', previewBgColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Color Picker Row: Title + Custom Color Button
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Background Color (रंग चुनें):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          FullColorPickerDialog.show(
                            context,
                            initialHex: selectedBgColor,
                            onColorSelected: (newHex) {
                              setModalState(() => selectedBgColor = newHex);
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF6366F1), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.palette_rounded, size: 14, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text('Custom Color', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Preset Color Circles
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        '#FFFFFF', '#F8FAFC', '#DCFCE7', '#FEF3C7', '#E0F2FE', '#FFEDD5', '#FCE7F3', '#F3E8FF', '#CCFBF1', '#ECFCCB', '#F1F5F9',
                        '#10B981', '#0284C7', '#8B5CF6', '#6366F1', '#F97316', '#EC4899', '#EF4444', '#F59E0B', '#06B6D4', '#1E293B',
                      ].map((hex) {
                        final isSel = selectedBgColor.toLowerCase() == hex.toLowerCase();
                        final c = hexToColor(hex);
                        return InkWell(
                          onTap: () => setModalState(() => selectedBgColor = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                width: isSel ? 2.5 : 1,
                              ),
                              boxShadow: isSel ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)] : null,
                            ),
                            child: isSel
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                await AuthService.saveSellerRelatedItemBg(username, selectedBgColor.trim());
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Related items background color updated! 🎨'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save error: $e ❌'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Saving...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : const Text(
                              'Save to Database 🚀',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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

  Widget _buildRelatedPreviewItemCard(String name, String rate, String emoji, Color itemBg) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 0.88,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: itemBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5, color: Color(0xFF0F172A)),
          ),
          Text(
            rate,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 9.5, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text('Buy Now', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageHomeLayoutDialog() async {
    final username = _sellerUsername;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    List<Map<String, dynamic>> catSections = await AuthService.getSellerCategorySections(username);
    List<Map<String, dynamic>> secList = await AuthService.getSellerSections(username);
    List<Map<String, dynamic>> savedLayout = await AuthService.getSellerHomeLayout(username);

    if (mounted) {
      Navigator.pop(context); // close loader
    } else {
      return;
    }

    // Build the default / all available components
    final List<Map<String, dynamic>> discoveredItems = [];

    // 1. Festival Animation
    discoveredItems.add({
      'id': 'festival_animation',
      'type': 'festival_animation',
      'title': 'Festival Animation 🎆',
      'subtitle': 'Lottie animation banner below header',
      'icon': '🎆',
      'is_visible': true,
    });

    // 2. Main Posters / Sliders
    discoveredItems.add({
      'id': 'main_sliders',
      'type': 'main_slider',
      'title': 'Main Sliders / Posters 🖼️',
      'subtitle': 'Top 3D banner carousel',
      'icon': '🖼️',
      'is_visible': true,
    });

    // 3. Category Sections
    for (int i = 0; i < catSections.length; i++) {
      final cs = catSections[i];
      final title = (cs['title'] ?? 'Categories').toString().trim();
      final id = (cs['id'] ?? 'cat_sec_$i').toString().trim();
      final layout = (cs['layout'] ?? '4 cols').toString().trim();
      discoveredItems.add({
        'id': 'cat_sec_$id',
        'type': 'category_section',
        'ref_id': id,
        'title': 'Category Section: $title',
        'subtitle': 'Categories only showcase ($layout)',
        'icon': '🗂️',
        'is_visible': true,
      });
    }

    // 4. Product / Store Sections
    for (var s in secList) {
      final sName = (s['name'] ?? '').toString().trim();
      final sIcon = (s['icon'] ?? '📦').toString().trim();
      final sCols = (s['columns'] ?? 2).toString().trim();
      if (sName.isNotEmpty) {
        discoveredItems.add({
          'id': 'prod_sec_$sName',
          'type': 'product_section',
          'ref_id': sName,
          'title': 'Section: $sName',
          'subtitle': 'Product catalog grid ($sCols columns)',
          'icon': sIcon.isNotEmpty ? sIcon : '📦',
          'is_visible': true,
        });
      }
    }

    // Reconcile with saved layout order
    List<Map<String, dynamic>> orderedList = [];
    if (savedLayout.isNotEmpty) {
      final Set<String> matchedIds = {};
      for (var savedItem in savedLayout) {
        final sId = (savedItem['id'] ?? '').toString().trim();
        final match = discoveredItems.firstWhere(
          (d) => d['id'] == sId,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          matchedIds.add(sId);
          orderedList.add({
            ...match,
            'is_visible': savedItem['is_visible'] ?? true,
            'is_child': savedItem['is_child'] == true,
            'child_overlap': savedItem['child_overlap'] == true,
          });
        }
      }
      // Add any newly discovered items that weren't in saved layout
      for (var d in discoveredItems) {
        if (!matchedIds.contains(d['id'])) {
          orderedList.add({
            ...d,
            'is_child': false,
            'child_overlap': false,
          });
        }
      }
    } else {
      orderedList = discoveredItems.map((d) => {...d, 'is_child': false, 'child_overlap': false}).toList();
    }

    if (orderedList.isNotEmpty) {
      orderedList[0]['is_child'] = false;
      orderedList[0]['child_overlap'] = false;
    }

    if (!mounted) return;

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {

          void moveItem(int oldIndex, int newIndex) {
            setModalState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = orderedList.removeAt(oldIndex);
              orderedList.insert(newIndex, item);
              if (orderedList.isNotEmpty) {
                orderedList[0]['is_child'] = false;
              }
            });
          }

          void moveUp(int index) {
            if (index > 0) {
              setModalState(() {
                final item = orderedList.removeAt(index);
                orderedList.insert(index - 1, item);
                if (orderedList.isNotEmpty) {
                  orderedList[0]['is_child'] = false;
                }
              });
            }
          }

          void moveDown(int index) {
            if (index < orderedList.length - 1) {
              setModalState(() {
                final item = orderedList.removeAt(index);
                orderedList.insert(index + 1, item);
                if (orderedList.isNotEmpty) {
                  orderedList[0]['is_child'] = false;
                }
              });
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Modal Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF0D9488), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Home Page Listing Order 📑',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Drag ya Up/Down se order karein. "Child ↳" se content upar wale se chipak jayega',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Informational Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, color: Color(0xFF0D9488), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '💡 Tip: Kisi section ko upar wale ka "Child ↳" banane ke liye right slide karein ya "Attach / Child ↳" dabayein. Child content ka gap khatam ho kar thoda hissa upar wale ke andar overlap ho jayega.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF134E4A), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reorderable List
                Expanded(
                  child: orderedList.isEmpty
                      ? const Center(
                          child: Text(
                            'No home page sections found.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: orderedList.length,
                          onReorder: moveItem,
                          itemBuilder: (context, idx) {
                            final item = orderedList[idx];
                            final String iId = (item['id'] ?? '').toString();
                            final String iTitle = (item['title'] ?? '').toString();
                            final String iSub = (item['subtitle'] ?? '').toString();
                            final String iIcon = (item['icon'] ?? '📦').toString();
                            final String iType = (item['type'] ?? '').toString();
                            final bool isVis = (item['is_visible'] != false);
                            final bool isChild = (idx > 0 && item['is_child'] == true);

                            Color badgeColor = const Color(0xFF64748B);
                            String typeLabel = 'Section';
                            if (iType == 'festival_animation') {
                              badgeColor = const Color(0xFFEC4899);
                              typeLabel = 'Animation';
                            } else if (iType == 'main_slider') {
                              badgeColor = const Color(0xFF3B82F6);
                              typeLabel = 'Banner Poster';
                            } else if (iType == 'category_section') {
                              badgeColor = const Color(0xFF8B5CF6);
                              typeLabel = 'Categories';
                            } else if (iType == 'product_section') {
                              badgeColor = const Color(0xFF10B981);
                              typeLabel = 'Products';
                            }

                            return GestureDetector(
                              key: ValueKey(iId),
                              onHorizontalDragEnd: (details) {
                                if (idx > 0 && details.primaryVelocity != null) {
                                  if (details.primaryVelocity! > 150) {
                                    // Slide right -> become Child
                                    setModalState(() {
                                      item['is_child'] = true;
                                    });
                                  } else if (details.primaryVelocity! < -150) {
                                    // Slide left -> unmark Child
                                    setModalState(() {
                                      item['is_child'] = false;
                                    });
                                  }
                                }
                              },
                              child: Container(
                                margin: EdgeInsets.only(
                                  left: isChild ? 16.0 : 0.0,
                                  bottom: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isChild
                                      ? const Color(0xFFF0FDFA)
                                      : (isVis ? Colors.white : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isChild
                                        ? const Color(0xFF0D9488)
                                        : (isVis ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                                    width: isChild ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isChild
                                          ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.03),
                                      blurRadius: isChild ? 6 : 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isChild)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCCFBF1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF99F6E4)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF0F766E)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '↳ Child of #$idx: ${orderedList[idx - 1]['title'] ?? 'Parent'}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F766E),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        item['is_child'] = false;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                                                      ),
                                                      child: const Text(
                                                        'Detach ✕',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F766E),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // Option 1: Bottom me (Zero Gap)
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          item['child_overlap'] = false;
                                                        });
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: (item['child_overlap'] != true) ? const Color(0xFF0D9488) : Colors.white,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(
                                                            color: (item['child_overlap'] != true) ? const Color(0xFF0D9488) : const Color(0xFF99F6E4),
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '🔗 Bottom me (Zero Gap)',
                                                            style: TextStyle(
                                                              fontSize: 8.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: (item['child_overlap'] != true) ? Colors.white : const Color(0xFF0F766E),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  // Option 2: Bottom ke Top pr (Overlap)
                                                  Expanded(
                                                    child: InkWell(
                                                      onTap: () {
                                                        setModalState(() {
                                                          item['child_overlap'] = true;
                                                        });
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: (item['child_overlap'] == true) ? const Color(0xFF0D9488) : Colors.white,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(
                                                            color: (item['child_overlap'] == true) ? const Color(0xFF0D9488) : const Color(0xFF99F6E4),
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            '📐 Bottom ke Top pr (Overlap)',
                                                            style: TextStyle(
                                                              fontSize: 8.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: (item['child_overlap'] == true) ? Colors.white : const Color(0xFF0F766E),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          // Rank Number Badge
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isChild
                                                  ? const Color(0xFF0D9488)
                                                  : const Color(0xFF0D9488).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '#${idx + 1}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isChild ? Colors.white : const Color(0xFF0D9488),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // Icon Box
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isChild ? const Color(0xFFE6FFFA) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(7),
                                            ),
                                            child: Center(
                                              child: Text(iIcon, style: const TextStyle(fontSize: 16)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // Title, Subtitle, & Child Attach Chip
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        iTitle,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12.5,
                                                          color: isVis ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: badgeColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        typeLabel,
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                          color: badgeColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  iSub,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: isVis ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (idx > 0 && !isChild) ...[
                                                  const SizedBox(height: 3),
                                                  InkWell(
                                                    onTap: () {
                                                      setModalState(() {
                                                        item['is_child'] = true;
                                                      });
                                                    },
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.link_rounded, size: 11, color: Color(0xFF475569)),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            '+ Attach as Child ↳',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFF475569),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // Visibility Toggle
                                          InkWell(
                                            onTap: () {
                                              setModalState(() {
                                                item['is_visible'] = !isVis;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.all(4),
                                              child: Icon(
                                                isVis ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                                size: 17,
                                                color: isVis ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),

                                          // Up Button
                                          InkWell(
                                            onTap: idx > 0 ? () => moveUp(idx) : null,
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: Icon(
                                                Icons.arrow_upward_rounded,
                                                size: 17,
                                                color: idx > 0 ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),

                                          // Down Button
                                          InkWell(
                                            onTap: idx < orderedList.length - 1 ? () => moveDown(idx) : null,
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: Icon(
                                                Icons.arrow_downward_rounded,
                                                size: 17,
                                                color: idx < orderedList.length - 1 ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),

                                          // Drag Indicator
                                          ReorderableDragStartListener(
                                            index: idx,
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 2),
                                              child: Icon(Icons.drag_indicator_rounded, color: Color(0xFF94A3B8), size: 19),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Save Button Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      // Reset button
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            orderedList = discoveredItems.map((d) => {...d, 'is_child': false}).toList();
                          });
                        },
                        child: const Text('Reset ↺', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),

                      // Save Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setModalState(() => isSaving = true);
                                  try {
                                    if (orderedList.isNotEmpty) {
                                      orderedList[0]['is_child'] = false;
                                    }
                                    await AuthService.saveSellerHomeLayout(username, orderedList);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✓ Home Page listing order saved successfully! 🎉'),
                                          backgroundColor: Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Save error: $e ❌'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Hierarchy Order 🚀',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    title: 'Category Section 🗂️',
                    subtitle: 'Show categories only',
                    icon: Icons.dashboard_customize_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: _showManageCategorySectionsDialog,
                  ),
                  _buildMasterCard(
                    title: 'Page Listing 📑',
                    subtitle: 'Home content hierarchy',
                    icon: Icons.format_list_numbered_rounded,
                    color: const Color(0xFF0D9488),
                    onTap: _showManageHomeLayoutDialog,
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
                  _buildMasterCard(
                    title: 'Welcome Popup 🎁',
                    subtitle: 'New customer popup',
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFFF97316),
                    onTap: _showManageWelcomePopupDialog,
                  ),
                  _buildMasterCard(
                    title: 'Header Text 📢',
                    subtitle: 'Set 2 custom texts',
                    icon: Icons.title_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: _showManageHeaderTextDialog,
                  ),
                  _buildMasterCard(
                    title: 'Festival Animation 🎆',
                    subtitle: 'Upload festival Lottie',
                    icon: Icons.celebration_rounded,
                    color: const Color(0xFFEC4899),
                    onTap: _showManageFestivalAnimationDialog,
                  ),
                  _buildMasterCard(
                    title: 'Related Items 🎨',
                    subtitle: 'Product page items color',
                    icon: Icons.format_paint_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: _showManageRelatedItemsThemeDialog,
                  ),
                  _buildMasterCard(
                    title: 'Action Buttons 🔘',
                    subtitle: 'Top & View More style',
                    icon: Icons.smart_button_rounded,
                    color: const Color(0xFF2563EB),
                    onTap: _showManageActionButtonsDialog,
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
