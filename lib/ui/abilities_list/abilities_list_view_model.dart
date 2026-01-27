import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ability.dart';
import '../../main.dart';

final abilitiesListViewModelProvider =
    FutureProvider<List<Ability>>((ref) async {
  final repository = ref.watch(abilityRepositoryProvider);
  return repository.getAllAbilities();
});
