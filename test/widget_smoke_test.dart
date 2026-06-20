import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_tracker/models/restaurant.dart';
import 'package:restaurant_tracker/widgets/haptic_slider.dart';
import 'package:restaurant_tracker/widgets/restaurant_card.dart';
import 'package:restaurant_tracker/widgets/category_selector.dart';
import 'package:restaurant_tracker/models/category.dart';

void main() {
  testWidgets('HapticSlider renders label, subtitle and value', (tester) async {
    int value = 5;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HapticSlider(
          label: 'Food',
          subtitle: 'How good was the food?',
          value: value,
          min: 1,
          max: 10,
          step: 1,
          haptic: SliderHaptic.heavy,
          onChanged: (v) => value = v,
        ),
      ),
    ));

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('How good was the food?'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('Price slider formats value with a dollar sign', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HapticSlider(
          label: 'Price',
          value: 120,
          min: 1,
          max: 500,
          step: 10,
          haptic: SliderHaptic.light,
          valueLabelBuilder: (v) => '\$$v',
          onChanged: (_) {},
        ),
      ),
    ));

    expect(find.text('\$120'), findsOneWidget);
  });

  testWidgets('RestaurantCard shows name, address and overall score',
      (tester) async {
    final now = DateTime.now();
    final r = Restaurant(
      id: '1',
      name: 'Joe\'s Pizza',
      address: '7 Carmine St, New York',
      foodRating: 9,
      atmosphereRating: 8, // overall = 8.5
      price: 25,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RestaurantCard(restaurant: r)),
    ));

    expect(find.text('Joe\'s Pizza'), findsOneWidget);
    expect(find.text('7 Carmine St, New York'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget); // overall rating badge
  });

  testWidgets('CategorySelector toggles a category on tap', (tester) async {
    Set<FoodCategory> selected = {};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => CategorySelector(
            selected: selected,
            onChanged: (s) => setState(() => selected = s),
          ),
        ),
      ),
    ));

    expect(selected.isEmpty, true);
    await tester.tap(find.text('Vegan'));
    await tester.pump();
    expect(selected.contains(FoodCategory.vegan), true);
  });
}
