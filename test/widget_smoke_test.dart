import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_tracker/models/restaurant.dart';
import 'package:restaurant_tracker/models/visit.dart';
import 'package:restaurant_tracker/theme/app_theme.dart';
import 'package:restaurant_tracker/widgets/tap_rating_bar.dart';
import 'package:restaurant_tracker/widgets/restaurant_card.dart';
import 'package:restaurant_tracker/widgets/category_selector.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

Restaurant _restaurant(List<Visit> visits) {
  final now = DateTime.now();
  return Restaurant(
    id: '1',
    name: 'Joe\'s Pizza',
    address: '7 Carmine St, New York',
    visits: visits,
    createdAt: now,
    updatedAt: now,
  );
}

Visit _visit(int food, int atmos, int priceTier) => Visit(
      id: 'v${food}_$atmos',
      date: DateTime.now(),
      foodRating: food,
      atmosphereRating: atmos,
      price: priceTier,
    );

void main() {
  testWidgets('TapRatingBar shows label, value and descriptor', (tester) async {
    await tester.pumpWidget(_wrap(TapRatingBar(
      label: 'Food',
      value: 5,
      onChanged: (_) {},
    )));

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Decent'), findsOneWidget); // word for 5
  });

  testWidgets('TapRatingBar shows Perfect at 10', (tester) async {
    await tester.pumpWidget(_wrap(TapRatingBar(
      label: 'Atmosphere',
      value: 10,
      onChanged: (_) {},
    )));

    expect(find.text('10'), findsOneWidget);
    expect(find.text('Perfect'), findsOneWidget);
  });

  testWidgets('RestaurantCard shows name, address, visits and avg score',
      (tester) async {
    // Two visits: overall = avg of (9+8)/2 and (7+8)/2 = (8.5 + 7.5)/2 = 8.0
    final r = _restaurant([_visit(9, 8, 3), _visit(7, 8, 2)]);

    await tester.pumpWidget(_wrap(RestaurantCard(restaurant: r)));

    expect(find.text('Joe\'s Pizza'), findsOneWidget);
    expect(find.text('7 Carmine St, New York'), findsOneWidget);
    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // overall badge
  });

  testWidgets('CategorySelector toggles a category on tap', (tester) async {
    Set<String> selected = {};
    await tester.pumpWidget(_wrap(
      StatefulBuilder(
        builder: (context, setState) => CategorySelector(
          selected: selected,
          onChanged: (s) => setState(() => selected = s),
        ),
      ),
    ));

    expect(selected.isEmpty, true);
    await tester.tap(find.text('Vegan'));
    await tester.pump();
    expect(selected.contains('vegan'), true);
  });
}
