import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/entry.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteEntriesProvider);
    final later = ref.watch(laterEntriesProvider);
    final t = context.t;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.saved),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.star), text: t.favorites),
              Tab(icon: const Icon(Icons.schedule), text: t.readLater),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedEntries(value: favorites, emptyText: t.noFavoritesYet),
            _SavedEntries(value: later, emptyText: t.noReadLaterYet),
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
      data: (items) => items.isEmpty
          ? Center(child: Text(emptyText))
          : EntryList(entries: items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text(context.t.failedToLoadSavedItems(error))),
    );
  }
}
