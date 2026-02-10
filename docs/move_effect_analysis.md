# Move Effect Processor Refactoring - Detailed Analysis

## Absorb - Comprehensive Review

### Move Basics
- **Type**: Grass
- **Category**: Special
- **Power**: 20
- **Accuracy**: 100%
- **PP**: 25
- **Targets**: Single adjacent Pokémon

### Effect Type: DRAIN/HEALING

**Primary Effect**: "User recovers half the HP inflicted on opponent."
- **Trigger**: GUARANTEED (effect_chance: "-- %")
- **When Applied**: After damage is dealt to opponent
- **Mechanics**: 
  - User heals for 50% of damage dealt
  - Example: If Absorb deals 40 damage, user recovers 20 HP
  - Cannot exceed max HP

**Ability Interactions**:
1. **Liquid Ooze** (Opponent's ability)
   - Reverses the effect
   - User LOSES HP instead of gaining
   - Amount: Same percentage as would be gained (50% of damage in this case)
   - Net effect: User takes 50% of damage as recoil

**Item Interactions**:
1. **Big Root** (User's item)
   - Increases healing by 30% (multiplicative)
   - Calculation: 50% × 1.3 = 65% healing
   - Example: Deals 40 damage → heals for 26 HP (instead of 20)

### What Tests Are Needed

#### Basic Healing
- [x] Move deals damage and heals user for 50% of damage dealt
- [ ] Healing cannot exceed max HP
- [ ] Healing respects current HP properly

#### With Big Root Item
- [ ] Big Root increases healing to 65% of damage
- [ ] Multiplicative calculation: base% × 1.3

#### With Liquid Ooze Ability  
- [ ] Liquid Ooze reverses effect entirely
- [ ] User loses HP equal to what would be healed
- [ ] Amount is 50% of damage dealt

#### Edge Cases
- [ ] Partial damage (not full HP amount available) - healing capped
- [ ] Target at full HP already - no healing occurs
- [ ] Draining from Ghost-type with normal immunity rules
- [ ] Multiple Absorb hits in sequence - each hit heals independently
- [ ] Frozen user cannot heal? (ability check needed)

### Current Implementation Issues

**In move_effect_processor.dart**:
```dart
// This is TOO NAIVE:
if (normalized.contains('recover') || normalized.contains('heal') || normalized.contains('drain')) {
  events.addAll(_parseHealingEffect(move, defender, events.length));
}
```

Problems:
1. Only checks for keywords - doesn't understand mechanics
2. `_parseHealingEffect()` tries to parse percentage from string (error-prone)
3. Doesn't account for item interactions (Big Root)
4. Doesn't check for ability reversals (Liquid Ooze)
5. Doesn't validate healing doesn't exceed max HP
6. Doesn't handle multi-hit interaction (each hit = separate heal)
7. No events logged for item/ability modifiers

### Proper Implementation Strategy

Instead of substring matching, we should:

1. **Create a Move Effect Metadata System**
   - Pre-defined effects for known moves
   - Structured data (not string parsing)
   - Easy to test and extend

2. **Drain Healing Effect Handler**
   ```
   DrainEffect {
     baseDrainPercent: 50,  // Percentage of damage
     targetDrainPercent: null,  // Usually null
     affectedByBigRoot: true,  // Can Big Root increase it?
     affectedByLiquidOoze: true,  // Can ability reverse it?
     ...
   }
   ```

3. **Structured Processing**
   - Apply base healing
   - Apply item modifiers (Big Root)
   - Check ability overrides (Liquid Ooze)
   - Cap at max HP
   - Generate detailed events for each step

### Recommended Refactoring Steps

1. Create move effect metadata file (JSON or Dart constants)
2. Build specific effect handlers (not generic string parsing):
   - `DrainHealingEffectHandler`
   - `StatusConditionEffectHandler`
   - `StatChangeEffectHandler`
   - etc.
3. Update MoveEffectProcessor to dispatch to handlers
4. Write comprehensive tests for each handler
5. Validate against all related moves

### Moves Similar to Absorb (Drain Effects)
- Drain Punch (50% healing)
- Giga Drain (50% healing)
- Leech Life (50% healing)
- Draining Kiss (50% healing)
- Drain Punch (50% healing)
- Dream Eater (50% healing, only on sleeping targets)
- Essence Drain (75% healing)
- Horn Leech (50% healing)
- Milk Drink (various)
- Roost (various)
- Strength Sap (various)
- etc.

These all need structured handling, not substring matching.
