import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies picked images out of the (volatile) image_picker cache into the
/// app's permanent documents directory, so attached photos survive restarts.
/// The web has no filesystem: [persist] passes paths through untouched and
/// [downloadToFile] declines, so covers stay as network URLs there.
class MediaStorage {
  static const _uuid = Uuid();

  static Future<Directory> _mediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'media'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the new permanent path for [sourcePath].
  static Future<String> persist(String sourcePath) async {
    if (kIsWeb) return sourcePath; // no filesystem in the browser
    final dir = await _mediaDir();
    final ext = p.extension(sourcePath);
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Downloads an image [url] (e.g. a Google Place photo) into permanent
  /// storage and returns the local path, or null on failure. Follows
  /// redirects automatically.
  static Future<String?> downloadToFile(String url) async {
    if (kIsWeb) return null; // keep the network URL on web
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      final dir = await _mediaDir();
      final dest = p.join(dir.path, '${_uuid.v4()}.jpg');
      await File(dest).writeAsBytes(res.bodyBytes);
      return dest;
    } catch (_) {
      return null;
    }
  }
}
