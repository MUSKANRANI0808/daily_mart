import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// ProductBorderWrapper wraps any product image widget with a custom PNG border frame set by the seller.
class ProductBorderWrapper extends StatefulWidget {
  final Widget child;
  final String? borderImage;
  final String? sellerUsername;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry padding;

  const ProductBorderWrapper({
    super.key,
    required this.child,
    this.borderImage,
    this.sellerUsername,
    this.width,
    this.height,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ProductBorderWrapper> createState() => _ProductBorderWrapperState();
}

class _ProductBorderWrapperState extends State<ProductBorderWrapper> {
  String? _borderImg;

  @override
  void initState() {
    super.initState();
    _loadBorder();
  }

  @override
  void didUpdateWidget(covariant ProductBorderWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.borderImage != oldWidget.borderImage ||
        widget.sellerUsername != oldWidget.sellerUsername) {
      _loadBorder();
    }
  }

  Future<void> _loadBorder() async {
    if (widget.borderImage != null && widget.borderImage!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _borderImg = widget.borderImage;
        });
      }
      return;
    }

    final sUsername = widget.sellerUsername;
    if (sUsername != null && sUsername.isNotEmpty) {
      final cached = AuthService.getCachedSellerProductBorderImage(sUsername);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _borderImg = cached;
          });
        }
      }

      final fresh = await AuthService.getSellerProductBorderImage(sUsername);
      if (mounted && fresh != _borderImg) {
        setState(() {
          _borderImg = fresh;
        });
      }
    }
  }

  Widget _buildBorderOverlay(String borderData) {
    if (borderData.trim().isEmpty) return const SizedBox.shrink();

    Widget imgWidget;
    if (borderData.startsWith('http://') || borderData.startsWith('https://')) {
      imgWidget = Image.network(
        borderData,
        fit: BoxFit.fill,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      String base64Str = borderData;
      if (borderData.contains(',')) {
        base64Str = borderData.split(',').last.trim();
      }
      try {
        final bytes = base64Decode(base64Str);
        imgWidget = Image.memory(
          bytes,
          fit: BoxFit.fill,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imgWidget,
      );
    }
    return imgWidget;
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.borderImage ?? _borderImg;

    if (border == null || border.trim().isEmpty) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.padding != EdgeInsets.zero
            ? Padding(padding: widget.padding, child: widget.child)
            : widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: _buildBorderOverlay(border),
          ),
        ),
      ],
    );
  }
}
