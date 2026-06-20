import 'package:flutter/material.dart';

import '../data/restaurant_database.dart';
import '../models/restaurant.dart';
import '../models/visit.dart';
import '../theme/app_theme.dart';
import '../widgets/visit_form.dart';

/// Adds a new visit to an existing restaurant, or edits an existing visit
/// when [visit] is provided.
class AddVisitScreen extends StatefulWidget {
  const AddVisitScreen({super.key, required this.restaurant, this.visit});

  final Restaurant restaurant;
  final Visit? visit;

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _db = RestaurantDatabase.instance;
  final _visitKey = GlobalKey<VisitFormState>();
  bool _saving = false;

  bool get _isEditing => widget.visit != null;

  Future<void> _save() async {
    setState(() => _saving = true);
    final newVisit = _visitKey.currentState!.collect();

    final visits = List<Visit>.of(widget.restaurant.visits);
    if (_isEditing) {
      final idx = visits.indexWhere((v) => v.id == widget.visit!.id);
      if (idx >= 0) {
        visits[idx] = newVisit;
      } else {
        visits.add(newVisit);
      }
    } else {
      visits.add(newVisit);
    }

    await _db.upsert(widget.restaurant.copyWith(visits: visits));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Visit' : 'Add Visit'),
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
          Text(widget.restaurant.name,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.ink)),
          if (widget.restaurant.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.restaurant.address,
                style: TextStyle(fontSize: 13, color: colors.subtle)),
          ],
          const SizedBox(height: 24),
          VisitForm(key: _visitKey, initial: widget.visit),
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
                _isEditing ? 'Save changes' : 'Save visit',
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
