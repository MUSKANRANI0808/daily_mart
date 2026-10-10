import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'screens/role_selection_screen.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/dashboards/delivery_boy_dashboard.dart';
import 'screens/seller/seller_main_nav_screen.dart';
import 'screens/customer/customer_main_nav_screen.dart';

import 'services/notification_service.dart';
import 'services/background_notification_service.dart';
import 'services/network_service.dart';
import 'widgets/global_internet_wrapper.dart';
import 'utils/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  if (!kIsWeb) {
    await BackgroundNotificationService.initialize();
  }
  await NetworkService.instance.initialize();
  final currentDeliveryBoy = await AuthService.getDeliveryBoySession();
  final currentUser = await AuthService.getCurrentUser();
  Map<String, String>? initialSeller;
  if (currentUser != null && currentUser.role == UserRole.customer) {
    initialSeller = await AuthService.getLastSelectedSeller();
    if (initialSeller != null && (initialSeller['username'] ?? '').isNotEmpty) {
      // Warm up welcome popup cache in 0ms
      await AuthService.getSellerWelcomePopupImage(initialSeller['username']!);
    }
  }
  runApp(DailyMartApp(
    initialUser: currentUser,
    initialDeliveryBoy: currentDeliveryBoy,
    initialSeller: initialSeller,
  ));
}

class DailyMartApp extends StatelessWidget {
  final UserModel? initialUser;
  final Map<String, dynamic>? initialDeliveryBoy;
  final Map<String, String>? initialSeller;
  const DailyMartApp({
    super.key,
    this.initialUser,
    this.initialDeliveryBoy,
    this.initialSeller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppToast.navigatorKey,
      title: 'Daily Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return GlobalInternetWrapper(child: child ?? const SizedBox());
      },
      home: _getHomeScreen(),
    );
  }

  Widget _getHomeScreen() {
    if (initialDeliveryBoy != null) {
      return DeliveryBoyDashboardScreen(deliveryBoy: initialDeliveryBoy!);
    }
    if (initialUser != null) {
      switch (initialUser!.role) {
        case UserRole.admin:
          return AdminDashboard(user: initialUser!);
        case UserRole.seller:
          return SellerMainNavScreen(seller: initialUser!);
        case UserRole.customer:
          return CustomerMainNavScreen(
            customer: initialUser!,
            initialSeller: initialSeller,
          );
      }
    }
    return const RoleSelectionScreen();
  }
}
