import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Small chooser: take a photo with the camera or pick from the library.
class PhotoSourceSheet extends StatelessWidget {
  const PhotoSourceSheet({super.key});

  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const PhotoSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: AppTheme.accent),
            title: const Text('Take a photo',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading:
                Icon(Icons.photo_library_outlined, color: AppTheme.accent),
            title: const Text('Choose from library',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
