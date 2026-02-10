# Absorb Move - Current Test Coverage vs. Required Coverage

## Current Test (move_effect_processor_test.dart, line 465-479)

### What It Tests
✅ Move is recognized as having secondary effect
✅ Attacker HP increases (basic healing occurs)
❌ **MAJOR GAPS** (see below)

### What It Does NOT Test

#### 1. **Healing Amount Accuracy**
- Current test: `expect(attacker.currentHp, greaterThanOrEqualTo(50))`
- Problem: Only checks HP increased, not by how much
- Required: Verify exactly 50% of damage is healed
  - Move power: 20
  - Assuming ~15-25 damage dealt (depends on modifiers)
  - Should heal: 7.5-12.5 HP
  - Test should verify: 50% ± margin of actual damage

#### 2. **Max HP Capping**
- No test for: healing that would exceed max HP
- Scenario: Attacker at 95/100 HP, Absorb deals 20 damage
- Expected: Heal only 5 HP to reach max, not 10
- Current code: `pokemon.currentHp += actualHeal;` might exceed maxHp

#### 3. **Big Root Item Interaction**
- **MISSING ENTIRELY** - No test exists
- Required test:
  ```dart
  test('Absorb with Big Root item increases healing to 65%')
  // Attacker holding Big Root
  // Same 20 damage dealt
  // Should heal: 20 × 0.65 = 13 HP (not 10)
  // Verify: attacker.currentHp increased by ~13 instead of ~10
  ```

#### 4. **Liquid Ooze Ability Interaction**
- **MISSING ENTIRELY** - No test exists
- Required test:
  ```dart
  test('Absorb against Liquid Ooze causes user to lose HP')
  // Defender has Liquid Ooze ability
  // Absorb deals 20 damage
  // Instead of healing, attacker should LOSE 50% of that (10 HP)
  // Starting at 100, should drop to 90
  // Verify: attacker.currentHp == 90
  ```

#### 5. **Multi-Hit Interaction**
- **MISSING** - What if move hits twice?
- Absorb is single-hit, but other drain moves might be multi-hit
- If multi-hit: each hit should trigger healing independently

#### 6. **Event Logging**
- Current test: Doesn't verify SimulationEvents generated
- Missing events:
  - Heal applied
  - Item modifier (Big Root) applied
  - Ability modifier (Liquid Ooze) applied
  - HP caps applied

#### 7. **Edge Cases**
- Attacker already at max HP (should heal 0, not error)
- Defender has immunity (move doesn't hit, no healing)
- Attacker has Liquid Ooze (self-reversal? unlikely but test)

## Implementation Reality Check

### Current move_effect_processor.dart Issue

```dart
if (normalized.contains('recover') || normalized.contains('heal') || normalized.contains('drain')) {
  events.addAll(_parseHealingEffect(move, defender, events.length));
}
```

And the `_parseHealingEffect` tries:
```dart
if (move.secondaryEffect?.contains('half') ?? false) {
  healAmount = pokemon.maxHp ~/ 2;  // ❌ WRONG: This is 50% of MAX, not damage!
}
```

### The Bug
- Takes 50% of **max HP** instead of 50% of **damage dealt**
- Absorb on a 100 HP Pokémon would always heal 50 HP (wrong!)
- Should heal based on actual damage calculator result (10-15 HP typically)

## Path Forward

We need to:
1. **Stop string parsing** - Create structured effect definitions
2. **Create DrainHealingEffect class** - Encapsulate the logic
3. **Integrate with damage calculation** - Know actual damage before applying healing
4. **Write comprehensive tests** - All scenarios above
5. **Handle all drain moves systematically** - Not just keyword matching

This is exactly why the user said the processor is "too naive" - it's trying to extract structured information from natural language descriptions, which is fragile and error-prone.
