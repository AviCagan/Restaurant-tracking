import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A bold gradient app bar that gives the app its colorful, friendly header.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      title: Text(title,
          style: AppTheme.heading(24, color: Colors.white)),
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.accentGradient),
      ),
    );
  }
}
