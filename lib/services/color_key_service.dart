import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/processed_asset.dart';

class ColorKeyResult {
  ColorKeyResult({
    required this.keyColor,
    required this.pngBytes,
    required this.width,
    required this.height,
    required this.matchedRatio,
    this.shadow,
  });

  final KeyColor keyColor;
  final Uint8List pngBytes;
  final int width;
  final int height;
  final double matchedRatio;
  final GroundShadow? shadow;
}

class ColorKeyService {
  static const int _maxEdge = 1600;
  static const double _hardKey = 46;
  static const double _softKey = 58;
  static const double _outlineLuma = 48;

  ColorKeyResult process(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('画像を読み込めませんでした');
    }

    img.Image src = decoded;
    if (src.width > _maxEdge || src.height > _maxEdge) {
      src = img.copyResize(
        src,
        width: src.width >= src.height ? _maxEdge : null,
        height: src.height > src.width ? _maxEdge : null,
        interpolation: img.Interpolation.average,
      );
    }

    final winner = _detectKey(src);
    final keyed = img.Image(
      width: src.width,
      height: src.height,
      numChannels: 4,
    );

    var matched = 0;
    final total = src.width * src.height;

    for (final pixel in src) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final luma = 0.299 * r + 0.587 * g + 0.114 * b;
      final dist = _chromaDist(r, g, b, winner.r, winner.g, winner.b);
      final keyHue = _isKeyHue(r, g, b, winner);

      var alpha = 255;
      if (luma <= _outlineLuma) {
        alpha = 255;
      } else if (dist <= _hardKey || (keyHue && dist <= _softKey)) {
        alpha = 0;
        matched++;
      } else if (dist < _softKey) {
        final t = (dist - _hardKey) / (_softKey - _hardKey);
        alpha = (pow(t, 1.8) * 255).clamp(0, 255).toInt();
        matched++;
      }

      var outR = r;
      var outG = g;
      var outB = b;
      if (alpha > 0 && alpha < 255) {
        final spill = 1.0 - (alpha / 255.0);
        final despilled = _despill(r, g, b, winner, spill);
        outR = despilled.$1;
        outG = despilled.$2;
        outB = despilled.$3;
      }

