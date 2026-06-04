import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteEntriesProvider);
    final later = ref.watch(laterEntriesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.star), text: 'Favorites'),
              Tab(icon: Icon(Icons.schedule), text: 'Read later'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedEntries(value: favorites, emptyText: 'No favorites yet.'),
            _SavedEntries(value: later, emptyText: 'No read-later items yet.'),
          ],
        ),
      ),
    );
  }
}

class _SavedEntries extends StatelessWidget {
  const _SavedEntries({required this.value, required this.emptyText});

  final AsyncValue<List<Entry>> value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (items) => items.isEmpty ? Center(child: Text(emptyText)) : EntryList(entries: items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load saved items: $error')),
    );
  }
}
