/// Ways the restaurant list can be ordered.
enum SortOption {
  newest('Newest'),
  ratingHigh('Rating · High to Low'),
  ratingLow('Rating · Low to High'),
  priceLow('Price · Low to High'),
  priceHigh('Price · High to Low'),
  nameAZ('Name · A to Z'),
  nameZA('Name · Z to A'),
  distanceNear('Distance · Nearest'),
  distanceFar('Distance · Farthest');

  const SortOption(this.label);
  final String label;

  bool get needsLocation =>
      this == SortOption.distanceNear || this == SortOption.distanceFar;
}
