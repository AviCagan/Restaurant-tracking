import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies picked images out of the (volatile) image_picker cache into the
/// app's permanent documents directory, so attached photos survive restarts.
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
    final dir = await _mediaDir();
    final ext = p.extension(sourcePath);
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }
}
