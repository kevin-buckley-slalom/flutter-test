/// Event that occurs during battle simulation
class SimulationEvent {
  final String message;
  final SimulationEventType type;
  final String? affectedPokemonName;
  final int? damageAmount;
  final int? hpBefore;
  final int? hpAfter;

  SimulationEvent({
    required this.message,
    required this.type,
    this.affectedPokemonName,
    this.damageAmount,
    this.hpBefore,
    this.hpAfter,
  });

  @override
  String toString() => message;
}

enum SimulationEventType {
  move,
  damage,
  heal,
  statusChange,
  abilityActivation,
  itemActivation,
  fieldEffect,
  weatherChange,
  terrainChange,
  summary,
}
