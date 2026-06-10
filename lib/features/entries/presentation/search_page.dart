import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/content_type.dart';
import '../../categories/presentation/category_providers.dart';
import 'content_flow_page.dart';
import 'entry_providers.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchEntryFilterProvider);
    final contentTypes = ref.watch(visibleContentTypePreferencesProvider);
    final entries = ref.watch(entriesProvider(filter));
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.search),
        actions: [
          IconButton(
            tooltip: t.filter,
            icon: const Icon(Icons.tune),
            onPressed: () => _showSearchFilterSheet(context, ref, filter),
          ),
        ],
      ),
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
          contentTypes.when(
            data: (items) {
              if (filter.contentType != null &&
                  !items.any((item) => item.type == filter.contentType)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(searchEntryFilterProvider.notifier).state =
                      filter.copyWith(contentType: null);
                });
              }
              return _SearchActiveFilterBar(
                filter: filter,
                onClear: () {
                  ref.read(searchEntryFilterProvider.notifier).state =
                      filter.copyWith(
                    category: 'All',
                    unreadOnly: false,
                    favoriteOnly: false,
                    laterOnly: false,
                    contentType: null,
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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

class _SearchActiveFilterBar extends StatelessWidget {
  const _SearchActiveFilterBar({
    required this.filter,
    required this.onClear,
  });

  final EntryFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final chips = <String>[
      if (filter.category != null && filter.category != 'All')
        t.categoryLabel(filter.category!),
      if (filter.contentType != null) t.contentTypeLabel(filter.contentType),
      if (filter.favoriteOnly) t.favorites,
      if (filter.laterOnly) t.readLater,
      if (filter.unreadOnly) t.unread,
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

Future<void> _showSearchFilterSheet(
  BuildContext context,
  WidgetRef ref,
  EntryFilter filter,
) async {
  final t = context.t;
  final categories = await ref.read(categoryNamesProvider.future);
  final contentTypes =
      await ref.read(visibleContentTypePreferencesProvider.future);
  if (!context.mounted) return;
  var draft = filter;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final allCategories = ['All', ...categories];
        final allTypes = <ContentType?>[
          null,
          ...contentTypes.map((item) => item.type),
        ];
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
                    for (final type in allTypes)
                      ChoiceChip(
                        label: Text(t.contentTypeLabel(type)),
                        selected: draft.contentType == type,
                        onSelected: (_) => setModalState(
                          () => draft = draft.copyWith(contentType: type),
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
                      label: Text(t.favorites),
                      selected: draft.favoriteOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(favoriteOnly: value),
                      ),
                    ),
                    FilterChip(
                      label: Text(t.readLater),
                      selected: draft.laterOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(laterOnly: value),
                      ),
                    ),
                    FilterChip(
                      label: Text(t.unread),
                      selected: draft.unreadOnly,
                      onSelected: (value) => setModalState(
                        () => draft = draft.copyWith(unreadOnly: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        ref.read(searchEntryFilterProvider.notifier).state =
                            filter.copyWith(
                          category: 'All',
                          unreadOnly: false,
                          favoriteOnly: false,
                          laterOnly: false,
                          contentType: null,
                        );
                        Navigator.of(context).pop();
                      },
                      child: Text(t.clearFilters),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        ref.read(searchEntryFilterProvider.notifier).state =
                            draft;
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
