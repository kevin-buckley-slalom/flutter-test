# Multi-Hit Move Implementation Design

## Phase 2 - Multi-Hit Damage System

### Overview
Multi-hit moves attack multiple times in a single turn. Each hit is calculated separately with individual accuracy checks and damage rolls.

### Move Categories Identified

#### 1. **2-Hit Moves** (Fixed, always 2 hits)
- Bonemerang, Double Hit, Double Iron Bash, Double Kick, Dual Chop, Dual Wingbeat, Gear Grind, Twineedle, Dragon Darts
- Power per hit: Listed power value
- Total hits: Always 2

#### 2. **2-5 Hit Moves** (Variable, probabilistic)
- Arm Thrust, Barrage, Bone Rush, Bullet Seed, Comet Punch, Double Slap, Fury Attack, Fury Swipes, Icicle Spear, Pin Missile, Rock Blast, Scale Shot, Spike Cannon, Tail Slap, Water Shuriken
- Hit Distribution:
  - 2 hits: 37.5% chance
  - 3 hits: 37.5% chance
  - 4 hits: 12.5% chance
  - 5 hits: 12.5% chance
- Power per hit: Listed power value
- With Skill Link ability: Always 5 hits

#### 3. **3-Hit Moves** (Fixed, always 3 hits)
- Triple Kick, Triple Axel
- Power varies per hit (Triple Kick: 10/20/30, Triple Axel: 20/40/60)

### Architecture Design

```
Move Model Enhancement
├── isMultiHit: bool (derived from effect/secondary_effect)
├── multiHitType: enum (fixed2, fixed3, variable2to5)
├── multiHitPowerPattern: List<int>? (for variable power moves)
└── Methods to determine hit count

DamageCalculator Enhancement  
├── calculateMultiHitDamage()
│   ├── Determines number of hits
│   ├── Rolls accuracy for each hit
│   ├── Calculates damage per hit
│   └── Returns list of hit results
└── Maintains existing calculateDamage() for single-hit moves

BattleSimulationEngine Enhancement
├── Handle multi-hit results
├── Apply secondary effects per hit or after final hit
├── Log each hit separately
└── Track cumulative damage

MultiHitResult Model (NEW)
├── hitCount: int
├── hitDamages: List<int>
├── totalDamage: int
├── missedHits: List<int> (indices)
└── breakReason: String? (if stopped early)
```

### Implementation Rules

#### Hit Calculation
1. **Determine Hit Count**:
   - Fixed 2-hit: Always 2
   - Fixed 3-hit: Always 3
   - Variable 2-5: Roll distribution (37.5%, 37.5%, 12.5%, 12.5%)
   
2. **Accuracy Per Hit**:
   - Each hit has independent accuracy check
   - If a hit misses, remaining hits are cancelled
   - Example: Move with 90% accuracy, 5 hits planned → each hit has 90% chance

3. **Damage Per Hit**:
   - Calculate damage independently for each hit
   - Use listed power value (not total)
   - Apply all modifiers (STAB, type effectiveness, etc.)
   - Damage rolls independently per hit

4. **Secondary Effects**:
   - **Per-hit effects**: Flinch, secondary damage
   - **After-all-hits effects**: Status conditions, stat changes
   - Effect chance applies to final hit only (or each hit for per-hit effects)

### Test Cases Required

```dart
// Fixed 2-hit moves
test('Bonemerang hits exactly twice with independent damage rolls')
test('Double Kick misses second hit if first misses')
test('Twineedle applies poison chance after both hits')

// Variable 2-5 hit moves
test('Fury Attack hit distribution follows 37.5/37.5/12.5/12.5%')
test('Bullet Seed stops on first miss')
test('Rock Blast with Skill Link always hits 5 times')

// Fixed 3-hit moves
test('Triple Kick increases power each hit (10/20/30)')
test('Triple Axel doubles power each hit (20/40/60)')

// Damage calculations
test('Each hit applies type effectiveness independently')
test('STAB applies to each hit')
test('Critical hits roll independently per hit')
test('Damage variance applies per hit')

// Secondary effects
test('Double Iron Bash flinch chance applies after both hits')
test('Scale Shot stat changes apply after all hits complete')
test('Gear Grind damage calculated correctly with Steel type')

// Edge cases
test('Accuracy affects each hit independently')
test('Substitute broken mid-combo stops remaining hits')
test('Focus Sash/Sturdy triggered by final hit only')
test('Counter/Mirror Coat counts cumulative damage')
```

