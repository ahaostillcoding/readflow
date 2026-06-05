import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/sidebar_item_preference.dart';
import '../../categories/presentation/category_providers.dart';
import 'sidebar_providers.dart';

class SidebarManagementPage extends ConsumerWidget {
  const SidebarManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final items = ref.watch(sidebarItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.manageSidebar)),
      body: items.when(
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: Switch(
                  value: item.visible,
                  onChanged: (value) => _setVisible(ref, items, index, value),
                ),
                title: Text(_label(context, item)),
                subtitle: Text(
                  item.type == SidebarItemType.page
                      ? t.sidebarPageItems
                      : t.sidebarCategoryItems,
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: t.moveUp,
                      onPressed: index == 0
                          ? null
                          : () => _move(ref, items, index, -1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: t.moveDown,
                      onPressed: index == items.length - 1
                          ? null
                          : () => _move(ref, items, index, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: items.length,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(t.failedToLoadCategories(error))),
      ),
    );
  }

  Future<void> _setVisible(
    WidgetRef ref,
    List<SidebarItemPreference> items,
    int index,
    bool visible,
  ) async {
    final updated = [...items];
    updated[index] = updated[index].copyWith(visible: visible);
    await ref.read(sidebarRepositoryProvider).saveItems(updated);
    _invalidate(ref);
  }

  Future<void> _move(
    WidgetRef ref,
    List<SidebarItemPreference> items,
    int index,
    int direction,
  ) async {
    final target = index + direction;
    if (target < 0 || target >= items.length) return;
    final updated = [...items];
    final current = updated[index];
    updated[index] = updated[target];
    updated[target] = current;
    await ref.read(sidebarRepositoryProvider).saveItems(updated);
    _invalidate(ref);
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(sidebarItemsProvider);
    ref.invalidate(visibleSidebarItemsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(categoryNamesProvider);
  }

  String _label(BuildContext context, SidebarItemPreference item) {
    final t = context.t;
    if (item.type == SidebarItemType.category) return t.categoryLabel(item.key);
    return switch (item.key) {
      'home' => t.home,
      'feeds' => t.feeds,
      'saved' => t.saved,
      'search' => t.search,
      'recommended' => t.forYou,
      'novels' => t.novels,
      'movies' => t.movies,
      'settings' => t.settings,
      _ => item.key,
    };
  }
}
