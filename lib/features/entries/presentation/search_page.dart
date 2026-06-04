import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/content_type.dart';
import '../../categories/presentation/category_providers.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchEntryFilterProvider);
    final categories = ref.watch(categoryNamesProvider);
    final entries = ref.watch(entriesProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search all local content',
              ),
              onChanged: (query) {
                ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(query: query);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Favorites'),
                  selected: filter.favoriteOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(favoriteOnly: value);
                  },
                ),
                FilterChip(
                  label: const Text('Read later'),
                  selected: filter.laterOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(laterOnly: value);
                  },
                ),
                FilterChip(
                  label: const Text('Unread'),
                  selected: filter.unreadOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(unreadOnly: value);
                  },
                ),
              ],
            ),
          ),
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
                      label: Text(category),
                      selected: filter.category == category,
                      onSelected: (_) {
                        ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(category: category);
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: all.length,
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load categories: $error')),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final values = [null, ...ContentType.values];
                final type = values[index];
                return ChoiceChip(
                  label: Text(type?.name ?? 'Any type'),
                  selected: filter.contentType == type,
                  onSelected: (_) {
                    ref.read(searchEntryFilterProvider.notifier).state = filter.copyWith(contentType: type);
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: ContentType.values.length + 1,
            ),
          ),
          Expanded(
            child: entries.when(
              data: (items) => items.isEmpty ? const Center(child: Text('No matching content.')) : EntryList(entries: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Search failed: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
