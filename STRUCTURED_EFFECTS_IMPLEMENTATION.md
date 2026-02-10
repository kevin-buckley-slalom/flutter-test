# Structured Effects Implementation in moves.json

## ✅ What We Just Added

Added `structuredEffects` field to 6 drain healing moves in `assets/data/moves.json`:

### Drain Healing Moves Updated:

1. **Absorb** (line 17)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.50,
       "triggersPerHit": true
     }
   ]
   ```

2. **Drain Punch** (line 5683)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.50,
       "triggersPerHit": true
     }
   ]
   ```

3. **Draining Kiss** (line 5715)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.75,
       "triggersPerHit": true
     }
   ]
   ```

4. **Giga Drain** (line 9880)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.50,
       "triggersPerHit": true
     }
   ]
   ```

5. **Horn Leech** (line 11543)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.50,
       "triggersPerHit": true
     }
   ]
   ```

6. **Leech Life** (line 13240)
   ```json
   "structuredEffects": [
     {
       "type": "DrainHealing",
       "drainPercent": 0.50,
       "triggersPerHit": true
     }
   ]
   ```

---

## Schema Definition

The `structuredEffects` field has this structure:

```json
{
  "type": "DrainHealing",           // Effect type identifier
  "drainPercent": 0.50,             // Healing percentage (0.0-1.0)
  "triggersPerHit": true            // Whether it applies per hit in multi-hit moves
}
```

### Field Meanings:

- **type**: Identifies which effect class to instantiate (`DrainHealing`, `StatusInfliction`, `StatChange`, etc.)
- **drainPercent**: Percentage of damage dealt that heals the user
  - Absorb/Drain Punch/Giga Drain/Horn Leech/Leech Life: `0.50` (50%)
  - Draining Kiss: `0.75` (75%)
  - Dream Eater: `0.50` (50%) - when used on sleeping target
- **triggersPerHit**: Whether the effect applies to each hit separately in multi-hit moves
  - Always `true` for drain moves (healing applies per-hit)
  - Would be `false` for effects that only trigger once

---

## Next Steps: Wire Into Battle Engine

To actually use these structured effects in battle, you'll need to:

### Step 1: Update Move Model

Add deserialization to [lib/data/models/move.dart](lib/data/models/move.dart):

```dart
class Move {
  // ... existing fields ...
  
  /// Structured effects parsed from moves.json
  final List<dynamic> structuredEffects;  // Will be parsed into MoveEffect objects
  
  // In Move.fromJson():
  structuredEffects: json['structuredEffects'] as List<dynamic>? ?? [],
}
```

### Step 2: Create MoveEffectFactory

Create [lib/domain/services/move_effect_factory.dart](lib/domain/services/move_effect_factory.dart):

```dart
import 'package:championdex/domain/models/move_effect.dart';

class MoveEffectFactory {
  /// Create structured MoveEffect objects from JSON data
  static List<MoveEffect> createEffectsFromJson(
    List<dynamic>? effectsList,
  ) {
    final effects = <MoveEffect>[];
    
    if (effectsList == null || effectsList.isEmpty) {
      return effects;
    }
    
    for (final effectData in effectsList) {
      if (effectData is! Map<String, dynamic>) continue;
      
      final type = effectData['type'] as String?;
      
      switch (type) {
        case 'DrainHealing':
          effects.add(DrainHealingEffect(
            drainPercent: effectData['drainPercent'] as double? ?? 0.50,
            isGuaranteed: effectData['isGuaranteed'] as bool? ?? true,
            probabilityPercent: effectData['probabilityPercent'] as double? ?? 100.0,
          ));
          break;
        // Future: Add StatusInfliction, StatChange, etc.
        // case 'StatusInfliction':
        // case 'StatChange':
        // etc.
      }
    }
    
    return effects;
  }
  
  /// Fallback: Create effects from string parsing (for old moves without structuredEffects)
  static List<MoveEffect> createEffectsFromString(String? effectString) {
    // ... legacy string parsing logic ...
    return [];
  }
}
```

### Step 3: Update Battle Engine

Modify [lib/domain/services/battle_simulation_engine.dart](lib/domain/services/battle_simulation_engine.dart) at line 447:

**Current code (string-based):**
```dart
// Apply status effects from move
if (move.effectChancePercent != null || move.effectChanceRaw == '-- %') {
  final secondaryEffectEvents =
      MoveEffectProcessor.processSecondaryEffect(move, attacker, defender);
  events.addAll(secondaryEffectEvents);
}
```

**New code (structured):**
```dart
// Apply structured effects
final damageDealt = damageResult.averageDamage;

