import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeds'),
        actions: [
          IconButton(
            tooltip: 'Refresh all',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final results = await ref.read(feedsControllerProvider.notifier).refreshAll();
              if (!context.mounted) return;
              final failed = results.where((result) => !result.success).length;
              showMessage(context, failed == 0 ? 'Refresh complete' : 'Refresh complete, $failed failed');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddFeedPage())),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: feeds.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No feeds yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) => FeedCard(feed: items[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load feeds: $error')),
      ),
    );
  }
}

class FeedCard extends ConsumerWidget {
  const FeedCard({required this.feed, super.key});

  final Feed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: feed.iconUrl == null ? null : NetworkImage(feed.iconUrl!),
              child: feed.iconUrl == null ? const Icon(Icons.rss_feed) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feed.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${feed.category} | Last refresh: ${formatShortDate(feed.lastFetchAt)}'),
                  if (feed.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      feed.lastError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: feed.enabled,
              onChanged: (value) => ref.read(feedsControllerProvider.notifier).setEnabled(feed.id, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'refresh') {
                  final result = await ref.read(feedsControllerProvider.notifier).refreshFeed(feed);
                  if (context.mounted) {
                    showMessage(context, result.success ? 'Refresh complete' : 'Refresh failed: ${result.error}');
                  }
                }
                if (value == 'rename' && context.mounted) {
                  await _rename(context, ref);
                }
                if (value == 'category' && context.mounted) {
                  await _changeCategory(context, ref);
                }
                if (value == 'delete' && context.mounted) {
                  await _delete(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'category', child: Text('Change category')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: feed.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename feed'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      await ref.read(feedsControllerProvider.notifier).renameFeed(feed.id, title);
    }
  }

  Future<void> _changeCategory(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoryNamesProvider.future);
    var selected = categories.contains(feed.category) ? feed.category : 'Other';
    if (!context.mounted) return;
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change category'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<String>(
            initialValue: selected,
            items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() => selected = value ?? 'Other'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(selected), child: const Text('Save')),
        ],
      ),
    );
    if (category != null) {
      await ref.read(feedsControllerProvider.notifier).changeCategory(feed.id, category);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete feed'),
        content: Text('Delete "${feed.title}" and its local articles?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(feedsControllerProvider.notifier).deleteFeed(feed.id);
    }
  }
}
