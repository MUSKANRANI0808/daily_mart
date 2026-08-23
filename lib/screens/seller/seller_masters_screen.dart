import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/color_picker_dialog.dart';
import '../../utils/csv_exporter.dart';
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

    // 1. INSTANT LOCAL CACHE DISPLAY (0.01 Seconds)
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

    // 2. BACKGROUND VPS REFRESH
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

  // --- MASTER DIALOGS ---

  void _showManageCategoriesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;
          final cats = _sellerCategories;

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
                    const Row(
                      children: [
                        Icon(Icons.category_rounded, color: Color(0xFF0284C7), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Category Master 📁',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final nameCtrl = TextEditingController();
                      String colorHex = '#8B5CF6';

                      await showDialog(
                        context: context,
                        builder: (dCtx) => StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Category Name',
                                      hintText: 'e.g. Grocery, Dairy, Spices',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Text('Badge Color: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          FullColorPickerDialog.show(
                                            context,
                                            initialHex: colorHex,
                                            onColorSelected: (newHex) {
                                              setDialogState(() {
                                                colorHex = newHex;
                                              });
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: hexToColor(colorHex, defaultColor: const Color(0xFF8B5CF6)),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.grey.shade400),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final catName = nameCtrl.text.trim();
                                    if (catName.isNotEmpty) {
                                      await AuthService.addSellerCategory(username, catName, '', color: colorHex);
                                      if (dCtx.mounted) Navigator.pop(dCtx);
                                      await _loadData();
                                      setModalState(() {});
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                                  child: const Text('Save Category', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: cats.isEmpty
                      ? const Center(child: Text('No categories added yet', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (cCtx, idx) {
                            final cat = cats[idx];
                            final catId = int.tryParse(cat['id']?.toString() ?? '0') ?? 0;
                            final catName = cat['name'] ?? '';
                            final colorHex = cat['color'] ?? '#8B5CF6';

                            return ListTile(
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: hexToColor(colorHex, defaultColor: const Color(0xFF8B5CF6)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                onPressed: () async {
                                  if (catId > 0) {
                                    await AuthService.deleteSellerCategory(catId, username, catName);
                                    await _loadData();
                                    setModalState(() {});
                                  }
                                },
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

  void _showManageSectionsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;
          final secs = _sellerSections;

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
                    const Row(
                      children: [
                        Icon(Icons.view_carousel_rounded, color: Color(0xFF8B5CF6), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Section Master 🏷️',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final nameCtrl = TextEditingController();
                      String colorHex = '#EC4899';

                      await showDialog(
                        context: context,
                        builder: (dCtx) => StatefulBuilder(
                          builder: (context, setDialogState) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Add Store Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Section Title',
                                      hintText: 'e.g. Daily Use, Trending, Popular',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Text('Ribbon Color: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          FullColorPickerDialog.show(
                                            context,
                                            initialHex: colorHex,
                                            onColorSelected: (newHex) {
                                              setDialogState(() {
                                                colorHex = newHex;
                                              });
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: hexToColor(colorHex, defaultColor: const Color(0xFFEC4899)),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.grey.shade400),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final secName = nameCtrl.text.trim();
                                    if (secName.isNotEmpty) {
                                      await AuthService.addSellerSection(username, secName, '🏷️', '#FFFFFF', colorHex);
                                      if (dCtx.mounted) Navigator.pop(dCtx);
                                      await _loadData();
                                      setModalState(() {});
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                                  child: const Text('Save Section', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Add Store Section', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: secs.isEmpty
                      ? const Center(child: Text('No store sections added yet', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: secs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (sCtx, idx) {
                            final sec = secs[idx];
                            final secId = int.tryParse(sec['id']?.toString() ?? '0') ?? 0;
                            final secName = sec['name'] ?? '';
                            final textColor = sec['text_color'] ?? '#EC4899';

                            return ListTile(
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: hexToColor(textColor, defaultColor: const Color(0xFFEC4899)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              title: Text(secName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                onPressed: () async {
                                  if (secId > 0) {
                                    await AuthService.deleteSellerSection(secId, username, secName);
                                    await _loadData();
                                    setModalState(() {});
                                  }
                                },
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

  void _showManageUnitsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final username = _sellerUsername;
          final units = _sellerUnits;

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
                    const Row(
                      children: [
                        Icon(Icons.straighten_rounded, color: Color(0xFF10B981), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Unit Master 📏',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final nameCtrl = TextEditingController();
                      await showDialog(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Add Measurement Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          content: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unit Name',
                              hintText: 'e.g. Kg, Pcs, Ltr, Pkt, Box',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                final unitName = nameCtrl.text.trim();
                                if (unitName.isNotEmpty) {
                                  await AuthService.addSellerUnit(username, unitName);
                                  if (dCtx.mounted) Navigator.pop(dCtx);
                                  await _loadData();
                                  setModalState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              child: const Text('Save Unit', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text('Add New Unit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: units.isEmpty
                      ? const Center(child: Text('No custom units added yet', style: TextStyle(color: Color(0xFF94A3B8))))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: units.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (uCtx, idx) {
                            final u = units[idx];
                            final uId = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
                            final uName = u['name'] ?? '';

                            return ListTile(
                              title: Text(uName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                onPressed: () async {
                                  if (uId > 0) {
                                    await AuthService.deleteSellerUnit(uId, username, uName);
                                    await _loadData();
                                    setModalState(() {});
                                  }
                                },
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

  void _showManageSearchBarDialog() {
    int currentLimit = 5;
    Color animColor = const Color(0xFF10B981);
    double animHeight = 4.0;

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
                    const Row(
                      children: [
                        Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Search Bar Style 🔍',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Visible Categories in Bar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                Row(
                  children: [5, 4, 3].map((num) {
                    final isSel = currentLimit == num;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10, top: 6),
                      child: ChoiceChip(
                        label: Text('$num Categories'),
                        selected: isSel,
                        selectedColor: const Color(0xFF8B5CF6),
                        labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                        onSelected: (_) => setModalState(() => currentLimit = num),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Apply Changes 🎨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
                        trailing: Text(
                          '₹${p['rate']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                        ),
                      );
                    },
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
            // Top Master Header Banner
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

            // Master Cards Grid (2-Columns Layout matching image 2)
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
                    title: 'Add New Product 📦',
                    subtitle: 'Create single item',
                    icon: Icons.add_box_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: _showAddEditProductDialog,
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
