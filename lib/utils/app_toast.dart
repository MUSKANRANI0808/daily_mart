import 'dart:async';
import 'package:flutter/material.dart';

/// Universal sleek, upper-center toast notification for DailyMart.
/// Displays a slim, premium pill message with no icons, slightly above center,
/// and automatically fades out without blocking user interaction.
class AppToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Shows an elegant toast message.
  /// Can be called as:
  ///   AppToast.show('Message');
  ///   AppToast.show(context, 'Message');
  static void show(
    dynamic contextOrMessage, [
    String? optionalMessage,
    Duration duration = const Duration(milliseconds: 2000),
  ]) {
    BuildContext? context;
    String rawMessage;

    if (contextOrMessage is BuildContext) {
      context = contextOrMessage;
      rawMessage = optionalMessage ?? '';
    } else {
      rawMessage = contextOrMessage?.toString() ?? '';
      if (optionalMessage != null && optionalMessage.isNotEmpty) {
        rawMessage = optionalMessage;
      }
    }

    // Clean message: strip leading/trailing icons, checkmarks, and emojis
    final message = _cleanText(rawMessage);
    if (message.isEmpty) return;

    // Resolve overlay
    OverlayState? overlay;
    if (context != null && context.mounted) {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    }
    overlay ??= navigatorKey.currentState?.overlay;

    if (overlay == null) {
      debugPrint('[AppToast] No overlay found to show toast: $message');
      return;
    }

    // Cancel existing toast immediately
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }

    late OverlayEntry entry;
    final stateKey = GlobalKey<_AppToastState>();

    entry = OverlayEntry(
      builder: (ctx) {
        return _AppToastWidget(
          key: stateKey,
          message: message,
          onDismissed: () {
            if (_currentEntry == entry) {
              try {
                entry.remove();
              } catch (_) {}
              _currentEntry = null;
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      stateKey.currentState?.hide();
    });
  }

  /// Removes emojis, checkmarks, box symbols, and leading/trailing bullets/icons
  static String _cleanText(String input) {
    if (input.isEmpty) return '';

    String text = input
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2B50}\u{2705}\u{2714}\u{2713}\u{274C}\u{26A0}]', unicode: true), '')
        .replaceAll('✓', '')
        .replaceAll('✔', '')
        .replaceAll('✅', '')
        .replaceAll('⚠️', '')
        .replaceAll('🚀', '')
        .replaceAll('✨', '')
        .replaceAll('📦', '')
        .replaceAll('🔒', '')
        .replaceAll('💵', '')
        .replaceAll('📄', '')
        .trim();

    text = text.replaceFirst(RegExp(r'^[\s\-:–—•]+'), '').trim();
    return text;
  }
}

class _AppToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const _AppToastWidget({
    super.key,
    required this.message,
    required this.onDismissed,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _controller.forward();
  }

  void hide() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Stack(
            children: [
              // Position: "bich ke thoda upr me aae" (Upper-center / slightly above middle)
              Align(
                alignment: const Alignment(0, -0.28),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: mediaQuery.size.width > 500 ? 60 : 28,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 9.5, // Thin/patla sleek pill theme
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF20F172A),
                        borderRadius: BorderRadius.circular(30), // Sleek capsule shape
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.25,
                          height: 1.35,
                          decoration: TextDecoration.none,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
