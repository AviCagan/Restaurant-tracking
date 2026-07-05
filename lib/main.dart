import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/app_prefs.dart';
import 'data/auth_service.dart';
import 'data/category_mapping.dart';
import 'data/category_store.dart';
import 'data/firebase_services.dart';
import 'data/folder_store.dart';
import 'data/friend_group_store.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'screens/main_scaffold.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  await CategoryStore.load();
  await CategoryMapping.load();
  await AppPrefs.load();
  await FolderStore.load();
  await FriendGroupStore.load();
  await AuthService.load();

  // Cloud layer — if Firebase isn't configured on this machine, the app
  // simply keeps running local-only.
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    CloudBoot.init();
  } catch (e) {
    debugPrint('Firebase unavailable, running local-only: $e');
  }

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
          title: 'YUMS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: ValueListenableBuilder<bool>(
            valueListenable: CloudBoot.needsSetup,
            builder: (context, needsSetup, _) {
              return ValueListenableBuilder<UserProfile?>(
                valueListenable: AuthService.user,
                builder: (context, user, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: AppPrefs.localMode,
                    builder: (context, localMode, _) {
                      final Widget screen;
                      if (needsSetup) {
                        screen = const ProfileSetupScreen();
                      } else if (user != null || localMode) {
                        screen = const MainScaffold();
                      } else {
                        screen = const WelcomeScreen();
                      }
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: screen,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
