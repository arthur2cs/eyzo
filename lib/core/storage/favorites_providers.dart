import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_item.dart';
import 'favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(),
);

class FavoritesController extends StateNotifier<List<FavoriteItem>> {
  FavoritesController(this._repository) : super(_repository.getAll());

  final FavoritesRepository _repository;

  Future<void> add(FavoriteItem item) async {
    await _repository.save(item);
    state = _repository.getAll();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    state = _repository.getAll();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesController, List<FavoriteItem>>((ref) {
      return FavoritesController(ref.watch(favoritesRepositoryProvider));
    });