      keyed.setPixelRgba(pixel.x, pixel.y, outR, outG, outB, alpha);
    }

    _erodeAlpha(keyed, times: 1);
    _contractHoles(keyed);

    return ColorKeyResult(
      keyColor: winner,
      pngBytes: Uint8List.fromList(img.encodePng(keyed)),
      width: keyed.width,
      height: keyed.height,
      matchedRatio: matched / total,
      shadow: _detectFeetShadow(keyed),
    );
  }

  KeyColor _detectKey(img.Image src) {
    final samples = <(int, int, int)>[];
    const inset = 4;
    final points = <(int, int)>[
      (inset, inset),
      (src.width - 1 - inset, inset),
      (inset, src.height - 1 - inset),
      (src.width - 1 - inset, src.height - 1 - inset),
      (src.width ~/ 2, inset),
      (src.width ~/ 2, src.height - 1 - inset),
    ];

    for (final p in points) {
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final x = (p.$1 + dx).clamp(0, src.width - 1);
          final y = (p.$2 + dy).clamp(0, src.height - 1);
          final pix = src.getPixel(x, y);
          samples.add((pix.r.toInt(), pix.g.toInt(), pix.b.toInt()));
        }
      }
    }

    final scores = <KeyColor, double>{
      for (final k in KeyColor.values) k: 0,
    };
    for (final s in samples) {
      for (final k in KeyColor.values) {
        final d = _chromaDist(s.$1, s.$2, s.$3, k.r, k.g, k.b);
        scores[k] = scores[k]! + (1 / (1 + d));
      }
    }

    var winner = KeyColor.pb;
    var best = -1.0;
    scores.forEach((k, v) {
      if (v > best) {
        best = v;
        winner = k;
      }
    });
    return winner;
  }

  double _chromaDist(int r, int g, int b, int kr, int kg, int kb) {
    final y1 = 0.299 * r + 0.587 * g + 0.114 * b;
    final y2 = 0.299 * kr + 0.587 * kg + 0.114 * kb;
    final cb1 = 128 + (-0.169 * r - 0.331 * g + 0.500 * b);
    final cr1 = 128 + (0.500 * r - 0.419 * g - 0.081 * b);
    final cb2 = 128 + (-0.169 * kr - 0.331 * kg + 0.500 * kb);
    final cr2 = 128 + (0.500 * kr - 0.419 * kg - 0.081 * kb);
    final dCb = cb1 - cb2;
    final dCr = cr1 - cr2;
    final dY = (y1 - y2) * 0.25;
    return sqrt(dCb * dCb + dCr * dCr + dY * dY);
  }

  bool _isKeyHue(int r, int g, int b, KeyColor key) {
    switch (key) {
      case KeyColor.bb:
        return b > r + 12 && b > g + 8;
      case KeyColor.pb:
        return r > g + 18 && r >= b;
      case KeyColor.yb:
        return r > b + 18 && g > b + 12;
    }
  }

  (int, int, int) _despill(int r, int g, int b, KeyColor key, double amount) {
    final kr = key.r.toDouble();
    final kg = key.g.toDouble();
    final kb = key.b.toDouble();
    final gray = 0.299 * r + 0.587 * g + 0.114 * b;
    final nr = (r - (kr - gray) * amount * 0.35).clamp(0, 255).toInt();
    final ng = (g - (kg - gray) * amount * 0.35).clamp(0, 255).toInt();
    final nb = (b - (kb - gray) * amount * 0.35).clamp(0, 255).toInt();
    return (nr, ng, nb);
  }

  void _erodeAlpha(img.Image image, {int times = 1}) {
    final w = image.width;
    final h = image.height;
    for (var t = 0; t < times; t++) {
      final snapshot = List<int>.generate(w * h, (i) {
        final x = i % w;
        final y = i ~/ w;
        return image.getPixel(x, y).a.toInt();
      });
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final a = snapshot[y * w + x];
          if (a == 0) continue;
          final p = image.getPixel(x, y);
          final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
          if (luma <= _outlineLuma) continue;

          var kill = false;
          if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
            kill = true;
          } else {
            for (var dy = -1; dy <= 1 && !kill; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                if (snapshot[(y + dy) * w + (x + dx)] == 0) {
                  kill = true;
                  break;
                }
              }
            }
          }
          if (kill) {
            image.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
          }
        }
      }
    }
  }

  void _contractHoles(img.Image image) {
    final w = image.width;
    final h = image.height;
    final alpha = List<int>.generate(w * h, (i) {
      final x = i % w;
      final y = i ~/ w;
      return image.getPixel(x, y).a.toInt();
    });

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        if (alpha[i] == 0) continue;
        final p = image.getPixel(x, y);
        final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        if (luma <= _outlineLuma) continue;

        var transparentNeighbors = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (alpha[(y + dy) * w + (x + dx)] < 20) transparentNeighbors++;
          }
        }
        if (transparentNeighbors >= 6) {
          image.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 0);
        }
      }
    }
  }

  GroundShadow? _detectFeetShadow(img.Image image) {
    final w = image.width;
    final h = image.height;
    var minX = w, maxX = 0, minY = h, maxY = 0;
    var found = false;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (image.getPixel(x, y).a.toInt() < 20) continue;
        found = true;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (!found) return null;

    final boxW = (maxX - minX + 1).toDouble();
    final boxH = (maxY - minY + 1).toDouble();
    final band = (boxH * 0.14).clamp(10, 36).toInt();

    var bMinX = w, bMaxX = 0, bCount = 0;
    final xs = <int>[];
    for (var y = maxY - band; y <= maxY; y++) {
      if (y < 0) continue;
      for (var x = minX; x <= maxX; x++) {
        if (image.getPixel(x, y).a.toInt() < 20) continue;
        bCount++;
        xs.add(x);
        if (x < bMinX) bMinX = x;
        if (x > bMaxX) bMaxX = x;
      }
    }
    if (bCount < 8) return null;

    xs.sort();
    var bestGap = 0;
    for (var i = 1; i < xs.length; i++) {
      final gap = xs[i] - xs[i - 1];
      if (gap > bestGap) {
        bestGap = gap;
      }
    }

    final left = xs.first.toDouble();
    final right = xs.last.toDouble();
    final bottomW = (right - left + 1).clamp(8, boxW);
    if (bottomW > boxW * 0.78 && bestGap < boxW * 0.08) return null;

    return GroundShadow(
      cx: ((left + right) / 2) / w,
      cy: ((maxY + boxH * 0.012).clamp(0, h - 1)) / h,
      rx: (bottomW / w) * 0.92,
      ry: (bottomW / h) * 0.28,
    );
  }
}