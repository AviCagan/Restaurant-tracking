import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'category_selector.dart';

/// Result of the filter sheet: selected category keys and selected chain names.
class FilterSelection {
  final Set<String> categories;
  final Set<String> chains;
  const FilterSelection(this.categories, this.chains);

  int get count => categories.length + chains.length;
}

/// Bottom sheet to filter by categories (manageable) and by chain.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.initialCategories,
    required this.initialChains,
    required this.availableChains,
  });

  final Set<String> initialCategories;
  final Set<String> initialChains;
  final List<String> availableChains;

  static Future<FilterSelection?> show(
    BuildContext context, {
    required Set<String> categories,
    required Set<String> chains,
    required List<String> availableChains,
  }) {
    return showModalBottomSheet<FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FilterSheet(
        initialCategories: categories,
        initialChains: chains,
        availableChains: availableChains,
      ),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Set<String> _categories = {...widget.initialCategories};
  late final Set<String> _chains = {...widget.initialChains};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = _categories.length + _chains.length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('Filter',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (total > 0)
                    TextButton(
                      onPressed: () => setState(() {
                        _categories.clear();
                        _chains.clear();
                      }),
                      child: Text('Clear',
                          style: TextStyle(color: colors.subtle)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Categories'),
                      Text(
                        'Tap to filter · long-press to delete · Add your own',
                        style:
                            TextStyle(fontSize: 11.5, color: colors.subtle),
                      ),
                      const SizedBox(height: 12),
                      CategorySelector(
                        selected: _categories,
                        editable: true,
                        onChanged: (s) => setState(() => _categories = s),
                      ),
                      if (widget.availableChains.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionTitle('Chains'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.availableChains.map((chain) {
                            final on = _chains.contains(chain);
                            return GestureDetector(
                              onTap: () => setState(() {
                                on
                                    ? _chains.remove(chain)
                                    : _chains.add(chain);
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: on ? AppTheme.accent : colors.surface,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: on
                                          ? AppTheme.accent
                                          : colors.line),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_outlined,
                                        size: 16,
                                        color: on
                                            ? Colors.white
                                            : colors.subtle),
                                    const SizedBox(width: 6),
                                    Text(
                                      chain,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: on ? Colors.white : colors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(
                      context, FilterSelection(_categories, _chains)),
                  child: Text(
                    total == 0
                        ? 'Show all'
                        : 'Apply $total filter${total == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
}
