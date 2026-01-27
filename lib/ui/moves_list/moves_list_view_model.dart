import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/move.dart';
import '../../data/repositories/move_repository.dart';

final moveRepositoryProvider = Provider<MoveRepository>((ref) {
  return MoveRepository();
});

final movesListViewModelProvider = FutureProvider<List<Move>>((ref) async {
  final repository = ref.watch(moveRepositoryProvider);
  await repository.initialize();
  return repository.getAllMoves();
});
