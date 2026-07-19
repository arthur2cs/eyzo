import 'package:hive_flutter/hive_flutter.dart';

import '../../models/favorite_item.dart';
import 'hive_boxes.dart';

/// CRUD des favoris, stockés localement en JSON dans Hive (voir specs.md §4.6).
class FavoritesRepository {
  Box<dynamic> get _box => Hive.box<dynamic>(HiveBoxes.favorites);

  List<FavoriteItem> getAll() {
    final items = _box.values
        .map((raw) => FavoriteItem.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> save(FavoriteItem item) async {
    await _box.put(item.id, item.toJson());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
