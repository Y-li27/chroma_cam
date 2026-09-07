import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/processed_asset.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.assets});

  final List<ProcessedAsset> assets;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const _landscapeAspect = 4 / 3;
  static const _portraitAspect = 3 / 4;

  final _boundaryKey = GlobalKey();
  CameraController? _controller;
  String? _error;
  bool _ready = false;
  bool _saving = false;
  bool _showPanel = true;
  int _lens = 0;
  int _selected = 0;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  Uint8List? _stillBytes;
  int _stillW = 1;
  int _stillH = 1;
  late final List<_Placement> _layers;

  bool get _landscape =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  double get _frameAspect =>
      _landscape ? _landscapeAspect : _portraitAspect;

  Offset _initialOffset(int i) =>
      Offset(28.0 + (i % 3) * 20, 48.0 + i * 24);

  @override
  void initState() {
    super.initState();
    _layers = [
      for (var i = 0; i < widget.assets.length; i++)
        _Placement(
          asset: widget.assets[i],
          offset: _initialOffset(i),
          scale: 0.55,
        ),
    ];
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      setState(() => _error = 'カメラ権限が必要です');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'カメラが見つかりません');
        return;
      }
      _lens = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_lens < 0) _lens = 0;
      await _bind(cameras[_lens]);
    } catch (_) {
      setState(() => _error = 'カメラ初期化に失敗しました');
    }
  }

  Future<void> _bind(CameraDescription desc) async {
    final old = _controller;
    final next = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = next;
    await old?.dispose();
    await next.initialize();
    _minZoom = await next.getMinZoomLevel();
    _maxZoom = await next.getMaxZoomLevel();
    _zoom = _minZoom;
    await next.setZoomLevel(_zoom);
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _setZoom(double value) async {
    final z = value.clamp(_minZoom, _maxZoom);
    setState(() => _zoom = z);
    await _controller?.setZoomLevel(z);
  }

  Future<void> _flip() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    _lens = (_lens + 1) % cameras.length;
    setState(() => _ready = false);
    await _bind(cameras[_lens]);
  }

  void _resetSelected() {
    if (_layers.isEmpty) return;
    final i = _selected.clamp(0, _layers.length - 1);
    setState(() {
      _layers[i].offset = _initialOffset(i);
      _layers[i].scale = 0.55;
      _layers[i].opacity = 1;
      _layers[i].visible = true;
      _layers[i].showShadow = true;
    });
  }

  void _resetAll() {
    setState(() {
      for (var i = 0; i < _layers.length; i++) {
        _layers[i].offset = _initialOffset(i);
        _layers[i].scale = 0.55;
        _layers[i].opacity = 1;
        _layers[i].visible = true;
        _layers[i].showShadow = true;
      }
    });
  }

  Future<void> _capture() async {
    if (_saving || !_ready || _controller == null) return;
    setState(() => _saving = true);
    try {
      final shot = await _controller!.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw StateError('撮影画像を読めませんでした');

      _stillBytes = bytes;
      _stillW = decoded.width;
      _stillH = decoded.height;
      setState(() {});

      if (mounted) {
        await precacheImage(MemoryImage(bytes), context);
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final ctx = _boundaryKey.currentContext;
      final boundary = ctx?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('描画領域を取得できません');
      final image = await boundary.toImage(pixelRatio: 2);
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      image.dispose();
      if (raw == null) throw StateError('画像化に失敗しました');

      final raster = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: raw.buffer,
        order: img.ChannelOrder.rgba,
      );
      final jpeg = img.encodeJpg(raster, quality: 86);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/chroma_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(jpeg);
      await Gal.putImage(file.path, album: 'ChromaCam');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アルバムへ保存しました')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました')),
      );
    } finally {
      _stillBytes = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  void _moveLayer(int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= _layers.length) return;
    setState(() {
      final item = _layers.removeAt(from);
      _layers.insert(to, item);
      _selected = to;
    });
  }

  Widget _cameraPreview() {
    if (_stillBytes != null) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _stillW.toDouble(),
            height: _stillH.toDouble(),
            child: Image.memory(
              _stillBytes!,
              width: _stillW.toDouble(),
              height: _stillH.toDouble(),
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
          ),
        ),
      );
    }

    final preview = _controller!.value.previewSize;
    if (preview == null || preview.width == 0 || preview.height == 0) {
      return CameraPreview(_controller!);
    }

    final sensorW = preview.width;
    final sensorH = preview.height;
    final childW =
        _landscape ? math.max(sensorW, sensorH) : math.min(sensorW, sensorH);
    final childH =
        _landscape ? math.min(sensorW, sensorH) : math.max(sensorW, sensorH);

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: childW,
          height: childH,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _frame() {
    return AspectRatio(
      aspectRatio: _frameAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: _cameraPreview(),
                ),
                for (var i = 0; i < _layers.length; i++)
                  if (_layers[i].visible)
                    _DraggableOverlay(
                      placement: _layers[i],
                      interactive: !_saving,
                      onSelect: () => setState(() => _selected = i),
                      onChanged: () => setState(() {}),
                    ),
              ],
            ),
          ),
          if (!_saving &&
              _showPanel &&
              _selected >= 0 &&
              _selected < _layers.length &&
              _layers[_selected].visible)
            _SelectionFrame(placement: _layers[_selected]),
        ],
      ),
    );
  }

  Widget _shutter() {
    return GestureDetector(
      onTap: _saving ? null : _capture,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        alignment: Alignment.center,
        child: _saving
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFF40671),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text(_error!)),
      );
    }
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _landscape ? _landscapeBody() : _portraitBody(),
      ),
    );
  }

  Widget _portraitBody() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: Center(child: _frame()),
        ),
        if (_showPanel && !_saving && _layers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _buildPanel(),
          ),
        const SizedBox(height: 8),
        _shutter(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _landscapeBody() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Center(child: _frame()),
              ),
            ],
          ),
        ),
        if (_showPanel && !_saving && _layers.isNotEmpty)
          SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: _buildPanel(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
          child: _shutter(),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          Text(
            _landscape ? '4:3  枠内を保存' : '3:4  枠内を保存',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showPanel = !_showPanel),
            icon: Icon(
              _showPanel ? Icons.visibility_off_outlined : Icons.tune,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              _showPanel ? '調整を隠す' : '調整を表示',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: _flip,
            icon: const Icon(
              Icons.cameraswitch_outlined,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    final layer = _layers[_selected.clamp(0, _layers.length - 1)];
    final canShadow = layer.asset.shadow != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _layers.length,
              onReorderItem: (from, to) {
                setState(() {
                  final item = _layers.removeAt(from);
                  _layers.insert(to, item);
                  _selected = to;
                });
              },
              itemBuilder: (_, i) {
                final item = _layers[i];
                final on = i == _selected;
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(item.asset.id),
                  index: i,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: on
                              ? const Color(0xFFF40671)
                              : Colors.white24,
                          width: on ? 2 : 1,
                        ),
                      ),
                      child: Opacity(
                        opacity: item.visible ? 1 : 0.35,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            item.asset.pngBytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                layer.asset.keyColor.label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: layer.showShadow ? '影を消す' : '影を出す',
                onPressed: canShadow
                    ? () => setState(() => layer.showShadow = !layer.showShadow)
                    : null,
                icon: Icon(
                  layer.showShadow
                      ? Icons.wb_shade_outlined
                      : Icons.wb_sunny_outlined,
                  color: canShadow
                      ? (layer.showShadow
                          ? const Color(0xFFFDB200)
                          : Colors.white)
                      : Colors.white24,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'この配置をリセット',
                onPressed: _resetSelected,
                icon: const Icon(Icons.restart_alt, color: Colors.white),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '全部リセット',
                onPressed: _resetAll,
                icon: const Icon(Icons.settings_backup_restore,
                    color: Colors.white),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _moveLayer(_selected, -1),
                icon: const Icon(Icons.flip_to_back, color: Colors.white),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _moveLayer(_selected, 1),
                icon: const Icon(Icons.flip_to_front, color: Colors.white),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => layer.visible = !layer.visible),
                icon: Icon(
                  layer.visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('カメラ',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  min: _minZoom,
                  max: _maxZoom <= _minZoom ? _minZoom + 0.01 : _maxZoom,
                  value: _zoom.clamp(_minZoom, _maxZoom),
                  onChanged: _maxZoom <= _minZoom ? null : _setZoom,
                  activeColor: Colors.white,
                ),
              ),
              Text(
                '${_zoom.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          Row(
            children: [
              const Text('不透明度',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: layer.opacity,
                  onChanged: (v) => setState(() => layer.opacity = v),
                  activeColor: const Color(0xFFF40671),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('大きさ',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Expanded(
                child: Slider(
                  min: 0.15,
                  max: 2.8,
                  value: layer.scale.clamp(0.15, 2.8),
                  onChanged: (v) => setState(() => layer.scale = v),
                  activeColor: const Color(0xFF0069FC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '保存はシャッター時点のプレビュー枠です。ピンクの選択枠は入りません。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _Placement {
  _Placement({
    required this.asset,
    required this.offset,
    required this.scale,
  });

  final ProcessedAsset asset;
  Offset offset;
  double scale;
  double opacity = 1;
  bool visible = true;
  bool showShadow = true;

  double get displayWidth => asset.width * scale * 0.35;
  double get displayHeight =>
      asset.height * (displayWidth / asset.width);
}

class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({required this.placement});

  final _Placement placement;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: placement.offset.dx - 2,
      top: placement.offset.dy - 2,
      width: placement.displayWidth + 4,
      height: placement.displayHeight + 4,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF40671), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _DraggableOverlay extends StatefulWidget {
  const _DraggableOverlay({
    required this.placement,
    required this.interactive,
    required this.onSelect,
    required this.onChanged,
  });

  final _Placement placement;
  final bool interactive;
  final VoidCallback onSelect;
  final VoidCallback onChanged;

  @override
  State<_DraggableOverlay> createState() => _DraggableOverlayState();
}

class _DraggableOverlayState extends State<_DraggableOverlay> {
  double _baseScale = 1;
  Offset _baseOffset = Offset.zero;

  static const double _pinchFeel = 0.35;

  @override
  Widget build(BuildContext context) {
    final p = widget.placement;
    return Positioned(
      left: p.offset.dx,
      top: p.offset.dy,
      child: GestureDetector(
        onTap: widget.onSelect,
        onScaleStart: widget.interactive
            ? (_) {
                widget.onSelect();
                _baseScale = p.scale;
                _baseOffset = p.offset;
              }
            : null,
        onScaleUpdate: widget.interactive
            ? (d) {
                final damped = 1 + (d.scale - 1) * _pinchFeel;
                p.scale = (_baseScale * damped).clamp(0.15, 2.8);
                p.offset = _baseOffset + d.focalPointDelta;
                _baseOffset = p.offset;
                widget.onChanged();
              }
            : null,
        child: Opacity(
          opacity: p.opacity,
          child: SizedBox(
            width: p.displayWidth,
            height: p.displayHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (p.showShadow && p.asset.shadow != null)
                  CustomPaint(
                    size: Size(p.displayWidth, p.displayHeight),
                    painter: _GroundShadowPainter(p.asset.shadow!),
                  ),
                Image.memory(
                  p.asset.pngBytes,
                  width: p.displayWidth,
                  height: p.displayHeight,
                  filterQuality: FilterQuality.high,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroundShadowPainter extends CustomPainter {
  _GroundShadowPainter(this.shadow);
  final GroundShadow shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = shadow.cx * size.width;
    final cy = (shadow.cy * size.height).clamp(0.0, size.height).toDouble();
    final rx = (shadow.rx * size.width).clamp(12.0, size.width * 0.55);
    final ry = (shadow.ry * size.height).clamp(5.0, 28.0);

    final soft = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + ry * 0.15),
        width: rx * 2.2,
        height: ry * 2.4,
      ),
      soft,
    );

    final core = Paint()
      ..color = const Color(0x99000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 1.7,
        height: ry * 1.5,
      ),
      core,
    );
  }

  @override
  bool shouldRepaint(covariant _GroundShadowPainter oldDelegate) =>
      oldDelegate.shadow != shadow;
}