# Move Effect Processor Refactoring - Design Proposal

## Problem Statement: From Substring Matching to Structured Effects

The current move effect processor is **fundamentally broken** in how it handles healing/drain effects (and by extension, many other complex effects). The issues:

### Critical Bug #1: Absorb Healing Amount
**Current code:**
```dart
if (move.secondaryEffect?.contains('half') ?? false) {
  healAmount = pokemon.maxHp ~/ 2;  // ❌ WRONG
}
```

**The Bug:**
- Takes 50% of **max HP** instead of 50% of **damage dealt**
- Example: 100 HP Pokémon with Absorb
  - Current (wrong): Always heals 50 HP regardless of damage
  - Correct: If Absorb deals 20 damage, heals 10 HP (50% of 20)
  - Impact: **Massively overpowers healing moves**

**Root Cause:**
- Trying to parse effect from natural language text
- No knowledge of what "half" refers to (damage vs max HP)
- No integration with damage calculation system

### Critical Bug #2: No Context Awareness
Examples of where context matters:
- "May cause burn" vs "Causes burn" (probabilistic vs guaranteed)
- "Recover half the damage" (drain) vs "Restore HP by half" (flat healing)
- "May lower" (secondary effect) vs "Lowers" (guaranteed)
- Effect application point:
  - Before or after damage?
  - Once or per hit?
  - Interaction with abilities/items?

### Critical Bug #3: No Ability/Item Integration
**Big Root Item Example:**
- Absorb normally heals 50% of damage
- **With Big Root: heals 65% of damage** (30% more)
- Current code: **No knowledge of items, will always heal 50%**

**Liquid Ooze Ability Example:**
- Absorb normally heals attacker
- **Against Liquid Ooze: reverses effect, attacker loses HP instead**
- Current code: **No knowledge of abilities, will always heal**

### Critical Bug #4: Multi-Hit Interaction
- Multi-hit moves trigger effects **per hit**, not once per move
- Current code assumes effect applies once
- Drain moves on multi-hit should heal per hit independently

## Solution Architecture

### 1. Replace String Parsing with Structured Types

**Current (BAD):**
```dart
void processSecondaryEffect(Move move, ...) {
  if (move.secondaryEffect?.contains('burn')) { /* apply burn */ }
  else if (move.secondaryEffect?.contains('heal')) { /* apply heal */ }
  else if (move.secondaryEffect?.contains('lower')) { /* apply stat down */ }
  // ... dozens more substring checks
}
```

**Proposed (GOOD):**
```dart
abstract class MoveEffect {
  void apply(BattlePokemon attacker, BattlePokemon defender, 
    int damageDealt, List<SimulationEvent> events);
}

class DrainHealingEffect extends MoveEffect {
  final double drainPercent; // 0.50 for Absorb
  final bool isGuaranteed;
  
  void apply(...) {
    // Integration with damage result
    final healAmount = (damageDealt * drainPercent).floor();
    // Integrated ability/item handling
    final finalAmount = _applyAbilityModifiers(attacker, defender, healAmount);
    final cappedAmount = min(finalAmount, defender.maxHp - defender.currentHp);
    attacker.currentHp += cappedAmount;
  }
}
```

### 2. Move Model Extensions

**Add:**
```dart
class Move {
  // ... existing fields ...
  
  /// Structured effect object (replaces string parsing)
  final MoveEffect? effect;
  
  /// Whether effect triggers per hit (for multi-hit moves)
  final bool triggersPerHit;
  
  /// When effect applies relative to damage
  final EffectTiming effectTiming; // IMMEDIATE, AFTER_DAMAGE, END_OF_TURN
}

enum EffectTiming {
  immediate,      // Before move resolves (e.g., Trick Room)
  afterDamage,    // After damage calculated (e.g., Absorb heals)
  endOfTurn,      // After all actions this turn
  afterHit,       // After each hit (for multi-hit moves)
}
```

### 3. Effect Handler Hierarchy

```dart
// Base interface
abstract class MoveEffect {
  /// Apply this effect during battle resolution
  /// [damageDealt] is known at this point if effect is AFTER_DAMAGE
  void apply(
    BattlePokemon attacker,
    BattlePokemon defender,
    Move move,
    int damageDealt,
    List<SimulationEvent> events,
  );
}

// Specific implementations
class DrainHealingEffect extends MoveEffect {
  final double drainPercent;
  
  @override
  void apply(attacker, defender, move, damageDealt, events) {
    int healAmount = (damageDealt * drainPercent).floor();
    
    // Apply ability modifiers (Liquid Ooze reverses)
    if (defender.ability?.name == 'Liquid Ooze') {
      // Reverse: attacker loses instead of heals
      final lossAmount = min(healAmount, attacker.currentHp - 1);
      attacker.currentHp -= lossAmount;
      events.add(/* loss event */);
      return;
    }
    
    // Apply item modifiers (Big Root increases)
    if (attacker.heldItem?.name == 'Big Root') {
      healAmount = (healAmount * 1.30).floor(); // 30% increase
    }
    
    // Apply HP cap
    final actualHeal = min(healAmount, defender.maxHp - defender.currentHp);
    attacker.currentHp += actualHeal;
    
    if (actualHeal > 0) {
      events.add(/* healing event */);
    }
  }
}

class StatusConditionEffect extends MoveEffect {
  final String statusCondition;
  final double? probabilityPercent;
  
  @override
  void apply(attacker, defender, move, damageDealt, events) {
    // Check if probabilistic and roll
    if (probabilityPercent != null && 
        Random().nextDouble() * 100 > probabilityPercent!) {
      return; // Effect didn't trigger
    }
    
    // Apply ability checks (Water Absorb, etc.)
    if (defender.ability?.preventStatusCondition(statusCondition) ?? false) {
      events.add(/* immunity event */);
      return;
    }
    
    // Apply condition
    defender.applyStatusCondition(statusCondition);
    events.add(/* status applied event */);
  }
}

class StatChangeEffect extends MoveEffect {
  final Map<String, int> statChanges; // {'attack': -1, 'speed': -2}
  final bool affectsAttacker; // Some moves lower user's stats
  
  @override
  void apply(...) { /* similar pattern */ }
}

class FlinchEffect extends MoveEffect {
  @override
  void apply(attacker, defender, move, damageDealt, events) {
    // Only if damage was dealt
    if (damageDealt <= 0) return;
    
    // Check defender's ability (Inner Focus prevents)
    if (defender.ability?.name == 'Inner Focus') {
      events.add(/* immunity event */);
      return;
    }
    
    // Set flinch state
    defender.isFlinching = true;
    events.add(/* flinch event */);
  }
}
```

