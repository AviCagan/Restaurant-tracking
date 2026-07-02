import 'package:flutter/material.dart';

import 'data/app_prefs.dart';
import 'data/auth_service.dart';
import 'data/category_mapping.dart';
import 'data/category_store.dart';
import 'data/folder_store.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  await CategoryStore.load();
  await CategoryMapping.load();
  await AppPrefs.load();
  await FolderStore.load();
  await AuthService.load();
  runApp(const RestaurantTrackerApp());
}

class RestaurantTrackerApp extends StatelessWidget {
  const RestaurantTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Restaurant Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const MainScaffold(),
        );
      },
    );
  }
}
