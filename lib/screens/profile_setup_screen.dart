import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/category_store.dart';
import '../data/firebase_services.dart';
import '../models/category.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';

/// Quick first-time setup after Google sign-in: name, username, and picking
/// which categories you want. Everything can be changed later.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _nameCtrl =
      TextEditingController(text: FirebaseAuthService.suggestedName());
  late final _userCtrl =
      TextEditingController(text: FirebaseAuthService.suggestedUsername());
  bool _busy = false;

  /// Keys of the example categories the user tapped on.
  final Set<String> _picked = {};

  /// Categories the user created right here.
  final List<AppCategory> _custom = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Only keep what they actually chose (their own creations included).
    final chosen = [
      ...Catalog.starters.where((c) => _picked.contains(c.key)),
      ..._custom.where((c) => _picked.contains(c.key)),
    ];
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Pick at least one category — you can change them later.')));
      return;
    }
    setState(() => _busy = true);
    await CategoryStore.setAll(chosen);
    final error = await FirebaseAuthService.completeSetup(
        _nameCtrl.text, _userCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    // On success the app gate flips to MainScaffold automatically.
  }

  /// Create a category right here: name + icon.
  Future<void> _addCustom() async {
    final nameCtrl = TextEditingController();
    var iconIndex = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('New category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'e.g. Sushi'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                width: double.maxFinite,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryIcons.length - 1, // skip the chain icon
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final on = i == iconIndex;
                    return GestureDetector(
                      onTap: () => setDialog(() => iconIndex = i),
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(
                          color: on
                              ? AppTheme.accent.withValues(alpha: 0.18)
                              : dialogContext.colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: on
                                  ? AppTheme.accent
                                  : dialogContext.colors.line),
                        ),
                        child: Icon(categoryIcons[i],
                            size: 20,
                            color: on
                                ? AppTheme.accent
                                : dialogContext.colors.subtle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final label = nameCtrl.text.trim();
      final canonical = Catalog.keyFor(label);
      final cat = AppCategory(
        key: canonical.length >= 2
            ? canonical
            : 'custom_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        iconIndex: iconIndex,
      );
      Catalog.submit(label, iconIndex); // share it (best effort)
      setState(() {
        _custom.add(cat);
        _picked.add(cat.key); // you made it — obviously you want it
      });
    }
  }

  Widget _categoryCard(AppCategory c) {
    final colors = context.colors;
    final on = _picked.contains(c.key);
    return GestureDetector(
      onTap: () {
        Haptics.tick();
        setState(() => on ? _picked.remove(c.key) : _picked.add(c.key));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: on
              ? AppTheme.accent.withValues(alpha: 0.14)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: on ? AppTheme.accent : colors.line,
              width: on ? 2 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: on
                    ? AppTheme.accent
                    : AppTheme.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon,
                  size: 20, color: on ? Colors.white : AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(c.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: on ? AppTheme.accentDark : colors.ink)),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              scale: on ? 1 : 0,
              child: Icon(Icons.check_circle,
                  size: 20, color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addYourOwnCard() {
    final colors = context.colors;
    return GestureDetector(
      onTap: _addCustom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent, width: 1.4),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.add, size: 22, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Your own…',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Almost there! 🎉',
                    style: AppTheme.heading(28, color: Colors.white)),
                Text('Set up your profile in 30 seconds.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                Text('Your name',
                    style: AppTheme.heading(16, color: colors.ink)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'What friends call you'),
                ),
                const SizedBox(height: 20),
                Text('Pick a username',
                    style: AppTheme.heading(16, color: colors.ink)),
                const SizedBox(height: 4),
                Text('Friends add you with this — lowercase, no spaces.',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'username',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Pick your categories',
                        style: AppTheme.heading(16, color: colors.ink)),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _picked.isEmpty
                          ? const SizedBox.shrink()
                          : Container(
                              key: ValueKey(_picked.length),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${_picked.length} picked',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accentDark)),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tap what you eat — only those get added.',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.7,
                  children: [
                    ...Catalog.starters.map(_categoryCard),
                    ..._custom.map(_categoryCard),
                    _addYourOwnCard(),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.honey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All of this can be changed later from your profile '
                          'and settings.',
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.ink,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _finish,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Let\'s go!',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
