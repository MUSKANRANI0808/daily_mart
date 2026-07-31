import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

/// Isolated Countdown Banner Widget to prevent full screen rebuilds & image blinking
class SamplingCountdownBannerWidget extends StatefulWidget {
  final int initialSeconds;
  const SamplingCountdownBannerWidget({super.key, this.initialSeconds = 352269});

  @override
  State<SamplingCountdownBannerWidget> createState() => _SamplingCountdownBannerWidgetState();
}

class _SamplingCountdownBannerWidgetState extends State<SamplingCountdownBannerWidget> {
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
  final VoidCallback? onTap;
  const ShimmerGlassOrderButton({super.key, this.onTap});

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

class SellerSamplingScreen extends StatefulWidget {
  final UserModel seller;

  const SellerSamplingScreen({super.key, required this.seller});

  @override
  State<SellerSamplingScreen> createState() => _SellerSamplingScreenState();
}

class _SellerSamplingScreenState extends State<SellerSamplingScreen> {
  int _selectedTab = 0; // 0: Samples Catalog, 1: Customer Orders
  bool _isLoading = true;

  // Sub-filter for Customer Orders: 'All Orders', 'Process', 'Ready', 'Cancel'
  String _selectedStatusFilter = 'All Orders';

  // Active customer selected for drill-down view (null = show customer list)
  Map<String, dynamic>? _selectedCustomerGroup;

  List<Map<String, dynamic>> _catalogList = [];
  List<Map<String, dynamic>> _customerOrders = [];

  final ScrollController _catalogScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _catalogScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final username = widget.seller.username ?? '';
    final catalog = await AuthService.getSamplesCatalog(username);
    final orders = await AuthService.getSellerSampleOrders(username);
    if (mounted) {
      setState(() {
        _catalogList = catalog;
        _customerOrders = orders;
        _isLoading = false;
      });
    }
  }

