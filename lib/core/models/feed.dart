class Feed {
  const Feed({
    required this.id,
    required this.title,
    required this.url,
    required this.category,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.siteUrl,
    this.description,
    this.iconUrl,
    this.lastFetchAt,
    this.lastError,
  });

  final int id;
  final String title;
  final String url;
  final String? siteUrl;
  final String? description;
  final String? iconUrl;
  final String category;
  final bool enabled;
  final DateTime? lastFetchAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Feed.fromMap(Map<String, Object?> map) {
    return Feed(
      id: map['id'] as int,
      title: map['title'] as String,
      url: map['url'] as String,
      siteUrl: map['site_url'] as String?,
      description: map['description'] as String?,
      iconUrl: map['icon_url'] as String?,
      category: map['category'] as String,
      enabled: (map['enabled'] as int) == 1,
      lastFetchAt: _date(map['last_fetch_at'] as String?),
      lastError: map['last_error'] as String?,
      createdAt: _date(map['created_at'] as String?) ?? DateTime.now(),
      updatedAt: _date(map['updated_at'] as String?) ?? DateTime.now(),
    );
  }

  Feed copyWith({
    int? id,
    String? title,
    String? url,
    String? siteUrl,
    String? description,
    String? iconUrl,
    String? category,
    bool? enabled,
    DateTime? lastFetchAt,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Feed(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      siteUrl: siteUrl ?? this.siteUrl,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      lastFetchAt: lastFetchAt ?? this.lastFetchAt,
      lastError: lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _date(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }
}
