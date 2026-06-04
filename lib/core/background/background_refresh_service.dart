import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/feeds/data/feed_parser_service.dart';
import '../../features/feeds/data/feed_repository.dart';
import '../database/app_database.dart';

const _refreshTaskName = 'readflow.background.refresh';
const _refreshUniqueName = 'readflow.refresh.periodic';

class BackgroundRefreshService {
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> schedule(int minutes) async {
    if (!Platform.isAndroid) return;
    final frequency = Duration(minutes: minutes < 15 ? 15 : minutes);
    await Workmanager().registerPeriodicTask(
      _refreshUniqueName,
      _refreshTaskName,
      frequency: frequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 12),
        headers: const {
          'User-Agent': 'ReadFlow/0.1',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
        },
        responseType: ResponseType.plain,
      ),
    );

    final repository = FeedRepository(
      AppDatabase(),
      FeedParserService(dio),
    );
    await repository.refreshAllFeeds();
    return true;
  });
}