  /// Total count of orders in 'Process' or 'Pending' status
  int get _processOrdersCount {
    return _customerOrders.where((o) {
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

  Color _getAvatarColor(String text) {
    final colors = [
      const Color(0xFF00A3FF),
      const Color(0xFFE91E63),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];
    int hash = text.hashCode.abs();
    return colors[hash % colors.length];
  }

  /// Robust Image Builder helper (Prevents Blinking & Prevents QR Fallbacks)
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5, letterSpacing: 0.8),
          ),
          SizedBox(height: 2),
          Text(
            'Daily Mart Collection',
            style: TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  void _showAddSampleDialog() {
    final titleController = TextEditingController();
    final rateController = TextEditingController();
    String? pickedBase64Image;
    bool isUploading = false;

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
            Future<void> pickImage(ImageSource source) async {
              try {
                final picker = ImagePicker();
                final file = await picker.pickImage(source: source, imageQuality: 70);
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  setModalState(() {
                    pickedBase64Image = base64Encode(bytes);
                  });
                }
              } catch (e) {
                debugPrint('Error picking image: $e');
              }
            }

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
                          'Add New Sample Item 📸',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Image Preview / Selector Box
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (c) => Container(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(c);
                                    pickImage(ImageSource.camera);
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.camera_alt_rounded, size: 40, color: Color(0xFF0066FF)),
                                      SizedBox(height: 6),
                                      Text('Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(c);
                                    pickImage(ImageSource.gallery);
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.photo_library_rounded, size: 40, color: Color(0xFF10B981)),
                                      SizedBox(height: 6),
                                      Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        ),
                        child: pickedBase64Image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.memory(
                                  base64Decode(pickedBase64Image!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo_rounded, size: 44, color: Color(0xFF0066FF)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Click to upload sample image 📷',
                                    style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Camera or Gallery',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Caption / Title Input
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Product Caption / Title (e.g. NEW COLLECTION)',
                        prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF0066FF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Price / Rate Input
                    TextField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Rate per piece (₹ e.g. 250)',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF10B981)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                final rate = rateController.text.trim();
                                if (title.isEmpty || rate.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter Title and Rate!')),
                                  );
                                  return;
                                }

                                setModalState(() => isUploading = true);

                                await AuthService.addSampleCatalog(
                                  sellerUsername: widget.seller.username ?? '',
                                  sellerName: widget.seller.name ?? 'Seller',
                                  title: title,
                                  rate: rate,
                                  imageBase64: pickedBase64Image,
                                );

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _loadData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sample Product posted to Catalog! 🚀'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                        child: isUploading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Post Sample Catalog',
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

  void _deleteSample(String sampleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sample?'),
        content: const Text('Are you sure you want to delete this sample from your catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.deleteSampleCatalog(
        sellerUsername: widget.seller.username ?? '',
        sampleId: sampleId,
      );
      _loadData();
    }
  }

  void _updateOrderStatus(Map<String, dynamic> orderItem, String newStatus) async {
    final orderId = orderItem['id'].toString();
    final custMobile = orderItem['customer_mobile'].toString();

    await AuthService.updateSampleOrderStatus(
      sellerUsername: widget.seller.username ?? '',
      customerMobile: custMobile,
      orderId: orderId,
      newStatus: newStatus,
    );

    await _loadData();

    // If active group is open, update active group orders as well
    if (_selectedCustomerGroup != null) {
      final mobile = _selectedCustomerGroup!['mobile'].toString();
      final updatedOrders = _customerOrders.where((o) => o['customer_mobile'].toString() == mobile).toList();
      setState(() {
        _selectedCustomerGroup!['orders'] = updatedOrders;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to "$newStatus" ✨'),
          backgroundColor: newStatus == 'Ready'
              ? const Color(0xFF10B981)
              : (newStatus == 'Cancelled' || newStatus == 'Cancel' ? Colors.red : const Color(0xFFF59E0B)),
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  /// Show Bottom Sheet Modal with List of Customers who viewed the sample
  void _showSeenByCustomersModal(Map<String, dynamic> sampleItem) {
    final title = (sampleItem['title'] ?? 'SAMPLE').toString();
    final rate = (sampleItem['rate'] ?? '0').toString();
    List<Map<String, dynamic>> seenList = [];

    if (sampleItem['seen_by_list'] != null && sampleItem['seen_by_list'] is List) {
      seenList = (sampleItem['seen_by_list'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    final int count = seenList.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),

              // Header Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF0066FF), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Seen By Customers ($count)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: const CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Text(
                'Sample: ${title.toUpperCase()} (₹$rate)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),

              const Divider(height: 20),

              // Customers List
              Expanded(
                child: seenList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.visibility_off_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No customers have viewed this sample yet.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: seenList.length,
                        itemBuilder: (context, index) {
                          final c = seenList[index];
                          final name = (c['name'] ?? 'Customer').toString();
                          final mobile = (c['mobile'] ?? '').toString();
                          final viewedAt = (c['viewed_at'] ?? '').toString();
                          final avatarLetter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
                          final avatarColor = _getAvatarColor(name);

                          return Card(
                            elevation: 1,
                            color: const Color(0xFFF8FAFC),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      avatarLetter,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '+91 $mobile',
                                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                                        ),
                                        if (viewedAt.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, size: 11, color: Colors.grey),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Viewed: $viewedAt',
                                                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Phone Call Button
                                  if (mobile.isNotEmpty)
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDCFCE7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                                      ),
                                      onPressed: () => _makePhoneCall(mobile),
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
        );
      },
    );
  }

  /// Show Compact, Professional Order Detail Sheet
  void _showOrderClearDetailDialog(Map<String, dynamic> ord) async {
    final title = (ord['title'] ?? 'SAMPLE').toString();
    final rate = (ord['rate'] ?? '0').toString();
    final pcs = (ord['pcs'] ?? 1).toString();
    final total = (ord['total_price'] ?? 0).toString();
    final note = (ord['customer_note'] ?? '').toString();
    final dateStr = (ord['created_at'] ?? '').toString();
    final status = (ord['status'] ?? 'Process').toString();
    final custName = (ord['customer_name'] ?? 'Customer').toString();
    final custMobile = (ord['customer_mobile'] ?? '').toString();
    final imgUrl = (ord['image_url'] ?? '').toString();

    // Fetch customer default address
    final defaultAddr = await AuthService.getDefaultCustomerAddress(custMobile);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final String currentStatus = (ord['status'] ?? status).toString();
          final bool isProcessActive = (currentStatus == 'Pending' || currentStatus == 'Process');
          final bool isReadyActive = (currentStatus == 'Ready');
          final bool isCancelActive = (currentStatus == 'Cancelled' || currentStatus == 'Cancel');

          return Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Title & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sample Order Details 📋',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        child: const CircleAvatar(
                          radius: 13,
                          backgroundColor: Color(0xFFF1F5F9),
                          child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Full Size Image Box with Tap to Zoom Lightbox
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (c) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: const EdgeInsets.all(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              InteractiveViewer(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _buildSampleImageWidget(imgUrl, height: 400, width: double.infinity, fit: BoxFit.contain),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black.withOpacity(0.7),
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
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildSampleImageWidget(imgUrl, height: 170, fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
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

                  const SizedBox(height: 14),

                  // Product Title & Live Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isReadyActive
                              ? const Color(0xFFDCFCE7)
                              : (isCancelActive ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isReadyActive
                                ? const Color(0xFF86EFAC)
                                : (isCancelActive ? Colors.red.shade200 : const Color(0xFFFDE68A)),
                          ),
                        ),
                        child: Text(
                          isReadyActive ? 'READY ✅' : (isCancelActive ? 'CANCEL ❌' : 'PROCESS ⏳'),
                          style: TextStyle(
                            color: isReadyActive
                                ? const Color(0xFF15803D)
                                : (isCancelActive ? Colors.red : const Color(0xFFB45309)),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Rate & Total Price Info Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rate: ₹$rate / Pcs', style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                        Text('Qty: $pcs Pcs', style: const TextStyle(fontSize: 12, color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                        Text('Total: ₹$total', style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Customer Details + Default Address Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text('Customer Info:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(custName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Mobile: +91 $custMobile', style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
                        Text('Order Date: $dateStr', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),

                        const Divider(height: 14),

                        // Default Saved Customer Address
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            const Text('Default Address:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.all(Radius.circular(6)),
                              ),
                              child: const Text('DEFAULT ⭐', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          defaultAddr != null
                              ? '${defaultAddr['receiver'] ?? custName}\n${defaultAddr['houseNo'] ?? ''} ${defaultAddr['building'] ?? ''}, ${defaultAddr['locality'] ?? ''}, ${defaultAddr['landmark'] ?? ''}'
                              : 'No default address saved yet by customer.',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'Customer Note: "$note"',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Change Status Actions
                  const Text('Change Order Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Process Button
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isProcessActive ? const Color(0xFFFEF3C7) : Colors.white,
                            foregroundColor: isProcessActive ? const Color(0xFFB45309) : const Color(0xFF64748B),
                            side: BorderSide(
                              color: isProcessActive ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                              width: isProcessActive ? 1.4 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          onPressed: () {
                            setModalState(() {
                              ord['status'] = 'Process';
                            });
                            _updateOrderStatus(ord, 'Process');
                          },
                          child: const Text('Process ⏳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Ready Button
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isReadyActive ? const Color(0xFFDCFCE7) : Colors.white,
                            foregroundColor: isReadyActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            side: BorderSide(
                              color: isReadyActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              width: isReadyActive ? 1.4 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          onPressed: () {
                            setModalState(() {
                              ord['status'] = 'Ready';
                            });
                            _updateOrderStatus(ord, 'Ready');
                          },
                          child: const Text('Ready ✅', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Cancel Button
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isCancelActive ? const Color(0xFFFEE2E2) : Colors.white,
                            foregroundColor: isCancelActive ? Colors.red.shade700 : const Color(0xFF64748B),
                            side: BorderSide(
                              color: isCancelActive ? Colors.red : const Color(0xFFCBD5E1),
                              width: isCancelActive ? 1.4 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          ),
                          onPressed: () {
                            setModalState(() {
                              ord['status'] = 'Cancel';
                            });
                            _updateOrderStatus(ord, 'Cancel');
                          },
                          child: const Text('Cancel ❌', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Isolated Top Countdown Banner
            const SamplingCountdownBannerWidget(),

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
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                            _selectedCustomerGroup = null;
                          });
                        },
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

                    // Customer Orders Tab
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
                                'Customer Orders',
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
                      onRefresh: _loadData,
                      child: _selectedTab == 0 ? _buildSamplesCatalogView() : _buildCustomerOrdersView(),
                    ),
            ),
          ],
        ),
      ),

      // Bottom Right Dark Blue Camera + Plus Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSampleDialog,
        backgroundColor: const Color(0xFF0A2540), // Dark Blue Color
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(
          Icons.add_a_photo_rounded,
          size: 28,
          color: Colors.white,
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
            Text('No sample items in catalog yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text('Click 📷 button below to add new sample product!', style: TextStyle(color: Colors.grey, fontSize: 11.5)),
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
        final id = item['id'].toString();
        final title = item['title'] ?? 'NEW COLLECTION';
        final rate = item['rate'] ?? '250';
        final imgUrl = item['image_url'] ?? '';
        final sellerName = item['seller_name'] ?? widget.seller.name ?? 'Seller';
        List<Map<String, dynamic>> seenList = [];
        if (item['seen_by_list'] != null && item['seen_by_list'] is List) {
          seenList = (item['seen_by_list'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }
        final seenBy = seenList.length;

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
              // Full-Width Image Header Box Stack (Clickable to view full size)
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

                      // Delete Trash Red Circle Button (Top Right)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () => _deleteSample(id),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
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
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () => _showSeenByCustomersModal(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                'Seen By ($seenBy)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0066FF),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Active Shimmer Glass Order Button (Sisa ki chamak!)
                    const ShimmerGlassOrderButton(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build Customer Orders View (Tab 1)
  Widget _buildCustomerOrdersView() {
    if (_selectedCustomerGroup != null) {
      return _buildCustomerDetailOrdersView();
    }

    Map<String, List<Map<String, dynamic>>> groupedMap = {};
    for (var ord in _customerOrders) {
      final status = (ord['status'] ?? 'Process').toString();
      
      if (_selectedStatusFilter == 'Process' && status != 'Pending' && status != 'Process') {
        continue;
      }
      if (_selectedStatusFilter == 'Ready' && status != 'Ready') {
        continue;
      }
      if (_selectedStatusFilter == 'Cancel' && status != 'Cancelled' && status != 'Cancel') {
        continue;
      }

      final key = (ord['customer_mobile'] ?? 'Unknown').toString();
      if (!groupedMap.containsKey(key)) {
        groupedMap[key] = [];
      }
      groupedMap[key]!.add(ord);
    }

    final groupedList = groupedMap.entries.toList();

    return Column(
      children: [
        // Compact Sub-Filter Chips Row
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

        // Grouped Customers List
        Expanded(
          child: groupedList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No customer orders found in this filter.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: groupedList.length,
                  itemBuilder: (ctx, idx) {
                    final entry = groupedList[idx];
                    final mobile = entry.key;
                    final orders = entry.value;
                    final firstOrder = orders.first;
                    final custName = firstOrder['customer_name'] ?? 'Customer (+91 $mobile)';
                    final count = orders.length;

                    // Process Count for this specific customer
                    final int customerProcessCount = orders.where((o) {
                      final st = (o['status'] ?? 'Process').toString();
                      return st == 'Process' || st == 'Pending';
                    }).length;

                    final avatarLetter = custName.trim().isNotEmpty ? custName.trim()[0].toUpperCase() : 'C';
                    final avatarColor = _getAvatarColor(custName);

                    return Card(
                      elevation: 1.5,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCustomerGroup = {
                              'name': custName,
                              'mobile': mobile,
                              'orders': orders,
                            };
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: avatarColor,
                                child: Text(
                                  avatarLetter,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      custName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count ${count == 1 ? 'Order' : 'Orders'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Compact Black Circle Badge with White Text Number
                              if (customerProcessCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$customerProcessCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],

                              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  int _getFilterCount(String label) {
    if (label == 'All Orders') {
      return _customerOrders.length;
    } else if (label == 'Process') {
      return _customerOrders.where((o) {
        final st = (o['status'] ?? 'Process').toString();
        return st == 'Process' || st == 'Pending';
      }).length;
    } else if (label == 'Ready') {
      return _customerOrders.where((o) {
        final st = (o['status'] ?? 'Process').toString();
        return st == 'Ready';
      }).length;
    } else if (label == 'Cancel') {
      return _customerOrders.where((o) {
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1.5))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (isSelected && count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.all(3),
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

  Widget _buildCustomerDetailOrdersView() {
    final custName = _selectedCustomerGroup!['name'] ?? 'Customer';
    final custMobile = _selectedCustomerGroup!['mobile'] ?? '';
    final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(_selectedCustomerGroup!['orders'] ?? []);
    final count = orders.length;

    final avatarLetter = custName.trim().isNotEmpty ? custName.trim()[0].toUpperCase() : 'C';
    final avatarColor = _getAvatarColor(custName);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                onPressed: () {
                  setState(() {
                    _selectedCustomerGroup = null;
                  });
                },
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarColor,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      custName.toUpperCase(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$count ${count == 1 ? 'Order' : 'Orders'} • +91 $custMobile',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: orders.length,
            itemBuilder: (ctx, idx) {
              final ord = orders[idx];
              final title = ord['title'] ?? 'SAMPLE';
              final rate = ord['rate'] ?? '17';
              final pcs = ord['pcs'] ?? 1;
              final note = ord['customer_note'] ?? 'gg';
              final dateStr = ord['created_at'] ?? '';
              final status = ord['status'] ?? 'Process';
              final imgUrl = ord['image_url'] ?? '';

              return Card(
                elevation: 1.5,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showOrderClearDetailDialog(ord),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildSampleImageWidget(imgUrl, height: 80, width: 80),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: status == 'Ready'
                                          ? const Color(0xFFECFDF5)
                                          : (status == 'Cancelled' || status == 'Cancel' ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: status == 'Ready'
                                            ? const Color(0xFFA7F3D0)
                                            : (status == 'Cancelled' || status == 'Cancel' ? Colors.red.shade200 : const Color(0xFFFDE68A)),
                                      ),
                                    ),
                                    child: Text(
                                      status == 'Ready' ? 'READY' : (status == 'Cancelled' || status == 'Cancel' ? 'CANCEL' : 'PROCESS'),
                                      style: TextStyle(
                                        color: status == 'Ready'
                                            ? const Color(0xFF059669)
                                            : (status == 'Cancelled' || status == 'Cancel' ? Colors.red : const Color(0xFFD97706)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),

                              Text('Rate: ₹$rate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 2),

                              Text(
                                'Ordered Pcs: $pcs',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),

                              if (note.isNotEmpty)
                                Text(
                                  'Message: "$note"',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontStyle: FontStyle.italic),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                  ),

                                  PopupMenuButton<String>(
                                    onSelected: (newSt) => _updateOrderStatus(ord, newSt),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Actions',
                                            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF0F172A)),
                                        ],
                                      ),
                                    ),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'Process',
                                        child: Text('Process ⏳', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                      ),
                                      const PopupMenuItem(
                                        value: 'Ready',
                                        child: Text('Ready ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                      ),
                                      const PopupMenuItem(
                                        value: 'Cancel',
                                        child: Text('Cancel ❌', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
