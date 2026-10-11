enum ChannelType { text, voice }

class ChannelCategory {
  final String id;
  final String companyId;
  final String name;
  final int sortOrder;

  ChannelCategory({
    required this.id,
    required this.companyId,
    required this.name,
    required this.sortOrder,
  });

  factory ChannelCategory.fromMap(Map<String, dynamic> data, String id) {
    return ChannelCategory(
      id: id,
      companyId: data['company_id'] ?? '',
      name: data['name'] ?? '',
      sortOrder: data['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'company_id': companyId, 'name': name, 'sort_order': sortOrder};
  }
}

class Channel {
  final String id;
  final String categoryId;
  final String companyId;
  final String name;
  final ChannelType type;
  final int sortOrder;

  Channel({
    required this.id,
    required this.categoryId,
    required this.companyId,
    required this.name,
    required this.type,
    required this.sortOrder,
  });

  factory Channel.fromMap(Map<String, dynamic> data, String id) {
    return Channel(
      id: id,
      categoryId: data['category_id'] ?? '',
      companyId: data['company_id'] ?? '',
      name: data['name'] ?? '',
      type: ChannelType.values.firstWhere(
        (e) => e.toString() == 'ChannelType.${data['type']}',
        orElse: () => ChannelType.text,
      ),
      sortOrder: data['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category_id': categoryId,
      'company_id': companyId,
      'name': name,
      'type': type.toString().split('.').last,
      'sort_order': sortOrder,
    };
  }
}
