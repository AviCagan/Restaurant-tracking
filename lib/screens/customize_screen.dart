import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../data/rating_bars_store.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';

/// Settings → Customize: theme color, rating bars, and haptics.
class CustomizeScreen extends StatelessWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Customize'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const _SectionLabel('Theme color'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: AppPrefs.themeAccent,
              builder: (context, current, _) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: List.generate(kPalettes.length, (i) {
                    final p = kPalettes[i];
                    final on = i == current;
                    return GestureDetector(
                      onTap: () {
                        Haptics.tick();
                        AppPrefs.setThemeAccent(i);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(p.accent, Colors.white, 0.30)!,
                                  p.accent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: on ? colors.ink : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: on
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 24)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(p.name,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight:
                                      on ? FontWeight.w800 : FontWeight.w600,
                                  color: on ? colors.ink : colors.subtle)),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Rating bars'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
                'These show up whenever you rate a visit. Add your own — '
                'like Service, Value, or Dessert.',
                style: TextStyle(fontSize: 12.5, color: colors.subtle)),
          ),
          ValueListenableBuilder<List<BarDef>>(
            valueListenable: RatingBarsStore.all,
            builder: (context, bars, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  children: [
                    for (final bar in bars) ...[
                      ListTile(
                        leading: Text(bar.emoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(bar.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: bar.subtitle.isEmpty
                            ? (bar.builtin
                                ? Text('Built-in',
                                    style: TextStyle(
                                        color: colors.subtle, fontSize: 12))
                                : null)
                            : Text(bar.subtitle,
                                style: TextStyle(
                                    color: colors.subtle, fontSize: 12)),
                        trailing:
                            Icon(Icons.edit_outlined, color: colors.subtle),
                        onTap: () => _editBar(context, bar),
                      ),
                      Divider(height: 1, color: colors.line),
                    ],
                    ListTile(
                      leading: Icon(Icons.add_circle_outline,
                          color: AppTheme.accent),
                      title: Text('Add a rating bar',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent)),
                      onTap: () => _editBar(context, null),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Haptics'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: AppPrefs.hapticStrength,
              builder: (context, strength, _) {
                const labels = ['None', 'Light', 'Medium', 'Strong'];
                return Row(
                  children: List.generate(4, (i) {
                    final on = i == strength;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () async {
                            await AppPrefs.setHapticStrength(i);
                            Haptics.step(); // feel the new strength
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: on ? AppTheme.accent : colors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: on ? AppTheme.accent : colors.line),
                            ),
                            child: Center(
                              child: Text(labels[i],
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          on ? Colors.white : colors.ink)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Add ([bar] == null) or edit a rating bar: emoji, title, description.
  Future<void> _editBar(BuildContext context, BarDef? bar) async {
    final titleCtrl = TextEditingController(text: bar?.title ?? '');
    final subCtrl = TextEditingController(text: bar?.subtitle ?? '');
    final emojiCtrl = TextEditingController(text: bar?.emoji ?? '⭐');

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return AlertDialog(
          title: Text(bar == null
              ? 'New rating bar'
              : 'Edit ${bar.builtin ? '"${bar.title}"' : 'bar'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: emojiCtrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26),
                        decoration: const InputDecoration(hintText: '⭐'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: titleCtrl,
                        autofocus: bar == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            hintText: 'Title — e.g. Service'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Description (optional)'),
                ),
                const SizedBox(height: 8),
                Text('Use the emoji key on your keyboard for the icon.',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
              ],
            ),
          ),
          actions: [
            if (bar != null && !bar.builtin)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'delete'),
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFE0484D))),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, 'save');
              },
              child: Text(bar == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );

    if (action == 'delete' && bar != null) {
      await RatingBarsStore.delete(bar.id);
      return;
    }
    if (action != 'save') return;

    final emojiText = emojiCtrl.text.trim();
    final emoji = emojiText.isEmpty
        ? '⭐'
        : emojiText.characters.first.toString();
    if (bar == null) {
      await RatingBarsStore.add(emoji, titleCtrl.text, subCtrl.text);
    } else {
      await RatingBarsStore.update(bar.copyWith(
        emoji: emoji,
        title: titleCtrl.text.trim(),
        subtitle: subCtrl.text.trim(),
      ));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}
