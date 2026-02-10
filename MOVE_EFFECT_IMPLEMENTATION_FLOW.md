# Move Effect Implementation Flow: From Tests to Battle Simulator

## Current State: The Gap Between Tests and Implementation

Your DrainHealingEffect tests **pass perfectly**, but they're currently **not integrated** into the actual battle simulator. Here's the complete flow and what's missing:

---

## 1. User Selects "Absorb" in Battle UI

```
┌─────────────────────────────────────────────────────────┐
│  Battle Simulation UI                                    │
│  (battle_simulation_view.dart)                           │
└────────────────────┬────────────────────────────────────┘
                     │ User taps "Absorb" move
                     ▼
┌─────────────────────────────────────────────────────────┐
│  PokemonConfigBottomSheet                               │
│  - Shows available moves                                │
│  - User selects move + target                           │
│  - Calls onActionSet(AttackAction)                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  BattleSimulationViewModel                              │
│  - Stores AttackAction in pokemon.queuedAction           │
│    AttackAction {                                        │
│      moveName: 'Absorb',                                │
│      targetPokemonName: 'Pidgeot',                      │
│      switchInPokemonName: null,                         │
│    }                                                     │
└────────────────────┬────────────────────────────────────┘
                     │ User clicks "Execute Turn"
                     ▼
┌─────────────────────────────────────────────────────────┐
│  startSimulation() in ViewModel                          │
│  1. Fetches all moves from MoveRepository               │
│  2. Creates actionsMap from queued actions              │
│  3. Creates BattleSimulationEngine                      │
│  4. Calls engine.processTurn(...)                       │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Battle Engine Processes the Turn

```
┌──────────────────────────────────────────────────────────────┐
│  BattleSimulationEngine.processTurn()                        │
│  (battle_simulation_engine.dart, line 53)                    │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼ (For each Pokémon in turn order)
┌──────────────────────────────────────────────────────────────┐
│  Extract AttackAction from actionsMap                        │
│  AttackAction { moveName: 'Absorb', targetPokemonName: ... }│
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  Look up Move from moveDatabase                              │
│  Move {                                                      │
│    name: 'Absorb',                                          │
│    type: 'Grass',                                           │
│    category: 'Special',                                     │
│    power: 20,                                               │
│    effect: 'User recovers half...',                         │
│    secondaryEffect: 'User recovers half...',               │
│    inDepthEffect: null,                                     │
│  }                                                          │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  _executeMove(                                               │
│    attacker: Butterfree,                                    │
│    defenders: [Pidgeot],                                    │
│    move: Move(Absorb),                                      │
│    ...                                                      │
│  ) [battle_simulation_engine.dart, line 281]                │
└────────────────────┬─────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
   ┌─────────────┐          ┌──────────────────┐
   │ Check if    │          │ Calculate        │
   │ move hits   │          │ damage dealt     │
   │             │          │ (DamageCalculator)
   │ MISS? Skip  │          │ avgDamage = 18   │
   │ hit         │          │ maxDamage = 22   │
   └──────┬──────┘          └────────┬─────────┘
          │ HIT                      │
          └──────────┬───────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  Apply damage to defender.currentHp                         │
│  Pidgeot: 80 HP → 62 HP (took 18 damage)                   │
└────────────────────┬─────────────────────────────────────────┘
                     │
        ┌────────────┴─────────────────────┐
        ▼                                  ▼
   ┌──────────────────┐          ┌─────────────────────┐
   │ Secondary Effects│          │ In-Depth Effects    │
   │ [line 447]       │          │ [line 454]          │
   │                  │          │                     │
   │ processSecondary │          │ processInDepthEffect│
   │ Effect(move,    │          │ (move, attacker,   │
   │  attacker,      │          │  defender)          │
   │  defender)      │          │                     │
   │                  │          │                     │
   │ ⚠️ PROBLEM:      │          │ ⚠️ PROBLEM:         │
   │ Parses effect    │          │ Parses effect       │
   │ from STRINGS!    │          │ from STRINGS!       │
   │                  │          │                     │
   │ String-based     │          │ Looking for:        │
   │ pattern matching │          │ 'recover', 'drain', │
   │ Not structured   │          │ 'heal' in effect    │
   │                  │          │ string              │
   └──────────────────┘          └─────────────────────┘
        │                              │
        ▼                              ▼
   Generates healing events     Creates generic events
   with hardcoded logic         No context about move
                                 structure
