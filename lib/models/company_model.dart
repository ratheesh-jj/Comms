class Company {
  final String id;
  final String name;
  final String ownerId;
  final String iconUrl;
  final String bannerUrl;
  final String description;
  final List<String> tags;
  final List<String> members;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.iconUrl,
    required this.bannerUrl,
    required this.description,
    required this.tags,
    required this.members,
    required this.createdAt,
  });

  factory Company.fromMap(Map<String, dynamic> data, String id) {
    return Company(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['owner_id'] ?? '',
      iconUrl: data['icon_url'] ?? '',
      bannerUrl: data['banner_url'] ?? '',
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      members: List<String>.from(data['members'] ?? [data['owner_id'] ?? '']),
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'owner_id': ownerId,
      'icon_url': iconUrl,
      'banner_url': bannerUrl,
      'description': description,
      'tags': tags,
      'members': members,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
