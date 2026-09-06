import 'dart:typed_data';
import 'dart:ui' as ui;

enum KeyColor {
  pb('PB', 0xFFF40671),
  bb('BB', 0xFF0069FC),
  yb('YB', 0xFFFDB200);

  const KeyColor(this.label, this.hex);
  final String label;
  final int hex;

  ui.Color get color => ui.Color(0xFF000000 | hex);
  int get r => (hex >> 16) & 0xFF;
  int get g => (hex >> 8) & 0xFF;
  int get b => hex & 0xFF;
}

class GroundShadow {
  const GroundShadow({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
  });

  final double cx;
  final double cy;
  final double rx;
  final double ry;
}

class ProcessedAsset {
  ProcessedAsset({
    required this.id,
    required this.sourceName,
    required this.keyColor,
    required this.pngBytes,
    required this.width,
    required this.height,
    this.shadow,
    this.visible = true,
  });

  final String id;
  final String sourceName;
  final KeyColor keyColor;
  final Uint8List pngBytes;
  final int width;
  final int height;
  final GroundShadow? shadow;
  bool visible;
}