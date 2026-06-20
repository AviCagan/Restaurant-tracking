import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../data/restaurant_database.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../services/media_storage.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector.dart';
import '../widgets/haptic_slider.dart';
import '../widgets/place_autocomplete_field.dart';

class AddRatingScreen extends StatefulWidget {
  const AddRatingScreen({super.key, this.existing});

  /// When provided the screen edits an existing rating instead of creating.
  final Restaurant? existing;

  @override
  State<AddRatingScreen> createState() => _AddRatingScreenState();
}

class _AddRatingScreenState extends State<AddRatingScreen> {
  final _db = RestaurantDatabase.instance;
  final _places = PlacesService();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Place linkage
  String? _placeId;
  double? _lat;
  double? _lng;
  String? _photoUrl; // Google photo
  String? _customPhotoPath; // user-picked cover

  // Ratings
  int _food = 5;
  int _atmosphere = 5;
  int _price = 50;

  final Set<FoodCategory> _categories = {};
  final List<String> _mediaPaths = [];

  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _addressCtrl.text = e.address;
      _placeId = e.placeId;
      _lat = e.lat;
      _lng = e.lng;
      _photoUrl = e.photoUrl;
      _customPhotoPath = e.customPhotoPath;
      _food = e.foodRating;
      _atmosphere = e.atmosphereRating;
      _price = e.price;
      _categories.addAll(FoodCategory.fromKeys(e.categoryKeys));
      _mediaPaths.addAll(e.mediaPaths);
      _notesCtrl.text = e.notes;
    }
    _priceCtrl.text = _price.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onPlaceSelected(PlaceDetails d) {
    setState(() {
      if (_nameCtrl.text.trim().isEmpty && d.name.isNotEmpty) {
        _nameCtrl.text = d.name;
      }
      _addressCtrl.text = d.address;
      _lat = d.lat;
      _lng = d.lng;
      _photoUrl = d.photoUrl;
      // A newly selected place replaces a previous custom cover.
      _customPhotoPath = null;
    });
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) {
      final path = await MediaStorage.persist(x.path);
      if (mounted) setState(() => _customPhotoPath = path);
    }
  }

  Future<void> _addMedia() async {
    final imgs = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (imgs.isEmpty) return;
    final persisted = <String>[];
    for (final img in imgs) {
      persisted.add(await MediaStorage.persist(img.path));
    }
    if (mounted) setState(() => _mediaPaths.addAll(persisted));
  }

  void _setPrice(int value) {
    setState(() {
      _price = value;
      _priceCtrl.text = value.toString();
      _priceCtrl.selection =
          TextSelection.collapsed(offset: _priceCtrl.text.length);
    });
  }

  void _onPriceTyped(String raw) {
    final v = int.tryParse(raw);
    if (v == null) return;
    var clamped = v;
    if (clamped < 1) clamped = 1;
    if (clamped > 500) clamped = 500;
    setState(() => _price = clamped);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the restaurant a name first.')),
      );
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final existing = widget.existing;
    final restaurant = Restaurant(
      id: existing?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      placeId: _placeId,
      lat: _lat,
      lng: _lng,
      photoUrl: _photoUrl,
      customPhotoPath: _customPhotoPath,
      foodRating: _food,
      atmosphereRating: _atmosphere,
      price: _price,
      categoryKeys: _categories.map((c) => c.key).toList(),
      mediaPaths: _mediaPaths,
      notes: _notesCtrl.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      ownerId: existing?.ownerId,
      visibility: existing?.visibility ?? 'private',
      groupIds: existing?.groupIds ?? const [],
    );

    await _db.upsert(restaurant);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Rating' : 'New Rating'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.accent)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Cover photo preview
          _CoverPreview(
            networkUrl: _photoUrl,
            localPath: _customPhotoPath,
            onPick: _pickCover,
          ),
          const SizedBox(height: 20),

          _Label('Restaurant name'),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Joe\'s Pizza'),
          ),
          const SizedBox(height: 18),

          _Label('Address'),
          if (AppConfig.hasPlacesKey)
            PlaceAutocompleteField(
              controller: _addressCtrl,
              placesService: _places,
              onPlaceSelected: _onPlaceSelected,
            )
          else
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                hintText: 'Enter address',
                prefixIcon:
                    Icon(Icons.location_on_outlined, color: AppTheme.subtle),
              ),
            ),
          if (!AppConfig.hasPlacesKey)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Add a Google Maps API key to enable autocomplete & auto photos.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.subtle),
              ),
            ),
          const SizedBox(height: 28),

          // ---- Sliders ----
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
          const SizedBox(height: 18),
          HapticSlider(
            label: 'Price',
            subtitle: 'Roughly what you spent (1–500)',
            value: _price,
            min: 1,
            max: 500,
            step: 10,
            haptic: SliderHaptic.light,
            valueLabelBuilder: (v) => '\$$v',
            onChanged: _setPrice,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Exact amount',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.subtle,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: _onPriceTyped,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          _Label('Categories'),
          CategorySelector(
            selected: _categories,
            onChanged: (s) => setState(() {
              _categories
                ..clear()
                ..addAll(s);
            }),
          ),
          const SizedBox(height: 28),

          _Label('Photos'),
          _MediaGrid(
            paths: _mediaPaths,
            onAdd: _addMedia,
            onRemove: (path) => setState(() => _mediaPaths.remove(path)),
          ),
          const SizedBox(height: 28),

          _Label('Notes'),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Anything extra about the place…',
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _save,
              child: Text(
                _isEditing ? 'Save changes' : 'Save rating',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.networkUrl,
    required this.localPath,
    required this.onPick,
  });

  final String? networkUrl;
  final String? localPath;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasLocal = localPath != null && localPath!.isNotEmpty;
    final hasNetwork = networkUrl != null && networkUrl!.isNotEmpty;

    Widget content;
    if (hasLocal) {
      content = Image.file(File(localPath!), fit: BoxFit.cover);
    } else if (hasNetwork) {
      content = CachedNetworkImage(imageUrl: networkUrl!, fit: BoxFit.cover);
    } else {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 32, color: AppTheme.subtle),
            SizedBox(height: 8),
            Text('Add a cover photo',
                style: TextStyle(color: AppTheme.subtle)),
            Text('(auto-filled when you pick an address)',
                style: TextStyle(color: AppTheme.subtle, fontSize: 11)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (hasLocal || hasNetwork)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Change',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
            ),
            child: const Icon(Icons.add_photo_alternate_outlined,
                color: AppTheme.subtle),
          ),
        ),
        ...paths.map((path) {
          return Stack(
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
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
