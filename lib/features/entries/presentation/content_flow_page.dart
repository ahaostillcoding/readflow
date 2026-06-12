import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/entry.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/category_providers.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../reader/presentation/reader_page.dart';
import '../../settings/presentation/settings_provider.dart';
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
          if (fixedCategory == null)
            IconButton(
              tooltip: t.filter,
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _showEntryFilterSheet(
                context,
                ref,
                filter: filter,
                onChanged: (next) => filterNotifier.state = next,
              ),
            ),
          IconButton(
            tooltip: t.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
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
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: t.searchHomeHint,
              ),
              onChanged: (value) {
                filterNotifier.state = baseFilter.copyWith(query: value);
              },
            ),
          ),
          if (fixedCategory == null)
            categories.when(
              data: (_) => _ActiveFilterBar(
                filter: filter,
                onClear: () {
                  filterNotifier.state = baseFilter.copyWith(
                    category: 'All',
                    unreadOnly: false,
                    favoriteOnly: false,
                    laterOnly: false,
                  );
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          if (fixedCategory != null)
            _ActiveFilterBar(
              filter: filter,
              showCategory: false,
              onClear: () {
                filterNotifier.state = baseFilter.copyWith(
                  unreadOnly: false,
                  favoriteOnly: false,
                  laterOnly: false,
                );
              },
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

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({
    required this.filter,
    required this.onClear,
    this.showCategory = true,
  });

  final EntryFilter filter;
  final VoidCallback onClear;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final chips = <String>[
      if (showCategory && filter.category != null && filter.category != 'All')
        t.categoryLabel(filter.category!),
      if (filter.unreadOnly) t.unread,
      if (filter.favoriteOnly) t.favorite,
      if (filter.laterOnly) t.later,
    ];
    if (chips.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${t.activeFilters}:',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              for (final chip in chips) ...[
                InputChip(label: Text(chip), onDeleted: onClear),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showEntryFilterSheet(
  BuildContext context,
  WidgetRef ref, {
  required EntryFilter filter,
  required ValueChanged<EntryFilter> onChanged,
}) async {
  final t = context.t;
  final categories = await ref.read(categoryNamesProvider.future);
  if (!context.mounted) return;
  var draft = filter;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final allCategories = ['All', ...categories];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(t.filter, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in allCategories)
                      ChoiceChip(
                        label: Text(t.categoryLabel(category)),
                        selected: draft.category == category,
                        onSelected: (_) => setModalState(
                          () => draft = draft.copyWith(category: category),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(t.unread),
                      selected: draft.unreadOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(unreadOnly: value),
                      ),
                    ),
                    FilterChip(
                      label: Text(t.favorite),
                      selected: draft.favoriteOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(favoriteOnly: value),
                      ),
                    ),
                    FilterChip(
                      label: Text(t.later),
                      selected: draft.laterOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(laterOnly: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        onChanged(filter.copyWith(
                          category: 'All',
                          unreadOnly: false,
                          favoriteOnly: false,
                          laterOnly: false,
                        ));
                        Navigator.of(context).pop();
                      },
                      child: Text(t.clearFilters),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        onChanged(draft);
                        Navigator.of(context).pop();
                      },
                      child: Text(t.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class EntryList extends StatelessWidget {
  const EntryList({required this.entries, super.key});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    return _EntryListView(entries: entries);
  }
}

class _EntryListView extends ConsumerWidget {
  const _EntryListView({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return ListView.separated(
      padding: EdgeInsets.all(switch (settings.listDensity) {
        ListDensity.compact => 10,
        ListDensity.comfortable => 18,
        ListDensity.spacious => 22,
      }),
      itemCount: entries.length,
      itemBuilder: (context, index) => EntryTile(entry: entries[index]),
      separatorBuilder: (_, __) => SizedBox(
        height: switch (settings.listDensity) {
          ListDensity.compact => 6,
          ListDensity.comfortable => 8,
          ListDensity.spacious => 12,
        },
      ),
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
    final settings = ref.watch(settingsControllerProvider);
    final imageSize = switch (settings.listDensity) {
      ListDensity.compact => 64.0,
      ListDensity.comfortable => 84.0,
      ListDensity.spacious => 104.0,
    };
    final cardPadding = switch (settings.listDensity) {
      ListDensity.compact => 8.0,
      ListDensity.comfortable => 12.0,
      ListDensity.spacious => 16.0,
    };
    final subtitle =
        '${entry.sourceName} · ${t.categoryLabel(entry.category)} · ${formatShortDate(entry.publishedAt ?? entry.fetchedAt)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReaderPage(entryId: entry.id)));
          },
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.showEntryImages && entry.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      entry.imageUrl!,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          SizedBox(width: imageSize, height: imageSize),
                    ),
                  ),
                if (settings.showEntryImages && entry.imageUrl != null)
                  const SizedBox(width: 12),
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
                          fontSize: 15.5,
                          height: 1.34,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                      if (settings.showEntrySummaries &&
                          (entry.aiSummary?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 6),
                        Text(entry.aiSummary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ] else if (settings.showEntrySummaries &&
                          (entry.summary?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 6),
                        Text(entry.summary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
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
                      icon: Icon(entry.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded),
                      onPressed: () async {
                        await ref
                            .read(entryRepositoryProvider)
                            .setFavorite(entry.id, !entry.isFavorite);
                        ref.invalidate(entriesProvider);
                        ref.invalidate(favoriteEntriesProvider);
                        ref.invalidate(recommendedEntriesProvider);
                      },
                    ),
                    PopupMenuButton<String>(
                      tooltip: t.moreActions,
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) async {
                        if (value == 'later') {
                          await ref
                              .read(entryRepositoryProvider)
                              .setLater(entry.id, !entry.isLater);
                          ref.invalidate(entriesProvider);
                          ref.invalidate(laterEntriesProvider);
                          ref.invalidate(recommendedEntriesProvider);
                        }
                        if (value == 'read') {
                          await ref
                              .read(entryRepositoryProvider)
                              .markRead(entry.id, !entry.isRead);
                          ref.invalidate(entriesProvider);
                        }
                        if (value == 'copy') {
                          await Clipboard.setData(
                              ClipboardData(text: entry.link));
                          if (context.mounted) {
                            showMessage(context, context.t.linkCopied);
                          }
                        }
                        if (value == 'open') {
                          final uri = Uri.tryParse(entry.link);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'later',
                          child:
                              Text(entry.isLater ? t.removeLater : t.readLater),
                        ),
                        PopupMenuItem(
                          value: 'read',
                          child: Text(entry.isRead ? t.markUnread : t.markRead),
                        ),
                        PopupMenuItem(value: 'copy', child: Text(t.copyLink)),
                        PopupMenuItem(
                            value: 'open', child: Text(t.openInBrowser)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
