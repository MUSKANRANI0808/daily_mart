import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'screens/role_selection_screen.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/dashboards/delivery_boy_dashboard.dart';
import 'screens/seller/seller_main_nav_screen.dart';
import 'screens/customer/customer_main_nav_screen.dart';

import 'services/notification_service.dart';
import 'services/background_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  await BackgroundNotificationService.initialize();
  final currentDeliveryBoy = await AuthService.getDeliveryBoySession();
  final currentUser = await AuthService.getCurrentUser();
  runApp(DailyMartApp(initialUser: currentUser, initialDeliveryBoy: currentDeliveryBoy));
}

class DailyMartApp extends StatelessWidget {
  final UserModel? initialUser;
  final Map<String, dynamic>? initialDeliveryBoy;
  const DailyMartApp({super.key, this.initialUser, this.initialDeliveryBoy});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
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
          return CustomerMainNavScreen(customer: initialUser!);
      }
    }
    return const RoleSelectionScreen();
  }
}
