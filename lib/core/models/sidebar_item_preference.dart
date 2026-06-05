enum SidebarItemType {
  page,
  category;
}

class SidebarItemPreference {
  const SidebarItemPreference({
    required this.type,
    required this.key,
    required this.visible,
    required this.sortOrder,
  });

  final SidebarItemType type;
  final String key;
  final bool visible;
  final int sortOrder;

  String get id => '${type.name}:$key';

  SidebarItemPreference copyWith({
    bool? visible,
    int? sortOrder,
  }) {
    return SidebarItemPreference(
      type: type,
      key: key,
      visible: visible ?? this.visible,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'key': key,
      'visible': visible,
      'sortOrder': sortOrder,
    };
  }

  static SidebarItemPreference? fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String?;
    final key = json['key'] as String?;
    if (typeName == null || key == null || key.trim().isEmpty) return null;
    final type = SidebarItemType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => SidebarItemType.page,
    );
    return SidebarItemPreference(
      type: type,
      key: key,
      visible: json['visible'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
