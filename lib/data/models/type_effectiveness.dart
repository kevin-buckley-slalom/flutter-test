enum Effectiveness {
  immune(0.0, 'Immune'),
  hardlyEffective(0.25, 'Hardly Effective'),
  notVeryEffective(0.5, 'Not Very Effective'),
  normal(1.0, 'Normal'),
  superEffective(2.0, 'Super Effective'),
  extremelyEffective(4.0, 'Extremely Effective');

  final double multiplier;
  final String label;

  const Effectiveness(this.multiplier, this.label);
}

class TypeEffectiveness {
  final Map<String, Effectiveness> effectivenessMap;

  TypeEffectiveness(this.effectivenessMap);

  List<String> get immunities => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.immune)
      .map((e) => e.key)
      .toList()
      ..sort();

  List<String> get hardlyEffective => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.hardlyEffective)
      .map((e) => e.key)
      .toList()
      ..sort();

  List<String> get resistances => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.notVeryEffective)
      .map((e) => e.key)
      .toList()
      ..sort();

  List<String> get neutral => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.normal)
      .map((e) => e.key)
      .toList()
      ..sort();

  List<String> get weaknesses => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.superEffective)
      .map((e) => e.key)
      .toList()
      ..sort();

  List<String> get extremeWeaknesses => effectivenessMap.entries
      .where((e) => e.value == Effectiveness.extremelyEffective)
      .map((e) => e.key)
      .toList()
      ..sort();
}





