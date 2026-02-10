import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/battle/simulation_event.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

/// Processes move secondary and in-depth effects
class MoveEffectProcessor {
  static final _uuid = const Uuid();
  static final _random = Random();

  /// Process secondary effect of a move after it deals damage
  /// Returns list of SimulationEvents representing the effects
  static List<SimulationEvent> processSecondaryEffect(
    Move move,
    BattlePokemon attacker,
    BattlePokemon defender,
  ) {
    final events = <SimulationEvent>[];

    // If move has no secondary effect, return empty
    if (!move.hasSecondaryEffect) {
      return events;
    }

    // Determine if effect should trigger based on chance
    if (!_shouldEffectTrigger(move)) {
      return events;
    }

    // Parse and apply the secondary effect
    if (move.secondaryEffect != null) {
      events.addAll(_applyEffect(
        move.secondaryEffect!,
        attacker,
        defender,
        move,
        isSecondary: true,
      ));
    }

    return events;
  }

  /// Process in-depth effect of a move (unique mechanics)
  /// This is called for moves with complex effects that require special handling
  static List<SimulationEvent> processInDepthEffect(
    Move move,
    BattlePokemon attacker,
    BattlePokemon defender,
  ) {
    final events = <SimulationEvent>[];

    if (move.inDepthEffect == null) {
      return events;
    }

    // Parse and apply the in-depth effect
    events.addAll(_applyEffect(
      move.inDepthEffect!,
      attacker,
      defender,
      move,
      isSecondary: false,
    ));

    return events;
  }

  /// Determines if an effect should trigger based on chance percentage
  /// Returns true if the effect should occur
  static bool _shouldEffectTrigger(Move move) {
    // Guaranteed effects (-- % or null chance)
    if (move.effectChancePercent == null &&
        (move.effectChanceRaw == '-- %' || move.effectChanceRaw == null)) {
      return true;
    }

    // Probabilistic effects
    if (move.effectChancePercent != null) {
      return _random.nextInt(100) < move.effectChancePercent!;
    }

    // Default to not triggering if no clear chance
    return false;
  }

