/// Price represented as a 1–4 tier ($ to $$$$) instead of an exact amount.
class PriceTier {
  static const int min = 1;
  static const int max = 4;

  static const List<String> _signs = ['', '\$', '\$\$', '\$\$\$', '\$\$\$\$'];
  static const List<String> _ranges = [
    '',
    'Under \$20',
    'Under \$50',
    'Under \$100',
    '\$100+',
  ];

  static int clamp(int tier) => tier < min ? min : (tier > max ? max : tier);

  static String signs(int tier) => _signs[clamp(tier)];
  static String range(int tier) => _ranges[clamp(tier)];

  /// Old data stored an exact dollar amount; map it onto a tier.
  /// Values 1–4 are already tiers and pass through unchanged.
  static int fromStored(int value) {
    if (value >= min && value <= max) return value;
    if (value < 20) return 1;
    if (value < 50) return 2;
    if (value < 100) return 3;
    return 4;
  }
}
