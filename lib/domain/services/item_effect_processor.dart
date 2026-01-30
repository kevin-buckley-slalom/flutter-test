import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/services/simulation_event.dart';

/// Processes item effects and triggers
class ItemEffectProcessor {
  /// Get damage modifier from attacker's item for this move
  static double getDamageModifier(
    String? item,
    String moveCategory,
    String moveType,
  ) {
    if (item == null) return 1.0;

    final itemLower = item.toLowerCase();

    switch (itemLower) {
      case 'choice band':
        return moveCategory == 'Physical' ? 1.5 : 1.0;
      case 'choice specs':
        return moveCategory == 'Special' ? 1.5 : 1.0;
      case 'life orb':
        return 1.3; // 1.3x all moves, but takes 10% recoil
      case 'assault vest':
        return 1.0; // No damage boost
      case 'choice scarf':
        return 1.0; // Speed boost, not damage
      default:
        return 1.0;
    }
  }

  /// Check if item triggers after move and apply effects
  static List<SimulationEvent> processTurnItem(
    BattlePokemon pokemon,
    String lastMoveType,
    bool tookDamage,
    int damageAmount,
  ) {
    final events = <SimulationEvent>[];
    final item = pokemon.item?.toLowerCase();

    if (item == null) return events;

    switch (item) {
      case 'life orb':
        if (lastMoveType != 'Status') {
          // Take 10% recoil damage
          final recoilDamage = (pokemon.maxHp / 10).toInt();
          final newHp =
              (pokemon.currentHp - recoilDamage).clamp(0, pokemon.maxHp);
          final actualRecoil = pokemon.currentHp - newHp;
          pokemon.currentHp = newHp;

          events.add(SimulationEvent(
            message:
                '${pokemon.pokemonName} lost $actualRecoil HP to Life Orb recoil!',
            type: SimulationEventType.damage,
            affectedPokemonName: pokemon.originalName,
            damageAmount: actualRecoil,
            hpBefore: pokemon.currentHp + actualRecoil,
            hpAfter: newHp,
          ));
        }
        break;

      case 'air balloon':
        // Immunity to ground moves until hit
        // (Handled in damage calculation, not here)
        break;

      case 'weakness policy':
        if (tookDamage) {
          // Check if damage was super-effective
          // For now, simplified: assume SE damage triggers it
          pokemon.statStages['atk'] =
              ((pokemon.statStages['atk'] ?? 0) + 2).clamp(-6, 6);
          pokemon.statStages['spa'] =
              ((pokemon.statStages['spa'] ?? 0) + 2).clamp(-6, 6);

          events.add(SimulationEvent(
            message:
                '${pokemon.pokemonName}\'s Weakness Policy boosted its offenses!',
            type: SimulationEventType.itemActivation,
            affectedPokemonName: pokemon.originalName,
          ));
        }
        break;

      case 'assault vest':
        // Reduces special damage taken by 25% (handled in damage calc)
        break;

      case 'rocky helmet':
        // If hit by contact move, damage opponent by 12.5% of their max HP
        // (Handled when opponent uses contact move)
        break;

      case 'scarf':
      case 'choice scarf':
        // Boosts speed by 1.5x (handled in turn order)
        break;

      case 'iron ball':
        // Reduces speed by 50% (handled in turn order)
        break;

      case 'exp share':
      case 'leftovers':
        // Healing/exp items (not relevant in damage calculation)
        break;
    }

    return events;
  }

  /// Check if item triggers at end of turn for passive healing
  static List<SimulationEvent> processEndOfTurnItem(BattlePokemon pokemon) {
    final events = <SimulationEvent>[];
    final item = pokemon.item?.toLowerCase();

    if (item == null) return events;

    switch (item) {
      case 'leftovers':
        final healAmount = (pokemon.maxHp / 8).toInt();
        final newHp = (pokemon.currentHp + healAmount).clamp(0, pokemon.maxHp);
        final actualHeal = newHp - pokemon.currentHp;

        if (actualHeal > 0) {
          pokemon.currentHp = newHp;
          events.add(SimulationEvent(
            message:
                '${pokemon.pokemonName} restored $actualHeal HP with Leftovers!',
            type: SimulationEventType.heal,
            affectedPokemonName: pokemon.originalName,
            damageAmount: actualHeal,
          ));
        }
        break;

      case 'black sludge':
        // Heals Poison types, damages others
        // TODO: Check pokemon type
        final healAmount = (pokemon.maxHp / 8).toInt();
        final newHp = (pokemon.currentHp + healAmount).clamp(0, pokemon.maxHp);
        final actualHeal = newHp - pokemon.currentHp;

        if (actualHeal > 0) {
          pokemon.currentHp = newHp;
          events.add(SimulationEvent(
            message:
                '${pokemon.pokemonName} restored $actualHeal HP with Black Sludge!',
            type: SimulationEventType.heal,
            affectedPokemonName: pokemon.originalName,
            damageAmount: actualHeal,
          ));
        }
        break;

      case 'shell bell':
        // Heals 1/8 of damage dealt to opponent
        // TODO: Track damage dealt this turn
        break;

      case 'drain chip':
      case 'aqua chill':
      case 'chill drive':
        // Passive healing effects
        break;
    }

    return events;
  }

  /// Get defensive modifier from item
  static double getDefensiveModifier(
    String? item,
    String damageType, // 'physical', 'special', 'status'
  ) {
    if (item == null) return 1.0;

    final itemLower = item.toLowerCase();

    switch (itemLower) {
      case 'assault vest':
        return damageType == 'special'
            ? 0.75
            : 1.0; // 25% reduction on special damage
      case 'filter':
      case 'solid rock':
        return 0.75; // 25% reduction on super-effective damage
      case 'thick club':
        return damageType == 'physical' ? 2.0 : 1.0; // (for Cubone/Marowak)
      default:
        return 1.0;
    }
  }
}
