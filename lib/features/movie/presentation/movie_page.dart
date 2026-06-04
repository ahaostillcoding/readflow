import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry.dart';
import '../../../core/utils/date_format.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../reader/presentation/reader_page.dart';

class MoviePage extends ConsumerWidget {
  const MoviePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(movieEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: entries.when(
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No movie content yet.'));
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 640 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 2.4 : 1.6,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => MovieCard(entry: items[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load movies: $error')),
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  const MovieCard({required this.entry, super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final extra = _extra(entry);
    final poster = (extra['posterUrl'] as String?) ?? entry.imageUrl;
    final rating = extra['rating'] as String?;
    final release = extra['releaseDate'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(entryId: entry.id))),
        child: Row(
          children: [
            if (poster != null)
              Image.network(
                poster,
                width: 112,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 112),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('${entry.sourceName} | ${formatShortDate(entry.publishedAt ?? entry.fetchedAt)}'),
                    if (rating != null) Text('Rating: $rating'),
                    if (release != null) Text('Release: $release'),
                    if (entry.summary != null) ...[
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(entry.summary!, maxLines: 3, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Object?> _extra(Entry entry) {
    try {
      return entry.extraJson == null ? const {} : (jsonDecode(entry.extraJson!) as Map<String, Object?>);
    } catch (_) {
      return const {};
    }
  }
}
