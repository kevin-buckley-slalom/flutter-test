import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/services/simulation_event.dart';

/// Processes ability effects and triggers
class AbilityEffectProcessor {
  /// Abilities that activate when switching in
  static const switchInAbilities = {
    'intimidate': 'reduces opponent Attack',
    'stealth rock': 'sets entry hazard',
    'entry hazard': 'sets up hazard',
    'terrain-setter': 'sets terrain',
    'weather-setter': 'sets weather',
  };

  /// Check if ability triggers on entry and apply effects
  static List<SimulationEvent> processSwitchInAbility(
    BattlePokemon pokemon,
    BattlePokemon? opponent,
  ) {
    final events = <SimulationEvent>[];
    final ability = pokemon.ability.toLowerCase();

    switch (ability) {
      case 'intimidate':
        if (opponent != null) {
          // Reduce opponent's attack by one stage
          opponent.statStages['atk'] =
              ((opponent.statStages['atk'] ?? 0) - 1).clamp(-6, 6);
          events.add(SimulationEvent(
            message:
                '${pokemon.pokemonName}\'s Intimidate lowered ${opponent.pokemonName}\'s Attack!',
            type: SimulationEventType.abilityActivation,
            affectedPokemonName: opponent.originalName,
          ));
        }
        break;

      case 'static':
        if (opponent != null && _shouldApplyStatus(30)) {
          // 30% chance to paralyze on contact
          opponent.status = 'paralysis';
          events.add(SimulationEvent(
            message: '${opponent.pokemonName} was paralyzed!',
            type: SimulationEventType.statusChange,
            affectedPokemonName: opponent.originalName,
          ));
        }
        break;

      case 'volt absorb':
      case 'water absorb':
      case 'flash fire':
        // These abilities don't trigger on switch-in
        break;

      case 'regenerator':
        // Triggers on switch-out, not in
        break;

      // Terrain/Weather setters
      case 'drizzle':
        events.add(SimulationEvent(
          message: '${pokemon.pokemonName} activated rain!',
          type: SimulationEventType.weatherChange,
        ));
        break;

      case 'drought':
        events.add(SimulationEvent(
          message: '${pokemon.pokemonName} activated sun!',
          type: SimulationEventType.weatherChange,
        ));
        break;

      case 'primordial sea':
        events.add(SimulationEvent(
          message: '${pokemon.pokemonName} activated heavy rain!',
          type: SimulationEventType.weatherChange,
        ));
        break;

      case 'desolate land':
        events.add(SimulationEvent(
          message: '${pokemon.pokemonName} activated harsh sunlight!',
          type: SimulationEventType.weatherChange,
        ));
        break;

      case 'terrain setter':
        // Implement terrain setters when available
        break;
    }

    return events;
  }

  /// Check if ability triggers during turn
  static List<SimulationEvent> processTurnAbility(
    BattlePokemon pokemon,
    BattlePokemon? opponent,
    String lastActionType, // 'attack', 'switch', 'status'
  ) {
    final events = <SimulationEvent>[];
    final ability = pokemon.ability.toLowerCase();

    switch (ability) {
      case 'regenerator':
        // Restore 1/3 of max HP on switch
        if (lastActionType == 'switch') {
          final hpToRestore = (pokemon.maxHp / 3).toInt();
          final newHp =
              (pokemon.currentHp + hpToRestore).clamp(0, pokemon.maxHp);
          pokemon.currentHp = newHp;
          events.add(SimulationEvent(
            message: '${pokemon.pokemonName} restored HP!',
            type: SimulationEventType.heal,
            affectedPokemonName: pokemon.originalName,
            damageAmount: hpToRestore,
          ));
        }
        break;

      case 'natural cure':
        // Remove status on switch
        if (lastActionType == 'switch' && pokemon.status != null) {
          pokemon.status = null;
          events.add(SimulationEvent(
            message: '${pokemon.pokemonName} was cured by Natural Cure!',
            type: SimulationEventType.abilityActivation,
            affectedPokemonName: pokemon.originalName,
          ));
        }
        break;

      case 'synchronize':
        // If poisoned/paralyzed/burned, opponent gets same status
        if (lastActionType == 'attack' &&
            opponent != null &&
            pokemon.status != null &&
            ['poison', 'paralysis', 'burn'].contains(pokemon.status)) {
          opponent.status = pokemon.status;
          events.add(SimulationEvent(
            message:
                '${opponent.pokemonName} was afflicted by ${pokemon.pokemonName}\'s Synchronize!',
            type: SimulationEventType.statusChange,
            affectedPokemonName: opponent.originalName,
          ));
        }
        break;

      case 'aftermath':
        // Damage opponent on contact KO
        // TODO: Check if pokemon was KO'd by contact move
        break;

      case 'rough skin':
      case 'iron barbs':
      case 'effect spore':
        // These trigger on contact damage taken
        break;
    }

    return events;
  }

  /// Helper to determine if a chance-based ability triggers
  static bool _shouldApplyStatus(int chancePercent) {
    // TODO: Integrate with simulation RNG
    // For now, simple probability check
    return (chancePercent / 100) > 0.5; // Simplified
  }
}
