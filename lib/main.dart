import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'screens/role_selection_screen.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/dashboards/customer_dashboard.dart';
import 'screens/seller/seller_main_nav_screen.dart';
import 'screens/customer/customer_main_nav_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final currentUser = await AuthService.getCurrentUser();
  runApp(DailyMartApp(initialUser: currentUser));
}

class DailyMartApp extends StatelessWidget {
  final UserModel? initialUser;
  const DailyMartApp({super.key, this.initialUser});

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
