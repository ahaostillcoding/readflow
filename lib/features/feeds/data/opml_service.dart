import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';

import '../../../core/models/feed.dart';

class OpmlImportItem {
  const OpmlImportItem({required this.url, this.title, this.category});

  final String url;
  final String? title;
  final String? category;
}

class OpmlService {
  Future<List<OpmlImportItem>> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose OPML file',
      type: FileType.custom,
      allowedExtensions: ['opml', 'xml'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return const [];

    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Could not read the selected OPML file.');
    }
    return parse(utf8.decode(bytes));
  }

  List<OpmlImportItem> parse(String opml) {
    final document = XmlDocument.parse(opml);
    final items = <OpmlImportItem>[];

    for (final outline in document.descendantElements.where((node) => node.name.local == 'outline')) {
      final url = outline.getAttribute('xmlUrl') ?? outline.getAttribute('url');
      if (url == null || url.trim().isEmpty) continue;
      items.add(
        OpmlImportItem(
          url: url.trim(),
          title: outline.getAttribute('title') ?? outline.getAttribute('text'),
          category: outline.parentElement?.getAttribute('title') ?? outline.parentElement?.getAttribute('text'),
        ),
      );
    }

    return items;
  }

  Future<String?> exportToFile(List<Feed> feeds) async {
    final content = build(feeds);
    return FilePicker.platform.saveFile(
      dialogTitle: 'Export OPML',
      fileName: 'readflow.opml',
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  }

  String build(List<Feed> feeds) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: 'ReadFlow Subscriptions');
      });
      builder.element('body', nest: () {
        final grouped = <String, List<Feed>>{};
        for (final feed in feeds) {
          grouped.putIfAbsent(feed.category, () => []).add(feed);
        }
        for (final entry in grouped.entries) {
          builder.element('outline', attributes: {'text': entry.key, 'title': entry.key}, nest: () {
            for (final feed in entry.value) {
              builder.element('outline', attributes: {
                'type': 'rss',
                'text': feed.title,
                'title': feed.title,
                'xmlUrl': feed.url,
                if (feed.siteUrl != null) 'htmlUrl': feed.siteUrl!,
              });
            }
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }
}

final opmlService = OpmlService();
