import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

/// Isolated Countdown Banner Widget to prevent full screen rebuilds & image blinking
class CustomerSamplingCountdownBannerWidget extends StatefulWidget {
  final int initialSeconds;
  const CustomerSamplingCountdownBannerWidget({super.key, this.initialSeconds = 352231});

  @override
  State<CustomerSamplingCountdownBannerWidget> createState() => _CustomerSamplingCountdownBannerWidgetState();
}

class _CustomerSamplingCountdownBannerWidgetState extends State<CustomerSamplingCountdownBannerWidget> {
  late Timer _timer;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _seconds > 0) {
        setState(() {
          _seconds--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    int hrs = seconds ~/ 3600;
    int mins = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C4A6E), // Deep Blue Banner
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            'Winter offer Start in 👉 ${_formatTimer(_seconds)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolated Shimmer Glass Order Button (Sisa ki chamak - Continuous Glass Reflection Sweep)
class ShimmerGlassOrderButton extends StatefulWidget {
  final VoidCallback onTap;
  const ShimmerGlassOrderButton({super.key, required this.onTap});

  @override
  State<ShimmerGlassOrderButton> createState() => _ShimmerGlassOrderButtonState();
}

class _ShimmerGlassOrderButtonState extends State<ShimmerGlassOrderButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final double left = -1.5 + (progress * 4.0);

            return Container(
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155), width: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_rounded, color: Color(0xFF10B981), size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Order Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  // Glass Sheen Reflection Beam (Sisa ki Chamak Sweep!)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: 0.45,
                      alignment: Alignment(left, 0),
                      child: Transform(
                        transform: Matrix4.skewX(-0.35),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.45),
                                Colors.white.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class CustomerSamplingScreen extends StatefulWidget {
  final UserModel customer;

  const CustomerSamplingScreen({super.key, required this.customer});

  @override
  State<CustomerSamplingScreen> createState() => _CustomerSamplingScreenState();
}

class _CustomerSamplingScreenState extends State<CustomerSamplingScreen> {
  int _selectedTab = 0; // 0: Samples Catalog, 1: Your Orders
  bool _isLoading = true;
  String _selectedStatusFilter = 'All Orders'; // 'All Orders', 'Process', 'Ready', 'Cancel'

  String _sellerUsername = '';
  String _sellerName = 'Seller';
  String _sellerMobile = '';

  List<Map<String, dynamic>> _catalogList = [];
  List<Map<String, dynamic>> _myOrders = [];

  final ScrollController _catalogScrollController = ScrollController();

  int get _processOrdersCount {
    return _myOrders.where((o) {
      final st = (o['status'] ?? 'Process').toString();
      return st == 'Process' || st == 'Pending';
    }).length;
  }

  void _showFullScreenImageDialog(BuildContext context, String imgUrl) {
    if (imgUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildSampleImageWidget(
                  imgUrl,
                  height: MediaQuery.of(context).size.height * 0.7,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.75),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSellerAndData();
  }

  @override
  void dispose() {
    _catalogScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerAndData() async {
    setState(() => _isLoading = true);
    final seller = await AuthService.getLastSelectedSeller();
    if (seller != null && seller['username'] != null) {
      _sellerUsername = seller['username']!;
      _sellerName = seller['name'] ?? _sellerUsername;
      _sellerMobile = seller['mobile'] ?? '';
    } else {
      final chats = await AuthService.getCustomerConversations(widget.customer.mobile ?? '');
      if (chats.isNotEmpty) {
        _sellerUsername = chats.first['seller_username'] ?? 'seller';
        _sellerName = chats.first['seller_name'] ?? _sellerUsername;
      } else {
        _sellerUsername = 'seller';
        _sellerName = 'Daily Mart Seller';
      }
    }

    final catalog = await AuthService.getAllSamplesForCustomer(
      customerMobile: widget.customer.mobile ?? '',
      currentSellerUsername: _sellerUsername,
    );
    final allOrders = await AuthService.getCustomerSampleOrders(widget.customer.mobile ?? '');
    final myOrders = allOrders.where((o) {
      final sUsername = (o['seller_username'] ?? '').toString().trim();
      return sUsername.isEmpty || sUsername == _sellerUsername.trim() || sUsername == 'seller';
    }).toList();

    // Auto-record customer sample view count & customer info
    if (widget.customer.mobile != null && widget.customer.mobile!.isNotEmpty) {
      for (var sample in catalog) {
        final sampleId = sample['id'].toString();
        await AuthService.recordSampleView(
          sellerUsername: _sellerUsername,
          sampleId: sampleId,
          customerName: widget.customer.name ?? '',
          customerMobile: widget.customer.mobile ?? '',
        );
      }
      // Re-fetch updated catalog with new counts
      final updatedCatalog = await AuthService.getAllSamplesForCustomer(
        customerMobile: widget.customer.mobile ?? '',
        currentSellerUsername: _sellerUsername,
      );
      if (mounted) {
        setState(() {
          _catalogList = updatedCatalog;
          _myOrders = myOrders;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _catalogList = catalog;
          _myOrders = myOrders;
          _isLoading = false;
        });
      }
    }
  }

  /// Robust Image Builder helper (Prevents Blinking & Prevents Bad Fallbacks)
  Widget _buildSampleImageWidget(String imgUrl, {double height = 200, double width = double.infinity, BoxFit fit = BoxFit.cover}) {
    final cleanImg = imgUrl.trim();

    if (cleanImg.isNotEmpty && (cleanImg.startsWith('data:image') || cleanImg.length > 200)) {
      try {
        final base64Str = cleanImg.contains(',') ? cleanImg.split(',').last : cleanImg;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(height, width),
        );
      } catch (_) {
        return _buildPlaceholderImage(height, width);
      }
    }

    if (cleanImg.isNotEmpty && cleanImg.startsWith('assets/') && !cleanImg.contains('delivery_boy') && !cleanImg.contains('preset')) {
      return Image.asset(
        cleanImg,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(height, width),
      );
    }

    return _buildPlaceholderImage(height, width);
  }

  Widget _buildPlaceholderImage(double height, double width) {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.checkroom_rounded, size: 44, color: Color(0xFF10B981)),
          SizedBox(height: 4),
          Text(
            'SAMPLE PRODUCT',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
          ),
          SizedBox(height: 2),
          Text(
            'Daily Mart Collection',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _showOrderNowModal(Map<String, dynamic> sampleItem) {
    final title = sampleItem['title'] ?? 'NEW COLLECTION';
    final rateStr = sampleItem['rate'] ?? '250';
    final double rate = double.tryParse(rateStr) ?? 250.0;
    final imgUrl = sampleItem['image_url'] ?? '';

    int pcs = 1;
    final noteController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double total = rate * pcs;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Place Sample Order 🛍️',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sample Item Preview Row
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildSampleImageWidget(imgUrl, height: 60, width: 60),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Rate: ₹$rateStr / Pcs',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Quantity Stepper (Pcs)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Quantity (Pcs):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, color: Color(0xFF0F172A)),
                                onPressed: () {
                                  if (pcs > 1) {
                                    setModalState(() => pcs--);
                                  }
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  '$pcs Pcs',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, color: Color(0xFF0F172A)),
                                onPressed: () {
                                  setModalState(() => pcs++);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Customer Note Input
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Write Note / Color Instructions (Optional)',
                        hintText: 'e.g. Please send red and green colors',
                        prefixIcon: const Icon(Icons.note_alt_rounded, color: Color(0xFF0066FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Total Calculation Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Order Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46))),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);

                                await AuthService.placeSampleOrder(
                                  sellerUsername: _sellerUsername,
                                  sellerName: _sellerName,
                                  customerMobile: widget.customer.mobile ?? '',
                                  customerName: widget.customer.name ?? '',
                                  sampleId: sampleItem['id'].toString(),
                                  title: title,
                                  rate: rateStr,
                                  pcs: pcs,
                                  note: noteController.text.trim(),
                                  imageUrl: imgUrl,
                                );

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  await _loadSellerAndData();
                                  setState(() => _selectedTab = 1); // Switch to Your Orders tab
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sample Order Placed Successfully! 🛍️'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm Sample Order',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Isolated Top Countdown Banner
            const CustomerSamplingCountdownBannerWidget(),

            const SizedBox(height: 10),

            // Top Filter Segment Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Samples Catalog Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedTab == 0
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)]
                                : [],
                          ),
                          child: Text(
                            'Samples Catalog',
                            style: TextStyle(
                              color: _selectedTab == 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Your Orders Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _selectedTab == 1
                                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Your Orders',
                                style: TextStyle(
                                  color: _selectedTab == 1 ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                              if (_processOrdersCount > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_processOrdersCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Tab View Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0066FF)))
                  : RefreshIndicator(
                      onRefresh: _loadSellerAndData,
                      child: _selectedTab == 0 ? _buildSamplesCatalogView() : _buildYourOrdersView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Full Width Single Column Samples Catalog View (Full Screen Width / High Chaudai!)
  Widget _buildSamplesCatalogView() {
    if (_catalogList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
            SizedBox(height: 8),
            Text('No sample items in seller catalog yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(left: 22, right: 40, top: 10, bottom: 10),
      itemCount: _catalogList.length,
      itemBuilder: (ctx, idx) {
        final reversedCatalog = _catalogList.reversed.toList();
        final item = reversedCatalog[idx];
        final title = item['title'] ?? 'NEW COLLECTION';
        final rate = item['rate'] ?? '250';
        final imgUrl = item['image_url'] ?? '';
        final sellerName = item['seller_name'] ?? _sellerName;

        return Card(
          elevation: 2,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Width Image Box (Click to view full size!)
              GestureDetector(
                onTap: () => _showFullScreenImageDialog(context, imgUrl),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildSampleImageWidget(imgUrl, height: 180, width: double.infinity),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                              SizedBox(width: 3),
                              Text('Full Size Image', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Card Bottom Details Area (Full Width / Maximum Chaudai!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                '₹$rate',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'By: $sellerName',
                                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Active Shimmer Glass Order Now Button (Sisa ki chamak!)
                    ShimmerGlassOrderButton(
                      onTap: () => _showOrderNowModal(item),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _getFilterCount(String label) {
    if (label == 'All Orders') {
      return _myOrders.length;
    } else if (label == 'Process') {
      return _myOrders.where((o) {
        final st = (o['status'] ?? 'Process').toString();
        return st == 'Process' || st == 'Pending';
      }).length;
    } else if (label == 'Ready') {
      return _myOrders.where((o) {
        final st = (o['status'] ?? 'Process').toString();
        return st == 'Ready';
      }).length;
    } else if (label == 'Cancel') {
      return _myOrders.where((o) {
        final st = (o['status'] ?? 'Process').toString();
        return st == 'Cancelled' || st == 'Cancel';
      }).length;
    }
    return 0;
  }

  /// Compact Filter Chip
  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedStatusFilter == label;
    final int count = isSelected ? _getFilterCount(label) : 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (isSelected && count > 0) ...[
              const SizedBox(width: 4.5),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build Your Orders View (Tab 1)
  Widget _buildYourOrdersView() {
    final filteredOrders = _myOrders.where((ord) {
      final status = (ord['status'] ?? 'Process').toString();
      if (_selectedStatusFilter == 'Process' && status != 'Pending' && status != 'Process') {
        return false;
      }
      if (_selectedStatusFilter == 'Ready' && status != 'Ready') {
        return false;
      }
      if (_selectedStatusFilter == 'Cancel' && status != 'Cancelled' && status != 'Cancel') {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Sub-Filter Chips Row (All Orders, Process, Ready, Cancel)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
          child: Row(
            children: [
              _buildFilterChip('All Orders'),
              const SizedBox(width: 6),
              _buildFilterChip('Process'),
              const SizedBox(width: 6),
              _buildFilterChip('Ready'),
              const SizedBox(width: 6),
              _buildFilterChip('Cancel'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No orders found in this filter.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: filteredOrders.length,
                  itemBuilder: (ctx, idx) {
                    final ord = filteredOrders[idx];
        String orderId = (ord['id'] ?? 'Order ${idx + 1}').toString();
        if (!orderId.toLowerCase().startsWith('order')) {
          orderId = 'Order $orderId';
        }
        final sellerName = ord['seller_name'] ?? 'Seller';
        final title = ord['title'] ?? 'NEW COLLECTION';
        final rate = ord['rate'] ?? '250';
        final pcs = ord['pcs'] ?? 1;
        final total = ord['total_price'] ?? 250;
        final note = ord['customer_note'] ?? '';
        final dateStr = ord['created_at'] ?? '';
        final status = ord['status'] ?? 'Process';
        final imgUrl = ord['image_url'] ?? '';

        return Card(
          elevation: 1.5,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orderId,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 11.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'Ready'
                            ? const Color(0xFFDCFCE7)
                            : (status == 'Cancelled' || status == 'Cancel' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: status == 'Ready'
                              ? const Color(0xFF86EFAC)
                              : (status == 'Cancelled' || status == 'Cancel' ? Colors.red.shade200 : const Color(0xFFFDE68A)),
                        ),
                      ),
                      child: Text(
                        status == 'Ready'
                            ? 'Ready ✅'
                            : (status == 'Cancelled' || status == 'Cancel' ? 'Cancelled ❌' : 'Process ⏳'),
                        style: TextStyle(
                          color: status == 'Ready'
                              ? const Color(0xFF15803D)
                              : (status == 'Cancelled' || status == 'Cancel' ? Colors.red : const Color(0xFFB45309)),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullScreenImageDialog(context, imgUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildSampleImageWidget(imgUrl, height: 48, width: 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seller: $sellerName',
                            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                          ),
                          Text(
                            'Qty: $pcs Pcs  • Total: ₹$total',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your Note: "$note"',
                    style: const TextStyle(fontSize: 11, color: Colors.black87, fontStyle: FontStyle.italic),
                  ),
                ],

                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ],
    );
  }
}
