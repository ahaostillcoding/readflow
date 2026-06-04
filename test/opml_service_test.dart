import 'package:flutter_test/flutter_test.dart';
import 'package:readflow/features/feeds/data/opml_service.dart';

void main() {
  test('parses OPML outlines', () {
    const opml = '''
<opml version="2.0">
  <body>
    <outline text="News">
      <outline type="rss" text="Example" xmlUrl="https://example.com/rss.xml" />
    </outline>
  </body>
</opml>
''';

    final items = OpmlService().parse(opml);

    expect(items, hasLength(1));
    expect(items.single.title, 'Example');
    expect(items.single.category, 'News');
    expect(items.single.url, 'https://example.com/rss.xml');
  });
}
