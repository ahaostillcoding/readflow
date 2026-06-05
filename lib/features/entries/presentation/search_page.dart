import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../categories/presentation/category_providers.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchEntryFilterProvider);
    final categories = ref.watch(categoryNamesProvider);
    final contentTypes = ref.watch(visibleContentTypePreferencesProvider);
    final entries = ref.watch(entriesProvider(filter));
    final t = context.t;

    return Scaffold(
      appBar: AppBar(title: Text(t.search)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.searchAllLocalContent,
              ),
              onChanged: (query) {
                ref.read(searchEntryFilterProvider.notifier).state =
                    filter.copyWith(query: query);
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
                  label: Text(t.favorites),
                  selected: filter.favoriteOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state =
                        filter.copyWith(favoriteOnly: value);
                  },
                ),
                FilterChip(
                  label: Text(t.readLater),
                  selected: filter.laterOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state =
                        filter.copyWith(laterOnly: value);
                  },
                ),
                FilterChip(
                  label: Text(t.unread),
                  selected: filter.unreadOnly,
                  onSelected: (value) {
                    ref.read(searchEntryFilterProvider.notifier).state =
                        filter.copyWith(unreadOnly: value);
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
                      label: Text(t.categoryLabel(category)),
                      selected: filter.category == category,
                      onSelected: (_) {
                        ref.read(searchEntryFilterProvider.notifier).state =
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
          SizedBox(
            height: 48,
            child: contentTypes.when(
              data: (items) {
                if (filter.contentType != null &&
                    !items.any((item) => item.type == filter.contentType)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(searchEntryFilterProvider.notifier).state =
                        filter.copyWith(contentType: null);
                  });
                }
                final values = [null, ...items.map((item) => item.type)];
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final type = values[index];
                    return ChoiceChip(
                      label: Text(t.contentTypeLabel(type)),
                      selected: filter.contentType == type,
                      onSelected: (_) {
                        ref.read(searchEntryFilterProvider.notifier).state =
                            filter.copyWith(contentType: type);
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: values.length,
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(t.failedToLoadCategories(error))),
            ),
          ),
          Expanded(
            child: entries.when(
              data: (items) => items.isEmpty
                  ? Center(child: Text(t.noMatchingContent))
                  : EntryList(entries: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(t.searchFailed(error))),
            ),
          ),
        ],
      ),
    );
  }
}
