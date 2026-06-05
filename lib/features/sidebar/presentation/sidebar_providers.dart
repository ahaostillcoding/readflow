import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/sidebar_item_preference.dart';
import '../../categories/presentation/category_providers.dart';
import '../data/sidebar_repository.dart';

final sidebarRepositoryProvider = Provider<SidebarRepository>((ref) {
  return SidebarRepository(ref.watch(appDatabaseProvider));
});

final sidebarItemsProvider =
    FutureProvider<List<SidebarItemPreference>>((ref) async {
  final categoryNames = await ref.watch(categoryNamesProvider.future);
  return ref
      .watch(sidebarRepositoryProvider)
      .getItems(categoryNames: categoryNames);
});

final visibleSidebarItemsProvider =
    FutureProvider<List<SidebarItemPreference>>((ref) async {
  final items = await ref.watch(sidebarItemsProvider.future);
  return items.where((item) => item.visible).toList();
});
