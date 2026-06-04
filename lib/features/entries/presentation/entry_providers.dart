import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/content_type.dart';
import '../../../core/models/entry.dart';
import '../data/entry_repository.dart';

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(appDatabaseProvider));
});

class EntryFilter {
  const EntryFilter({
    this.category,
    this.feedId,
    this.unreadOnly = false,
    this.favoriteOnly = false,
    this.laterOnly = false,
    this.query,
    this.contentType,
  });

  final String? category;
  final int? feedId;
  final bool unreadOnly;
  final bool favoriteOnly;
  final bool laterOnly;
  final String? query;
  final ContentType? contentType;

  EntryFilter copyWith({
    Object? category = _sentinel,
    Object? feedId = _sentinel,
    bool? unreadOnly,
    bool? favoriteOnly,
    bool? laterOnly,
    Object? query = _sentinel,
    Object? contentType = _sentinel,
  }) {
    return EntryFilter(
      category: category == _sentinel ? this.category : category as String?,
      feedId: feedId == _sentinel ? this.feedId : feedId as int?,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      laterOnly: laterOnly ?? this.laterOnly,
      query: query == _sentinel ? this.query : query as String?,
      contentType: contentType == _sentinel
          ? this.contentType
          : contentType as ContentType?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EntryFilter &&
        other.category == category &&
        other.feedId == feedId &&
        other.unreadOnly == unreadOnly &&
        other.favoriteOnly == favoriteOnly &&
        other.laterOnly == laterOnly &&
        other.query == query &&
        other.contentType == contentType;
  }

  @override
  int get hashCode => Object.hash(category, feedId, unreadOnly, favoriteOnly,
      laterOnly, query, contentType);
}

const _sentinel = Object();

final homeEntryFilterProvider = StateProvider<EntryFilter>((ref) {
  return const EntryFilter(category: 'All');
});

final searchEntryFilterProvider = StateProvider<EntryFilter>((ref) {
  return const EntryFilter(category: 'All');
});

final entriesProvider =
    FutureProvider.autoDispose.family<List<Entry>, EntryFilter>((ref, filter) {
  return ref.watch(entryRepositoryProvider).getEntries(
        category: filter.category,
        feedId: filter.feedId,
        unreadOnly: filter.unreadOnly,
        favoriteOnly: filter.favoriteOnly,
        laterOnly: filter.laterOnly,
        query: filter.query,
        contentType: filter.contentType,
      );
});

final entryProvider = FutureProvider.autoDispose.family<Entry?, int>((ref, id) {
  return ref.watch(entryRepositoryProvider).getEntry(id);
});

final favoriteEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).getEntries(favoriteOnly: true);
});

final laterEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).getEntries(laterOnly: true);
});

final novelEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .getEntries(contentType: ContentType.novel);
});

final movieEntriesProvider = FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .getEntries(contentType: ContentType.movie);
});

final recommendedEntriesProvider =
    FutureProvider.autoDispose<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).getRecommendedEntries();
});
