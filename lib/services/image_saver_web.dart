import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveJpeg(Uint8List jpeg, String filename) async {
  final blob = html.Blob([jpeg], 'image/jpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}