import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflow/features/feeds/data/full_text_service.dart';

void main() {
  test('extracts article content and removes noisy sections', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = server.listen((request) {
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
<!doctype html>
<html>
  <head><title>Readable article</title></head>
  <body>
    <nav>Navigation</nav>
    <article>
      <p>${List.filled(40, 'Important body').join(' ')}</p>
      <p>Second paragraph with <a href="/more">a link</a>.</p>
      <img src="/image.jpg">
      <div class="comments">Comments should disappear</div>
    </article>
  </body>
</html>
''');
      request.response.close();
    });

    final url = 'http://127.0.0.1:${server.port}/article';
    final result = await FullTextService(Dio()).fetch(url);

    expect(result.contentHtml, contains('Important body'));
    expect(result.contentHtml, isNot(contains('Navigation')));
    expect(result.contentHtml, isNot(contains('Comments should disappear')));
    expect(
        result.contentHtml, contains('http://127.0.0.1:${server.port}/more'));
    expect(result.imageUrl, 'http://127.0.0.1:${server.port}/image.jpg');

    await requests.cancel();
    await server.close(force: true);
  });
}
