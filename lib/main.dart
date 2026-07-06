import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/app_prefs.dart';
import 'data/auth_service.dart';
import 'data/category_mapping.dart';
import 'data/category_store.dart';
import 'data/firebase_services.dart';
import 'data/folder_store.dart';
import 'data/friend_group_store.dart';
import 'data/plan_store.dart';
import 'data/rating_bars_store.dart';
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
  AppTheme.usePalette(AppPrefs.themeAccent.value);
  await RatingBarsStore.load();
  await FolderStore.load();
  await FriendGroupStore.load();
  await PlanStore.load();
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

class RestaurantTrackerApp extends StatefulWidget {
  const RestaurantTrackerApp({super.key});

  @override
  State<RestaurantTrackerApp> createState() => _RestaurantTrackerAppState();
}

class _RestaurantTrackerAppState extends State<RestaurantTrackerApp>
    with SingleTickerProviderStateMixin {
  /// Glides the accent from the old palette to the new one; every tick
  /// updates [AppTheme.accent] and bumps [AppTheme.accentTick].
  late final AnimationController _accentCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  Color _fromAccent = AppTheme.accent;
  Color _fromDark = AppTheme.accentDark;

  @override
  void initState() {
    super.initState();
    AppPrefs.themeAccent.addListener(_retargetAccent);
    _accentCtrl.addListener(_stepAccent);
  }

  @override
  void dispose() {
    AppPrefs.themeAccent.removeListener(_retargetAccent);
    _accentCtrl.dispose();
    super.dispose();
  }

  void _retargetAccent() {
    // Start from wherever the color currently is (even mid-animation).
    _fromAccent = AppTheme.accent;
    _fromDark = AppTheme.accentDark;
    _accentCtrl.forward(from: 0);
  }

  void _stepAccent() {
    final target = kPalettes[
        AppPrefs.themeAccent.value.clamp(0, kPalettes.length - 1)];
    final t = Curves.easeInOutCubic.transform(_accentCtrl.value);
    AppTheme.accent =
        AppTheme.lerpAccentColor(_fromAccent, target.accent, t);
    AppTheme.accentDark =
        AppTheme.lerpAccentColor(_fromDark, target.accentDark, t);
    AppTheme.accentTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppTheme.accentTick,
      builder: (context, _, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.mode,
          builder: (context, mode, _) {
            return MaterialApp(
          title: 'YUMS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          // We animate the accent ourselves, frame by frame.
          themeAnimationDuration: Duration.zero,
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
      },
    );
  }
}