// Try structured effects first
final effectsList = move.structuredEffects;
if (effectsList.isNotEmpty) {
  final effects = MoveEffectFactory.createEffectsFromJson(effectsList);
  for (final effect in effects) {
    effect.apply(attacker, defender, move, damageDealt, events);
  }
} else {
  // Fallback to legacy string parsing
  final legacyEffects = MoveEffectFactory.createEffectsFromString(move.effect);
  for (final effect in legacyEffects) {
    effect.apply(attacker, defender, move, damageDealt, events);
  }
}
```

### Step 4: Multi-Hit Integration

For moves with multiple hits, apply per-hit effects after each hit:

```dart
// In _executeMove, when processing multi-hit damage:
final hits = calculateMultiHitDamage(move, attacker, defender);

for (int i = 0; i < hits.length; i++) {
  final hitDamage = hits[i];
  
  // Apply damage
  defender.currentHp -= hitDamage;
  
  // Apply per-hit effects (DrainHealing.triggersPerHit = true)
  final effects = MoveEffectFactory.createEffectsFromJson(move.structuredEffects);
  for (final effect in effects) {
    if (effect.triggersPerHit) {
      effect.apply(attacker, defender, move, hitDamage, events);
    }
  }
}

// After all hits, apply non-per-hit effects
for (final effect in effects) {
  if (!effect.triggersPerHit) {
    effect.apply(attacker, defender, move, totalDamage, events);
  }
}
```

---

## Testing the Integration

Once integrated, the battle simulator will:

1. ✅ Load Move(Absorb) from moves.json
2. ✅ Extract structuredEffects → `[{ type: "DrainHealing", drainPercent: 0.50 }]`
3. ✅ Create `DrainHealingEffect(drainPercent: 0.50)` via MoveEffectFactory
4. ✅ Calculate damage: Absorb deals 18 damage
5. ✅ Call `effect.apply(attacker, defender, move, 18, events)`
6. ✅ Apply healing: `18 * 0.50 = 9 HP`
7. ✅ Check Big Root: No → stay at 9 HP
8. ✅ Check Liquid Ooze: No → heal attacker
9. ✅ Generate SimulationEvent: "Butterfree recovered 9 HP!"
10. ✅ Multi-hit moves: Each hit triggers healing independently

---

## Example Flow: Butterfree Uses Absorb

```
User selects Absorb
      ↓
AttackAction { moveName: "Absorb" }
      ↓
Move.fromJson loads move + structuredEffects
      ↓
BattleEngine.processTurn()
      ↓
DamageCalculator → 18 damage
      ↓
Apply damage: Pidgeot 80 → 62 HP
      ↓
MoveEffectFactory.createEffectsFromJson([
  { type: "DrainHealing", drainPercent: 0.50 }
])
      ↓
DrainHealingEffect created
      ↓
effect.apply(Butterfree, Pidgeot, Absorb, 18, events)
      ↓
Healing calculated: 18 * 0.50 = 9
Check Big Root: not held → 9
Check Liquid Ooze: not used → heal
      ↓
Butterfree: 50 → 59 HP
      ↓
SimulationEvent added: "Butterfree recovered 9 HP!"
      ↓
Return all events to UI
```

---

## Summary of Data Formats

### moves.json Structure (NEW):
```json
{
  "Absorb": {
    "type": "Grass",
    "category": "Special",
    "power": 20,
    "accuracy": 100,
    "pp": 25,
    "effect": "...",
    "structuredEffects": [
      {
        "type": "DrainHealing",
        "drainPercent": 0.50,
        "triggersPerHit": true
      }
    ]
    // ... other fields ...
  }
}
```

### Move Model (needs update):
```dart
class Move {
  // ... existing fields ...
  final List<dynamic> structuredEffects;  // From JSON
}
```

### DrainHealingEffect (already implemented):
```dart
class DrainHealingEffect extends MoveEffect {
  final double drainPercent;
  final bool isGuaranteed;
  final double probabilityPercent;
  
  void apply(BattlePokemon attacker, BattlePokemon defender, 
             Move move, int damageDealt, List<SimulationEvent> events) {
    // Full implementation with Big Root, Liquid Ooze, multi-hit support
  }
}
```

---

## What Your Tests Validate

Your 15 passing tests in `test/domain/models/drain_healing_effect_test.dart` validate:

✅ Basic healing (50% of damage)
✅ No healing on miss (0 damage)
✅ HP capping (don't exceed max)
✅ Big Root item (+30%)
✅ Liquid Ooze reversal (damage instead)
✅ Liquid Ooze + Big Root interaction
✅ No event at max HP
✅ Per-hit triggering
✅ afterDamage timing
✅ Accurate description
✅ Multi-hit scenarios
✅ Odd damage truncation
✅ Big Root with odd damage
✅ Recoil damage capping
✅ Event with correct name

**Once integrated:** These same tests validate that the entire flow works end-to-end through the battle simulator! 🎯

