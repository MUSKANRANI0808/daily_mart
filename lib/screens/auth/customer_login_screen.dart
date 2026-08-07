import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/apitxt_otp_service.dart';
import '../customer/customer_main_nav_screen.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _mobileController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final mobile = _mobileController.text.trim();

      // Send OTP via Apitxt.com API
      final otpResult = await ApitxtOtpService.sendOtp(mobile);
      setState(() => _isLoading = false);

      if (mounted) {
        // Show OTP Verification Dialog
        _showOtpVerificationDialog(mobile, initialMessage: otpResult['message']);
      }
    }
  }

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
              // Header Icon
              const Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.mark_email_read_rounded, size: 34, color: Color(0xFF10B981)),
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
                style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
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
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
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

                        // Verify via ApitxtOtpService
                        final result = await ApitxtOtpService.verifyOtp(mobile, otp);
                        bool isSuccess = result['success'] == true;
                        if (!isSuccess) {
                          errorText = result['message'] ?? 'Invalid OTP code';
                        }

                        setModalState(() => isVerifying = false);

                        if (isSuccess) {
                          Navigator.pop(ctx);
                          _proceedWithLogin(mobile);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 10),

              // Resend OTP & Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
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
                    child: const Text('Resend SMS', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceedWithLogin(String mobile) async {
    setState(() => _isLoading = true);

    // 1. Sync & Restore customer profile and saved addresses from VPS Server Database for this mobile number
    await AuthService.fetchAndSyncCustomerProfileFromVps(mobile);

    // 2. Check if customer profile has Name
    final profile = await AuthService.getCustomerProfile(mobile);
    final existingName = (profile != null && profile['name'] != null) ? profile['name'].toString().trim() : '';
    final hasValidName = existingName.isNotEmpty && !existingName.startsWith('Customer');

    // 3. Check if customer address exists
    final prefs = await SharedPreferences.getInstance();
    final addrJsonStr = prefs.getString('customer_addresses_$mobile');
    bool hasAddress = false;
    if (addrJsonStr != null && addrJsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(addrJsonStr);
        hasAddress = list.isNotEmpty;
      } catch (_) {}
    }

    setState(() => _isLoading = false);

    if (!hasValidName || !hasAddress) {
      if (mounted) {
        _showCompleteProfileDialog(mobile, existingName: hasValidName ? existingName : null);
      }
    } else {
      final user = await AuthService.loginCustomer(mobile, customName: existingName);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => CustomerMainNavScreen(customer: user)),
          (route) => false,
        );
      }
    }
  }

  void _showCompleteProfileDialog(String mobile, {String? existingName}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingName ?? '');
    final houseController = TextEditingController();
    final buildingController = TextEditingController();
    final localityController = TextEditingController();
    final landmarkController = TextEditingController();
    final cityController = TextEditingController();
    final pincodeController = TextEditingController();
    String tag = 'Home';

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
                  // Icon Header
                  const Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFFDCFCE7),
                      child: Icon(Icons.person_pin_circle_rounded, size: 32, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Complete Customer Profile 👤📍',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please fill in your name and delivery address to proceed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // Name Field
                  TextFormField(
                    controller: nameController,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Your Full Name *',
                      hintText: 'Enter your name',
                      prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                  ),
                  const SizedBox(height: 14),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Delivery Address Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),

                  // Address Tag Selector
                  Row(
                    children: ['Home', 'Work', 'Other'].map((t) {
                      final isSelected = tag == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
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
                  const SizedBox(height: 12),

                  // Flat / House No
                  TextFormField(
                    controller: houseController,
                    decoration: InputDecoration(
                      labelText: 'Flat / House No. / Floor *',
                      prefixIcon: const Icon(Icons.other_houses_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Flat / House No.' : null,
                  ),
                  const SizedBox(height: 10),

                  // Street / Locality
                  TextFormField(
                    controller: localityController,
                    decoration: InputDecoration(
                      labelText: 'Street / Locality / Area *',
                      prefixIcon: const Icon(Icons.add_road_rounded, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter Street / Locality' : null,
                  ),
                  const SizedBox(height: 10),

                  // Landmark / Near Field
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
                  const SizedBox(height: 10),

                  // City & Pincode
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
                      const SizedBox(width: 10),
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
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final fullName = nameController.text.trim();
                        final prefs = await SharedPreferences.getInstance();

                        // 1. Save Address if provided
                        final newAddr = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'tag': tag,
                          'houseNo': houseController.text.trim(),
                          'building': buildingController.text.trim(),
                          'locality': localityController.text.trim(),
                          'landmark': landmarkController.text.trim(),
                          'city': cityController.text.trim(),
                          'pincode': pincodeController.text.trim(),
                          'receiverName': fullName,
                          'mobile': mobile,
                          'isDefault': true,
                        };

                        final existingAddrsStr = prefs.getString('customer_addresses_$mobile');
                        List<Map<String, dynamic>> addrsList = [];
                        if (existingAddrsStr != null && existingAddrsStr.isNotEmpty) {
                          try {
                            final List<dynamic> l = jsonDecode(existingAddrsStr);
                            addrsList = List<Map<String, dynamic>>.from(l);
                          } catch (_) {}
                        }
                        addrsList.insert(0, newAddr);
                        await AuthService.saveCustomerAddresses(mobile, addrsList);

                        // 2. Complete Customer Login with Custom Name
                        final user = await AuthService.loginCustomer(mobile, customName: fullName);

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerMainNavScreen(customer: user)),
                            (route) => false,
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Save & Continue 🚀',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
          // Background ambient soft glow circle
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
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
                color: const Color(0xFF059669).withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
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
                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
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
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                              ),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Customer Login',
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
                        'Enter your 10-digit mobile number to proceed',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 32),

                      // Input Form Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.08),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Mobile Number',
                                hintText: 'Enter 10-digit mobile',
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('+91 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
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
                                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Mobile number is required';
                                }
                                if (val.trim().length < 10) {
                                  return 'Enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text(
                                        'Continue as Customer ⚡',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
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
          ),
        ],
      ),
    );
  }
}
