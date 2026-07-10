/// Category names are the shared identity: every category's key is its
/// normalized label (see [norm]), identical for all users, so "Chinese 🥡"
/// and "chinese" are inherently the same category — no manual linking.
class CategoryMapping {
  /// Lowercase and strip everything but letters/digits, so "Chinese 🥡",
  /// "chinese" and "Chinese!" all count as the same category name. The
  /// canonical category keys and restaurant sync labels both use this.
  static String norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
