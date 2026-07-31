import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../role_selection_screen.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sellers = [];
  List<Map<String, dynamic>> _deliveryBoys = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final sellers = await AuthService.getSellersList();
    final deliveryBoys = await AuthService.getDeliveryBoys();
    if (mounted) {
      setState(() {
        _sellers = sellers;
        _deliveryBoys = deliveryBoys;
        _isLoading = false;
      });
    }
  }

  void _showAddSellerDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Create Seller Account',
                style: TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Seller Store/Owner Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Store Name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Seller Mobile Number',
                  labelStyle: TextStyle(color: Colors.grey),
                  counterText: '',
                  prefixText: '+91 ',
                  prefixStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                ),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Seller ID / Username',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Username' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Seller Password',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final result = await AuthService.createSellerResult(
                  name: nameController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                  mobile: mobileController.text,
                );

                if (context.mounted) {
                  Navigator.pop(ctx);
                  final bool success = result['success'] == true;
                  final String msg = result['message'] ?? 'Action completed';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                  );

                  if (success) {
                    _loadAllData();
                  }
                }
              }
            },
            child: const Text('Create Seller', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddDeliveryBoyDialog() {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final mobileController = TextEditingController();
    final vehicleController = TextEditingController(text: 'Bike');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.two_wheeler_rounded, color: Color(0xFFA78BFA)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Create Delivery Boy Account',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Delivery Boy Name',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA78BFA))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  labelStyle: TextStyle(color: Colors.grey),
                  counterText: '',
                  prefixText: '+91 ',
                  prefixStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA78BFA))),
                ),
                validator: (val) => val == null || val.trim().length < 10 ? 'Enter 10-digit Mobile' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Delivery Boy ID / Username',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA78BFA))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Username' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA78BFA))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter Password' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: vehicleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle (Bike / Scooter / E-rickshaw)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFA78BFA))),
                ),
              ),
            ],
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
              if (formKey.currentState!.validate()) {
                final result = await AuthService.createDeliveryBoyResult(
                  name: nameController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                  mobile: mobileController.text,
                  vehicle: vehicleController.text,
                );

                if (context.mounted) {
                  Navigator.pop(ctx);
                  final bool success = result['success'] == true;
                  final String msg = result['message'] ?? 'Action completed';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                  );

                  if (success) {
                    _loadAllData();
                  }
                }
              }
            },
            child: const Text('Create Delivery Boy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSeller(String username, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete Seller?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete seller "$name" ($username)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeliveryBoy(String username, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete Delivery Partner?', style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete delivery partner "$name" ($username)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin Dashboard',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Manage Sellers'),
            Tab(icon: Icon(Icons.two_wheeler_rounded), text: 'Manage Delivery Boys'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Manage Sellers
          _buildSellersTab(),
          // Tab 2: Manage Delivery Boys
          _buildDeliveryBoysTab(),
        ],
      ),
    );
  }

  Widget _buildSellersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Registered Sellers',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sellers.isEmpty
                  ? const Center(
                      child: Text('No sellers found.', style: TextStyle(color: Colors.grey)),
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

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF0EA5E9),
                              child: Icon(Icons.storefront_rounded, color: Colors.white),
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: $username  •  +91 $mobile', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteSeller(username, name),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBoysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Delivery Partners',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _deliveryBoys.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text('No delivery boys created yet.', style: TextStyle(color: Colors.grey)),
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

                        return Card(
                          color: const Color(0xFF1E293B),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF8B5CF6),
                              child: Icon(Icons.two_wheeler_rounded, color: Colors.white),
                            ),
                            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: $username  •  +91 $mobile  •  $vehicle', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => _confirmDeleteDeliveryBoy(username, name),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