  /// Applies parsed effect to the defender or field
  /// Returns SimulationEvents for the effects applied
  static List<SimulationEvent> _applyEffect(
    String effectString,
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move, {
    required bool isSecondary,
  }) {
    final events = <SimulationEvent>[];
    final normalized = effectString.toLowerCase();

    // Status Condition Effects
    if (normalized.contains('burn')) {
      _applyStatusCondition(defender, 'burn', events);
    } else if (normalized.contains('paralysis') ||
        normalized.contains('paralyze')) {
      _applyStatusCondition(defender, 'paralysis', events);
    } else if (normalized.contains('poison')) {
      if (normalized.contains('badly') || normalized.contains('toxic')) {
        _applyStatusCondition(defender, 'badPoison', events);
      } else {
        _applyStatusCondition(defender, 'poison', events);
      }
    } else if (normalized.contains('sleep')) {
      _applyStatusCondition(defender, 'sleep', events);
    } else if (normalized.contains('freeze')) {
      _applyStatusCondition(defender, 'freeze', events);
    } else if (normalized.contains('confus')) {
      _applyConfusion(defender, events);
    }

    // Stat Change Effects
    if (normalized.contains('raise') || normalized.contains('boost')) {
      events.addAll(_parseStatChanges(effectString, defender, true));
    } else if (normalized.contains('lower') || normalized.contains('reduce')) {
      events.addAll(_parseStatChanges(effectString, defender, false));
    }

    // Flinch Effects
    if (normalized.contains('flinch')) {
      _applyFlinch(defender, events);
    }

    // Healing Effects
    if (normalized.contains('recover') ||
        normalized.contains('heal') ||
        normalized.contains('drain')) {
      events.addAll(_parseHealingEffect(move, defender, events.length));
    }

    // Recoil Effects
    if (normalized.contains('recoil')) {
      events.addAll(_parseRecoilEffect(move, attacker));
    }

    // Trapping Effects
    if (normalized.contains('leech seed') || normalized.contains('trap')) {
      _applyTrap(defender, effectString, events);
    }

    // Multi-hit Effects
    if (normalized.contains('hit') &&
        (normalized.contains('2-5') ||
            normalized.contains('multiple') ||
            normalized.contains('times'))) {
      // Multi-hit effects are handled in damage calculation, log here
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${move.name} hits multiple times!',
        type: SimulationEventType.moveUsed,
        affectedPokemonName: defender.originalName,
      ));
    }

    return events;
  }

  /// Apply a status condition to a pokemon
  static void _applyStatusCondition(
    BattlePokemon pokemon,
    String status,
    List<SimulationEvent> events,
  ) {
    // Check if pokemon already has a status
    if (pokemon.status != null && pokemon.status != 'none') {
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} is already ${pokemon.status}!',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: pokemon.originalName,
      ));
      return;
    }

    pokemon.status = status;
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message: '${pokemon.pokemonName} was ${_getStatusMessage(status)}!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: pokemon.originalName,
    ));
  }

  /// Apply confusion to a pokemon (lasts 2-5 turns)
  static void _applyConfusion(
    BattlePokemon pokemon,
    List<SimulationEvent> events,
  ) {
    if (pokemon.isConfused) {
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} is already confused!',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: pokemon.originalName,
      ));
      return;
    }

    final turns = 2 + _random.nextInt(4); // 2-5 turns
    pokemon.setVolatileStatus('confusion_turns', turns);
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message: '${pokemon.pokemonName} became confused!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: pokemon.originalName,
    ));
  }

  /// Apply flinch to a pokemon
  static void _applyFlinch(
    BattlePokemon pokemon,
    List<SimulationEvent> events,
  ) {
    pokemon.setVolatileStatus('flinch', true);
    events.add(SimulationEvent(
      id: _uuid.v4(),
      message: '${pokemon.pokemonName} flinched!',
      type: SimulationEventType.statusApplied,
      affectedPokemonName: pokemon.originalName,
    ));
  }

  /// Apply trap effect (Leech Seed, etc)
  static void _applyTrap(
    BattlePokemon pokemon,
    String effectString,
    List<SimulationEvent> events,
  ) {
    if (effectString.toLowerCase().contains('leech seed')) {
      pokemon.setVolatileStatus('leech_seed', true);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} was seeded!',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: pokemon.originalName,
      ));
    }
  }

  /// Parse and apply stat changes
  static List<SimulationEvent> _parseStatChanges(
    String effectString,
    BattlePokemon pokemon,
    bool isRaise,
  ) {
    final events = <SimulationEvent>[];
    final normalized = effectString.toLowerCase();
    final direction = isRaise ? 'raised' : 'lowered';

    // Default change amount is 1 stage
    int stages = 1;
    if (normalized.contains('two') || normalized.contains('2')) stages = 2;
    if (normalized.contains('three') || normalized.contains('3')) stages = 3;

    // Apply change in appropriate direction
    stages = isRaise ? stages : -stages;

    // Identify which stats to change
    if (normalized.contains('attack') || normalized.contains('atk')) {
      pokemon.statStages['atk'] =
          ((pokemon.statStages['atk'] ?? 0) + stages).clamp(-6, 6);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName}\'s Attack was $direction!',
        type: SimulationEventType.statChanged,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    if (normalized.contains('defense') || normalized.contains('def')) {
      pokemon.statStages['def'] =
          ((pokemon.statStages['def'] ?? 0) + stages).clamp(-6, 6);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName}\'s Defense was $direction!',
        type: SimulationEventType.statChanged,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    if (normalized.contains('special attack') ||
        normalized.contains('sp. atk') ||
        normalized.contains('spa')) {
      pokemon.statStages['spa'] =
          ((pokemon.statStages['spa'] ?? 0) + stages).clamp(-6, 6);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName}\'s Sp. Atk was $direction!',
        type: SimulationEventType.statChanged,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    if (normalized.contains('special defense') ||
        normalized.contains('sp. def') ||
        normalized.contains('spd')) {
      pokemon.statStages['spd'] =
          ((pokemon.statStages['spd'] ?? 0) + stages).clamp(-6, 6);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName}\'s Sp. Def was $direction!',
        type: SimulationEventType.statChanged,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    if (normalized.contains('speed') || normalized.contains('spe')) {
      pokemon.statStages['spe'] =
          ((pokemon.statStages['spe'] ?? 0) + stages).clamp(-6, 6);
      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName}\'s Speed was $direction!',
        type: SimulationEventType.statChanged,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    return events;
  }

  /// Parse and apply healing effects
  static List<SimulationEvent> _parseHealingEffect(
    Move move,
    BattlePokemon pokemon,
    int currentEventCount,
  ) {
    final events = <SimulationEvent>[];

    // Parse healing percentage from effect string
    int healAmount = 0;

    if (move.secondaryEffect?.contains('half') ?? false) {
      healAmount = pokemon.maxHp ~/ 2;
    } else if (move.secondaryEffect?.contains('25%') ?? false) {
      healAmount = pokemon.maxHp ~/ 4;
    } else if (move.secondaryEffect?.contains('33%') ?? false) {
      healAmount = (pokemon.maxHp * 0.33).toInt();
    } else if (move.secondaryEffect?.contains('50%') ?? false) {
      healAmount = pokemon.maxHp ~/ 2;
    }

    if (healAmount > 0) {
      final actualHeal = min(healAmount, pokemon.maxHp - pokemon.currentHp);
      pokemon.currentHp += actualHeal;

      if (actualHeal > 0) {
        events.add(SimulationEvent(
          id: _uuid.v4(),
          message: '${pokemon.pokemonName} recovered $actualHeal HP!',
          type: SimulationEventType.statusApplied,
          affectedPokemonName: pokemon.originalName,
        ));
      }
    }

    return events;
  }

  /// Parse and apply recoil effects
  static List<SimulationEvent> _parseRecoilEffect(
    Move move,
    BattlePokemon pokemon,
  ) {
    final events = <SimulationEvent>[];

    // Most recoil moves deal 25-33% recoil
    int recoilPercent = 25;
    if (move.secondaryEffect?.contains('33%') ?? false) {
      recoilPercent = 33;
    }

    if (move.power != null && move.power! > 0) {
      // Estimate damage based on move power as percentage of max HP
      // This is a simplified calculation; actual damage would come from DamageCalculator
      final estimatedDamage = (move.power! * 2); // Rough estimate
      final recoilDamage = max(1, (estimatedDamage * recoilPercent ~/ 100));

      pokemon.currentHp = max(0, pokemon.currentHp - recoilDamage);

      events.add(SimulationEvent(
        id: _uuid.v4(),
        message: '${pokemon.pokemonName} took recoil damage!',
        type: SimulationEventType.statusApplied,
        affectedPokemonName: pokemon.originalName,
      ));
    }

    return events;
  }

  /// Get human-readable status message
  static String _getStatusMessage(String status) {
    return switch (status) {
      'burn' => 'burned',
      'paralysis' => 'paralyzed',
      'poison' => 'poisoned',
      'badPoison' => 'badly poisoned',
      'sleep' => 'put to sleep',
      'freeze' => 'frozen',
      'confusion' => 'confused',
      _ => status,
    };
  }
}
