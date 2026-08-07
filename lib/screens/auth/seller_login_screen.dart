import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/apitxt_otp_service.dart';
import '../seller/seller_main_nav_screen.dart';
import '../dashboards/delivery_boy_dashboard.dart';
import '../dashboards/admin_dashboard.dart';

class SellerLoginScreen extends StatefulWidget {
  const SellerLoginScreen({super.key});

  @override
  State<SellerLoginScreen> createState() => _SellerLoginScreenState();
}

class _SellerLoginScreenState extends State<SellerLoginScreen> {
  // 0 = Mobile + OTP, 1 = Username + Password
  int _selectedTab = 0;

  final _formKeyMobile = GlobalKey<FormState>();
  final _formKeyPassword = GlobalKey<FormState>();

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;

  // Handle Username + Password Login (Smart Auto-Detection for Admin, Delivery Boy, or Seller)
  void _handlePasswordLogin() async {
    if (_formKeyPassword.currentState!.validate()) {
      setState(() => _isLoading = true);
      final idText = _usernameController.text.trim();
      final passText = _passwordController.text.trim();

      // 1. Check Admin credentials
      final adminUser = await AuthService.loginAdmin(idText, passText);
      if (adminUser != null && mounted) {
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboard(user: adminUser)),
          (route) => false,
        );
        return;
      }

