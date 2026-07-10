/// A user account profile. In this preview it's stored locally; Phase 2's
/// Firebase integration will back it with real auth + Firestore.
class UserProfile {
  final String id;
  final String name;
  final String username;
  final String bio;

  /// Profile picture as a base64-encoded small JPEG ('' = none). Kept tiny
  /// (~256px) so it fits comfortably inside the Firestore profile doc.
  final String photo;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.bio = '',
    this.photo = '',
  });

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserProfile copyWith(
          {String? name, String? username, String? bio, String? photo}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        username: username ?? this.username,
        bio: bio ?? this.bio,
        photo: photo ?? this.photo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'bio': bio,
        'photo': photo,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'You',
        username: j['username'] as String? ?? 'you',
        bio: j['bio'] as String? ?? '',
        photo: j['photo'] as String? ?? '',
      );
}
