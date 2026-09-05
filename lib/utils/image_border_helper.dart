import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageBorderHelper {
  /// Converts white or near-white background pixels in an image to transparent (Alpha = 0)
  /// and returns a PNG base64 string ("data:image/png;base64,...").
  static Future<String> makeWhiteBackgroundTransparent(
    Uint8List bytes, {
    int whiteThreshold = 215,
  }) async {
    try {
      return await compute(_processImageBytes, {
        'bytes': bytes,
        'threshold': whiteThreshold,
      });
    } catch (_) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  static String _processImageBytes(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int threshold = params['threshold'] ?? 215;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }

    // Convert to RGBA (4 channels) so alpha channel exists
    final rgbaImage = decoded.convert(numChannels: 4);

    for (final frame in rgbaImage.frames) {
      for (final pixel in frame) {
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Check if pixel is near white
        if (r >= threshold && g >= threshold && b >= threshold) {
          pixel.a = 0; // Fully transparent!
        } else if (r >= threshold - 35 && g >= threshold - 35 && b >= threshold - 35) {
          // Smooth edge blending / anti-aliasing around border edges
          final avg = (r + g + b) / 3.0;
          final opacityRatio = (threshold - avg) / 35.0;
          final origAlpha = pixel.a.toDouble();
          pixel.a = (origAlpha * opacityRatio.clamp(0.0, 1.0)).toInt();
        }
      }
    }

    final pngBytes = img.encodePng(rgbaImage);
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }
}
