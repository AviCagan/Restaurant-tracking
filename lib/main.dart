import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'data/app_prefs.dart';
import 'data/auth_service.dart';
import 'data/block_store.dart';
import 'data/category_store.dart';
import 'data/firebase_services.dart';
import 'data/folder_store.dart';
import 'data/friend_group_store.dart';
import 'data/plan_store.dart';
import 'data/rating_bars_store.dart';
import 'firebase_options.dart';
import 'models/user_profile.dart';
import 'screens/add_home_screen_page.dart';
import 'screens/main_scaffold.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/web_bridge/web_bridge.dart' as web;
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  await CategoryStore.load();
  await AppPrefs.load();
  AppTheme.usePalette(AppPrefs.themeAccent.value);
  await RatingBarsStore.load();
  await FolderStore.load();
  await FriendGroupStore.load();
  await PlanStore.load();
  await BlockStore.load();
  await AuthService.load();

  // Cloud layer — if Firebase isn't configured on this machine, the app
  // simply keeps running local-only.
  try {
    var options = DefaultFirebaseOptions.currentPlatform;
    // Web: point authDomain at the domain the app is actually served
    // from. Firebase Hosting serves the /__/auth helpers on every one of
    // its domains, and a SAME-origin auth flow is the documented fix for
    // Safari 16.1+/iOS blocking third-party storage during sign-in.
    // https://firebase.google.com/docs/auth/web/redirect-best-practices
    final host = Uri.base.host;
    if (kIsWeb && host.isNotEmpty && host != 'localhost') {
      options = FirebaseOptions(
        apiKey: options.apiKey,
        appId: options.appId,
        messagingSenderId: options.messagingSenderId,
        projectId: options.projectId,
        authDomain: host,
        databaseURL: options.databaseURL,
        storageBucket: options.storageBucket,
        measurementId: options.measurementId,
      );
    }
    await Firebase.initializeApp(options: options);
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
                      return ValueListenableBuilder<bool>(
                        valueListenable: AppPrefs.a2hsSeen,
                        builder: (context, a2hsSeen, _) {
                          final Widget screen;
                          if (needsSetup) {
                            screen = const ProfileSetupScreen();
                          } else if (user != null || localMode) {
                            // Web only, once: nudge to add YUMS to the
                            // home screen (skip if already installed).
                            screen = kIsWeb &&
                                    !a2hsSeen &&
                                    !web.isStandalonePwa()
                                ? const AddHomeScreenPage()
                                : const MainScaffold();
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
