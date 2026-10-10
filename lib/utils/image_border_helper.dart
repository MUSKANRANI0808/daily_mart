import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ImageBorderHelper {
  /// Converts white or near-white background pixels in an image to transparent (Alpha = 0)
  /// using an ultra-fast outer flood-fill algorithm and returns a PNG base64 string ("data:image/png;base64,...").
  static Future<String> makeWhiteBackgroundTransparent(
    Uint8List bytes, {
    int whiteThreshold = 205,
  }) async {
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    try {
      return await compute(_processImageBytesWithParam, {
        'bytes': bytes,
        'threshold': whiteThreshold,
      }).timeout(
        const Duration(seconds: 4),
        onTimeout: () => processImageBytesSync(bytes, threshold: whiteThreshold),
      );
    } catch (_) {
      try {
        return processImageBytesSync(bytes, threshold: whiteThreshold);
      } catch (e) {
        final mime = isPng ? 'image/png' : 'image/jpeg';
        return 'data:$mime;base64,${base64Encode(bytes)}';
      }
    }
  }

  static String _processImageBytesWithParam(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int threshold = params['threshold'] ?? 205;
    return processImageBytesSync(bytes, threshold: threshold);
  }

  /// Removes white or near-white background from image bytes synchronously.
  /// Ultra-fast flat typed-array BFS from borders with zero GC overhead.
  static String processImageBytesSync(Uint8List bytes, {int threshold = 205}) {
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      final mime = isPng ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    // If image is already a transparent PNG (has alpha < 128 on borders or anywhere), keep it directly!
    if (decoded.hasAlpha) {
      int transparentPixels = 0;
      final pSample = decoded.getPixel(0, 0);
      for (int x = 0; x < decoded.width; x += 4) {
        decoded.getPixel(x, 0, pSample);
        if (pSample.a < 128) transparentPixels++;
        decoded.getPixel(x, decoded.height - 1, pSample);
        if (pSample.a < 128) transparentPixels++;
      }
      if (transparentPixels > 3) {
        // Already a transparent PNG! No heavy processing needed.
        if (isPng) {
          return 'data:image/png;base64,${base64Encode(bytes)}';
        }
        final pngBytes = img.encodePng(decoded);
        return 'data:image/png;base64,${base64Encode(pngBytes)}';
      }
    }

    // Downscale oversized images to max 650px for fast processing & lightweight storage
    if (decoded.width > 650 || decoded.height > 650) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 650 : null,
        height: decoded.height > decoded.width ? 650 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    final width = decoded.width;
    final height = decoded.height;
    final rgba = decoded.convert(numChannels: 4);

    final totalPixels = width * height;
    final visited = Uint8List(totalPixels);
    final queue = Int32List(totalPixels);
    int qHead = 0;
    int qTail = 0;

    final pCheck = rgba.getPixel(0, 0);

    bool isBackgroundPixel(img.Pixel p) {
      if (p.a == 0) return true;
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      // Pure or near white
      if (r >= threshold && g >= threshold && b >= threshold) return true;

      // Light grey / tint / shadow
      final avg = (r + g + b) / 3.0;
      final maxDiff = [ (r - g).abs(), (g - b).abs(), (b - r).abs() ].reduce((a, b) => a > b ? a : b);
      if (avg >= 195 && maxDiff <= 28) return true;
      if (avg >= 175 && maxDiff <= 16) return true;

      return false;
    }

    // Push all border pixels (top, bottom, left, right edges)
    for (int x = 0; x < width; x++) {
      for (final y in [0, height - 1]) {
        final idx = y * width + x;
        rgba.getPixel(x, y, pCheck);
        if (visited[idx] == 0 && isBackgroundPixel(pCheck)) {
          visited[idx] = 1;
          queue[qTail++] = idx;
        }
      }
    }
    for (int y = 0; y < height; y++) {
      for (final x in [0, width - 1]) {
        final idx = y * width + x;
        rgba.getPixel(x, y, pCheck);
        if (visited[idx] == 0 && isBackgroundPixel(pCheck)) {
          visited[idx] = 1;
          queue[qTail++] = idx;
        }
      }
    }

    // 4-way BFS flood fill with flat array (ultra-fast, zero allocations)
    final dx = [0, 0, 1, -1];
    final dy = [1, -1, 0, 0];

    while (qHead < qTail) {
      final cur = queue[qHead++];
      final cx = cur % width;
      final cy = cur ~/ width;

      // Set pixel transparent
      rgba.getPixel(cx, cy, pCheck);
      pCheck.a = 0;

      for (int i = 0; i < 4; i++) {
        final nx = cx + dx[i];
        final ny = cy + dy[i];
        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          final nidx = ny * width + nx;
          if (visited[nidx] == 0) {
            visited[nidx] = 1;
            rgba.getPixel(nx, ny, pCheck);
            if (isBackgroundPixel(pCheck)) {
              queue[qTail++] = nidx;
            } else {
              // Edge smoothing
              final avg = (pCheck.r + pCheck.g + pCheck.b) / 3.0;
              if (avg > threshold - 25) {
                final ratio = ((threshold - avg) / 25.0).clamp(0.1, 0.9);
                pCheck.a = (pCheck.a * ratio).toInt();
              }
            }
          }
        }
      }
    }

    final pngBytes = img.encodePng(rgba);
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }

  /// Converts any image format (JPG, JPEG, WEBP, etc.) to a clean PNG base64 string.
  /// If makeWhiteTransparent is true, removes white/near-white backgrounds.
  static Future<String> convertToPng(
    Uint8List bytes, {
    bool makeWhiteTransparent = true,
  }) async {
    final isPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;

    if (makeWhiteTransparent) {
      try {
        return await makeWhiteBackgroundTransparent(bytes, whiteThreshold: 205).timeout(
          const Duration(seconds: 4),
          onTimeout: () => isPng ? 'data:image/png;base64,${base64Encode(bytes)}' : processImageBytesSync(bytes),
        );
      } catch (_) {
        return isPng ? 'data:image/png;base64,${base64Encode(bytes)}' : 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    }

    if (isPng) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }

    try {
      return await compute(_processToPngOnly, bytes).timeout(
        const Duration(seconds: 4),
        onTimeout: () => _processToPngOnly(bytes),
      );
    } catch (_) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
  }

  static String _processToPngOnly(Uint8List bytes) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }
    if (decoded.width > 650 || decoded.height > 650) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 650 : null,
        height: decoded.height > decoded.width ? 650 : null,
        interpolation: img.Interpolation.linear,
      );
    }
    final pngBytes = img.encodePng(decoded);
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }

  /// Removes white background from an existing base64 image or HTTP URL.
  static Future<String?> removeWhiteFromExistingImage(String currentImg) async {
    final trimmed = currentImg.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.startsWith('data:image')) {
        final commaIdx = trimmed.indexOf(',');
        final base64Data = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(base64Data);
        return await makeWhiteBackgroundTransparent(bytes, whiteThreshold: 205);
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final res = await http.get(Uri.parse(trimmed)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return await makeWhiteBackgroundTransparent(res.bodyBytes, whiteThreshold: 205);
        }
      }
    } catch (_) {}
    return null;
  }
}