### 4. Multi-Hit Integration

For multi-hit moves, apply effects per-hit:

```dart
class DamageCalculator {
  static MultiHitResult calculateMultiHitDamage(...) {
    final hitDamages = <int>[];
    final hitEvents = <SimulationEvent>[];
    
    while (hitCount > 0) {
      // Roll hit
      if (!_checkAccuracy()) {
        // First miss breaks chain
        return MultiHitResult(...);
      }
      
      // Calculate single hit damage
      final damage = _rollDamage(...);
      hitDamages.add(damage);
      
      // ✨ Apply per-hit effects HERE
      if (move.effect?.triggersPerHit ?? false) {
        move.effect!.apply(attacker, defender, move, damage, hitEvents);
      }
      
      hitCount--;
    }
    
    return MultiHitResult(
      hitCount: hitDamages.length,
      hitDamages: hitDamages,
      totalDamage: hitDamages.fold(0, (a, b) => a + b),
      events: hitEvents,
    );
  }
}
```

## Implementation Roadmap

### Phase 1: Extract Effect Metadata from JSON
Parse move definitions to identify effect types:
```json
{
  "name": "Absorb",
  "effect": "User recovers half the HP inflicted on opponent.",
  "effect_type": "DRAIN_HEALING",
  "drain_percent": 50,
  "triggers_per_hit": false,
  "effect_timing": "AFTER_DAMAGE"
}
```

### Phase 2: Build Effect Handlers
Implement handler classes for common effects:
- [ ] DrainHealingEffect (Absorb, Drain Punch, Giga Drain, Leech Life, etc.)
- [ ] StatusConditionEffect (Thunder Wave, Will-O-Wisp, Toxic, etc.)
- [ ] StatChangeEffect (Dragon Dance, Swords Dance, Growl, etc.)
- [ ] FlinchEffect (Flinch-chance moves)
- [ ] RecoilEffect (Jump Kick, High Jump Kick, Struggle)
- [ ] ConfusionEffect (Confusion chance)
- [ ] TrappingEffect (Wrap, Fire Spin, etc.)

### Phase 3: Rewrite Move Effect Processor
```dart
class MoveEffectProcessor {
  static List<SimulationEvent> processSecondaryEffect(
    Move move,
    BattlePokemon attacker,
    BattlePokemon defender,
    int damageDealt,
  ) {
    final events = <SimulationEvent>[];
    
    if (move.effect == null) return events;
    
    // Single point of application
    move.effect!.apply(attacker, defender, move, damageDealt, events);
    
    return events;
  }
}
```

### Phase 4: Migrate All Moves
Convert all 934 moves to structured effects:
1. Prioritize: Drain healing (8), Status conditions (200+), Stat changes (150+)
2. Build tests as you go
3. Verify against current behavior

### Phase 5: Multi-Hit Integration
Connect with `DamageCalculator.calculateMultiHitDamage()` to apply effects per-hit.

## Test Coverage Strategy

### For Each Effect Type: Test Matrix

**DrainHealingEffect (Absorb):**
- [ ] Basic: Heals correct % of damage dealt (50%)
- [ ] HP capping: Doesn't exceed max HP
- [ ] Item: Big Root increases to 65%
- [ ] Ability: Liquid Ooze reverses (user loses HP)
- [ ] Multi-hit: Each hit heals independently
- [ ] No damage: Zero healing (defensive move)
- [ ] Immunity: Doesn't heal if immune somehow

**StatusConditionEffect:**
- [ ] Guaranteed effect applies
- [ ] Probabilistic effect rolls correctly
- [ ] Ability immunity works (Water Absorb vs Thunder Wave)
- [ ] Already-afflicted check (can't double-apply)
- [ ] Multi-hit: Applies per hit independently

## Expected Outcome

- **Correctness**: All effects behave like real Pokémon games
- **Maintainability**: Clear, testable code instead of string parsing
- **Extensibility**: Easy to add new effect types
- **Debuggability**: Can see exactly what effect a move has
- **Performance**: No runtime string parsing

## Timeline

- **Phase 1-2**: 1-2 weeks (effect metadata + handlers)
- **Phase 3-4**: 2-3 weeks (rewrite + migration)
- **Phase 5**: 1 week (multi-hit integration)
- **Total**: 4-6 weeks for complete refactoring

## Questions for User

1. Should I start with DrainHealingEffect since it's well-understood from Absorb analysis?
2. Should I build Phase 1-2 (structure + handlers) before migrating existing moves?
3. Should I refactor during Phase 2 or after Phase 2 (multi-hit) is complete?
