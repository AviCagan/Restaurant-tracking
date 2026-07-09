import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/firebase_services.dart';
import '../data/restaurant_database.dart';
import '../models/restaurant.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/sign_in_prompt.dart';
import 'all_restaurants_screen.dart';
import 'restaurant_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Restaurant> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await RestaurantDatabase.instance.getAll();
    if (mounted) setState(() => _all = all);
  }

  List<Restaurant> get _favorites =>
      _all.where((r) => r.isFavorite).toList();

  Future<void> _openDetail(Restaurant r) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r)));
    _load();
  }

  Future<void> _editProfile(UserProfile user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final userCtrl = TextEditingController(text: user.username);
    final bioCtrl = TextEditingController(text: user.bio);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 12),
            TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await AuthService.updateProfile(user.copyWith(
        name: nameCtrl.text.trim().isEmpty ? user.name : nameCtrl.text.trim(),
        username: userCtrl.text.trim().replaceAll('@', ''),
        bio: bioCtrl.text.trim(),
      ));
    }
  }

  /// Two-step account deletion: "are you sure?", then type CONFIRM
  /// (case sensitive) to actually delete.
  Future<void> _deleteAccount() async {
    const danger = Color(0xFFE0484D);
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This permanently removes your profile, username, friends, and '
            'everything you\'ve shared. This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final matches = ctrl.text == 'CONFIRM';
          return AlertDialog(
            title: const Text('Last step'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Type CONFIRM (all caps) to delete your account.'),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(hintText: 'CONFIRM'),
                  onChanged: (_) => setDialog(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  disabledBackgroundColor: danger.withValues(alpha: 0.3),
                ),
                onPressed: matches
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Delete forever'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await FirebaseAuthService.deleteAccount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Your account has been deleted. 👋')));
    // Back to the root so the welcome screen shows.
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Profile'),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          if (user == null) {
            return const SignInPrompt(
                message:
                    'Create a profile to share your ratings and follow friends.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(user.initials,
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 30)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('@${user.username}',
                        style: TextStyle(color: colors.subtle)),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.ink)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: AppTheme.panel(context, radius: 18),
                child: Row(
                  children: [
                    _Stat(label: 'Places visited', value: '${_all.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.favorite, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text('Favorites',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              if (_favorites.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tap the heart on a restaurant to add it here.',
                    style: TextStyle(color: colors.subtle),
                  ),
                )
              else
                ..._favorites.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RestaurantCard(
                        restaurant: r,
                        onTap: () => _openDetail(r),
                      ),
                    )),
              const SizedBox(height: 12),
              _Tile(
                icon: Icons.restaurant_menu,
                label: 'All my restaurants (${_all.length})',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AllRestaurantsScreen(
                        title: 'My Restaurants', restaurants: _all),
                  ),
                ),
              ),
              _Tile(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () => _editProfile(user),
              ),
              _Tile(
                icon: Icons.logout,
                label: 'Sign out',
                onTap: () async {
                  FirebaseAuthService.isCloudSignedIn
                      ? await FirebaseAuthService.signOut()
                      : await AuthService.signOut();
                  // Pop back to the root so the welcome screen shows,
                  // instead of this (now signed-out) profile page.
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
              _Tile(
                icon: Icons.delete_forever_outlined,
                label: 'Delete account',
                color: const Color(0xFFE0484D),
                onTap: _deleteAccount,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: colors.subtle)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.panel(context, radius: 16),
      child: ListTile(
        leading: Icon(icon, color: color ?? colors.ink),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: color)),
        trailing: Icon(Icons.chevron_right, color: colors.subtle),
        onTap: onTap,
      ),
    );
  }
}
