import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the 3D viewport (which excludes the closet UI) and opens the
/// native share sheet.
class ScreenshotService {
  /// Returns null on success, or a user-facing error message.
  static Future<String?> captureAndShare(GlobalKey boundaryKey,
      {required String caption, Rect? origin}) async {
    try {
      final ctx = boundaryKey.currentContext;
      final boundary = ctx?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return 'Nothing to capture yet.';
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return 'Could not encode the picture.';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/glam_closet_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      final result = await SharePlus.instance.share(ShareParams(
        text: caption,
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: origin,
      ));
      if (result.status == ShareResultStatus.unavailable) {
        return 'Sharing is not available on this device.';
      }
      return null;
    } on FileSystemException catch (e) {
      return 'Could not save the picture (${e.osError?.message ?? e.message}).';
    } catch (e) {
      return 'Could not share the picture: $e';
    }
  }
}
