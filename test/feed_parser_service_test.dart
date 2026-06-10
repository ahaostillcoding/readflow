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

  test('prefers RSS content encoded and resolves relative media', () {
    final repeated = List.filled(80, 'Long paragraph').join(' ');
    final xml = '''
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>Example Feed</title>
    <link>https://example.com/blog/</link>
    <description>Example description</description>
    <item>
      <title>Full Article</title>
      <link>/blog/full</link>
      <guid>full</guid>
      <description><![CDATA[Short summary]]></description>
      <content:encoded><![CDATA[<p>$repeated</p><img src="/img/a.jpg">]]></content:encoded>
      <media:thumbnail url="/thumb.jpg" />
    </item>
  </channel>
</rss>
''';

    final parser = FeedParserService(Dio());
    final feed = parser.parse(xml,
        feedUrl: 'https://example.com/rss.xml', category: 'News');
    final entry = feed.entries.single;

    expect(entry.link, 'https://example.com/blog/full');
    expect(entry.contentHtml, contains('Long paragraph'));
    expect(entry.contentHtml, contains('https://example.com/img/a.jpg'));
    expect(entry.imageUrl, 'https://example.com/thumb.jpg');
    expect(entry.fullTextStatus, 'feed_full');
  });

  test('parses Atom xhtml content', () {
    final repeated = List.filled(90, 'Body text').join(' ');
    final xml = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Feed</title>
  <link href="https://example.com" rel="alternate"/>
  <entry>
    <title>Atom XHTML</title>
    <id>atom-xhtml</id>
    <link href="/atom-xhtml" rel="alternate"/>
    <summary>Short atom summary</summary>
    <content type="xhtml">
      <div xmlns="http://www.w3.org/1999/xhtml"><p>$repeated</p></div>
    </content>
    <updated>2026-06-01T10:00:00Z</updated>
  </entry>
</feed>
''';

    final parser = FeedParserService(Dio());
    final feed = parser.parse(xml,
        feedUrl: 'https://example.com/atom.xml', category: 'Articles');
    final entry = feed.entries.single;

    expect(entry.link, 'https://example.com/atom-xhtml');
    expect(entry.contentHtml, contains('Body text'));
    expect(entry.fullTextStatus, 'feed_full');
  });
}
