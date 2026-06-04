import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      headers: const {
        'User-Agent': 'ReadFlow/0.1 (+https://example.local/readflow)',
        'Accept':
            'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
      responseType: ResponseType.plain,
    ),
  );
});
