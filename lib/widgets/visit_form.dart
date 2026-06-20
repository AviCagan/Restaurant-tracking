import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/item.dart';
import '../models/price_tier.dart';
import '../models/visit.dart';
import '../services/media_storage.dart';
import '../theme/app_theme.dart';
import 'haptic_slider.dart';
import 'rating_picker_sheet.dart';

/// Editable form for a single visit (date, sliders, price tier, items,
/// photos, notes).
///
/// Parents drive it with a `GlobalKey<VisitFormState>` and call
/// [VisitFormState.collect] to read the resulting [Visit] on save.
class VisitForm extends StatefulWidget {
  const VisitForm({super.key, this.initial});

  final Visit? initial;

  @override
  VisitFormState createState() => VisitFormState();
}

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController price;
  int? rating;
  _ItemDraft({String name = '', int? price, this.rating})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price?.toString() ?? '');
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class VisitFormState extends State<VisitForm> {
  final _picker = ImagePicker();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  int _food = 5;
  int _atmosphere = 5;
  int _priceTier = 2;
  final List<_ItemDraft> _items = [];
  final List<String> _photoPaths = [];

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    if (v != null) {
      _date = v.date;
      _food = v.foodRating;
      _atmosphere = v.atmosphereRating;
      _priceTier = PriceTier.clamp(v.price);
      _notesCtrl.text = v.notes;
      _photoPaths.addAll(v.photoPaths);
      for (final it in v.items) {
        _items.add(
            _ItemDraft(name: it.name, price: it.price, rating: it.rating));
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  /// Read the current editor state as a [Visit].
  Visit collect() {
    final items = <Item>[];
    for (final d in _items) {
      final name = d.name.text.trim();
      if (name.isEmpty) continue;
      items.add(Item(
        name: name,
        price: int.tryParse(d.price.text.trim()),
        rating: d.rating,
      ));
    }
    return Visit(
      id: widget.initial?.id ?? const Uuid().v4(),
      date: _date,
      foodRating: _food,
      atmosphereRating: _atmosphere,
      price: _priceTier,
      notes: _notesCtrl.text.trim(),
      items: items,
      photoPaths: List.of(_photoPaths),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  static const _maxPhotos = 10;

  Future<void> _addPhotos() async {
    final remaining = _maxPhotos - _photoPaths.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Up to $_maxPhotos photos per visit.')),
      );
      return;
    }
    final imgs = await _picker.pickMultiImage(
        maxWidth: 1600, imageQuality: 85, limit: remaining);
    if (imgs.isEmpty) return;
    final persisted = <String>[];
    for (final img in imgs.take(remaining)) {
      persisted.add(await MediaStorage.persist(img.path));
    }
    if (!mounted) return;
    setState(() => _photoPaths.addAll(persisted));
    if (imgs.length > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the first $_maxPhotos were added.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Date ----
        const _SectionLabel('Date'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: colors.subtle),
                const SizedBox(width: 12),
                Text(DateFormat.yMMMMd().format(_date),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.edit_outlined, size: 16, color: colors.subtle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        HapticSlider(
          label: 'Food',
          subtitle: 'How good was the food? (1–10)',
          value: _food,
          min: 1,
          max: 10,
          step: 1,
          haptic: SliderHaptic.heavy,
          onChanged: (v) => setState(() => _food = v),
        ),
        const SizedBox(height: 18),
        HapticSlider(
          label: 'Atmosphere',
          subtitle: 'Customer service, restaurant style, seating, etc. (1–10)',
          value: _atmosphere,
          min: 1,
          max: 10,
          step: 1,
          haptic: SliderHaptic.heavy,
          onChanged: (v) => setState(() => _atmosphere = v),
        ),
        const SizedBox(height: 24),

        // ---- Price tier ----
        const _SectionLabel('Price'),
        const SizedBox(height: 10),
        _PriceTierSelector(
          selected: _priceTier,
          onChanged: (t) => setState(() => _priceTier = t),
        ),
        const SizedBox(height: 28),

        // ---- What did you get ----
        Row(
          children: [
            const _SectionLabel('What did you get?'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemDraft())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
            ),
          ],
        ),
        if (_items.isEmpty)
          Text('Optional — add dishes and rate each one.',
              style: TextStyle(fontSize: 12.5, color: colors.subtle)),
        ..._items.asMap().entries.map((e) => _ItemRow(
              key: ValueKey(e.value),
              draft: e.value,
              onRatingChanged: (r) => setState(() => e.value.rating = r),
              onRemove: () => setState(() {
                e.value.dispose();
                _items.removeAt(e.key);
              }),
            )),
        const SizedBox(height: 28),

        // ---- Photos ----
        Row(
          children: [
            const _SectionLabel('Photos'),
            const SizedBox(width: 8),
            Text('${_photoPaths.length}/$_maxPhotos',
                style: TextStyle(fontSize: 12.5, color: colors.subtle)),
          ],
        ),
        const SizedBox(height: 10),
        _PhotoGrid(
          paths: _photoPaths,
          canAdd: _photoPaths.length < _maxPhotos,
          onAdd: _addPhotos,
          onRemove: (p) => setState(() => _photoPaths.remove(p)),
        ),
        const SizedBox(height: 28),

        // ---- Notes ----
        const _SectionLabel('Notes'),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Anything extra about this visit…',
          ),
        ),
      ],
    );
  }
}

class _PriceTierSelector extends StatelessWidget {
  const _PriceTierSelector({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: List.generate(4, (i) {
        final tier = i + 1;
        final on = tier == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(tier);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: on ? AppTheme.accent : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: on ? AppTheme.accent : colors.line),
                ),
                child: Column(
                  children: [
                    Text(
                      PriceTier.signs(tier),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: on ? Colors.white : colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PriceTier.range(tier),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: on
                            ? Colors.white.withValues(alpha: 0.9)
                            : colors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.draft,
    required this.onRatingChanged,
    required this.onRemove,
  });

  final _ItemDraft draft;
  final ValueChanged<int?> onRatingChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: draft.name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Dish name',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: TextField(
              controller: draft.price,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: const InputDecoration(
                hintText: '\$',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final result = await RatingPickerSheet.show(
                context,
                title: draft.name.text.trim().isEmpty
                    ? 'Rate this dish'
                    : draft.name.text.trim(),
                current: draft.rating,
              );
              if (result != null) onRatingChanged(result == 0 ? null : result);
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: draft.rating != null
                    ? AppTheme.accent.withValues(alpha: 0.14)
                    : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: draft.rating != null
                        ? AppTheme.accent
                        : colors.line),
              ),
              child: Center(
                child: Text(
                  draft.rating?.toString() ?? '–',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color:
                        draft.rating != null ? AppTheme.accent : colors.subtle,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 18, color: colors.subtle),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.paths,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (canAdd)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.line),
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: colors.subtle),
            ),
          ),
        ...paths.map((path) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(path),
                      width: 84, height: 84, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(path),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            )),
      ],
    );
  }
}
