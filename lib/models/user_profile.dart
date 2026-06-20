/// A user account profile. In this preview it's stored locally; Phase 2's
/// Firebase integration will back it with real auth + Firestore.
class UserProfile {
  final String id;
  final String name;
  final String username;
  final String bio;

  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.bio = '',
  });

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserProfile copyWith({String? name, String? username, String? bio}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        username: username ?? this.username,
        bio: bio ?? this.bio,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'username': username, 'bio': bio};

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'You',
        username: j['username'] as String? ?? 'you',
        bio: j['bio'] as String? ?? '',
      );
}