```

---

## 3. The Current Problem: String-Based Effects

In [move_effect_processor.dart](move_effect_processor.dart) line 125-130:

```dart
// Healing Effects
if (normalized.contains('recover') || normalized.contains('heal') || normalized.contains('drain')) {
  events.addAll(_parseHealingEffect(move, defender, events.length));
}
```

**Issues with current approach:**
- ✗ Parses natural language strings like "User recovers half the HP inflicted on opponent"
- ✗ No type safety or structure
- ✗ Hardcoded string matching logic (fragile)
- ✗ No access to actual damage dealt (guessed from move.power)
- ✗ Can't properly handle ability/item interactions
- ✗ Multi-hit moves don't work correctly

---

## 4. What Your Tests Are Creating (Not Yet Integrated)

Your `DrainHealingEffect` is a **structured, testable alternative**:

```dart
// Test creates this object:
final effect = DrainHealingEffect(drainPercent: 0.50);

// In tests, it's called directly:
effect.apply(attacker, defender, absorb, damageDealt, events);

// It handles:
✓ Actual damage amount (not guessed from BP)
✓ Big Root item (+30%)
✓ Liquid Ooze ability (reversal)
✓ HP capping (can't exceed max)
✓ Multi-hit scenarios (triggers per hit)
✓ Type safety and clear semantics
```

---

## 5. The Gap: Where Integration Needs to Happen

### Option A: Create Move.structuredEffects List (Recommended)

Update `Move` model to include structured effects:

```dart
class Move {
  final String name;
  // ... existing fields ...
  
  // NEW: Structured effects (replaces string parsing)
  final List<MoveEffect> structuredEffects;  // [DrainHealingEffect(...)]
  
  // Keep old fields for backward compatibility during migration
  final String effect;
  final String? secondaryEffect;
  final String? inDepthEffect;
}
```

Then in [moves.json](assets/data/moves.json), add structured effect data:

```json
{
  "name": "Absorb",
  "type": "Grass",
  "category": "Special",
  "power": 20,
  "accuracy": 100,
  "pp": 25,
  "effect": "User recovers half the HP inflicted on opponent.",
  "structuredEffects": [
    {
      "type": "DrainHealing",
      "drainPercent": 0.50,
      "triggersPerHit": true
    }
  ]
}
```

### Option B: Create Move-to-MoveEffect Mapper (Interim)

Create a mapping function that converts Move → List<MoveEffect>:

```dart
class MoveEffectFactory {
  static List<MoveEffect> createEffectsFromMove(Move move) {
    final effects = <MoveEffect>[];
    
    // Parse Absorb, Drain Punch, Giga Drain, etc.
    if (move.name == 'Absorb' || 
        move.name == 'Drain Punch' ||
        move.name == 'Giga Drain') {
      effects.add(DrainHealingEffect(drainPercent: 0.50));
    }
    
    // ... etc for other moves
    
    return effects;
  }
}
```

---

## 6. Integration Point: Update battle_simulation_engine.dart

Currently at [line 447-457](battle_simulation_engine.dart#L447-L457):

```dart
// CURRENT (String-based):
if (move.effectChancePercent != null || move.effectChanceRaw == '-- %') {
  final secondaryEffectEvents =
      MoveEffectProcessor.processSecondaryEffect(move, attacker, defender);
  events.addAll(secondaryEffectEvents);
}

// PROPOSED (Structured):
final damageDealt = damageResult.averageDamage;  // ← Already have this!

// Apply structured effects
final effects = move.structuredEffects;  // or MoveEffectFactory.createEffectsFromMove(move)
for (final effect in effects) {
  effect.apply(attacker, defender, move, damageDealt, events);
}
```

**Key insight:** The engine already has `damageResult.averageDamage` at this point—exactly what `DrainHealingEffect.apply()` needs!

---

## 7. Complete Flow With Structured Effects

```
┌────────────────────────────────────────────┐
│ 1. User selects Absorb in UI               │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 2. AttackAction queued in BattlePokemon    │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 3. BattleSimulationEngine.processTurn()   │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 4. Look up Move(Absorb) from database     │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 5. _executeMove(Butterfree, Pidgeot,      │
│    Move(Absorb), ...)                     │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 6. Calculate damage:                       │
│    damageDealt = 18 (average)              │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 7. Apply defender damage:                  │
│    Pidgeot: 80 → 62 HP                     │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 8. Apply structured effects:               │
│                                            │
│ for (effect in move.structuredEffects) {  │
│   effect.apply(attacker, defender,       │
│               move, 18, events)           │
│ }                                         │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 9. DrainHealingEffect.apply() called:     │
│    - drainPercent = 0.50                   │
│    - damageDealt = 18                      │
│    - healing = 18 * 0.50 = 9 HP           │
│    - Check Big Root? No                    │
│    - Check Liquid Ooze? No                 │
│    - Heal: Butterfree 50 → 59 HP          │
│    - Add SimulationEvent                   │
└─────────────────┬──────────────────────────┘
                  ▼
┌────────────────────────────────────────────┐
│ 10. Return all SimulationEvents to UI      │
└────────────────────────────────────────────┘
```

---

## 8. Testing the Integration

Once integrated, the **same tests pass** but now validate the entire flow:

```dart
test('Absorb in battle simulator heals attacker', () {
  // Real Move object from moves.json with structuredEffects
  final absorb = Move(
    name: 'Absorb',
    structuredEffects: [
      DrainHealingEffect(drainPercent: 0.50)
    ],
    // ... other fields ...
  );
  
  // Simulate through real engine
  final outcome = engine.processTurn(
    team1Active: [butterfree],
    team2Active: [pidgeot],
    team1Bench: [],
    team2Bench: [],
    actionsMap: {
      'Butterfree': AttackAction(moveName: 'Absorb', targetPokemonName: 'Pidgeot')
    },
    fieldConditions: {},
  );
  
  // Verify healing occurred
  expect(outcome.events.where((e) => e.message.contains('recovered')).length, greaterThan(0));
});
```

---

## 9. Multi-Hit Integration

For moves like **Fury Attack** (2-5 hits):

```dart
// In DamageCalculator or _executeMove:
final multiHitInfo = move.getMultiHitInfo();  // { minHits: 2, maxHits: 5 }

for (int hit = 0; hit < damagePerHit.length; hit++) {
  final hitDamage = damagePerHit[hit];
  
  // Apply damage
  defender.currentHp -= hitDamage;
  
  // Apply per-hit effects
  for (final effect in move.structuredEffects) {
    if (effect.triggersPerHit) {
      effect.apply(attacker, defender, move, hitDamage, events);
      // ← Heal 50% of THIS hit's damage, not total
    }
  }
}

// Apply end-of-move effects (single-trigger)
for (final effect in move.structuredEffects) {
  if (!effect.triggersPerHit) {
    effect.apply(attacker, defender, move, totalDamage, events);
  }
}
```

---

## Summary: The Missing Link

Your DrainHealingEffect is **correct and well-tested**, but it's not being used because:

1. ✗ `Move` objects don't have `structuredEffects` field
2. ✗ No mapping from `Move` → `List<MoveEffect>`
3. ✗ `BattleSimulationEngine` still uses string-based `MoveEffectProcessor`
4. ✗ No integration point to call `effect.apply()` with actual damage dealt

**Next step:** Add structured effects to moves.json and wire them into the engine. The tests will validate both the individual effect AND the full battle flow!

