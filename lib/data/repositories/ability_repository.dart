import '../models/ability.dart';
import '../services/ability_data_service.dart';

class AbilityRepository {
  final AbilityDataService _abilityDataService;

  AbilityRepository({required AbilityDataService abilityDataService})
      : _abilityDataService = abilityDataService;

  Future<Ability?> getAbilityByName(String name) async {
    await _abilityDataService.loadData();
    return _abilityDataService.getAbilityByName(name);
  }

  Future<List<Ability>> getAllAbilities() async {
    await _abilityDataService.loadData();
    return _abilityDataService.getAllAbilities();
  }
}
