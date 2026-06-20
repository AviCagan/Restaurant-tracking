import 'dart:async';

import 'package:flutter/material.dart';

import '../services/places_service.dart';
import '../theme/app_theme.dart';

/// Address field with Google Places autocomplete. When a suggestion is
/// tapped it resolves full [PlaceDetails] (name, coords, photo) via
/// [onPlaceSelected].
class PlaceAutocompleteField extends StatefulWidget {
  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.placesService,
    required this.onPlaceSelected,
    this.hint = 'Search address…',
  });

  final TextEditingController controller;
  final PlacesService placesService;
  final void Function(PlaceDetails details) onPlaceSelected;
  final String hint;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  Timer? _debounce;
  List<PlacePrediction> _suggestions = [];
  bool _loading = false;
  bool _suppress = false; // don't re-search right after a selection

  @override
  void initState() {
    super.initState();
    widget.placesService.newSession();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (_suppress) {
      _suppress = false;
      return;
    }
    _debounce?.cancel();
    final text = widget.controller.text;
    if (text.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text));
  }

  Future<void> _search(String text) async {
    setState(() => _loading = true);
    final results = await widget.placesService.autocomplete(text);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _loading = false;
    });
  }

  Future<void> _select(PlacePrediction p) async {
    setState(() {
      _suggestions = [];
      _loading = true;
    });
    final details = await widget.placesService.details(p.placeId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (details != null) {
      _suppress = true;
      widget.onPlaceSelected(details);
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.location_on_outlined,
                color: AppTheme.subtle),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _suggestions.take(5).map((p) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined,
                      color: AppTheme.subtle, size: 20),
                  title: Text(p.mainText,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: p.secondaryText.isEmpty
                      ? null
                      : Text(p.secondaryText,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _select(p),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
