import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/content_type_preference.dart';
import '../../../core/models/feed_category.dart';
import '../../../core/utils/snackbar.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../sidebar/presentation/sidebar_providers.dart';
import 'category_providers.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final categories = ref.watch(categoriesProvider);
    final contentTypes = ref.watch(contentTypePreferencesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.manageCategories),
          bottom: TabBar(
            tabs: [
              Tab(text: t.feedCategories),
              Tab(text: t.contentTypes),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            categories.when(
              data: (items) => _CategoryList(items: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(t.failedToLoadCategories(error))),
            ),
            contentTypes.when(
              data: (items) => _ContentTypeList(items: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(t.failedToLoadCategories(error))),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.items});

  final List<FeedCategory> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: Text(t.addCategory),
            ),
          );
        }
        final category = items[index - 1];
        final locked = category.name == 'Other';
        return Card(
          child: ListTile(
            title: Text(t.categoryLabel(category.name)),
            subtitle: locked ? Text(t.systemCategoryLocked) : null,
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: t.moveUp,
                  onPressed: index == 1
                      ? null
                      : () => _move(context, ref, category, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: t.moveDown,
                  onPressed: index == items.length
                      ? null
                      : () => _move(context, ref, category, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: t.renameCategory,
                  onPressed:
                      locked ? null : () => _rename(context, ref, category),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: t.deleteCategory,
                  onPressed:
                      locked ? null : () => _delete(context, ref, category),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length + 1,
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await _categoryNameDialog(context, context.t.addCategory);
    if (name == null) return;
    try {
      await ref.read(categoryRepositoryProvider).addCategory(name);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.saveFailed(error));
    }
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, FeedCategory category) async {
    final name = await _categoryNameDialog(context, context.t.renameCategory,
        initialValue: category.name);
    if (name == null) return;
    try {
      await ref.read(categoryRepositoryProvider).renameCategory(category, name);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.saveFailed(error));
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, FeedCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t.deleteCategory),
        content: Text(context.t.deleteCategoryMessage(category.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.t.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(category);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.saveFailed(error));
    }
  }

  Future<void> _move(BuildContext context, WidgetRef ref, FeedCategory category,
      int direction) async {
    try {
      await ref
          .read(categoryRepositoryProvider)
          .moveCategory(category, direction);
      _invalidate(ref);
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.saveFailed(error));
    }
  }

  Future<String?> _categoryNameDialog(
    BuildContext context,
    String title, {
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.t.categoryName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(context.t.save)),
        ],
      ),
    );
    controller.dispose();
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _ContentTypeList extends ConsumerWidget {
  const _ContentTypeList({required this.items});

  final List<ContentTypePreference> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            title: Text(t.contentTypeLabel(item.type)),
            leading: Switch(
              value: item.visible,
              onChanged: (value) => _setVisible(ref, index, value),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: t.moveUp,
                  onPressed: index == 0 ? null : () => _move(ref, index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: t.moveDown,
                  onPressed: index == items.length - 1
                      ? null
                      : () => _move(ref, index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length,
    );
  }

  Future<void> _setVisible(WidgetRef ref, int index, bool visible) async {
    final updated = [...items];
    updated[index] = updated[index].copyWith(visible: visible);
    await ref
        .read(categoryRepositoryProvider)
        .saveContentTypePreferences(updated);
    _invalidate(ref);
  }

  Future<void> _move(WidgetRef ref, int index, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= items.length) return;
    final updated = [...items];
    final current = updated[index];
    updated[index] = updated[target];
    updated[target] = current;
    await ref
        .read(categoryRepositoryProvider)
        .saveContentTypePreferences(updated);
    _invalidate(ref);
  }
}

void _invalidate(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(categoryNamesProvider);
  ref.invalidate(contentTypePreferencesProvider);
  ref.invalidate(visibleContentTypePreferencesProvider);
  ref.invalidate(sidebarItemsProvider);
  ref.invalidate(visibleSidebarItemsProvider);
  ref.invalidate(feedsControllerProvider);
  ref.invalidate(entriesProvider);
  ref.invalidate(favoriteEntriesProvider);
  ref.invalidate(laterEntriesProvider);
  ref.invalidate(recommendedEntriesProvider);
}
