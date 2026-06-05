import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/entry.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/category_providers.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../reader/presentation/reader_page.dart';
import 'entry_providers.dart';

class ContentFlowPage extends ConsumerWidget {
  const ContentFlowPage({this.fixedCategory, this.title, super.key});

  final String? fixedCategory;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseFilter = ref.watch(homeEntryFilterProvider);
    final filter = fixedCategory == null
        ? baseFilter
        : baseFilter.copyWith(category: fixedCategory);
    final entries = ref.watch(entriesProvider(filter));
    final categories = ref.watch(categoryNamesProvider);
    final t = context.t;
    final filterNotifier = ref.read(homeEntryFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? t.appName),
        actions: [
          IconButton(
            tooltip: t.refreshAll,
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final results =
                  await ref.read(feedsControllerProvider.notifier).refreshAll();
              if (!context.mounted) return;
              final failed = results.where((result) => !result.success).length;
              showMessage(context, context.t.refreshComplete(failed));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.searchHomeHint,
              ),
              onChanged: (value) {
                filterNotifier.state = baseFilter.copyWith(query: value);
              },
            ),
          ),
          if (fixedCategory == null)
            SizedBox(
              height: 48,
              child: categories.when(
                data: (items) {
                  final all = ['All', ...items];
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final category = all[index];
                      return ChoiceChip(
                        label: Text(t.categoryLabel(category)),
                        selected: filter.category == category,
                        onSelected: (_) {
                          filterNotifier.state =
                              filter.copyWith(category: category);
                        },
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: all.length,
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text(t.failedToLoadCategories(error))),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(t.unread),
                  selected: filter.unreadOnly,
                  onSelected: (value) {
                    filterNotifier.state =
                        baseFilter.copyWith(unreadOnly: value);
                  },
                ),
                FilterChip(
                  label: Text(t.favorite),
                  selected: filter.favoriteOnly,
                  onSelected: (value) {
                    filterNotifier.state =
                        baseFilter.copyWith(favoriteOnly: value);
                  },
                ),
                FilterChip(
                  label: Text(t.later),
                  selected: filter.laterOnly,
                  onSelected: (value) {
                    filterNotifier.state =
                        baseFilter.copyWith(laterOnly: value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(t.noContentYet));
                }
                return EntryList(entries: items);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(t.failedToLoadContent(error))),
            ),
          ),
        ],
      ),
    );
  }
}

class EntryList extends StatelessWidget {
  const EntryList({required this.entries, super.key});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => EntryTile(entry: entries[index]),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
    );
  }
}

class EntryTile extends ConsumerWidget {
  const EntryTile({required this.entry, super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.t;
    final subtitle =
        '${entry.sourceName} | ${t.categoryLabel(entry.category)} | ${formatShortDate(entry.publishedAt ?? entry.fetchedAt)}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReaderPage(entryId: entry.id)));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    entry.imageUrl!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 84, height: 84),
                  ),
                ),
              if (entry.imageUrl != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            entry.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                    if (entry.aiSummary?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(entry.aiSummary!,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ] else if (entry.summary?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(entry.summary!,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    if (entry.readingProgress > 0 &&
                        entry.readingProgress < 1) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: entry.readingProgress),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: entry.isFavorite ? t.removeFavorite : t.favorite,
                    icon:
                        Icon(entry.isFavorite ? Icons.star : Icons.star_border),
                    onPressed: () async {
                      await ref
                          .read(entryRepositoryProvider)
                          .setFavorite(entry.id, !entry.isFavorite);
                      ref.invalidate(entriesProvider);
                      ref.invalidate(favoriteEntriesProvider);
                      ref.invalidate(recommendedEntriesProvider);
                    },
                  ),
                  IconButton(
                    tooltip: entry.isLater ? t.removeLater : t.readLater,
                    icon: Icon(entry.isLater
                        ? Icons.schedule
                        : Icons.schedule_outlined),
                    onPressed: () async {
                      await ref
                          .read(entryRepositoryProvider)
                          .setLater(entry.id, !entry.isLater);
                      ref.invalidate(entriesProvider);
                      ref.invalidate(laterEntriesProvider);
                      ref.invalidate(recommendedEntriesProvider);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
