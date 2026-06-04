import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/feed_category.dart';
import '../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(appDatabaseProvider));
});

final categoriesProvider = FutureProvider<List<FeedCategory>>((ref) {
  return ref.watch(categoryRepositoryProvider).getCategories();
});

final categoryNamesProvider = FutureProvider<List<String>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  return categories.map((category) => category.name).toList();
});
