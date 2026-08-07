import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

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
  String _searchQuery = '';

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

    if (mounted) {
      setState(() {
        _allProducts = products;
        _sellerUnits = units;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = List.from(_allProducts);
      });
    } else {
      setState(() {
        _filteredProducts = _allProducts.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final desc = (p['description'] ?? '').toString().toLowerCase();
          final unit = (p['unit'] ?? '').toString().toLowerCase();
          return name.contains(query) || desc.contains(query) || unit.contains(query);
        }).toList();
      });
    }
  }

  /// Open Manage Custom Units Dialog
  void _showManageUnitsDialog() {
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
                              'Create, edit or delete custom measurement units',
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
                            hintText: 'e.g. 100 Gram, 250g, 1 Kg, 1 L, 1 Pcs',
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
                  const Text('Your Store Units List:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: _sellerUnits.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No custom units added yet.', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _sellerUnits.length,
                            itemBuilder: (context, idx) {
                              final uMap = _sellerUnits[idx];
                              final uId = (uMap['id'] as num?)?.toInt() ?? 0;
                              final uName = (uMap['unit_name'] ?? '').toString();

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
    final nameController = TextEditingController(text: isEditing ? (productToEdit['name'] ?? '') : '');
    final descController = TextEditingController(text: isEditing ? (productToEdit['description'] ?? '') : '');
    final qtyController = TextEditingController(
      text: isEditing ? ((productToEdit['qty'] ?? 1).toString()) : '1',
    );
    final rateController = TextEditingController(
      text: isEditing ? ((productToEdit['rate'] ?? 0.0).toString()) : '',
    );

    final availableUnitNames = _sellerUnits.map((u) => (u['unit_name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
    if (availableUnitNames.isEmpty) {
      availableUnitNames.addAll(AuthService.defaultUnits);
    }

    String selectedUnit = isEditing
        ? (productToEdit['unit'] ?? availableUnitNames.first)
        : (availableUnitNames.isNotEmpty ? availableUnitNames.first : '1 Kg');

    if (!availableUnitNames.contains(selectedUnit)) {
      availableUnitNames.insert(0, selectedUnit);
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

                  // Unit Selection Header + Shortcut "+ Add Unit" Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Unit / Measurement *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showManageUnitsDialog();
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8B5CF6), size: 16),
                            SizedBox(width: 4),
                            Text('+ Manage Units', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
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

                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);

                      final username = widget.seller.username ?? '';
                      if (isEditing) {
                        final pId = (productToEdit['id'] as num?)?.toInt() ?? 0;
                        await AuthService.updateSellerProduct(
                          id: pId,
                          sellerUsername: username,
                          name: pName,
                          description: pDesc,
                          unit: selectedUnit,
                          qty: pQty,
                          rate: pRate,
                        );
                      } else {
                        await AuthService.addSellerProduct(
                          sellerUsername: username,
                          name: pName,
                          description: pDesc,
                          unit: selectedUnit,
                          qty: pQty,
                          rate: pRate,
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
    final pId = (product['id'] as num?)?.toInt() ?? 0;
    final pName = product['name'] ?? 'Product';

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
            icon: const Icon(Icons.straighten_rounded, color: Colors.white),
            tooltip: 'Manage Units',
            onPressed: _showManageUnitsDialog,
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
                    Text(
                      '${_filteredProducts.length} Products | ${_sellerUnits.length} Units',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _showManageUnitsDialog,
                      child: const Text(
                        '🏷️ Manage Units',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ],
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, idx) {
                          final p = _filteredProducts[idx];
                          final name = p['name'] ?? '';
                          final desc = p['description'] ?? '';
                          final unit = p['unit'] ?? 'Pcs';
                          final qty = (p['qty'] ?? 1) is num ? (p['qty'] as num).toInt() : 1;
                          final rate = (p['rate'] ?? 0.0) is num ? (p['rate'] as num).toDouble() : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEDE9FE),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                qty > 1 ? '$unit (x$qty)' : unit,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF6D28D9),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '₹${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 20),
                                        onPressed: () => _showAddEditProductDialog(productToEdit: p),
                                        tooltip: 'Edit Product',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                        onPressed: () => _confirmDeleteProduct(p),
                                        tooltip: 'Delete Product',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
