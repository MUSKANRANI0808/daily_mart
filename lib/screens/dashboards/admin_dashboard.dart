import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/header_theme_helper.dart';
import '../customer/seller_orders_screen.dart';
import '../role_selection_screen.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class AdminDashboard extends StatefulWidget {
  final UserModel user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // 0: Sellers, 1: Delivery Boys, 2: Order Details
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _deliveryBoys = [];
  List<Map<String, dynamic>> _flatOrdersList = [];
  bool _isLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;
  int _selectedDelayMinutes = 0; // 0 = All Times, 15, 30, 45, 60, 120
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Pickup', 'Delivered', 'Cancelled'
  String _tableSearchQuery = '';
  final TextEditingController _tableSearchController = TextEditingController();

  final ScrollController _horizontalScrollController = ScrollController();
  double _dragStartX = 0.0;

  Timer? _pollingTimer;
  final Set<String> _knownOrderIds = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year, today.month, today.day);
    _loadAllData();
    _startAdminOrderPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _horizontalScrollController.dispose();
    _tableSearchController.dispose();
    super.dispose();
  }

  void _startAdminOrderPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final freshOrders = await AuthService.getAllOrdersFlatListForAdmin();
      if (!mounted) return;

      bool hasNewOrder = false;
      for (var ord in freshOrders) {
        final orderId = (ord['order_no'] ?? '').toString();
        if (orderId.isNotEmpty && !_knownOrderIds.contains(orderId)) {
          _knownOrderIds.add(orderId);
          if (!_isFirstLoad) {
            hasNewOrder = true;
            // Popup Push Notification ONLY for NEW Customer Orders!
            NotificationService.showSystemNotification(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: '🛍️ New Order Placed!',
              body: 'Customer ${ord['customer_name']} placed ${ord['order_no']} for ${ord['seller_name']}. Amount: ₹${ord['amount']}',
              payload: 'admin_new_order',
            );
          }
        }
      }

      if (_isFirstLoad) {
        _isFirstLoad = false;
      }

      if (hasNewOrder && mounted) {
        setState(() {
          _flatOrdersList = freshOrders;
        });
      }
    });
  }

  Future<void> _loadAllData() async {
    // 1. Load instantly from SharedPreferences Local Cache (0 ms perceived latency)
    final cachedSellers = await AuthService.getCachedSellersList();
    final cachedDeliveryBoys = await AuthService.getCachedDeliveryBoys();
    final cachedFlatOrders = await AuthService.getCachedAllOrdersFlatListForAdmin();

    if ((cachedSellers.isNotEmpty || cachedDeliveryBoys.isNotEmpty || cachedFlatOrders.isNotEmpty) && mounted) {
      setState(() {
        _sellers = cachedSellers;
        _deliveryBoys = cachedDeliveryBoys;
        _flatOrdersList = cachedFlatOrders;
        _isLoading = false;
      });
    }

    // 2. Refresh from VPS Server Database in background
    final sellers = await AuthService.getSellersList();
    final deliveryBoys = await AuthService.getDeliveryBoys();
    final flatOrders = await AuthService.getAllOrdersFlatListForAdmin();

    if (mounted) {
      setState(() {
        _sellers = sellers;
        _deliveryBoys = deliveryBoys;
        _flatOrdersList = flatOrders;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _flatOrdersList.where((ord) {
      // 1. Date Range Filter
      final DateTime dt = ord['raw_date'] ?? DateTime.now();
      if (_startDate != null) {
        final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        if (dt.isBefore(startOfDay)) return false;
      }
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (dt.isAfter(endOfDay)) return false;
      }

      // 2. Order Status Dropdown Filter
      if (_selectedStatusFilter != 'All') {
        final ordStatus = (ord['order_status'] ?? '').toString().toLowerCase();
        final filterLower = _selectedStatusFilter.toLowerCase();
        if (ordStatus != filterLower) return false;
      }

      // 3. Clock Delay Time Filter (pickup to delivered duration > X minutes)
      if (_selectedDelayMinutes > 0) {
        final DateTime? pDt = ord['raw_pickup_time'];
        final DateTime? dDt = ord['raw_delivered_time'];
        if (pDt == null || dDt == null) return false;

        final int diffMins = dDt.difference(pDt).inMinutes;
        if (diffMins <= _selectedDelayMinutes) return false;
      }

      // 4. Global Search Query Filter (Live Row Filtering)
      if (_tableSearchQuery.isNotEmpty) {
        final q = _tableSearchQuery;
        final orderNo = (ord['order_no'] ?? '').toString().toLowerCase();
        final custName = (ord['customer_name'] ?? '').toString().toLowerCase();
        final sellerName = (ord['seller_name'] ?? '').toString().toLowerCase();
        final sellerLoc = (ord['seller_location'] ?? '').toString().toLowerCase();
        final delBoy = (ord['delivery_boy'] ?? '').toString().toLowerCase();
        final status = (ord['order_status'] ?? '').toString().toLowerCase();
        final payMode = (ord['payment_mode'] ?? '').toString().toLowerCase();
        final payStatus = (ord['payment_status'] ?? '').toString().toLowerCase();
        final amount = (ord['amount'] ?? '').toString().toLowerCase();
        final sendTime = (ord['order_send_time'] ?? '').toString().toLowerCase();
        final date = (ord['date'] ?? '').toString().toLowerCase();

        final matches = orderNo.contains(q) ||
            custName.contains(q) ||
            sellerName.contains(q) ||
            sellerLoc.contains(q) ||
            delBoy.contains(q) ||
            status.contains(q) ||
            payMode.contains(q) ||
            payStatus.contains(q) ||
            amount.contains(q) ||
            sendTime.contains(q) ||
            date.contains(q);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  Future<String?> _showAddNewLocationDialog() async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.add_location_alt_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Add New Location', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Color(0xFF0F172A)),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter Location Name (e.g. Sector 5)',
            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF10B981))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final locName = textController.text.trim();
              if (locName.isNotEmpty) {
                await AuthService.addLocation(locName);
                if (ctx.mounted) Navigator.pop(ctx, locName);
              }
            },
            child: const Text('Add Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManageHeaderThemeDialog() async {
    final currentConfig = await AuthService.getHeaderThemeConfig();
    String selectedPreset = currentConfig['preset_id'] ?? 'midnight_navy';
    String color1Hex = currentConfig['color1'] ?? '#0F172A';
    String color2Hex = currentConfig['color2'] ?? '#1E1B4B';
    String color3Hex = currentConfig['color3'] ?? '#312E81';
    String selectedDirection = currentConfig['direction'] ?? 'diagonal';
    String selectedShading = currentConfig['shading'] ?? 'dark';
    bool enableShining = currentConfig['enable_shining'] ?? true;
    double particleOpacity = (currentConfig['particle_opacity'] as num?)?.toDouble() ?? 0.9;

    bool isFestivalActive = currentConfig['is_festival_active'] ?? false;
    String festivalTitle = currentConfig['festival_title'] ?? 'FREEDOM SALE 🇮🇳';
    String lottieUrl = currentConfig['lottie_url'] ?? 'https://assets3.lottiefiles.com/packages/lf20_u4jjb9bd.json';
    double lottieOpacity = (currentConfig['lottie_opacity'] as num?)?.toDouble() ?? 0.75;

    final c1Controller = TextEditingController(text: color1Hex);
    final c2Controller = TextEditingController(text: color2Hex);
    final c3Controller = TextEditingController(text: color3Hex);
    final festivalTitleCtrl = TextEditingController(text: festivalTitle);
    final lottieUrlCtrl = TextEditingController(text: lottieUrl);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final liveConfig = {
            'preset_id': selectedPreset,
            'color1': c1Controller.text.trim(),
            'color2': c2Controller.text.trim(),
            'color3': c3Controller.text.trim(),
            'direction': selectedDirection,
            'shading': selectedShading,
            'enable_shining': enableShining,
            'particle_opacity': particleOpacity,
            'is_festival_active': isFestivalActive,
            'festival_title': festivalTitleCtrl.text.trim(),
            'lottie_url': lottieUrlCtrl.text.trim(),
            'lottie_opacity': lottieOpacity,
          };

          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Header Theme & Colors Manager 🎨',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customize the animated top header banner colors, gradient direction, intensity shading, and shining glass shimmer beam across the app.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // LIVE ANIMATED HEADER PREVIEW CARD
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipPath(
                      clipper: HeaderArcWaveClipper(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: HeaderThemeHelper.buildDecoration(liveConfig),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: GroceryFloatingBackgroundParticles(
                                particleOpacity: particleOpacity,
                              ),
                            ),
                            if (isFestivalActive && lottieUrlCtrl.text.isNotEmpty)
                              Positioned.fill(
                                child: FestivalLottieHeaderWidget(config: liveConfig),
                              ),
                            if (enableShining)
                              const Positioned.fill(
                                child: ContinuousShiningGlassBeamWidget(),
                              ),
                            Positioned(
                              top: 15,
                              left: 15,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Live Theme Preview 🏪',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (isFestivalActive && festivalTitleCtrl.text.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            festivalTitleCtrl.text,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Daily Mart Animated Header Canvas',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. PRESET THEMES SELECTOR
                  const Text(
                    'Choose Preset Theme:',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HeaderThemeHelper.presets.map((preset) {
                      final isSelected = selectedPreset == preset['id'];
                      return ChoiceChip(
                        label: Text('${preset['icon']} ${preset['name']}'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF8B5CF6),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedPreset = preset['id'];
                              if (preset['id'] != 'custom') {
                                c1Controller.text = preset['color1'];
                                c2Controller.text = preset['color2'];
                                c3Controller.text = preset['color3'];
                                selectedDirection = preset['direction'];
                                selectedShading = preset['shading'];
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 2. GRADIENT DIRECTION SELECTION
                  const Text(
                    'Gradient Direction (Horizontal / Vertical / Sidha):',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'id': 'horizontal', 'label': '↔️ Horizontal (Sidha Left-Right)'},
                      {'id': 'vertical', 'label': '↕️ Vertical (Top-Bottom)'},
                      {'id': 'diagonal', 'label': '↘️ Diagonal (TopLeft-BottomRight)'},
                      {'id': 'radial', 'label': '🎯 Radial Glow (Center Outward)'},
                    ].map((d) {
                      final isSelected = selectedDirection == d['id'];
                      return ChoiceChip(
                        label: Text(d['label']!),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0EA5E9),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedDirection = d['id']!;
                              selectedPreset = 'custom';
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 3. CUSTOM GRADIENT COLORS WITH VISUAL COLOR SCALE PICKER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Custom Gradient Colors (Tap Circle to Pick):',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '🎨 Color Scale Palette',
                        style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // COLOR 1 SCALE PICKER
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _showColorPickerScaleDialog(
                              title: 'Color 1 (Start)',
                              initialColorHex: c1Controller.text,
                              onColorSelected: (hex) {
                                setDialogState(() {
                                  c1Controller.text = hex;
                                  selectedPreset = 'custom';
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: c1Controller,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Color 1 (Start)',
                                labelStyle: const TextStyle(fontSize: 11),
                                suffixIcon: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(6),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: HeaderThemeHelper.hexToColor(c1Controller.text),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade400, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: HeaderThemeHelper.hexToColor(c1Controller.text).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // COLOR 2 SCALE PICKER
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _showColorPickerScaleDialog(
                              title: 'Color 2 (End)',
                              initialColorHex: c2Controller.text,
                              onColorSelected: (hex) {
                                setDialogState(() {
                                  c2Controller.text = hex;
                                  selectedPreset = 'custom';
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: c2Controller,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Color 2 (End)',
                                labelStyle: const TextStyle(fontSize: 11),
                                suffixIcon: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(6),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: HeaderThemeHelper.hexToColor(c2Controller.text),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade400, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: HeaderThemeHelper.hexToColor(c2Controller.text).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // COLOR 3 SCALE PICKER
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _showColorPickerScaleDialog(
                              title: 'Color 3 (Accent)',
                              initialColorHex: c3Controller.text,
                              onColorSelected: (hex) {
                                setDialogState(() {
                                  c3Controller.text = hex;
                                  selectedPreset = 'custom';
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: c3Controller,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Color 3 (Accent)',
                                labelStyle: const TextStyle(fontSize: 11),
                                suffixIcon: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                prefixIcon: Container(
                                  margin: const EdgeInsets.all(6),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: HeaderThemeHelper.hexToColor(c3Controller.text),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade400, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: HeaderThemeHelper.hexToColor(c3Controller.text).withValues(alpha: 0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. SHADING INTENSITY (Halka / Gahara)
                  const Text(
                    'Color Shading Intensity (Halka / Gahara Color):',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'id': 'light', 'label': '☀️ Soft Light (Halka)'},
                      {'id': 'medium', 'label': '🌤️ Medium Vivid'},
                      {'id': 'dark', 'label': '🌙 Deep Dark (Gahara)'},
                      {'id': 'ultra_dark', 'label': '🖤 Ultra Dark Obsidian'},
                    ].map((s) {
                      final isSelected = selectedShading == s['id'];
                      return ChoiceChip(
                        label: Text(s['label']!),
                        selected: isSelected,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedShading = s['id']!;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 5. SHINING METALLIC BEAM TOGGLE
                  SwitchListTile(
                    activeThumbColor: const Color(0xFF8B5CF6),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Continuous Shining Glass Light Beam ✨',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Enable sweeping animated metallic glass shimmer beam overlay across header.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    value: enableShining,
                    onChanged: (val) {
                      setDialogState(() => enableShining = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // 6. PARTICLE ICON OPACITY SLIDER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Floating Icons Opacity:',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${(particleOpacity * 100).round()}%',
                        style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  Slider(
                    value: particleOpacity,
                    min: 0.2,
                    max: 1.0,
                    divisions: 8,
                    activeColor: const Color(0xFF8B5CF6),
                    onChanged: (val) {
                      setDialogState(() => particleOpacity = val);
                    },
                  ),
                  const Divider(height: 30),

                  // 7. FESTIVAL & SEASONAL ANIMATION MANAGER (FLIPKART STYLE)
                  Row(
                    children: const [
                      Icon(Icons.festival_rounded, color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Flipkart Style Festive Animated Theme 🎆',
                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable smooth floating vector Lottie animations (Freedom Sale, Diwali Fireworks, Flipkart Grocery, Flash Sale) or paste any custom Lottie JSON URL / prompt.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  const SizedBox(height: 10),

                  SwitchListTile(
                    activeThumbColor: const Color(0xFFF59E0B),
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Festive Header Animation 🎈',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text('Overlay floating festive vector graphics over header background.'),
                    value: isFestivalActive,
                    onChanged: (val) {
                      setDialogState(() => isFestivalActive = val);
                    },
                  ),

                  if (isFestivalActive) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: festivalTitleCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Festive Banner Title / Badge (e.g. FREEDOM SALE 🇮🇳)',
                        prefixIcon: Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Choose Festival Animation Preset:',
                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: HeaderThemeHelper.festivalPresets.map((f) {
                        final isSelected = lottieUrlCtrl.text.trim() == f['url'];
                        return ChoiceChip(
                          label: Text(f['name']!),
                          selected: isSelected,
                          selectedColor: const Color(0xFFF59E0B),
                          backgroundColor: const Color(0xFFFEF3C7),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF92400E),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                lottieUrlCtrl.text = f['url']!;
                                festivalTitleCtrl.text = f['title']!;
                                c1Controller.text = f['color1']!;
                                c2Controller.text = f['color2']!;
                                c3Controller.text = f['color3']!;
                                selectedPreset = 'custom';
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: lottieUrlCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Custom Lottie JSON URL / Code Prompt',
                        hintText: 'Paste https://assets.../lottie.json URL',
                        prefixIcon: Icon(Icons.link_rounded, color: Color(0xFF0EA5E9), size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                label: const Text('Save & Publish Theme 🎨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);

                  final finalConfig = {
                    'preset_id': selectedPreset,
                    'color1': c1Controller.text.trim(),
                    'color2': c2Controller.text.trim(),
                    'color3': c3Controller.text.trim(),
                    'direction': selectedDirection,
                    'shading': selectedShading,
                    'enable_shining': enableShining,
                    'particle_opacity': particleOpacity,
                    'is_festival_active': isFestivalActive,
                    'festival_title': festivalTitleCtrl.text.trim(),
                    'lottie_url': lottieUrlCtrl.text.trim(),
                    'lottie_opacity': lottieOpacity,
                  };

                  await AuthService.saveHeaderThemeConfig(finalConfig);
                  nav.pop();

                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('App Animated Header Theme Updated & Published Successfully! 🎨✨'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showColorPickerScaleDialog({
    required String title,
    required String initialColorHex,
    required Function(String hexCode) onColorSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SpectrumColorPickerDialog(
        title: title,
        initialColorHex: initialColorHex,
        onColorSelected: onColorSelected,
      ),
    );
  }

  void _showAddSellerDialog() async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    List<String> locations = await AuthService.getLocations();
    String selectedLocation = locations.isNotEmpty ? locations.first : 'Main Market';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.storefront_rounded, color: Color(0xFF0EA5E9)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create Seller Account',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Store/Owner Name',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Store Name' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Mobile Number',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      counterText: '',
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller ID / Username',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Username' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Password',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
                  ),
                  const SizedBox(height: 14),

                  // Location Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final newLoc = await _showAddNewLocationDialog();
                          if (newLoc != null && newLoc.isNotEmpty) {
                            final updated = await AuthService.getLocations();
                            setDialogState(() {
                              locations = updated;
                              selectedLocation = newLoc;
                            });
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.add_location_alt_rounded, color: Color(0xFF0EA5E9), size: 14),
                            SizedBox(width: 4),
                            Text('+ Add New Location', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: locations.contains(selectedLocation) ? selectedLocation : (locations.isNotEmpty ? locations.first : null),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF0EA5E9), size: 15),
                            const SizedBox(width: 6),
                            Text(loc, style: const TextStyle(color: Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLocation = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);

                    final result = await AuthService.createSellerResult(
                      name: nameController.text,
                      username: usernameController.text,
                      password: passwordController.text,
                      mobile: mobileController.text,
                      location: selectedLocation,
                    );

                    final bool success = result['success'] == true;
                    final String msg = result['message'] ?? 'Action completed';

                    if (success) {
                      nav.pop();
                      _loadAllData();
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Create Seller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDeliveryBoyDialog() async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    final vehicleController = TextEditingController(text: 'Bike');
    final formKey = GlobalKey<FormState>();

    List<String> locations = await AuthService.getLocations();
    String selectedLocation = locations.isNotEmpty ? locations.first : 'Main Market';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.two_wheeler_rounded, color: Color(0xFF8B5CF6)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create Delivery Boy Account',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Delivery Boy Name',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Name' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      counterText: '',
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Delivery Boy ID / Username',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Username' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: vehicleController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Vehicle (Bike / Scooter / E-rickshaw)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final newLoc = await _showAddNewLocationDialog();
                          if (newLoc != null && newLoc.isNotEmpty) {
                            final updated = await AuthService.getLocations();
                            setDialogState(() {
                              locations = updated;
                              selectedLocation = newLoc;
                            });
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.add_location_alt_rounded, color: Color(0xFF8B5CF6), size: 14),
                            SizedBox(width: 4),
                            Text('+ Add New Location', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: locations.contains(selectedLocation) ? selectedLocation : (locations.isNotEmpty ? locations.first : null),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF8B5CF6), size: 15),
                            const SizedBox(width: 6),
                            Text(loc, style: const TextStyle(color: Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLocation = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);

                    final result = await AuthService.createDeliveryBoyResult(
                      name: nameController.text,
                      username: usernameController.text,
                      password: passwordController.text,
                      mobile: mobileController.text,
                      vehicle: vehicleController.text,
                      location: selectedLocation,
                    );

                    final bool success = result['success'] == true;
                    final String msg = result['message'] ?? 'Action completed';

                    if (success) {
                      nav.pop();
                      _loadAllData();
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Create Delivery Boy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSellerDialog(Map<String, dynamic> seller) async {
    final nameController = TextEditingController(text: seller['name'] ?? '');
    final mobileController = TextEditingController(text: seller['mobile'] ?? '');
    final passwordController = TextEditingController(text: seller['password'] ?? '');
    final username = (seller['username'] ?? '').toString();
    final formKey = GlobalKey<FormState>();

    List<String> locations = await AuthService.getLocations();
    String selectedLocation = (seller['location'] ?? '').toString().trim();
    if (selectedLocation.isEmpty && locations.isNotEmpty) {
      selectedLocation = locations.first;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit Seller ($username)',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Store/Owner Name',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Store Name' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Mobile Number',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      counterText: '',
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Seller Password',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
                  ),
                  const SizedBox(height: 14),

                  // Location Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final newLoc = await _showAddNewLocationDialog();
                          if (newLoc != null && newLoc.isNotEmpty) {
                            final updated = await AuthService.getLocations();
                            setDialogState(() {
                              locations = updated;
                              selectedLocation = newLoc;
                            });
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.add_location_alt_rounded, color: Color(0xFF0EA5E9), size: 14),
                            SizedBox(width: 4),
                            Text('+ Add New Location', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: locations.contains(selectedLocation) ? selectedLocation : (locations.isNotEmpty ? locations.first : null),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0EA5E9))),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF0EA5E9), size: 15),
                            const SizedBox(width: 6),
                            Text(loc, style: const TextStyle(color: Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLocation = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);

                    final result = await AuthService.updateSellerResult(
                      username: username,
                      name: nameController.text,
                      password: passwordController.text,
                      mobile: mobileController.text,
                      location: selectedLocation,
                    );

                    final bool success = result['success'] == true;
                    final String msg = result['message'] ?? 'Action completed';

                    if (success) {
                      nav.pop();
                      _loadAllData();
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Update Seller', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDeliveryBoyDialog(Map<String, dynamic> deliveryBoy) async {
    final nameController = TextEditingController(text: deliveryBoy['name'] ?? '');
    final mobileController = TextEditingController(text: deliveryBoy['mobile'] ?? '');
    final passwordController = TextEditingController(text: deliveryBoy['password'] ?? '');
    final vehicleController = TextEditingController(text: deliveryBoy['vehicle'] ?? 'Bike');
    final username = (deliveryBoy['username'] ?? '').toString();
    final formKey = GlobalKey<FormState>();

    List<String> locations = await AuthService.getLocations();
    String selectedLocation = (deliveryBoy['location'] ?? '').toString().trim();
    if (selectedLocation.isEmpty && locations.isNotEmpty) {
      selectedLocation = locations.first;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit Delivery Boy ($username)',
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Delivery Boy Name',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Name' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      counterText: '',
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: vehicleController,
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Vehicle (Bike / Scooter / E-rickshaw)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location:',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final newLoc = await _showAddNewLocationDialog();
                          if (newLoc != null && newLoc.isNotEmpty) {
                            final updated = await AuthService.getLocations();
                            setDialogState(() {
                              locations = updated;
                              selectedLocation = newLoc;
                            });
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.add_location_alt_rounded, color: Color(0xFF8B5CF6), size: 14),
                            SizedBox(width: 4),
                            Text('+ Add New Location', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: locations.contains(selectedLocation) ? selectedLocation : (locations.isNotEmpty ? locations.first : null),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                    ),
                    items: locations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Color(0xFF8B5CF6), size: 15),
                            const SizedBox(width: 6),
                            Text(loc, style: const TextStyle(color: Color(0xFF0F172A))),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLocation = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(ctx);

                    final result = await AuthService.updateDeliveryBoyResult(
                      username: username,
                      name: nameController.text,
                      password: passwordController.text,
                      mobile: mobileController.text,
                      vehicle: vehicleController.text,
                      location: selectedLocation,
                    );

                    final bool success = result['success'] == true;
                    final String msg = result['message'] ?? 'Action completed';

                    if (success) {
                      nav.pop();
                      _loadAllData();
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    );
                  }
                },
                child: const Text('Update Delivery Boy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteSeller(String username, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete Seller?', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete seller "$name" ($username)?',
          style: const TextStyle(color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.deleteSeller(username);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Seller "$name" deleted successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                _loadAllData();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeliveryBoy(String username, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete Delivery Partner?', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete delivery partner "$name" ($username)?',
          style: const TextStyle(color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.deleteDeliveryBoy(username);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Delivery partner "$name" deleted successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                _loadAllData();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern Light Background
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 2,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  tooltip: 'Open Menu',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: Text(
                _selectedIndex == 0
                    ? 'Manage Sellers'
                    : (_selectedIndex == 1 ? 'Manage Delivery' : 'Order Details'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6)),
                  tooltip: 'Manage Header Theme & Colors',
                  onPressed: _showManageHeaderThemeDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0EA5E9)),
                  tooltip: 'Refresh Data',
                  onPressed: _loadAllData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  tooltip: 'Logout',
                  onPressed: _handleLogout,
                ),
              ],
            ),
      drawer: isDesktop ? null : _buildMobileDrawer(),
      body: Row(
        children: [
          // Permanent Sidebar for Desktop/Web view
          if (isDesktop) _buildDesktopSidebar(),

          // Main Active Screen Content
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: SafeArea(
                child: Column(
                  children: [
                    // Desktop Header Bar
                    if (isDesktop) _buildDesktopHeaderBar(),

                    // Content Area
                    Expanded(
                      child: _selectedIndex == 0
                          ? _buildSellersTab()
                          : (_selectedIndex == 1 ? _buildDeliveryBoysTab() : _buildOrderDetailsTab()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Left Sidebar Menu for Desktop/Web view
  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Sleek Navy Sidebar
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Daily Mart 🛍️',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Admin Control Portal',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'MAIN MENU',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
            ),
          ),

          // Menu Option 1: Manage Sellers
          _buildSidebarMenuItem(
            index: 0,
            title: 'Manage Sellers',
            subtitle: '${_sellers.length} Stores Registered',
            icon: Icons.storefront_rounded,
            activeColor: const Color(0xFF0EA5E9),
          ),

          const SizedBox(height: 6),

          // Menu Option 2: Manage Delivery Boys
          _buildSidebarMenuItem(
            index: 1,
            title: 'Manage Delivery Boys',
            subtitle: '${_deliveryBoys.length} Partners Registered',
            icon: Icons.two_wheeler_rounded,
            activeColor: const Color(0xFF8B5CF6),
          ),

          const SizedBox(height: 6),

          // Menu Option 3: Order Details
          _buildSidebarMenuItem(
            index: 2,
            title: 'Order Details',
            subtitle: '${_filteredOrders.length} Filtered (${_flatOrdersList.length} Total)',
            icon: Icons.inventory_2_rounded,
            activeColor: const Color(0xFF10B981),
          ),

          const Spacer(),

          const Divider(color: Color(0xFF1E293B), height: 1),

          // Admin User Details & Logout Button at Bottom of Sidebar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF0EA5E9),
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name.isNotEmpty ? widget.user.name : 'Administrator',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'System Admin',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                    tooltip: 'Logout',
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single Item in Sidebar
  Widget _buildSidebarMenuItem({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: activeColor.withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeColor : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isSelected ? activeColor.withValues(alpha: 0.9) : const Color(0xFF64748B),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header Bar for Desktop View
  Widget _buildDesktopHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedIndex == 0
                    ? 'Sellers Management'
                    : (_selectedIndex == 1 ? 'Delivery Partners Management' : 'Order Details Overview'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                _selectedIndex == 0
                    ? 'Overview of all registered sellers and store details'
                    : (_selectedIndex == 1
                        ? 'Overview of active delivery partners and assignments'
                        : 'View all orders in tabular format with date range filtering'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
            ),
            icon: const Icon(Icons.palette_rounded, color: Colors.white, size: 18),
            label: const Text(
              'Header Theme & Colors 🎨',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _showManageHeaderThemeDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0EA5E9)),
            tooltip: 'Refresh Data',
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
          if (_selectedIndex != 2)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedIndex == 0 ? const Color(0xFF0EA5E9) : const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: Text(
                _selectedIndex == 0 ? '+ Add New Seller' : '+ Add Delivery Boy',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _selectedIndex == 0 ? _showAddSellerDialog : _showAddDeliveryBoyDialog,
            ),
        ],
      ),
    );
  }

  /// Mobile Drawer for Mobile Views
  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            child: Row(
              children: const [
                Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0EA5E9), size: 36),
                SizedBox(width: 12),
                Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storefront_rounded, color: Color(0xFF0EA5E9)),
            title: const Text('Manage Sellers', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF8B5CF6)),
            title: const Text('Manage Delivery Boys', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_rounded, color: Color(0xFF10B981)),
            title: const Text('Order Details', style: TextStyle(color: Colors.white)),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded, color: Color(0xFF8B5CF6)),
            title: const Text('Header Theme & Colors 🎨', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showManageHeaderThemeDialog();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  /// Sellers Tab View
  Widget _buildSellersTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 650;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registered Sellers',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text('Add Seller', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: _showAddSellerDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : _sellers.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.storefront_rounded, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text('No sellers found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sellers.length,
                      itemBuilder: (ctx, idx) {
                        final s = _sellers[idx];
                        final name = s['name'] ?? 'Seller Store';
                        final username = s['username'] ?? '';
                        final mobile = s['mobile'] ?? '';
                        final location = (s['location'] ?? '').toString().trim();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white, // Clean Light Card
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x0A000000),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.storefront_rounded, color: Color(0xFF0EA5E9), size: 22),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ID: $username  •  +91 $mobile${location.isNotEmpty ? '  •  📍 $location' : ''}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF0EA5E9)),
                                  tooltip: 'Edit Seller',
                                  onPressed: () => _showEditSellerDialog(s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  tooltip: 'Delete Seller',
                                  onPressed: () => _confirmDeleteSeller(username, name),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  /// Delivery Boys Tab View
  Widget _buildDeliveryBoysTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 650;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDesktop) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Delivery Partners',
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text('Add Delivery Boy', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: _showAddDeliveryBoyDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : _deliveryBoys.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.two_wheeler_rounded, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text('No delivery boys created yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _deliveryBoys.length,
                      itemBuilder: (ctx, idx) {
                        final d = _deliveryBoys[idx];
                        final name = d['name'] ?? 'Delivery Boy';
                        final username = d['username'] ?? '';
                        final mobile = d['mobile'] ?? '';
                        final vehicle = d['vehicle'] ?? 'Bike';
                        final location = (d['location'] ?? '').toString().trim();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white, // Clean Light Card
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x0A000000),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF8B5CF6), size: 22),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'ID: $username  •  +91 $mobile  •  $vehicle${location.isNotEmpty ? '  •  📍 $location' : ''}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6)),
                                  tooltip: 'Edit Delivery Boy',
                                  onPressed: () => _showEditDeliveryBoyDialog(d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  tooltip: 'Delete Delivery Boy',
                                  onPressed: () => _confirmDeleteDeliveryBoy(username, name),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  /// Order Details Tab View (10-Column Data Table with Date Range Filter)
  Widget _buildOrderDetailsTab() {
    final filtered = _filteredOrders;

    double totalCash = 0.0;
    double totalOnline = 0.0;

    for (var ord in filtered) {
      final double amt = double.tryParse(ord['amount']?.toString() ?? '') ?? 0.0;
      final String payStatus = (ord['payment_status_display'] ?? '').toString().toLowerCase();
      final String payMode = (ord['payment_mode_display'] ?? '').toString().toLowerCase();

      if (payStatus == 'paid') {
        if (payMode.contains('online') || payMode.contains('upi') || payMode.contains('paytm')) {
          totalOnline += amt;
        } else {
          totalCash += amt;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date Range Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.filter_alt_rounded, color: Color(0xFF0EA5E9), size: 20),
                    SizedBox(width: 6),
                    Text('Date Range Filter:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),

                // Start Date Input
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0EA5E9)),
                  label: Text(
                    _startDate == null ? 'Start Date' : 'From: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                    style: TextStyle(color: _startDate == null ? const Color(0xFF64748B) : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                    }
                  },
                ),

                const Text('to', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),

                // End Date Input
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.event_rounded, size: 16, color: Color(0xFF0EA5E9)),
                  label: Text(
                    _endDate == null ? 'End Date' : 'To: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                    style: TextStyle(color: _endDate == null ? const Color(0xFF64748B) : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                ),

                // Preset Buttons
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(() {
                      _startDate = DateTime(today.year, today.month, today.day);
                      _endDate = DateTime(today.year, today.month, today.day);
                    });
                  },
                  child: const Text('Today', style: TextStyle(fontSize: 12)),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(() {
                      _startDate = today.subtract(const Duration(days: 7));
                      _endDate = today;
                    });
                  },
                  child: const Text('Last 7 Days', style: TextStyle(fontSize: 12)),
                ),

                if (_startDate != null || _endDate != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.redAccent),
                    label: const Text('Clear Filter', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    onPressed: () => setState(() {
                      _startDate = null;
                      _endDate = null;
                    }),
                  ),

                const SizedBox(width: 12),
                // Live Row Search Bar Filter
                Container(
                  width: 280,
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _tableSearchController,
                          onChanged: (val) {
                            setState(() {
                              _tableSearchQuery = val.trim().toLowerCase();
                            });
                          },
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            hintText: 'Search Order #, Customer, Seller, Location...',
                            hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_tableSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _tableSearchController.clear();
                            setState(() {
                              _tableSearchQuery = '';
                            });
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scroll Controls & Table Title Header with Total Cash & Total Online Badges
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 8),
                  Text(
                    'Orders Table (${filtered.length} Records)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Total Cash Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_rounded, size: 15, color: Color(0xFF16A34A)),
                        const SizedBox(width: 5),
                        const Text('Total Cash: ', style: TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                        Text('₹${totalCash.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total Online Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 15, color: Color(0xFF0284C7)),
                        const SizedBox(width: 5),
                        const Text('Total Online: ', style: TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w600)),
                        Text('₹${totalOnline.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF075985), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total Collection Badge (Total Cash + Total Online in BOLD)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, size: 15, color: Color(0xFF9333EA)),
                        const SizedBox(width: 5),
                        const Text('Total Collection: ', style: TextStyle(fontSize: 12, color: Color(0xFF7E22CE), fontWeight: FontWeight.bold)),
                        Text('₹${(totalCash + totalOnline).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF581C87), fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Excel Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.file_download_rounded, size: 16, color: Colors.white),
                    label: const Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (filtered.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No order data available to export.')),
                        );
                        return;
                      }
                      CsvExporter.exportOrders(filtered);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${filtered.length} orders downloaded successfully as Excel/CSV!'),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Clock Delay Time Filter Button
                  PopupMenuButton<int>(
                    tooltip: 'Filter by Delivery Delay Time',
                    initialValue: _selectedDelayMinutes,
                    onSelected: (val) {
                      setState(() {
                        _selectedDelayMinutes = val;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedDelayMinutes > 0 ? const Color(0xFFFEF3C7) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedDelayMinutes > 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: _selectedDelayMinutes > 0 ? const Color(0xFFD97706) : const Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _selectedDelayMinutes == 0
                                ? 'Delay Time'
                                : _selectedDelayMinutes >= 60
                                    ? '> ${(_selectedDelayMinutes / 60).toStringAsFixed(_selectedDelayMinutes % 60 == 0 ? 0 : 1)} Hr'
                                    : '> ${_selectedDelayMinutes}m',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedDelayMinutes > 0 ? const Color(0xFFB45309) : const Color(0xFF0F172A),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem<int>(
                        value: 0,
                        child: Text('All Delivery Times'),
                      ),
                      const PopupMenuItem<int>(
                        value: 15,
                        child: Text('> 15 Mins Delay'),
                      ),
                      const PopupMenuItem<int>(
                        value: 30,
                        child: Text('> 30 Mins Delay'),
                      ),
                      const PopupMenuItem<int>(
                        value: 45,
                        child: Text('> 45 Mins Delay'),
                      ),
                      const PopupMenuItem<int>(
                        value: 60,
                        child: Text('> 1 Hour Delay'),
                      ),
                      const PopupMenuItem<int>(
                        value: 120,
                        child: Text('> 2 Hours Delay'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Order Status Dropdown Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    height: 34,
                    decoration: BoxDecoration(
                      color: _selectedStatusFilter != 'All' ? const Color(0xFFF0F9FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedStatusFilter != 'All' ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        icon: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF0EA5E9)),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatusFilter = val;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                          DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                          DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 10-Column Data Table Container with Prominent Visible Scrollbar
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : filtered.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_rounded, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              _flatOrdersList.isEmpty
                                  ? 'No real orders found in database yet.\nPlace an order from Customer App to view it live here.'
                                  : 'No orders match the selected date range.',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Listener(
                        onPointerDown: (event) {
                          _dragStartX = event.position.dx;
                        },
                        onPointerMove: (event) {
                          if (_horizontalScrollController.hasClients) {
                            final double deltaX = event.position.dx - _dragStartX;
                            _dragStartX = event.position.dx;
                            final double targetOffset = (_horizontalScrollController.offset - deltaX)
                                .clamp(0.0, _horizontalScrollController.position.maxScrollExtent);
                            _horizontalScrollController.jumpTo(targetOffset);
                          }
                        },
                        child: ScrollConfiguration(
                          behavior: AppScrollBehavior(),
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 60,
                            horizontalMargin: 16,
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('S.N.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Customer Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Order No.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Order Send Date Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Seller Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Seller Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Pickup Date Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Delivered Date Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Order Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Delivery Boy Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status Date Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Payment Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Payment Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ],
                            rows: List.generate(filtered.length, (idx) {
                              final ord = filtered[idx];
                              final status = (ord['order_status'] ?? 'Pending').toString();

                              Color statusBg = const Color(0xFFFEF3C7);
                              Color statusFg = const Color(0xFFB45309);
                              if (status == 'Delivered') {
                                statusBg = const Color(0xFFDCFCE7);
                                statusFg = const Color(0xFF15803D);
                              } else if (status == 'Pickup') {
                                statusBg = const Color(0xFFDBEAFE);
                                statusFg = const Color(0xFF1D4ED8);
                              } else if (status == 'Cancelled') {
                                statusBg = const Color(0xFFFEE2E2);
                                statusFg = const Color(0xFFB91C1C);
                              }

                              final double amt = double.tryParse(ord['amount']?.toString() ?? '') ?? 0.0;

                              final String payStatus = (ord['payment_status_display'] ?? 'Unpaid').toString();
                              final bool isPaid = payStatus.toLowerCase() == 'paid';

                              final String payMode = (ord['payment_mode_display'] ?? 'Cash').toString();
                              final bool isOnline = payMode.toLowerCase().contains('online') ||
                                  payMode.toLowerCase().contains('upi') ||
                                  payMode.toLowerCase().contains('paytm');

                              return DataRow(
                                color: WidgetStateProperty.all(idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
                                cells: [
                                  DataCell(Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                                  DataCell(Text((ord['date'] ?? '').toString(), style: const TextStyle(color: Color(0xFF0F172A)))),
                                  DataCell(Text((ord['customer_name'] ?? '').toString(), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFDBA74))),
                                    child: Text((ord['order_no'] ?? '').toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                                  )),
                                  DataCell(Text((ord['order_send_time'] ?? '').toString(), style: const TextStyle(color: Color(0xFF475569), fontSize: 12))),
                                  DataCell(Text('₹${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                                  DataCell(Text((ord['seller_name'] ?? '').toString(), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFCBD5E1))),
                                    child: Text((ord['seller_location'] ?? '-').toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  )),
                                  DataCell((() {
                                    final String pTime = (ord['pickup_time'] ?? '').toString().trim();
                                    return pTime.isEmpty
                                        ? const Text('-', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))
                                        : Text(pTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12));
                                  })()),
                                  DataCell((() {
                                    final String dTime = (ord['delivered_time'] ?? '').toString().trim();
                                    return dTime.isEmpty
                                        ? const Text('-', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))
                                        : Text(dTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12));
                                  })()),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                  )),
                                  DataCell(Text((ord['delivery_boy_name'] ?? '').toString(), style: const TextStyle(color: Color(0xFF475569)))),
                                  DataCell((() {
                                    final String stTime = (ord['status_time'] ?? '').toString().trim();
                                    return stTime.isEmpty
                                        ? const Text('-', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))
                                        : Text(stTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12));
                                  })()),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      payStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  )),
                                  DataCell(
                                    payMode.isEmpty
                                        ? const Text('-', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isOnline ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isOnline ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isOnline ? Icons.credit_card_rounded : Icons.payments_rounded,
                                                  size: 13,
                                                  color: isOnline ? const Color(0xFF0284C7) : const Color(0xFF475569),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  payMode,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isOnline ? const Color(0xFF0369A1) : const Color(0xFF334155),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

class SpectrumCanvasPainter extends CustomPainter {
  final double hue;

  SpectrumCanvasPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Base Hue background
    final baseColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    final paintBase = Paint()..color = baseColor;
    canvas.drawRect(rect, paintBase);

    // 2. Horizontal Saturation gradient (White -> Transparent)
    final whiteGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Colors.white.withOpacity(0.0)],
    );
    final paintWhite = Paint()..shader = whiteGradient.createShader(rect);
    canvas.drawRect(rect, paintWhite);

    // 3. Vertical Value gradient (Transparent -> Black)
    final blackGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withOpacity(0.0), Colors.black],
    );
    final paintBlack = Paint()..shader = blackGradient.createShader(rect);
    canvas.drawRect(rect, paintBlack);
  }

  @override
  bool shouldRepaint(covariant SpectrumCanvasPainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

class SpectrumColorPickerDialog extends StatefulWidget {
  final String title;
  final String initialColorHex;
  final Function(String hexCode) onColorSelected;

  const SpectrumColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColorHex,
    required this.onColorSelected,
  });

  @override
  State<SpectrumColorPickerDialog> createState() => _SpectrumColorPickerDialogState();
}

class _SpectrumColorPickerDialogState extends State<SpectrumColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    Color initColor = HeaderThemeHelper.hexToColor(widget.initialColorHex);
    HSVColor hsv = HSVColor.fromColor(initColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(hsv.toColor()));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final r = ((color.value >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((color.value >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (color.value & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#${r}${g}${b}'.toUpperCase();
  }

  void _updateFromHSV(double h, double s, double v) {
    setState(() {
      _hue = h;
      _saturation = s;
      _value = v;
      final currentColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      _hexController.text = _colorToHex(currentColor);
    });
  }

  void _updateFromHex(String input) {
    String clean = input.trim();
    if (!clean.startsWith('#')) clean = '#$clean';
    if (clean.length == 7) {
      try {
        Color c = HeaderThemeHelper.hexToColor(clean);
        HSVColor hsv = HSVColor.fromColor(c);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    final currentHex = _colorToHex(currentColor);

    final r = (currentColor.value >> 16) & 0xFF;
    final g = (currentColor.value >> 8) & 0xFF;
    final b = currentColor.value & 0xFF;

    // CMYK calculation
    final dr = r / 255.0;
    final dg = g / 255.0;
    final db = b / 255.0;
    final k = 1.0 - math.max(dr, math.max(dg, db));
    final c = k == 1.0 ? 0 : (((1.0 - dr - k) / (1.0 - k)) * 100).round();
    final m = k == 1.0 ? 0 : (((1.0 - dg - k) / (1.0 - k)) * 100).round();
    final y = k == 1.0 ? 0 : (((1.0 - db - k) / (1.0 - k)) * 100).round();
    final kPct = (k * 100).round();

    // HSL calculation
    final hsl = HSLColor.fromColor(currentColor);
    final hslH = hsl.hue.round();
    final hslS = (hsl.saturation * 100).round();
    final hslL = (hsl.lightness * 100).round();

    // HSV calculation
    final hsvH = _hue.round();
    final hsvS = (_saturation * 100).round();
    final hsvV = (_value * 100).round();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: currentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: currentColor.withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Color Picker - ${widget.title}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. 2D SATURATION / VALUE SPECTRUM CANVAS (MATCHING SCREENSHOT 2)
              LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth;
                  const canvasHeight = 180.0;

                  final cursorX = (_saturation * canvasWidth).clamp(0.0, canvasWidth);
                  final cursorY = ((1.0 - _value) * canvasHeight).clamp(0.0, canvasHeight);

                  void handleTouch(Offset localPos) {
                    final newSat = (localPos.dx / canvasWidth).clamp(0.0, 1.0);
                    final newVal = (1.0 - (localPos.dy / canvasHeight)).clamp(0.0, 1.0);
                    _updateFromHSV(_hue, newSat, newVal);
                  }

                  return GestureDetector(
                    onPanDown: (details) => handleTouch(details.localPosition),
                    onPanUpdate: (details) => handleTouch(details.localPosition),
                    child: Container(
                      width: canvasWidth,
                      height: canvasHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SpectrumCanvasPainter(hue: _hue),
                            ),
                          ),
                          // Cursor Ring
                          Positioned(
                            left: cursorX - 10,
                            top: cursorY - 10,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentColor,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // 2. RAINBOW HUE SLIDER
              const Text(
                'Color Spectrum / Hue Bar:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sliderWidth = constraints.maxWidth;
                  final thumbX = ((_hue / 360.0) * sliderWidth).clamp(0.0, sliderWidth);

                  void handleHueTouch(Offset localPos) {
                    final newHue = ((localPos.dx / sliderWidth) * 360.0).clamp(0.0, 360.0);
                    _updateFromHSV(newHue, _saturation, _value);
                  }

                  return GestureDetector(
                    onPanDown: (details) => handleHueTouch(details.localPosition),
                    onPanUpdate: (details) => handleHueTouch(details.localPosition),
                    child: Container(
                      width: sliderWidth,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: (thumbX - 10).clamp(0.0, sliderWidth - 20),
                            top: 2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 3. HEX INPUT FIELD WITH COPY BUTTON (MATCHING SCREENSHOT 2)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      onChanged: _updateFromHex,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), letterSpacing: 1.0),
                      decoration: InputDecoration(
                        labelText: 'HEX COLOR CODE',
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B), size: 18),
                          tooltip: 'Copy HEX Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: currentHex));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied $currentHex to clipboard!'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF8B5CF6),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. COLOR SPEC BADGES (RGB, CMYK, HSV, HSL - MATCHING SCREENSHOT 2)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildColorSpecBadge('RGB', '$r, $g, $b'),
                  _buildColorSpecBadge('CMYK', '$c%, $m%, $y%, $kPct%'),
                  _buildColorSpecBadge('HSV', '$hsvH°, $hsvS%, $hsvV%'),
                  _buildColorSpecBadge('HSL', '$hslH°, $hslS%, $hslL%'),
                ],
              ),
              const SizedBox(height: 16),

              // 5. QUICK PALETTE PRESET SWATCHES
              const Text(
                'Quick Preset Swatches:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  '#0F172A', '#1E1B4B', '#2E1065', '#0C4A6E', '#064E3B', '#451A03', '#4C0519',
                  '#10B981', '#0EA5E9', '#8B5CF6', '#F59E0B', '#EF4444', '#EC4899', '#6366F1',
                  '#FBBF24', '#FCD34D', '#34D399', '#38BDF8', '#A855F7', '#FB7185', '#FFFFFF',
                ].map((hex) {
                  final c = HeaderThemeHelper.hexToColor(hex);
                  final isSelected = currentHex.toLowerCase() == hex.toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      HSVColor hsv = HSVColor.fromColor(c);
                      _updateFromHSV(hsv.hue, hsv.saturation, hsv.value);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.black12,
                          width: isSelected ? 3 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(color: c.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 6. ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      widget.onColorSelected(currentHex);
                      Navigator.pop(context);
                    },
                    child: const Text('Select Color 🎨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSpecBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
