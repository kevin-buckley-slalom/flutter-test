import 'package:championdex/domain/battle/simulation_event.dart';

/// Represents a queued action for a Pokémon in battle
abstract class BattleAction {
  const BattleAction();
}

class SwitchAction extends BattleAction {
  final String targetPokemonName;

  const SwitchAction({required this.targetPokemonName});
}

class AttackAction extends BattleAction {
  final String moveName;
  final String? targetPokemonName; // The pokemon name being targeted
  final String? switchInPokemonName; // For moves with switches_out effect

  const AttackAction({
    required this.moveName,
    this.targetPokemonName,
    this.switchInPokemonName,
  });
}

/// Represents a single Pokémon on the battlefield with its current state
class BattlePokemon {
  final String pokemonName;
  final String originalName; // Original pokemon name before potential switches
  final int maxHp;
  int currentHp;
  final int level;
  final String ability;
  final String? item;
  final bool isShiny;
  final String teraType;
  final List<String> moves; // List of move names
  final Map<String, int>
      statStages; // -6 to +6 for HP, ATK, DEF, SPA, SPD, SPE, ACC, EVA
  final BattleAction? queuedAction;
  final String? imagePath;
  final String? imagePathLarge;
  final dynamic stats; // PokemonStats object with base stats
  List<String>
      types; // Current types (can be modified by moves like Forest's Curse)
  String?
      status; // Status condition: paralysis, burn, freeze, poison, sleep, confusion

  // Volatile status (battle-turn-specific conditions)
  Map<String, dynamic> volatileStatus =
      {}; // confusion_turns, leech_seed, substitute_hp, flinch, etc.
  int protectionCounter = 0; // Increments with successive protection move uses
  String? multiturnMoveName; // Name of move being executed over multiple turns
  int? multiturnMoveTurnsRemaining; // Turns left for multi-turn moves

  BattlePokemon({
    required this.pokemonName,
    required this.originalName,
    required this.maxHp,
    required this.currentHp,
    required this.level,
    required this.ability,
    required this.item,
    required this.isShiny,
    required this.teraType,
    required this.moves,
    required this.statStages,
    required this.queuedAction,
    required this.imagePath,
    required this.imagePathLarge,
    required this.stats,
    required this.types,
    this.status,
  });

  /// Creates a copy with some fields replaced
  BattlePokemon copyWith({
    String? pokemonName,
    String? originalName,
    int? maxHp,
    int? currentHp,
    int? level,
    String? ability,
    String? item,
    bool? isShiny,
    String? teraType,
    List<String>? moves,
    Map<String, int>? statStages,
    BattleAction? queuedAction,
    bool clearQueuedAction = false,
    String? imagePath,
    String? imagePathLarge,
    dynamic stats,
    List<String>? types,
    String? status,
    Map<String, dynamic>? volatileStatus,
    int? protectionCounter,
    String? multiturnMoveName,
    int? multiturnMoveTurnsRemaining,
    bool clearVolatileStatus = false,
  }) {
    return BattlePokemon(
      pokemonName: pokemonName ?? this.pokemonName,
      originalName: originalName ?? this.originalName,
      maxHp: maxHp ?? this.maxHp,
      currentHp: currentHp ?? this.currentHp,
      level: level ?? this.level,
      ability: ability ?? this.ability,
      item: item ?? this.item,
      isShiny: isShiny ?? this.isShiny,
      teraType: teraType ?? this.teraType,
      moves: moves ?? this.moves,
      statStages:
          statStages != null ? Map.from(statStages) : Map.from(this.statStages),
      queuedAction:
          clearQueuedAction ? null : (queuedAction ?? this.queuedAction),
      imagePath: imagePath ?? this.imagePath,
      imagePathLarge: imagePathLarge ?? this.imagePathLarge,
      stats: stats ?? this.stats,
      types: types ?? this.types,
      status: status ?? this.status,
    )
      ..volatileStatus = clearVolatileStatus
          ? {}
          : (volatileStatus != null
              ? Map.from(volatileStatus)
              : Map.from(this.volatileStatus))
      ..protectionCounter = protectionCounter ?? this.protectionCounter
      ..multiturnMoveName = multiturnMoveName ?? this.multiturnMoveName
      ..multiturnMoveTurnsRemaining =
          multiturnMoveTurnsRemaining ?? this.multiturnMoveTurnsRemaining;
  }

