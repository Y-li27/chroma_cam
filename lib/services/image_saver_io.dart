import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveJpeg(Uint8List jpeg, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(jpeg);
  await Gal.putImage(file.path, album: 'ChromaCam');
}