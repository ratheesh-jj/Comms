class CompanyRole {
  final String id;
  final String companyId;
  final String name;
  final int color; // Hex color integer
  final int permissions; // Bitfield for permissions
  final int position;

  CompanyRole({
    required this.id,
    required this.companyId,
    required this.name,
    required this.color,
    required this.permissions,
    required this.position,
  });

  factory CompanyRole.fromMap(Map<String, dynamic> data, String docId) {
    return CompanyRole(
      id: docId,
      companyId: data['company_id'] ?? '',
      name: data['name'] ?? '',
      color: data['color'] ?? 0xFFFFFFFF,
      permissions: data['permissions'] ?? 0,
      position: data['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'name': name,
      'color': color,
      'permissions': permissions,
      'position': position,
    };
  }
}