  /// Sets a volatile status condition
  void setVolatileStatus(String statusName, dynamic value) {
    volatileStatus[statusName] = value;
  }

  /// Gets a volatile status condition
  dynamic getVolatileStatus(String statusName) {
    return volatileStatus[statusName];
  }

  /// Clears a specific volatile status
  void clearVolatile(String statusName) {
    volatileStatus.remove(statusName);
  }

  /// Checks if Pokémon is flinching
  bool get isFlinching => volatileStatus['flinch'] == true;

  /// Checks if Pokémon is confused
  bool get isConfused =>
      volatileStatus['confusion_turns'] != null &&
      (volatileStatus['confusion_turns'] as int) > 0;

  /// Gets remaining confusion turns
  int get confusionTurns => (volatileStatus['confusion_turns'] as int?) ?? 0;

  /// Checks if Pokémon has Leech Seed
  bool get hasLeechSeed => volatileStatus['leech_seed'] == true;

  /// Checks if Pokémon has Substitute active
  bool get hasSubstitute => volatileStatus['substitute_hp'] != null;

  /// Gets Substitute remaining HP
  int get substituteHp => (volatileStatus['substitute_hp'] as int?) ?? 0;

  /// Calculates HP percentage
  double get hpPercentage => currentHp / maxHp;

  /// Determines color based on HP percentage
  String getHpColor() {
    if (hpPercentage > 0.5) return 'green';
    if (hpPercentage > 0.25) return 'yellow';
    return 'red';
  }
}

/// Represents the full state of the battle simulation UI
class BattleUiState {
  final String team1Id;
  final String team1Name;
  final String team2Id;
  final String team2Name;
  final bool isSinglesBattle; // true for singles, false for doubles
  final List<BattlePokemon?> team1Pokemon; // 1-2 slots for current battlefield
  final List<BattlePokemon?> team2Pokemon; // 1-2 slots for current battlefield
  final List<BattlePokemon> team1Bench; // Full bench for switching
  final List<BattlePokemon> team2Bench; // Full bench for switching
  final Map<String, dynamic> fieldConditions; // terrain, weather, rooms, etc.
  final List<SimulationEvent> simulationLog; // Log of battle events
  final bool isSimulationRunning;
  final bool allActionsSet;
  final Map<String, BattleAction>
      originalActionsMap; // Original queued actions for replay

  BattleUiState({
    required this.team1Id,
    required this.team1Name,
    required this.team2Id,
    required this.team2Name,
    required this.isSinglesBattle,
    required this.team1Pokemon,
    required this.team2Pokemon,
    required this.team1Bench,
    required this.team2Bench,
    required this.fieldConditions,
    required this.simulationLog,
    required this.isSimulationRunning,
    required this.allActionsSet,
    this.originalActionsMap = const {},
  });

  /// Creates a copy with some fields replaced
  BattleUiState copyWith({
    String? team1Id,
    String? team1Name,
    String? team2Id,
    String? team2Name,
    bool? isSinglesBattle,
    List<BattlePokemon?>? team1Pokemon,
    List<BattlePokemon?>? team2Pokemon,
    List<BattlePokemon>? team1Bench,
    List<BattlePokemon>? team2Bench,
    Map<String, dynamic>? fieldConditions,
    List<SimulationEvent>? simulationLog,
    bool? isSimulationRunning,
    bool? allActionsSet,
    Map<String, BattleAction>? originalActionsMap,
  }) {
    return BattleUiState(
      team1Id: team1Id ?? this.team1Id,
      team1Name: team1Name ?? this.team1Name,
      team2Id: team2Id ?? this.team2Id,
      team2Name: team2Name ?? this.team2Name,
      isSinglesBattle: isSinglesBattle ?? this.isSinglesBattle,
      team1Pokemon: team1Pokemon ?? this.team1Pokemon,
      team2Pokemon: team2Pokemon ?? this.team2Pokemon,
      team1Bench: team1Bench ?? this.team1Bench,
      team2Bench: team2Bench ?? this.team2Bench,
      fieldConditions: fieldConditions ?? this.fieldConditions,
      simulationLog: simulationLog ?? this.simulationLog,
      isSimulationRunning: isSimulationRunning ?? this.isSimulationRunning,
      allActionsSet: allActionsSet ?? this.allActionsSet,
      originalActionsMap: originalActionsMap ?? this.originalActionsMap,
    );
  }
}
