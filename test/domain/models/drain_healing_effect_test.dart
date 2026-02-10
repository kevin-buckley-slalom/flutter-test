import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';
import 'package:championdex/domain/battle/battle_ui_state.dart';
import 'package:championdex/domain/models/move_effect.dart';
import 'package:championdex/domain/battle/simulation_event.dart';

void main() {
  group('DrainHealingEffect (Absorb)', () {
    late BattlePokemon attacker;
    late BattlePokemon defender;
    late Move absorb;
    late List<SimulationEvent> events;

    setUp(() {
      // Attacker: Butterfree at 50/100 HP
      attacker = BattlePokemon(
        pokemonName: 'Butterfree',
        originalName: 'Butterfree',
        currentHp: 50,
        maxHp: 100,
        level: 20,
        ability: 'Compound Eyes',
        item: null,
        isShiny: false,
        teraType: 'Normal',
        moves: ['Absorb'],
        statStages: {},
        queuedAction: null,
        imagePath: null,
        imagePathLarge: null,
        stats: null,
        types: ['Bug', 'Flying'],
      );

      // Defender: Pidgeot at 80/120 HP
      defender = BattlePokemon(
        pokemonName: 'Pidgeot',
        originalName: 'Pidgeot',
        currentHp: 80,
        maxHp: 120,
        level: 20,
        ability: 'Keen Eye',
        item: null,
        isShiny: false,
        teraType: 'Normal',
        moves: [],
        statStages: {},
        queuedAction: null,
        imagePath: null,
        imagePathLarge: null,
        stats: null,
        types: ['Normal', 'Flying'],
      );

      // Create Absorb move
      absorb = Move(
        name: 'Absorb',
        type: 'Grass',
        category: 'Special',
        power: 20,
        accuracy: 100,
        pp: 25,
        effect: 'User recovers half the HP inflicted on opponent.',
        makesContact: false,
        generation: 1,
        secondaryEffect: 'User recovers half the HP inflicted on opponent.',
      );

      events = [];
    });

    test('Basic healing: heals 50% of damage dealt', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Simulate: Absorb deals 20 damage
      const damageDealt = 20;
      final initialHp = attacker.currentHp;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Should heal: 20 * 0.50 = 10 HP
      expect(attacker.currentHp, equals(initialHp + 10));
      expect(events.length, equals(1));
      expect(events[0].message, contains('recovered 10 HP'));
    });

    test('No healing if damage is zero (miss)', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);
      final initialHp = attacker.currentHp;

      effect.apply(attacker, defender, absorb, 0, events);

      expect(attacker.currentHp, equals(initialHp)); // No change
      expect(events.isEmpty, isTrue);
    });

    test('HP capping: cannot exceed max HP', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Attacker at 95/100 HP, takes 20 damage heal
      attacker.currentHp = 95;
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Should only heal 5 HP to reach max, not 10
      expect(attacker.currentHp, equals(100)); // Max HP
      expect(events[0].message, contains('recovered 5 HP'));
    });

    test('Big Root item increases healing to 65%', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Attacker holding Big Root
      attacker = attacker.copyWith(item: 'Big Root');
      attacker.currentHp = 50;
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Base healing: 20 * 0.50 = 10
      // With Big Root: 10 * 1.30 = 13
      expect(attacker.currentHp, equals(50 + 13));
      expect(events[0].message, contains('Big Root'));
    });

    test('Liquid Ooze ability reverses healing to damage', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Defender has Liquid Ooze ability
      defender = defender.copyWith(ability: 'Liquid Ooze');
      attacker.currentHp = 50;
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Should lose HP instead: 20 * 0.50 = 10 HP lost
      expect(attacker.currentHp, equals(50 - 10));
      expect(events[0].message, contains('Liquid Ooze'));
      expect(events[0].message, contains('lost'));
    });

    test('Liquid Ooze + Big Root: Big Root ignored when reversed', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Both Big Root and Liquid Ooze
      attacker = attacker.copyWith(item: 'Big Root');
      defender = defender.copyWith(ability: 'Liquid Ooze');
      attacker.currentHp = 50;
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Liquid Ooze reverses BEFORE Big Root is applied
      // So just lose 10 HP (50% of 20), not 13
      expect(attacker.currentHp, equals(50 - 10));
    });

    test('Attacker already at max HP: no healing event', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      attacker.currentHp = 100; // Already at max
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      expect(attacker.currentHp, equals(100));
      // No event generated when healing is 0
      expect(events.isEmpty, isTrue);
    });

    test('triggers per-hit (for multi-hit moves)', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);
      expect(effect.triggersPerHit, isTrue);
    });

    test('effect timing is afterDamage', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);
      expect(effect.timing, equals(EffectTiming.afterDamage));
    });

    test('description is accurate', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);
      expect(effect.description, contains('50'));
      expect(effect.description, contains('Drain'));
    });

    test('Multiple hits scenario: each hit heals independently', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      attacker.currentHp = 50;
      events.clear();

      // First hit: 10 damage dealt
      effect.apply(attacker, defender, absorb, 10, events);
      expect(attacker.currentHp, equals(50 + 5)); // 50% of 10

      // Second hit: 10 damage dealt (effect should apply again)
      effect.apply(attacker, defender, absorb, 10, events);
      expect(attacker.currentHp, equals(55 + 5)); // Another 50% of 10

      expect(events.length, equals(2));
    });

    test('Healing amount calculation edge case: odd damage', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      attacker.currentHp = 50;
      const damageDealt = 15; // Odd number

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // 15 * 0.50 = 7.5 -> truncates to 7
      expect(attacker.currentHp, equals(50 + 7));
    });

    test('Big Root with odd damage: multiplicative calculation', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      attacker = attacker.copyWith(item: 'Big Root');
      attacker.currentHp = 50;
      const damageDealt = 15;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // 15 * 0.50 = 7.5 (truncates to 7)
      // 7 * 1.30 = 9.1 (truncates to 9)
      expect(attacker.currentHp, equals(50 + 9));
    });

    test('Recoil cannot kill user (prevents going to 0 or below)', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      // Create Liquid Ooze reversal scenario where user would die
      defender = defender.copyWith(ability: 'Liquid Ooze');
      attacker.currentHp = 5; // Very low
      const damageDealt = 20;

      effect.apply(attacker, defender, absorb, damageDealt, events);

      // Should lose 10 HP, but clamped to keep at least 1 HP
      expect(attacker.currentHp, equals(1)); // 5 - 4, clamped to leave 1
    });

    test('Event generated with correct pokemon name', () {
      final effect = DrainHealingEffect(drainPercent: 0.50);

      effect.apply(attacker, defender, absorb, 20, events);

      expect(events[0].affectedPokemonName, equals('Butterfree'));
      expect(events[0].message, contains('Butterfree'));
    });
  });
}
