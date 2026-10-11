class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String friendCode;
  final List<String> friends;
  final String status;
  final DateTime? lastSeen;
  final String? avatarUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.friendCode,
    required this.friends,
    this.status = 'offline',
    this.lastSeen,
    this.avatarUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['display_name'] ?? 'Unknown',
      friendCode: data['friend_code'] ?? '',
      friends: List<String>.from(data['friends'] ?? []),
      status: data['status'] ?? 'offline',
      lastSeen: data['last_seen'] != null
          ? DateTime.tryParse(data['last_seen'].toString())
          : null,
      avatarUrl: data['avatar_url'],
    );
  }

  /// Returns true if the user has been active in the last 2 minutes
  bool get isOnline {
    if (lastSeen == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    return diff.inMinutes < 2;
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'display_name': displayName,
      'friend_code': friendCode,
      'friends': friends,
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
      'avatar_url': avatarUrl,
    };
  }
}
