import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_flow_page.dart';
import 'entry_providers.dart';

class RecommendedPage extends ConsumerWidget {
  const RecommendedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(recommendedEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recommended')),
      body: entries.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Recommendations will appear after you add feeds.'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Based on your favorites, read-later list, sources, and categories.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(child: EntryList(entries: items)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Recommendations failed: $error')),
      ),
    );
  }
}
