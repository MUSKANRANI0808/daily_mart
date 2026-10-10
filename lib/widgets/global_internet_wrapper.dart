import 'package:flutter/material.dart';
import '../services/network_service.dart';
import 'no_internet_screen.dart';

/// Global App-level wrapper that automatically intercepts and displays
/// the animated NoInternetScreen whenever connectivity is lost,
/// across all screens and user roles (Customer, Seller, Delivery Boy, Admin).
class GlobalInternetWrapper extends StatelessWidget {
  final Widget child;

  const GlobalInternetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.instance.isConnectedNotifier,
      builder: (context, isConnected, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: isConnected
              ? KeyedSubtree(
                  key: const ValueKey('app_online_content'),
                  child: child,
                )
              : KeyedSubtree(
                  key: const ValueKey('app_offline_screen'),
                  child: NoInternetScreen(
                    onRetry: () {
                      NetworkService.instance.checkConnection();
                    },
                  ),
                ),
        );
      },
    );
  }
}
