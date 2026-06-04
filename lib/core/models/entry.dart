import 'content_type.dart';

class Entry {
  const Entry({
    required this.id,
    required this.feedId,
    required this.guid,
    required this.title,
    required this.link,
    required this.fetchedAt,
    required this.isRead,
    required this.isFavorite,
    required this.isLater,
    required this.readingProgress,
    required this.contentType,
    required this.sourceName,
    required this.category,
    this.author,
    this.summary,
    this.contentHtml,
    this.imageUrl,
    this.publishedAt,
    this.aiSummary,
    this.aiTags,
    this.fullTextStatus,
    this.extraJson,
  });

  final int id;
  final int feedId;
  final String guid;
  final String title;
  final String link;
  final String? author;
  final String? summary;
  final String? contentHtml;
  final String? imageUrl;
  final DateTime? publishedAt;
  final DateTime fetchedAt;
  final bool isRead;
  final bool isFavorite;
  final bool isLater;
  final double readingProgress;
  final String? aiSummary;
  final String? aiTags;
  final String? fullTextStatus;
  final ContentType contentType;
  final String? extraJson;
  final String sourceName;
  final String category;

  factory Entry.fromMap(Map<String, Object?> map) {
    return Entry(
      id: map['id'] as int,
      feedId: map['feed_id'] as int,
      guid: map['guid'] as String,
      title: map['title'] as String,
      link: map['link'] as String,
      author: map['author'] as String?,
      summary: map['summary'] as String?,
      contentHtml: map['content_html'] as String?,
      imageUrl: map['image_url'] as String?,
      publishedAt: _date(map['published_at'] as String?),
      fetchedAt: _date(map['fetched_at'] as String?) ?? DateTime.now(),
      isRead: (map['is_read'] as int) == 1,
      isFavorite: (map['is_favorite'] as int) == 1,
      isLater: (map['is_later'] as int) == 1,
      readingProgress: ((map['reading_progress'] as num?) ?? 0).toDouble(),
      aiSummary: map['ai_summary'] as String?,
      aiTags: map['ai_tags'] as String?,
      fullTextStatus: map['full_text_status'] as String?,
      contentType: ContentType.fromValue(map['content_type'] as String?),
      extraJson: map['extra_json'] as String?,
      sourceName: (map['source_name'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Other',
    );
  }

  List<String> get tagList {
    final tags = aiTags;
    if (tags == null || tags.trim().isEmpty) return const [];
    return tags.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
  }

  static DateTime? _date(String? value) {
    return value == null ? null : DateTime.tryParse(value);
  }
}
