import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../data/known_chains.dart';
import '../data/restaurant_database.dart';
import '../models/restaurant.dart';
import '../services/media_storage.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector.dart';
import '../widgets/place_autocomplete_field.dart';
import '../widgets/visit_form.dart';

/// Creates a new restaurant (with its first visit), or edits an existing
/// restaurant's identity (name/categories/chain/cover) when [existing] is set.
class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key, this.existing});

  final Restaurant? existing;

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _db = RestaurantDatabase.instance;
  final _places = PlacesService();
  final _picker = ImagePicker();
  final _visitKey = GlobalKey<VisitFormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _chainCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isChain = false;

  String? _placeId;
  double? _lat;
  double? _lng;
  String? _photoUrl;
  String? _customPhotoPath;
  final Set<String> _categories = {};

  bool _saving = false;
  bool _downloadingCover = false;

  // For smart chain detection.
  List<Restaurant> _existing = [];
  bool _userTouchedChain = false;

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
      _categories.addAll(e.categoryKeys);
      _isChain = e.isChain;
      _chainCtrl.text = e.chainName ?? '';
      _locationCtrl.text = e.locationLabel ?? '';
      _userTouchedChain = true; // don't auto-detect over an existing choice
    }
    _nameCtrl.addListener(_onNameChanged);
    _loadExisting();
  }

  void _onNameChanged() => _applyChainDetection(_nameCtrl.text);

  Future<void> _loadExisting() async {
    final all = await _db.getAll();
    if (!mounted) return;
    setState(() => _existing = widget.existing == null
        ? all
        : all.where((r) => r.id != widget.existing!.id).toList());
  }

  /// Detect a likely chain name from [name] using the user's own data first,
  /// then a list of well-known chains. Returns the chain's display name or null.
  String? _detectChain(String name) {
    final n = normalizeChain(name);
    if (n.length < 3) return null;
    for (final r in _existing) {
      final base = (r.chainName ?? r.name).trim();
      if (normalizeChain(base) == n) return base;
    }
    for (final c in kKnownChains) {
      final cl = normalizeChain(c);
      if (cl.length < 3) continue;
      if (n == cl || n.contains(cl)) return c;
    }
    return null;
  }

  void _applyChainDetection(String name) {
    if (_userTouchedChain || _isChain) return;
    final detected = _detectChain(name);
    if (detected == null) return;
    setState(() {
      _isChain = true;
      _chainCtrl.text = detected;
      if (_locationCtrl.text.trim().isEmpty && _addressCtrl.text.contains(',')) {
        _locationCtrl.text = _addressCtrl.text.split(',').first.trim();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Recognized "$detected" as a chain — '
              'confirm the location below.')),
    );
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _chainCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _toggleChain(bool on) {
    _userTouchedChain = true;
    setState(() {
      _isChain = on;
      if (on) {
        if (_chainCtrl.text.trim().isEmpty) {
          _chainCtrl.text = _nameCtrl.text.trim();
        }
        if (_locationCtrl.text.trim().isEmpty &&
            _addressCtrl.text.contains(',')) {
          _locationCtrl.text = _addressCtrl.text.split(',').first.trim();
        }
      }
    });
  }

  void _onPlaceSelected(PlaceDetails d) {
    setState(() {
      if (d.name.isNotEmpty) _nameCtrl.text = d.name;
      _addressCtrl.text = d.address;
      _lat = d.lat;
      _lng = d.lng;
      _photoUrl = d.photoUrl;
      _customPhotoPath = null;
      _downloadingCover = d.photoUrl != null;
    });
    if (d.photoUrl != null) _downloadCover(d.photoUrl!);
    _applyChainDetection(d.name);
  }

  Future<void> _downloadCover(String url) async {
    final local = await MediaStorage.downloadToFile(url);
    if (!mounted) return;
    setState(() {
      if (local != null) {
        _customPhotoPath = local;
        _photoUrl = null;
      }
      _downloadingCover = false;
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the restaurant a name first.')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final e = widget.existing;

    String? chainName;
    String? locationLabel;
    if (_isChain) {
      chainName = _chainCtrl.text.trim().isEmpty
          ? _nameCtrl.text.trim()
          : _chainCtrl.text.trim();
      locationLabel = _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim();
    }

    final restaurant = Restaurant(
      id: e?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      placeId: _placeId,
      lat: _lat,
      lng: _lng,
      photoUrl: _photoUrl,
      customPhotoPath: _customPhotoPath,
      categoryKeys: _categories.toList(),
      visits: _isEditing
          ? e!.visits
          : [_visitKey.currentState!.collect()],
      isChain: _isChain,
      chainName: _isChain ? chainName : null,
      locationLabel: _isChain ? locationLabel : null,
      createdAt: e?.createdAt ?? now,
      updatedAt: now,
      ownerId: e?.ownerId,
      visibility: e?.visibility ?? 'private',
      groupIds: e?.groupIds ?? const [],
    );

    await _db.upsert(restaurant);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final addressLocked = _lat != null && _lng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Restaurant' : 'New Restaurant'),
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
          _CoverPreview(
            networkUrl: _photoUrl,
            localPath: _customPhotoPath,
            loading: _downloadingCover,
            onPick: _pickCover,
          ),
          const SizedBox(height: 20),

          const _Label('Restaurant name'),
          if (AppConfig.hasPlacesKey)
            PlaceAutocompleteField(
              controller: _nameCtrl,
              placesService: _places,
              hint: 'Search a restaurant…',
              prefixIcon: Icons.restaurant_outlined,
              onPlaceSelected: _onPlaceSelected,
            )
          else
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Joe\'s Pizza'),
            ),
          const SizedBox(height: 18),

          Row(
            children: [
              const _Label('Address'),
              if (addressLocked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle,
                    color: Color(0xFF34C759), size: 16),
                const SizedBox(width: 4),
                Text('confirmed',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              hintText: AppConfig.hasPlacesKey
                  ? 'Picked automatically when you choose a restaurant'
                  : 'Enter address',
              prefixIcon: Icon(Icons.location_on_outlined, color: colors.subtle),
            ),
          ),
          if (AppConfig.hasPlacesKey)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Tip: search the name above and pick the right location to lock '
                'in the address & photo.',
                style: TextStyle(fontSize: 11.5, color: colors.subtle),
              ),
            ),
          const SizedBox(height: 24),

          const _Label('Categories'),
          const SizedBox(height: 10),
          CategorySelector(
            selected: _categories,
            editable: true,
            onChanged: (s) => setState(() {
              _categories
                ..clear()
                ..addAll(s);
            }),
          ),
          const SizedBox(height: 28),

          // ---- Chain ----
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _isChain,
                  onChanged: _toggleChain,
                  activeThumbColor: AppTheme.accent,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Part of a chain',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Groups all locations under one category',
                    style: TextStyle(fontSize: 12, color: colors.subtle),
                  ),
                  secondary:
                      Icon(Icons.storefront_outlined, color: colors.subtle),
                ),
                if (_isChain)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _chainCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Chain name',
                            hintText: 'e.g. Chipotle',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _locationCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'This location',
                            hintText: 'e.g. Times Square',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (!_isEditing) ...[
            Divider(color: colors.line),
            const SizedBox(height: 16),
            Text('First visit',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.ink)),
            const SizedBox(height: 16),
            VisitForm(key: _visitKey),
            const SizedBox(height: 30),
          ],

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
                _isEditing ? 'Save changes' : 'Save restaurant',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
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
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.networkUrl,
    required this.localPath,
    required this.loading,
    required this.onPick,
  });

  final String? networkUrl;
  final String? localPath;
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasLocal = localPath != null && localPath!.isNotEmpty;
    final hasNetwork = networkUrl != null && networkUrl!.isNotEmpty;

    Widget content;
    if (hasLocal) {
      content = Image.file(File(localPath!), fit: BoxFit.cover);
    } else if (hasNetwork) {
      content = CachedNetworkImage(imageUrl: networkUrl!, fit: BoxFit.cover);
    } else {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 32, color: colors.subtle),
            const SizedBox(height: 8),
            Text('Add a cover photo', style: TextStyle(color: colors.subtle)),
            Text('(auto-filled when you pick a restaurant)',
                style: TextStyle(color: colors.subtle, fontSize: 11)),
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
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (loading)
              Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            if (hasLocal || hasNetwork)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
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
