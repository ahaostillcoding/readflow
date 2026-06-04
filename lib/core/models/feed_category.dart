class FeedCategory {
  const FeedCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;

  factory FeedCategory.fromMap(Map<String, Object?> map) {
    return FeedCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
    );
  }
}
