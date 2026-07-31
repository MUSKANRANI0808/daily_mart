import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class CustomerAddressesScreen extends StatefulWidget {
  final UserModel customer;
  const CustomerAddressesScreen({super.key, required this.customer});

  @override
  State<CustomerAddressesScreen> createState() => _CustomerAddressesScreenState();
}

class _CustomerAddressesScreenState extends State<CustomerAddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  String get _prefsKey => 'customer_addresses_${widget.customer.mobile}';

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr);
        final loaded = List<Map<String, dynamic>>.from(list);

        // Sanitize: GUARANTEE strictly ONLY 1 address is default!
        bool foundDefault = false;
        for (var addr in loaded) {
          if (addr['isDefault'] == true) {
            if (foundDefault) {
              addr['isDefault'] = false;
            } else {
              foundDefault = true;
            }
          }
        }
        if (!foundDefault && loaded.isNotEmpty) {
          loaded.first['isDefault'] = true;
        }

        setState(() {
          _addresses = loaded;
          _isLoading = false;
        });
        await _saveAddressesToPrefs();
        return;
      } catch (e) {
        debugPrint('Error parsing addresses: $e');
      }
    }
    setState(() {
      _addresses = [];
      _isLoading = false;
    });
  }

  Future<void> _saveAddressesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_addresses));
  }

  void _openAddEditDialog([Map<String, dynamic>? existingAddress]) {
    final isEditing = existingAddress != null;
    final formKey = GlobalKey<FormState>();

    String tag = existingAddress?['tag'] ?? 'Home';
    final houseController = TextEditingController(text: existingAddress?['houseNo'] ?? '');
    final buildingController = TextEditingController(text: existingAddress?['building'] ?? '');
    final localityController = TextEditingController(text: existingAddress?['locality'] ?? '');
    final landmarkController = TextEditingController(text: existingAddress?['landmark'] ?? '');
    final cityController = TextEditingController(text: existingAddress?['city'] ?? '');
    final pincodeController = TextEditingController(text: existingAddress?['pincode'] ?? '');
    final receiverController = TextEditingController(text: existingAddress?['receiverName'] ?? (widget.customer.name ?? ''));
    final phoneController = TextEditingController(text: existingAddress?['mobile'] ?? (widget.customer.mobile ?? ''));
    bool isDefault = existingAddress?['isDefault'] ?? (_addresses.isEmpty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Delivery Address ✏️' : 'Add New Delivery Address 📍',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Address Tag Selector
                  const Text('Save Address As:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((t) {
                      final isSelected = tag == t;
                      IconData iconData = Icons.home_rounded;
                      if (t == 'Work') iconData = Icons.work_rounded;
                      if (t == 'Other') iconData = Icons.location_on_rounded;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: ChoiceChip(
                          avatar: Icon(iconData, size: 16, color: isSelected ? Colors.white : const Color(0xFF10B981)),
                          label: Text(t, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setModalState(() => tag = t);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // House / Flat / Floor
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House No. / Floor *',
                      prefixIcon: const Icon(Icons.other_houses_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter House/Flat No.' : null,
                  ),
                  const SizedBox(height: 12),

                  // Building / Apartment
                  TextFormField(
                    controller: buildingController,
                    decoration: InputDecoration(
                      labelText: 'Building / Apartment Name',
                      prefixIcon: const Icon(Icons.apartment_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Street / Locality
                  TextFormField(
                    controller: localityController,
                    decoration: InputDecoration(
                      labelText: 'Street / Area / Locality *',
                      prefixIcon: const Icon(Icons.add_road_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter Street or Locality' : null,
                  ),
                  const SizedBox(height: 12),

                  // Landmark / Near
                  TextFormField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Landmark / Near (e.g. Near Shiv Mandir, School)',
                      hintText: 'e.g. Near Temple / School',
                      prefixIcon: const Icon(Icons.near_me_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row: City & Pincode
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityController,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter City' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: pincodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: 'Pincode *',
                            counterText: '',
                            prefixIcon: const Icon(Icons.pin_drop_rounded, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().length < 6) ? '6 digits' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Landmark
                  TextFormField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: 'Nearby Landmark (Optional)',
                      prefixIcon: const Icon(Icons.flag_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Receiver Name & Phone
                  TextFormField(
                    controller: receiverController,
                    decoration: InputDecoration(
                      labelText: 'Receiver Name *',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Name' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      labelText: 'Contact Phone Number *',
                      counterText: '',
                      prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().length < 10) ? '10 digits' : null,
                  ),
                  const SizedBox(height: 12),

                  // Set Default Checkbox
                  CheckboxListTile(
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Make this my default delivery address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isDefault,
                    onChanged: (val) {
                      setModalState(() => isDefault = val ?? false);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newAddr = {
                          'id': existingAddress?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          'tag': tag,
                          'houseNo': houseController.text.trim(),
                          'building': buildingController.text.trim(),
                          'locality': localityController.text.trim(),
                          'landmark': landmarkController.text.trim(),
                          'city': cityController.text.trim(),
                          'pincode': pincodeController.text.trim(),
                          'receiverName': receiverController.text.trim(),
                          'mobile': phoneController.text.trim(),
                          'isDefault': isDefault,
                        };

                        setState(() {
                          if (isDefault) {
                            for (var a in _addresses) {
                              a['isDefault'] = false;
                            }
                          }
                          if (isEditing) {
                            final idx = _addresses.indexWhere((a) => a['id'] == existingAddress['id']);
                            if (idx != -1) _addresses[idx] = newAddr;
                          } else {
                            _addresses.insert(0, newAddr);
                          }
                        });

                        await _saveAddressesToPrefs();
                        if (context.mounted) Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Address updated successfully! 📍' : 'Address saved successfully! 📍'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    child: Text(
                      isEditing ? 'Update Address' : 'Save Delivery Address',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteAddress(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address?'),
        content: const Text('Are you sure you want to remove this delivery address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _addresses.removeWhere((a) => a['id'] == id);
      });
      await _saveAddressesToPrefs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address deleted'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _setDefaultAddress(String id) async {
    setState(() {
      for (var a in _addresses) {
        a['isDefault'] = (a['id'] == id);
      }
    });
    await _saveAddressesToPrefs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default address updated! ⭐'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Saved Delivery Addresses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _addresses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_off_rounded, size: 60, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No Saved Addresses Yet',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your home, office or delivery address to quickly place daily orders.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
                          label: const Text('Add Delivery Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () => _openAddEditDialog(),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _addresses.length,
                  itemBuilder: (ctx, idx) {
                    final addr = _addresses[idx];
                    final tag = addr['tag'] ?? 'Home';
                    final houseNo = addr['houseNo'] ?? '';
                    final building = addr['building'] ?? '';
                    final locality = addr['locality'] ?? '';
                    final landmark = addr['landmark'] ?? '';
                    final city = addr['city'] ?? '';
                    final pincode = addr['pincode'] ?? '';
                    final receiver = addr['receiverName'] ?? '';
                    final phone = addr['mobile'] ?? '';
                    final isDefault = addr['isDefault'] == true;

                    IconData tagIcon = Icons.home_rounded;
                    if (tag == 'Work') tagIcon = Icons.work_rounded;
                    if (tag == 'Other') tagIcon = Icons.location_on_rounded;

                    final fullAddress = [
                      if (houseNo.isNotEmpty) houseNo,
                      if (building.isNotEmpty) building,
                      if (locality.isNotEmpty) locality,
                      if (landmark.isNotEmpty) 'Near $landmark',
                      if (city.isNotEmpty) city,
                      if (pincode.isNotEmpty) 'PIN: $pincode',
                    ].join(', ');

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDefault ? const BorderSide(color: Color(0xFF10B981), width: 1.8) : BorderSide.none,
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tag Badge Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(tagIcon, size: 16, color: const Color(0xFF15803D)),
                                      const SizedBox(width: 6),
                                      Text(
                                        tag.toUpperCase(),
                                        style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF9C3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFDE047)),
                                    ),
                                    child: const Text(
                                      'DEFAULT ADDRESS ⭐',
                                      style: TextStyle(color: Color(0xFFA16207), fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Receiver Name
                            Text(
                              receiver,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),

                            // Full Address String
                            Text(
                              fullAddress,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
                            ),
                            const SizedBox(height: 6),

                            // Contact Mobile
                            Row(
                              children: [
                                const Icon(Icons.phone_rounded, size: 14, color: Colors.black45),
                                const SizedBox(width: 4),
                                Text(
                                  '+91 $phone',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            // Action Buttons: Edit, Delete, Set Default
                            Row(
                              children: [
                                if (!isDefault)
                                  TextButton.icon(
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                    label: const Text('Set Default', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () => _setDefaultAddress(addr['id']),
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 20),
                                  onPressed: () => _openAddEditDialog(addr),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                  onPressed: () => _deleteAddress(addr['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text('Add Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openAddEditDialog(),
      ),
    );
  }
}
