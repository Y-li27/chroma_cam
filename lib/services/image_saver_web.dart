// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> saveJpeg(Uint8List jpeg, String filename) async {
  final ua = html.window.navigator.userAgent;
  final ios = ua.contains('iPhone') ||
      ua.contains('iPad') ||
      ua.contains('iPod') ||
      (ua.contains('Macintosh') && ua.contains('Mobile'));

  if (ios) {
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [
        XFile.fromData(
          jpeg,
          name: filename,
          mimeType: 'image/jpeg',
        ),
      ],
    );
    return;
  }

  final blob = html.Blob([jpeg], 'image/jpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}