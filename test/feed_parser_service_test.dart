import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflow/core/models/content_type.dart';
import 'package:readflow/features/feeds/data/feed_parser_service.dart';

void main() {
  test('parses RSS 2.0 feeds', () {
    const xml = '''
<rss version="2.0">
  <channel>
    <title>Example Feed</title>
    <link>https://example.com</link>
    <description>Example description</description>
    <item>
      <title>First Article</title>
      <link>https://example.com/first</link>
      <guid>first</guid>
      <description><![CDATA[<p>Hello RSS</p>]]></description>
      <pubDate>Mon, 01 Jun 2026 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

    final parser = FeedParserService(Dio());
    final feed = parser.parse(xml,
        feedUrl: 'https://example.com/rss.xml', category: 'News');

    expect(feed.title, 'Example Feed');
    expect(feed.entries, hasLength(1));
    expect(feed.entries.first.title, 'First Article');
    expect(feed.entries.first.summary, 'Hello RSS');
    expect(feed.entries.first.contentType, ContentType.news);
  });

  test('parses Atom feeds', () {
    const xml = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Feed</title>
  <link href="https://example.com" rel="alternate"/>
  <entry>
    <title>Atom Article</title>
    <id>atom-1</id>
    <link href="https://example.com/atom-1" rel="alternate"/>
    <summary>Atom summary</summary>
    <updated>2026-06-01T10:00:00Z</updated>
  </entry>
</feed>
''';

    final parser = FeedParserService(Dio());
    final feed = parser.parse(xml,
        feedUrl: 'https://example.com/atom.xml', category: 'Articles');

    expect(feed.title, 'Atom Feed');
    expect(feed.entries.single.guid, 'atom-1');
    expect(feed.entries.single.contentType, ContentType.article);
  });
}
