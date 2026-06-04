import '../../../core/models/content_type.dart';

class ParsedFeed {
  const ParsedFeed({
    required this.title,
    required this.feedUrl,
    required this.entries,
    this.siteUrl,
    this.description,
    this.iconUrl,
  });

  final String title;
  final String feedUrl;
  final String? siteUrl;
  final String? description;
  final String? iconUrl;
  final List<ParsedEntry> entries;
}

class ParsedEntry {
  const ParsedEntry({
    required this.guid,
    required this.title,
    required this.link,
    required this.contentType,
    this.author,
    this.summary,
    this.contentHtml,
    this.imageUrl,
    this.publishedAt,
    this.extraJson,
  });

  final String guid;
  final String title;
  final String link;
  final String? author;
  final String? summary;
  final String? contentHtml;
  final String? imageUrl;
  final DateTime? publishedAt;
  final ContentType contentType;
  final String? extraJson;
}
