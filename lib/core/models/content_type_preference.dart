import 'content_type.dart';

class ContentTypePreference {
  const ContentTypePreference({
    required this.type,
    required this.visible,
    required this.sortOrder,
  });

  final ContentType type;
  final bool visible;
  final int sortOrder;

  ContentTypePreference copyWith({
    bool? visible,
    int? sortOrder,
  }) {
    return ContentTypePreference(
      type: type,
      visible: visible ?? this.visible,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'visible': visible,
      'sortOrder': sortOrder,
    };
  }

  static ContentTypePreference? fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String?;
    if (typeName == null) return null;
    final type = ContentType.fromValue(typeName);
    return ContentTypePreference(
      type: type,
      visible: json['visible'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? type.index,
    );
  }
}
