import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry.dart';
import '../../../core/utils/date_format.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../reader/presentation/reader_page.dart';

class NovelPage extends ConsumerWidget {
  const NovelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(novelEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novels')),
      body: entries.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No novel updates yet.'));
          final grouped = <String, List<Entry>>{};
          for (final item in items) {
            grouped.putIfAbsent(_novelTitle(item), () => []).add(item);
          }
          final groups = grouped.entries.toList()
            ..sort((a, b) {
              final ad = a.value.first.publishedAt ?? a.value.first.fetchedAt;
              final bd = b.value.first.publishedAt ?? b.value.first.fetchedAt;
              return bd.compareTo(ad);
            });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              final latest = group.value.first;
              return Card(
                child: ListTile(
                  title: Text(group.key),
                  subtitle: Text('Latest: ${_chapterName(latest)} | ${formatShortDate(latest.publishedAt ?? latest.fetchedAt)}'),
                  trailing: latest.isRead ? const Icon(Icons.done) : const Icon(Icons.play_arrow),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(entryId: latest.id))),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load novels: $error')),
      ),
    );
  }

  String _novelTitle(Entry entry) {
    final extra = _extra(entry);
    return (extra['novelTitle'] as String?)?.trim().isNotEmpty == true ? extra['novelTitle'] as String : entry.sourceName;
  }

  String _chapterName(Entry entry) {
    final extra = _extra(entry);
    return (extra['chapterName'] as String?)?.trim().isNotEmpty == true ? extra['chapterName'] as String : entry.title;
  }

  Map<String, Object?> _extra(Entry entry) {
    try {
      return entry.extraJson == null ? const {} : (jsonDecode(entry.extraJson!) as Map<String, Object?>);
    } catch (_) {
      return const {};
    }
  }
}
