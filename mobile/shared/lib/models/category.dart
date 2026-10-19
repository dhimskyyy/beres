/// Model Kategori Jasa Dinamis Beres v1.4.0 (FR-005, FR-036)
class JobCategory {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String iconName;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const JobCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.iconName,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String? ?? 'tools',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
