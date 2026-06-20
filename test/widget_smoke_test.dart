import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_tracker/models/restaurant.dart';
import 'package:restaurant_tracker/models/visit.dart';
import 'package:restaurant_tracker/models/category.dart';
import 'package:restaurant_tracker/theme/app_theme.dart';
import 'package:restaurant_tracker/widgets/haptic_slider.dart';
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

Visit _visit(int food, int atmos, int price) => Visit(
      id: 'v${food}_$atmos',
      date: DateTime.now(),
      foodRating: food,
      atmosphereRating: atmos,
      price: price,
    );

void main() {
  testWidgets('HapticSlider renders label, subtitle and value', (tester) async {
    await tester.pumpWidget(_wrap(HapticSlider(
      label: 'Food',
      subtitle: 'How good was the food?',
      value: 5,
      min: 1,
      max: 10,
      step: 1,
      haptic: SliderHaptic.heavy,
      onChanged: (_) {},
    )));

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('How good was the food?'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('Price slider shows custom value above its quick-pick max',
      (tester) async {
    await tester.pumpWidget(_wrap(HapticSlider(
      label: 'Price',
      value: 1200, // above the 1..500 range
      min: 1,
      max: 500,
      step: 10,
      haptic: SliderHaptic.light,
      valueLabelBuilder: (v) => '\$$v',
      onChanged: (_) {},
    )));

    expect(find.text('\$1200'), findsOneWidget); // chip shows true value
    expect(find.byType(Slider), findsOneWidget); // slider still renders (pinned)
  });

  testWidgets('RestaurantCard shows name, address, visits and avg score',
      (tester) async {
    // Two visits: overall = avg of (9+8)/2 and (7+8)/2 = (8.5 + 7.5)/2 = 8.0
    final r = _restaurant([_visit(9, 8, 30), _visit(7, 8, 20)]);

    await tester.pumpWidget(_wrap(RestaurantCard(restaurant: r)));

    expect(find.text('Joe\'s Pizza'), findsOneWidget);
    expect(find.text('7 Carmine St, New York'), findsOneWidget);
    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // overall badge
  });

  testWidgets('CategorySelector toggles a category on tap', (tester) async {
    Set<FoodCategory> selected = {};
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
    expect(selected.contains(FoodCategory.vegan), true);
  });
}
