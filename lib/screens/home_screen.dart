import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/processed_asset.dart';
import '../services/color_key_service.dart';
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ColorKeyService();
  final _assets = <ProcessedAsset>[];
  bool _busy = false;
  String? _status;

  Future<void> _pickAndProcess() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _busy = true;
      _status = '透過処理中…';
    });

    var added = 0;
    var failed = 0;
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        failed++;
        continue;
      }
      try {
        final out = _service.process(bytes);
        _assets.add(
          ProcessedAsset(
            id: const Uuid().v4(),
            sourceName: file.name,
            keyColor: out.keyColor,
            pngBytes: out.pngBytes,
            width: out.width,
            height: out.height,
            shadow: out.shadow,
          ),
        );
        added++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = failed == 0
          ? '$added 件を追加しました'
          : '$added 件追加 / $failed 件は判別できませんでした';
    });
  }

  void _remove(String id) {
    setState(() => _assets.removeWhere((a) => a.id == id));
  }

  Future<void> _openCamera() async {
    if (_assets.where((a) => a.visible).isEmpty) {
      setState(() => _status = '表示中の素材がありません');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          assets: _assets.where((a) => a.visible).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChromaCam'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _Legend(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _status!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          Expanded(
            child: _assets.isEmpty
                ? const _EmptyHint()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (_, i) {
                      final asset = _assets[i];
                      return _AssetCard(
                        asset: asset,
                        onToggle: () =>
                            setState(() => asset.visible = !asset.visible),
                        onRemove: () => _remove(asset.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _pickAndProcess,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_assets.isEmpty ? 'ファイルを選ぶ' : '追加する'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0069FC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy || _assets.isEmpty ? null : _openCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('カメラで撮る'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF40671),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (final key in KeyColor.values) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: key.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(key.label, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 16),
          ],
          const Spacer(),
          Text(
            '自動判別 → 透過',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear,
              size: 56, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Text(
            'PB / BB / YB の素材を選んでください',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onToggle,
    required this.onRemove,
  });

  final ProcessedAsset asset;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: asset.visible ? 1 : 0.35,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: asset.keyColor.color.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _CheckerPainter()),
                    Image.memory(asset.pngBytes, fit: BoxFit.contain),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: asset.keyColor.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      asset.keyColor.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggle,
                    icon: Icon(
                      asset.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 10.0;
    final light = Paint()..color = const Color(0xFF2A2A33);
    final dark = Paint()..color = const Color(0xFF1E1E26);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), odd ? light : dark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}