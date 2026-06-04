enum ContentType {
  article,
  news,
  wechat,
  novel,
  movie,
  other;

  static ContentType fromValue(String? value) {
    return ContentType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ContentType.other,
    );
  }
}
