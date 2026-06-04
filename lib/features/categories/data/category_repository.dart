import '../../../core/database/app_database.dart';
import '../../../core/models/feed_category.dart';

class CategoryRepository {
  CategoryRepository(this._database);

  final AppDatabase _database;

  Future<List<FeedCategory>> getCategories() async {
    final db = await _database.instance;
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(FeedCategory.fromMap).toList();
  }
}
