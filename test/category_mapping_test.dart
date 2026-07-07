import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/data/category_mapping.dart';
import 'package:restaurant_tracker/models/category.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CategoryMapping.map.value = {};
    CategoryMapping.hidden.value = {};
  });

  test('autoLink links same-named categories with different keys', () async {
    const mine = [
      AppCategory(key: 'custom_1', label: 'Chinese', iconIndex: 0),
      AppCategory(key: 'custom_2', label: 'Sushi', iconIndex: 1),
    ];
    const theirs = [
      AppCategory(key: 'custom_99', label: 'chinese 🥡', iconIndex: 3),
      AppCategory(key: 'custom_98', label: 'Burgers', iconIndex: 4),
    ];

    await CategoryMapping.autoLink(theirs, mine);

    expect(CategoryMapping.map.value['custom_99'], 'custom_1');
    expect(CategoryMapping.map.value.containsKey('custom_98'), false);
    expect(CategoryMapping.resolve('custom_99'), 'custom_1');
  });

  test('autoLink skips identical keys, manual links, and hidden', () async {
    const mine = [
      AppCategory(key: 'dairy', label: 'Dairy', iconIndex: 0),
      AppCategory(key: 'custom_1', label: 'Pizza', iconIndex: 1),
      AppCategory(key: 'custom_2', label: 'Cafe', iconIndex: 2),
    ];
    const theirs = [
      AppCategory(key: 'dairy', label: 'Dairy', iconIndex: 0), // same key
      AppCategory(key: 'their_pizza', label: 'PIZZA!', iconIndex: 5),
      AppCategory(key: 'their_cafe', label: 'Cafe', iconIndex: 6),
    ];

    await CategoryMapping.link('their_pizza', 'custom_2'); // manual wins
    await CategoryMapping.hide('their_cafe'); // dismissed stays dismissed

    await CategoryMapping.autoLink(theirs, mine);

    expect(CategoryMapping.map.value.containsKey('dairy'), false);
    expect(CategoryMapping.map.value['their_pizza'], 'custom_2');
    expect(CategoryMapping.map.value.containsKey('their_cafe'), false);
  });
}
