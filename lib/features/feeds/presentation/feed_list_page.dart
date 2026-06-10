import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/feed.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/category_providers.dart';
import 'add_feed_page.dart';
import 'feed_providers.dart';

class FeedListPage extends ConsumerWidget {
  const FeedListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeds = ref.watch(feedsControllerProvider);
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.feeds),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddFeedPage())),
        icon: const Icon(Icons.add),
        label: Text(t.add),
      ),
      body: feeds.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(t.noFeedsYet));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) => FeedCard(feed: items[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(t.failedToLoadFeeds(error))),
      ),
    );
  }
}

class FeedCard extends ConsumerWidget {
  const FeedCard({required this.feed, super.key});

  final Feed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage:
                  feed.iconUrl == null ? null : NetworkImage(feed.iconUrl!),
              child: feed.iconUrl == null ? const Icon(Icons.rss_feed) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feed.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                      '${t.categoryLabel(feed.category)} | ${t.lastRefresh(formatShortDate(feed.lastFetchAt))}'),
                  if (feed.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      feed.lastError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: feed.enabled,
              onChanged: (value) => ref
                  .read(feedsControllerProvider.notifier)
                  .setEnabled(feed.id, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'refresh') {
                  final result = await ref
                      .read(feedsControllerProvider.notifier)
                      .refreshFeed(feed);
                  if (context.mounted) {
                    showMessage(
                        context,
                        result.success
                            ? context.t.refreshComplete(0)
                            : context.t.refreshFailed(result.error));
                  }
                }
                if (value == 'rename' && context.mounted) {
                  await _rename(context, ref);
                }
                if (value == 'category' && context.mounted) {
                  await _changeCategory(context, ref);
                }
                if (value == 'full_text' && context.mounted) {
                  await _fullTextSettings(context, ref);
                }
                if (value == 'delete' && context.mounted) {
                  await _delete(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'refresh', child: Text(context.t.refresh)),
                PopupMenuItem(value: 'rename', child: Text(context.t.rename)),
                PopupMenuItem(
                    value: 'category', child: Text(context.t.changeCategory)),
                PopupMenuItem(
                    value: 'full_text',
                    child: Text(context.t.fullTextSettings)),
                PopupMenuItem(value: 'delete', child: Text(context.t.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: feed.title);
    final t = context.t;
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.rename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(t.save)),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      await ref
          .read(feedsControllerProvider.notifier)
          .renameFeed(feed.id, title);
    }
  }

  Future<void> _changeCategory(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoryNamesProvider.future);
    var selected = categories.contains(feed.category) ? feed.category : 'Other';
    if (!context.mounted) return;
    final t = context.t;
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.changeCategory),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            initialValue: selected,
            items: categories
                .map((item) => DropdownMenuItem(
                    value: item, child: Text(t.categoryLabel(item))))
                .toList(),
            onChanged: (value) => setState(() => selected = value ?? 'Other'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(t.save)),
        ],
      ),
    );
    if (category != null) {
      await ref
          .read(feedsControllerProvider.notifier)
          .changeCategory(feed.id, category);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.delete),
        content: Text(t.deleteFeedMessage(feed.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(feedsControllerProvider.notifier).deleteFeed(feed.id);
    }
  }

  Future<void> _fullTextSettings(BuildContext context, WidgetRef ref) async {
    final selectorController =
        TextEditingController(text: feed.fullTextSelector ?? '');
    final excludeController =
        TextEditingController(text: feed.fullTextExcludeSelector ?? '');
    var mode = feed.fullTextMode;
    final t = context.t;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.fullTextSettings),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: InputDecoration(labelText: t.fullTextMode),
                items: [
                  DropdownMenuItem(value: 'off', child: Text(t.fullTextOff)),
                  DropdownMenuItem(
                      value: 'manual', child: Text(t.fullTextManual)),
                  DropdownMenuItem(value: 'auto', child: Text(t.fullTextAuto)),
                ],
                onChanged: (value) => setState(() => mode = value ?? 'manual'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: selectorController,
                decoration: InputDecoration(labelText: t.fullTextSelector),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: excludeController,
                decoration:
                    InputDecoration(labelText: t.fullTextExcludeSelector),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(t.save)),
        ],
      ),
    );
    if (saved == true) {
      await ref.read(feedsControllerProvider.notifier).updateFullTextSettings(
            feed.id,
            mode: mode,
            selector: selectorController.text,
            excludeSelector: excludeController.text,
          );
    }
    selectorController.dispose();
    excludeController.dispose();
  }
}
