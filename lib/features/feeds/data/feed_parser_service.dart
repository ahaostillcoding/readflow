import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../../core/models/content_type.dart';
import 'parsed_feed.dart';

class FeedParserService {
  FeedParserService(this._dio);

  final Dio _dio;

  Future<ParsedFeed> fetchAndParse(String url,
      {String category = 'Other'}) async {
    final response = await _dio.get<String>(url.trim());
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw const FormatException('The feed returned empty content.');
    }
    return parse(body, feedUrl: url.trim(), category: category);
  }

  ParsedFeed parse(String xmlText,
      {required String feedUrl, String category = 'Other'}) {
    final document = XmlDocument.parse(xmlText.trim());
    final root = document.rootElement;
    final rootName = root.name.local.toLowerCase();

    if (rootName == 'rss') {
      return _parseRss(root, feedUrl: feedUrl, category: category);
    }
    if (rootName == 'feed') {
      return _parseAtom(root, feedUrl: feedUrl, category: category);
    }
    if (rootName == 'rdf' || rootName == 'rdf:rdf') {
      return _parseRdf(root, feedUrl: feedUrl, category: category);
    }

    final channel = _firstDescendant(root, 'channel');
    if (channel != null) {
      return _parseRss(root, feedUrl: feedUrl, category: category);
    }

    throw const FormatException('Unsupported RSS, Atom, or RDF feed format.');
  }

  ParsedFeed _parseRss(XmlElement root,
      {required String feedUrl, required String category}) {
    final channel = _firstDescendant(root, 'channel') ?? root;
    final title = _text(_child(channel, 'title')) ?? feedUrl;
    final description = _text(_child(channel, 'description'));
    final siteUrl = _text(_child(channel, 'link'));
    final iconUrl = _text(_child(_child(channel, 'image'), 'url')) ??
        _text(_child(channel, 'icon'));

    final entries = _children(channel, 'item')
        .map(
            (item) => _parseRssItem(item, category: category, feedUrl: feedUrl))
        .whereType<ParsedEntry>()
        .toList();

    return ParsedFeed(
      title: _cleanText(title),
      feedUrl: feedUrl,
      siteUrl: siteUrl,
      description: description == null ? null : _cleanText(description),
      iconUrl: iconUrl,
      entries: entries,
    );
  }

  ParsedFeed _parseRdf(XmlElement root,
      {required String feedUrl, required String category}) {
    final title = _text(_child(root, 'title')) ?? feedUrl;
    final description = _text(_child(root, 'description'));
    final siteUrl = _text(_child(root, 'link'));
    final entries = _children(root, 'item')
        .map(
            (item) => _parseRssItem(item, category: category, feedUrl: feedUrl))
        .whereType<ParsedEntry>()
        .toList();

    return ParsedFeed(
      title: _cleanText(title),
      feedUrl: feedUrl,
      siteUrl: siteUrl,
      description: description == null ? null : _cleanText(description),
      entries: entries,
    );
  }

  ParsedFeed _parseAtom(XmlElement root,
      {required String feedUrl, required String category}) {
    final title = _text(_child(root, 'title')) ?? feedUrl;
    final description = _text(_child(root, 'subtitle'));
    final siteUrl = _atomLink(root, rel: 'alternate') ?? _atomLink(root);
    final iconUrl = _text(_child(root, 'icon')) ?? _text(_child(root, 'logo'));
    final entries = _children(root, 'entry')
        .map((entry) =>
            _parseAtomEntry(entry, category: category, feedUrl: feedUrl))
        .whereType<ParsedEntry>()
        .toList();

    return ParsedFeed(
      title: _cleanText(title),
      feedUrl: feedUrl,
      siteUrl: siteUrl,
      description: description == null ? null : _cleanText(description),
      iconUrl: iconUrl,
      entries: entries,
    );
  }

  ParsedEntry? _parseRssItem(XmlElement item,
      {required String category, required String feedUrl}) {
    final title = _text(_child(item, 'title')) ?? 'Untitled';
    final link = _resolveUrl(
      (_text(_child(item, 'link')) ?? _text(_child(item, 'origLink')) ?? '')
          .ifBlank(feedUrl),
      feedUrl,
    );
    final guid = _text(_child(item, 'guid')) ?? link.ifBlank(title);
    final rawSummary = _elementContent(_child(item, 'description'));
    final rawContent = _elementContent(_child(item, 'encoded')) ??
        _elementContent(_child(item, 'content')) ??
        rawSummary;
    final author =
        _text(_child(item, 'creator')) ?? _text(_child(item, 'author'));
    final imageUrl =
        _resolveNullableUrl(_imageFromItem(item, rawContent), link);
    final contentType = _inferContentType(
      category: category,
      feedUrl: feedUrl,
      title: title,
      summary: rawSummary,
    );

    return ParsedEntry(
      guid: guid,
      title: _cleanText(title),
      link: link,
      author: author == null ? null : _cleanText(author),
      summary: rawSummary == null ? null : _cleanText(_stripHtml(rawSummary)),
      contentHtml: _normalizeHtmlLinks(rawContent, link),
      imageUrl: imageUrl,
      publishedAt: _parseDate(
        _text(_child(item, 'pubDate')) ??
            _text(_child(item, 'published')) ??
            _text(_child(item, 'date')),
      ),
      contentType: contentType,
      extraJson: _extraJson(contentType, title, rawSummary, imageUrl),
      fullTextStatus: _fullTextStatus(rawSummary, rawContent),
    );
  }

  ParsedEntry? _parseAtomEntry(XmlElement entry,
      {required String category, required String feedUrl}) {
    final title = _text(_child(entry, 'title')) ?? 'Untitled';
    final link = _resolveUrl(
      (_atomLink(entry, rel: 'alternate') ?? _atomLink(entry) ?? '')
          .ifBlank(feedUrl),
      feedUrl,
    );
    final guid = _text(_child(entry, 'id')) ?? link.ifBlank(title);
    final rawSummary = _elementContent(_child(entry, 'summary'));
    final rawContent = _elementContent(_child(entry, 'content')) ?? rawSummary;
    final author = _text(_child(_child(entry, 'author'), 'name'));
    final imageUrl =
        _resolveNullableUrl(_imageFromItem(entry, rawContent), link);
    final contentType = _inferContentType(
      category: category,
      feedUrl: feedUrl,
      title: title,
      summary: rawSummary,
    );

    return ParsedEntry(
      guid: guid,
      title: _cleanText(title),
      link: link,
      author: author == null ? null : _cleanText(author),
      summary: rawSummary == null ? null : _cleanText(_stripHtml(rawSummary)),
      contentHtml: _normalizeHtmlLinks(rawContent, link),
      imageUrl: imageUrl,
      publishedAt: _parseDate(
          _text(_child(entry, 'published')) ?? _text(_child(entry, 'updated'))),
      contentType: contentType,
      extraJson: _extraJson(contentType, title, rawSummary, imageUrl),
      fullTextStatus: _fullTextStatus(rawSummary, rawContent),
    );
  }

  ContentType _inferContentType({
    required String category,
    required String feedUrl,
    required String title,
    String? summary,
  }) {
    final normalizedCategory = category.toLowerCase();
    final haystack = '$category $feedUrl $title ${summary ?? ''}'.toLowerCase();
    if (normalizedCategory == 'wechat' ||
        haystack.contains('wechat') ||
        haystack.contains('weixin')) {
      return ContentType.wechat;
    }
    if (normalizedCategory == 'novels' ||
        haystack.contains('novel') ||
        haystack.contains('chapter')) {
      return ContentType.novel;
    }
    if (normalizedCategory == 'movies' ||
        haystack.contains('movie') ||
        haystack.contains('film')) {
      return ContentType.movie;
    }
    if (normalizedCategory == 'news') return ContentType.news;
    if (normalizedCategory == 'articles') return ContentType.article;
    return ContentType.other;
  }

  String? _extraJson(
      ContentType type, String title, String? summary, String? imageUrl) {
    if (type == ContentType.novel) {
      final chapter =
          RegExp(r'(chapter\s*[0-9]+[^,._-]*)', caseSensitive: false)
              .firstMatch(title)
              ?.group(1);
      return jsonEncode({
        'novelTitle': chapter == null
            ? title
            : title.replaceFirst(chapter, '').trim().ifBlank(title),
        'chapterName': chapter ?? title,
      });
    }
    if (type == ContentType.movie) {
      final text = '$title ${summary ?? ''}';
      final rating = RegExp(r'([0-9](?:\.[0-9])?)\s*/\s*10').firstMatch(text);
      final release =
          RegExp(r'(20[0-9]{2}|19[0-9]{2})[-/][0-9]{1,2}[-/][0-9]{1,2}')
              .firstMatch(text);
      return jsonEncode({
        'movieTitle': title,
        'posterUrl': imageUrl,
        'rating': rating?.group(1),
        'releaseDate': release?.group(0),
      });
    }
    return null;
  }

  XmlElement? _child(XmlElement? element, String localName) {
    if (element == null) return null;
    for (final child in element.childElements) {
      if (child.name.local.toLowerCase() == localName.toLowerCase()) {
        return child;
      }
    }
    return null;
  }

  Iterable<XmlElement> _children(XmlElement element, String localName) {
    return element.childElements.where(
        (child) => child.name.local.toLowerCase() == localName.toLowerCase());
  }

  XmlElement? _firstDescendant(XmlElement element, String localName) {
    return element.descendantElements
        .where(
            (node) => node.name.local.toLowerCase() == localName.toLowerCase())
        .firstOrNull;
  }

  String? _text(XmlElement? element) {
    final text = element?.innerText.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _atomLink(XmlElement element, {String? rel}) {
    for (final link in _children(element, 'link')) {
      final linkRel = link.getAttribute('rel');
      if (rel != null && linkRel != rel) continue;
      final href = link.getAttribute('href');
      if (href != null && href.trim().isNotEmpty) return href.trim();
      final text = link.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _elementContent(XmlElement? element) {
    if (element == null) return null;
    final type = element.getAttribute('type')?.toLowerCase();
    if (type == 'xhtml') {
      final div = element.childElements
          .where((child) => child.name.local.toLowerCase() == 'div')
          .firstOrNull;
      final html = div?.innerXml.trim() ?? element.innerXml.trim();
      return html.isEmpty ? null : html;
    }
    if (type == 'html' || type == 'text/html') {
      final html = element.innerText.trim();
      return html.isEmpty ? null : html;
    }
    final xml = element.innerXml.trim();
    if (xml.contains('<![CDATA[') || xml.contains('<')) {
      final content = element.innerText.trim();
      return content.isEmpty ? null : content;
    }
    final text = element.innerText.trim();
    return text.isEmpty ? null : text;
  }

  String? _imageFromItem(XmlElement item, String? html) {
    for (final child in item.childElements) {
      final local = child.name.local.toLowerCase();
      final type = child.getAttribute('type') ?? '';
      if ((local == 'content' || local == 'thumbnail') &&
          child.getAttribute('url') != null) {
        if (local == 'thumbnail' || type.startsWith('image/')) {
          return child.getAttribute('url');
        }
      }
      if (local == 'enclosure' &&
          (child.getAttribute('type') ?? '').startsWith('image/')) {
        return child.getAttribute('url');
      }
    }
    if (html != null) {
      final document = html_parser.parse(html);
      final image = document.querySelector('img');
      return image?.attributes['src'];
    }
    return null;
  }

  String _stripHtml(String html) {
    return html_parser.parse(html).documentElement?.text ?? html;
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _resolveUrl(String value, String baseUrl) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return value.trim();
    if (uri.hasScheme) return uri.toString();
    final base = Uri.tryParse(baseUrl);
    return base == null ? value.trim() : base.resolveUri(uri).toString();
  }

  String? _resolveNullableUrl(String? value, String baseUrl) {
    if (value == null || value.trim().isEmpty) return null;
    return _resolveUrl(value, baseUrl);
  }

  String? _normalizeHtmlLinks(String? html, String baseUrl) {
    if (html == null || html.trim().isEmpty) return html;
    final fragment = html_parser.parseFragment(html);
    for (final image in fragment.querySelectorAll('img')) {
      final src = image.attributes['src'];
      if (src != null) image.attributes['src'] = _resolveUrl(src, baseUrl);
    }
    for (final link in fragment.querySelectorAll('a')) {
      final href = link.attributes['href'];
      if (href != null) link.attributes['href'] = _resolveUrl(href, baseUrl);
    }
    return fragment.nodes.map(_serializeHtmlNode).join();
  }

  String _serializeHtmlNode(dom.Node node) {
    if (node is dom.Element) return node.outerHtml;
    if (node is dom.Text) return node.data;
    return node.text ?? '';
  }

  String _fullTextStatus(String? summary, String? content) {
    if (content == null || content.trim().isEmpty) return 'feed_summary';
    final contentText = _cleanText(_stripHtml(content));
    final summaryText = summary == null ? '' : _cleanText(_stripHtml(summary));
    if (contentText.length >= 800) return 'feed_full';
    if (summaryText.isNotEmpty && contentText.length > summaryText.length * 2) {
      return 'feed_full';
    }
    final lower = contentText.toLowerCase();
    if (lower.contains('read more') ||
        lower.contains('continue reading') ||
        contentText.contains('阅读全文')) {
      return 'feed_summary';
    }
    return contentText.length >= 450 ? 'feed_full' : 'feed_summary';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    final iso = DateTime.tryParse(normalized);
    if (iso != null) return iso;
    try {
      return HttpDate.parse(normalized);
    } catch (_) {
      return null;
    }
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

extension _BlankString on String {
  String ifBlank(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