      // 2. Check Delivery Boy credentials
      final deliveryBoy = await AuthService.loginDeliveryBoy(idText, passText);
      if (deliveryBoy != null && mounted) {
        await AuthService.saveDeliveryBoySession(deliveryBoy);
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => DeliveryBoyDashboardScreen(deliveryBoy: deliveryBoy)),
          (route) => false,
        );
        return;
      }

      // 3. Check Seller credentials
      final sellerUser = await AuthService.loginSeller(idText, passText);
      setState(() => _isLoading = false);

      if (sellerUser != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => SellerMainNavScreen(seller: sellerUser)),
          (route) => false,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Credentials! Please check ID or Password.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // Handle Mobile Number + OTP Login
  void _handleMobileLogin() async {
    if (_formKeyMobile.currentState!.validate()) {
      setState(() => _isLoading = true);
      final mobile = _mobileController.text.trim();

      // Send OTP via Apitxt.com API
      final otpResult = await ApitxtOtpService.sendOtp(mobile);
      setState(() => _isLoading = false);

      if (mounted) {
        // Show OTP Verification Dialog for Partner / Seller
        _showOtpVerificationDialog(mobile, initialMessage: otpResult['message']);
      }
    }
  }

  // Show OTP Verification Dialog for Partner / Seller Mobile Login
  void _showOtpVerificationDialog(String mobile, {String? initialMessage}) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFF3E8FF),
                  child: Icon(Icons.mark_email_read_rounded, size: 34, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Verify Mobile Number 📲',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'An OTP SMS was sent to +91 $mobile',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the 4-digit OTP code received on your phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // OTP Input Field
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 16),

              // Verify Button
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final otp = otpController.text.trim();
                        if (otp.isEmpty) {
                          setModalState(() => errorText = 'Please enter the OTP');
                          return;
                        }

                        setModalState(() {
                          isVerifying = true;
                          errorText = null;
                        });

                        final result = await ApitxtOtpService.verifyOtp(mobile, otp);
                        bool isSuccess = result['success'] == true;

                        if (!isSuccess) {
                          setModalState(() {
                            isVerifying = false;
                            errorText = result['message'] ?? 'Invalid OTP code';
                          });
                          return;
                        }

                        // Smart Role Lookup for Mobile Number
                        final sellerUser = await AuthService.findSellerByMobile(mobile);
                        final deliveryBoy = await AuthService.findDeliveryBoyByMobile(mobile);
                        final bool isAdminMobile = (mobile.trim() == '9999999999' || mobile.trim() == '1234567890');

                        final availableRoles = <String>[];
                        if (sellerUser != null) availableRoles.add('seller');
                        if (deliveryBoy != null) availableRoles.add('delivery_boy');
                        if (isAdminMobile) availableRoles.add('admin');

                        setModalState(() => isVerifying = false);

                        if (mounted) {
                          Navigator.pop(ctx); // Close OTP sheet

                          if (availableRoles.length > 1) {
                            // Multiple roles found -> Let user select role
                            _showRoleSelectionBottomSheet(
                              mobile: mobile,
                              sellerUser: sellerUser,
                              deliveryBoy: deliveryBoy,
                              isAdminMobile: isAdminMobile,
                            );
                          } else if (deliveryBoy != null) {
                            // Only Delivery Boy registered
                            await AuthService.saveDeliveryBoySession(deliveryBoy);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => DeliveryBoyDashboardScreen(deliveryBoy: deliveryBoy)),
                              (route) => false,
                            );
                          } else if (isAdminMobile) {
                            // Admin mobile
                            final adminUser = UserModel(id: 'admin_1', name: 'Administrator', username: 'admin', role: UserRole.admin);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => AdminDashboard(user: adminUser)),
                              (route) => false,
                            );
                          } else {
                            // Seller (existing or auto-created session)
                            final user = sellerUser ?? await AuthService.loginSellerByMobile(mobile);
                            if (user != null) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => SellerMainNavScreen(seller: user)),
                                (route) => false,
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Enter Portal 🚪', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Change Number', style: TextStyle(color: Colors.black54)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final resendResult = await ApitxtOtpService.resendOtp(mobile);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resendResult['message'] ?? 'OTP Resent')),
                        );
                      }
                    },
                    child: const Text('Resend SMS', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Role Selection Dialog if Mobile is registered under multiple roles
  void _showRoleSelectionBottomSheet({
    required String mobile,
    required UserModel? sellerUser,
    required Map<String, dynamic>? deliveryBoy,
    required bool isAdminMobile,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(Icons.manage_accounts_rounded, size: 50, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Your Portal Role 👤',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Mobile +91 $mobile has multiple registered accounts. Select portal to enter:',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            if (sellerUser != null) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.storefront_rounded, color: Colors.white),
                label: Text('Enter as Seller (${sellerUser.name}) 🏪', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(bCtx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => SellerMainNavScreen(seller: sellerUser)),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            if (deliveryBoy != null) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white),
                label: Text('Enter as Delivery Partner (${deliveryBoy['name']}) 🚚', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await AuthService.saveDeliveryBoySession(deliveryBoy);
                  if (context.mounted) {
                    Navigator.pop(bCtx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => DeliveryBoyDashboardScreen(deliveryBoy: deliveryBoy)),
                      (route) => false,
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            if (isAdminMobile) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                label: const Text('Enter Admin Portal 🛡️', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(bCtx);
                  final adminUser = UserModel(id: 'admin_1', name: 'Administrator', username: 'admin', role: UserRole.admin);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => AdminDashboard(user: adminUser)),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Ambient soft glow circle
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing Header Logo Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 4,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Seller Portal Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    const Text(
                      'Login to manage your store & orders',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 28),

                // Dual Mode Tab Selector Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 0
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_android_rounded,
                                  size: 17,
                                  color: _selectedTab == 0 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Mobile OTP',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 0 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTab == 1
                                  ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.key_rounded,
                                  size: 17,
                                  color: _selectedTab == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ID & Password',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 1 ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
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
                const SizedBox(height: 24),

                // TAB 0: Mobile Number & OTP Form
                if (_selectedTab == 0)
                  Form(
                    key: _formKeyMobile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Registered Mobile Number',
                            hintText: 'Enter 10-digit mobile number',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('+91 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Mobile number is required';
                            }
                            final clean = val.replaceAll(RegExp(r'\D'), '');
                            if (clean.length < 10) {
                              return 'Enter valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleMobileLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'Send OTP SMS',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )

                // TAB 1: Username & Password Form
                else
                  Form(
                    key: _formKeyPassword,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Username / ID',
                            hintText: 'Enter Seller Username / ID',
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF8B5CF6)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePass,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B5CF6)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass ? Icons.visibility_off : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _handlePasswordLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Login to Portal',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
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
);
  }
}
