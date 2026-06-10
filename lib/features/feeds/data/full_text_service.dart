import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class FullTextResult {
  const FullTextResult({
    required this.contentHtml,
    this.title,
    this.imageUrl,
  });

  final String contentHtml;
  final String? title;
  final String? imageUrl;
}

class FullTextService {
  FullTextService(this._dio);

  final Dio _dio;

  Future<FullTextResult> fetch(
    String url, {
    String? includeSelector,
    String? excludeSelector,
  }) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ),
    );
    final html = response.data;
    if (html == null || html.trim().isEmpty) {
      throw const FormatException('The article page returned empty content.');
    }

    final document = html_parser.parse(html);
    _removeNoise(document);
    _removeBySelector(document, excludeSelector);

    final content = _selectContent(document, includeSelector);
    if (content == null) {
      throw const FormatException('Could not find article content.');
    }

    _normalizeLinks(content, url);
    final cleaned = _cleanHtml(content);
    if (_plainText(cleaned).length < 120) {
      throw const FormatException('Extracted article content is too short.');
    }

    return FullTextResult(
      title: document.querySelector('title')?.text.trim(),
      imageUrl: _firstImage(content),
      contentHtml: cleaned,
    );
  }

  dom.Element? _selectContent(dom.Document document, String? selector) {
    final normalized = selector?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      final selected = document.querySelector(normalized);
      if (selected != null) return selected;
    }

    for (final selector in const [
      'article',
      'main',
      '[role="main"]',
      '.article',
      '.post',
      '.entry-content',
      '.post-content',
      '.article-content',
      '#article',
      '#content',
    ]) {
      final element = document.querySelector(selector);
      if (_plainText(element?.outerHtml ?? '').length >= 240) {
        return element;
      }
    }

    dom.Element? best;
    var bestScore = 0;
    for (final element in document.querySelectorAll('body *')) {
      final paragraphs = element.querySelectorAll('p');
      if (paragraphs.length < 2) continue;
      final textLength = _plainText(element.outerHtml).length;
      final linkLength = element.querySelectorAll('a').fold<int>(
            0,
            (sum, link) => sum + link.text.trim().length,
          );
      final score = textLength - linkLength;
      if (score > bestScore) {
        best = element;
        bestScore = score;
      }
    }
    return best;
  }

  void _removeNoise(dom.Document document) {
    const selectors = [
      'script',
      'style',
      'noscript',
      'iframe',
      'nav',
      'footer',
      'header',
      'form',
      'aside',
      '.ad',
      '.ads',
      '.advertisement',
      '.comment',
      '.comments',
      '.share',
      '.social',
      '.related',
      '.recommend',
    ];
    for (final selector in selectors) {
      for (final element in document.querySelectorAll(selector)) {
        element.remove();
      }
    }
  }

  void _removeBySelector(dom.Document document, String? selector) {
    final normalized = selector?.trim();
    if (normalized == null || normalized.isEmpty) return;
    for (final element in document.querySelectorAll(normalized)) {
      element.remove();
    }
  }

  void _normalizeLinks(dom.Element element, String baseUrl) {
    for (final image in element.querySelectorAll('img')) {
      final src = image.attributes['src'];
      if (src != null) image.attributes['src'] = _resolveUrl(src, baseUrl);
    }
    for (final link in element.querySelectorAll('a')) {
      final href = link.attributes['href'];
      if (href != null) link.attributes['href'] = _resolveUrl(href, baseUrl);
    }
  }

  String _cleanHtml(dom.Element element) {
    const allowed = {
      'p',
      'br',
      'a',
      'img',
      'ul',
      'ol',
      'li',
      'blockquote',
      'pre',
      'code',
      'strong',
      'b',
      'em',
      'i',
      'h1',
      'h2',
      'h3',
      'h4',
      'figure',
      'figcaption',
    };
    for (final child in List<dom.Element>.from(element.querySelectorAll('*'))) {
      if (!allowed.contains(child.localName)) {
        child.attributes.clear();
        continue;
      }
      child.attributes.removeWhere(
        (key, _) =>
            key != 'href' && key != 'src' && key != 'alt' && key != 'title',
      );
    }
    return element.innerHtml.trim();
  }

  String? _firstImage(dom.Element element) {
    final src = element.querySelector('img')?.attributes['src'];
    return src == null || src.trim().isEmpty ? null : src.trim();
  }

  String _resolveUrl(String value, String baseUrl) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return value.trim();
    if (uri.hasScheme) return uri.toString();
    final base = Uri.tryParse(baseUrl);
    return base == null ? value.trim() : base.resolveUri(uri).toString();
  }

  String _plainText(String html) {
    return html_parser
            .parseFragment(html)
            .text
            ?.replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
  }
}
