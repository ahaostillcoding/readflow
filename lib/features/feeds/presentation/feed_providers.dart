import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/feed.dart';
import '../../../core/network/dio_provider.dart';
import '../../entries/presentation/entry_providers.dart';
import '../data/feed_parser_service.dart';
import '../data/feed_repository.dart';
import '../data/parsed_feed.dart';

final feedParserProvider = Provider<FeedParserService>((ref) {
  return FeedParserService(ref.watch(dioProvider));
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(appDatabaseProvider), ref.watch(feedParserProvider));
});

final feedsControllerProvider = StateNotifierProvider<FeedsController, AsyncValue<List<Feed>>>((ref) {
  return FeedsController(ref);
});

class FeedsController extends StateNotifier<AsyncValue<List<Feed>>> {
  FeedsController(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;

  FeedRepository get _repository => _ref.read(feedRepositoryProvider);

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.getFeeds);
  }

  Future<ParsedFeed> preview(String url, String category) {
    return _repository.previewFeed(url, category);
  }

  Future<void> addFeed(String url, String category, {String? title}) async {
    await _repository.addFeed(url: url, category: category, customTitle: title);
    await load();
    _ref.invalidate(entriesProvider);
  }

  Future<void> renameFeed(int id, String title) async {
    await _repository.updateFeedTitle(id, title);
    await load();
    _ref.invalidate(entriesProvider);
  }

  Future<void> changeCategory(int id, String category) async {
    await _repository.updateFeedCategory(id, category);
    await load();
    _ref.invalidate(entriesProvider);
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await _repository.setFeedEnabled(id, enabled);
    await load();
  }

  Future<void> deleteFeed(int id) async {
    await _repository.deleteFeed(id);
    await load();
    _ref.invalidate(entriesProvider);
  }

  Future<RefreshResult> refreshFeed(Feed feed) async {
    final result = await _repository.refreshFeed(feed);
    await load();
    _ref.invalidate(entriesProvider);
    return result;
  }

  Future<List<RefreshResult>> refreshAll() async {
    final results = await _repository.refreshAllFeeds();
    await load();
    _ref.invalidate(entriesProvider);
    return results;
  }
}
