import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/data/category_mapping.dart';

void main() {
  test('norm makes same-named categories identical across users', () {
    expect(CategoryMapping.norm('Chinese 🥡'), 'chinese');
    expect(CategoryMapping.norm('chinese'), 'chinese');
    expect(CategoryMapping.norm('CHINESE!'), 'chinese');
    expect(CategoryMapping.norm('Pizzaaaaaa 🍕'),
        isNot(CategoryMapping.norm('Pizza')));
    expect(CategoryMapping.norm('Fast Food'), 'fastfood');
    expect(CategoryMapping.norm('  Café 24/7  '), 'caf247');
  });
}