### Data Model Changes

```dart
// lib/data/models/move.dart
class Move {
  // ...existing fields...
  
  // Multi-hit support
  bool get isMultiHit => _detectMultiHit();
  MultiHitType? get multiHitType => _parseMultiHitType();
  List<int>? get powerPerHit => _parsePowerPattern();
  
  bool _detectMultiHit() {
    final text = (effect + secondaryEffect + inDepthEffect).toLowerCase();
    return text.contains('hits twice') ||
           text.contains('hits 2-5') ||
           text.contains('triple') ||
           text.contains('attacks twice') ||
           text.contains('user attacks twice');
  }
  
  MultiHitType? _parseMultiHitType() {
    final text = (effect + secondaryEffect).toLowerCase();
    if (text.contains('hits twice') || text.contains('attacks twice')) {
      return MultiHitType.fixed2;
    } else if (text.contains('hits 2-5') || text.contains('attacks 2-5')) {
      return MultiHitType.variable2to5;
    } else if (name.toLowerCase().contains('triple')) {
      return MultiHitType.fixed3;
    }
    return null;
  }
}

enum MultiHitType {
  fixed2,    // Always 2 hits
  fixed3,    // Always 3 hits (variable power)
  variable2to5,  // 2-5 hits with probability distribution
}

// lib/domain/models/multi_hit_result.dart (NEW FILE)
class MultiHitResult {
  final int hitCount;
  final List<int> hitDamages;
  final int totalDamage;
  final List<int> missedHits;
  final String? breakReason;
  
  MultiHitResult({
    required this.hitCount,
    required this.hitDamages,
    required this.missedHits,
    this.breakReason,
  }) : totalDamage = hitDamages.fold(0, (sum, dmg) => sum + dmg);
  
  bool get allHitsConnected => missedHits.isEmpty;
  int get successfulHits => hitDamages.length;
}
```

### Integration Points

1. **DamageCalculator.calculateDamage()**:
   - Check `move.isMultiHit`
   - If true, delegate to `calculateMultiHitDamage()`
   - Return MultiHitResult instead of single int

2. **BattleSimulationEngine.executeTurn()**:
   - Handle MultiHitResult
   - Log each hit with SimulationEvent
   - Apply secondary effects appropriately

3. **MoveEffectProcessor**:
   - Distinguish between per-hit and post-combo effects
   - Only apply after all hits complete (or after final hit)

### Success Criteria

✅ All 26 multi-hit moves properly handled
✅ Hit distribution matches Pokemon mechanics (37.5/37.5/12.5/12.5)
✅ Independent accuracy per hit
✅ Independent damage rolls per hit
✅ Secondary effects apply correctly
✅ Special cases (Triple Kick power progression) working
✅ Comprehensive test coverage (15+ tests)
✅ No regressions in existing single-hit moves
✅ Event logging shows each hit clearly

### Implementation Order

1. **Tests First** - Write all test cases (TDD)
2. **MultiHitResult Model** - Create data model
3. **Move Model Enhancement** - Add multi-hit detection
4. **DamageCalculator** - Implement calculateMultiHitDamage()
5. **Battle Engine Integration** - Handle MultiHitResult
6. **Effect Processor** - Distinguish per-hit vs post-combo
7. **Validation** - Run all tests, verify all 26 moves
8. **Documentation** - Update guides with multi-hit examples

### Notes

- Skill Link ability (always 5 hits) will be Phase 3 (abilities)
- Focus Band/Sash interaction is edge case for future
- Rage Powder/Follow Me in doubles is out of scope
- Protect/Detect blocks entire multi-hit sequence (Phase 3)
