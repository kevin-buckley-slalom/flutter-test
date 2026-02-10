# HP-Draining Moves: Complete Structured Effects Implementation

## ✅ All 15 HP-Draining Moves Updated in moves.json

Added proper `structuredEffects` to all HP-draining moves, accounting for their varying mechanics and drain percentages.

---

## 1. Damage-Based Drain Moves (Apply per hit)

These moves drain a percentage of damage dealt. Each hit in multi-hit moves applies the drain independently.

### 50% Drain Moves:
- **Absorb** (Grass/Special, 20 BP) ✓ Updated
- **Bouncy Bubble** (Water/Special, 90 BP) ✓ Updated
- **Drain Punch** (Fighting/Physical, 75 BP) ✓ Updated
- **Giga Drain** (Grass/Special, 75 BP) ✓ Updated
- **Leech Life** (Bug/Physical, 80 BP) ✓ Updated
- **Mega Drain** (Grass/Special, 40 BP) ✓ Updated
- **Parabolic Charge** (Electric/Special, 65 BP, targets all) ✓ Updated
- **Bitter Blade** (Fire/Physical, 90 BP) ✓ Updated
- **Dream Eater** (Psychic/Special, 100 BP, sleeping only) ✓ Updated

### 75% Drain Moves:
- **Draining Kiss** (Fairy/Special, 50 BP) ✓ Updated
- **Oblivion Wing** (Flying/Special, 80 BP) ✓ Updated

### Special Drain Moves:
- **Matcha Gotcha** (Grass/Special, 80 BP, targets all, may burn) ✓ Updated
  - Also applies StatusInfliction for burn effect
- **Horn Leech** (Grass/Physical, 75 BP) ✓ Updated

---

## 2. Status/Recurring Drain Moves

### Leech Seed (Grass/Status, 0 BP)
- **Type**: LeechSeed
- **Drain Percent**: 0.125 (1/8 of max HP per turn)
- **Recurring**: `true` (applies every turn while seeded)
- **Interactions**: Supports Big Root (+30%), Liquid Ooze (reversal)
- **Special Notes**: 
  - Doesn't work on Grass-type Pokémon
  - Persists until target switches or uses Rapid Spin
  - Passed with Baton Pass

### Dark Void (Dark/Status, 0 BP)
- **Type**: StatusInfliction
- **Status**: sleep
- **Targets Multiple**: true
- **Special Notes**:
  - Only usable by Darkrai (Darkrai signature move)
  - Not HP-draining, but sleep-based (related thematically)
  - Targets all adjacent opponents

---

## 3. JSON Structure Added to Each Move

### Standard Damage-Based Drain (50% Example):
```json
"structuredEffects": [
  {
    "type": "DrainHealing",
    "drainPercent": 0.50,
    "triggersPerHit": true
  }
]
```

### High-Drain (75% Example):
```json
"structuredEffects": [
  {
    "type": "DrainHealing",
    "drainPercent": 0.75,
    "triggersPerHit": true
  }
]
```

### Leech Seed (Recurring):
```json
"structuredEffects": [
  {
    "type": "LeechSeed",
    "drainPercent": 0.125,
    "recurringEffect": true,
    "triggersPerTurn": true,
    "note": "Leech Seed drains 1/8 (12.5%) of target's max HP each turn..."
  }
]
```

### Dark Void (Status Only):
```json
"structuredEffects": [
  {
    "type": "StatusInfliction",
    "status": "sleep",
    "targetsMultiple": true,
    "note": "Dark Void is a status move, not HP-draining..."
  }
]
```

---

## Complete Reference Table

| Move | Type | Category | BP | Drain % | Effect Type | Multi-Hit? | Multi-Target? | Special Notes |
|------|------|----------|----|----|-----------|-----------|---------------|---------------|
| Absorb | Grass | Special | 20 | 50% | DrainHealing | No | No | Gen 1 classic |
| Bitter Blade | Fire | Physical | 90 | 50% | DrainHealing | No | No | Slicing move, Gen 9 |
| Bouncy Bubble | Water | Special | 90 | 50% | DrainHealing | No | No | Let's Go exclusive |
| Dark Void | Dark | Status | — | — | StatusInfliction | No | Yes | Darkrai signature, sleep |
| Drain Punch | Fighting | Physical | 75 | 50% | DrainHealing | No | No | Punch move |
| Draining Kiss | Fairy | Special | 50 | 75% | DrainHealing | No | No | Contact move |
| Dream Eater | Psychic | Special | 100 | 50% | DrainHealing | No | No | Sleeping targets only |
| Giga Drain | Grass | Special | 75 | 50% | DrainHealing | No | No | Stronger Absorb |
| Horn Leech | Grass | Physical | 75 | 50% | DrainHealing | No | No | Contact move |
| Leech Life | Bug | Physical | 80 | 50% | DrainHealing | No | No | Updated Gen 8+ |
| Leech Seed | Grass | Status | — | 12.5% | LeechSeed | No | No | Recurring, not Grass-type |
| Matcha Gotcha | Grass | Special | 80 | 50% | DrainHealing | No | Yes | May burn, Let's Go |
| Mega Drain | Grass | Special | 40 | 50% | DrainHealing | No | No | Early Giga Drain |
| Oblivion Wing | Flying | Special | 80 | 75% | DrainHealing | No | No | Yveltal signature |
| Parabolic Charge | Electric | Special | 65 | 50% | DrainHealing | No | Yes | Targets all adjacent |

---

## Key Implementation Details

### DrainHealing Effect Properties:
- ✅ **triggersPerHit**: `true` for all damage-based drain moves
- ✅ **drainPercent**: Either `0.50` or `0.75`
- ✅ **isGuaranteed**: `true` (all drain moves have guaranteed healing)
- ✅ **Ability Interactions**: Big Root (+30%), Liquid Ooze (reversal)
- ✅ **Multi-Hit Support**: Each hit applies drain independently

### LeechSeed Effect Properties:
- ✅ **recurringEffect**: `true` (applies every turn)
- ✅ **triggersPerTurn**: `true` (not per-hit)
- ✅ **drainPercent**: `0.125` (1/8 of max HP)
- ✅ **Interactions**: Big Root, Liquid Ooze, type immunity (Grass), ability checks
- ✅ **Persistence**: Stays until switch or Rapid Spin

### StatusInfliction Effect Properties:
- ✅ **status**: Type of status (e.g., `sleep`, `burn`)
- ✅ **targetsMultiple**: For moves that hit multiple targets
- ✅ **Restrictions**: Can include ability immunity, type immunity notes

---

## Integration Notes

### For MoveEffectFactory:
When parsing JSON, handle these effect types:
```dart
switch (type) {
  case 'DrainHealing':
    return DrainHealingEffect(
      drainPercent: effectData['drainPercent'],
      isGuaranteed: effectData['isGuaranteed'] ?? true,
      probabilityPercent: effectData['probabilityPercent'] ?? 100.0,
    );
    
  case 'LeechSeed':
    return LeechSeedEffect(
      drainPercent: effectData['drainPercent'] ?? 0.125,
      recurringEffect: effectData['recurringEffect'] ?? true,
    );
    
  case 'StatusInfliction':
    return StatusInflictionEffect(
      status: effectData['status'],
      targetsMultiple: effectData['targetsMultiple'] ?? false,
    );
}
```

### For BattleSimulationEngine:

#### Damage-Based Drain (50% of damage):
```dart
// After calculating damageDealt
final effects = MoveEffectFactory.createEffectsFromJson(move.structuredEffects);
for (final effect in effects) {
  if (effect is DrainHealingEffect) {
    effect.apply(attacker, defender, move, damageDealt, events);
  }
}
```

#### Leech Seed (1/8 max HP per turn):
```dart
// At end of each turn (not immediately)
if (targetHasLeechSeed) {
  final leechDamage = (target.maxHp / 8).toInt();
  target.currentHp -= leechDamage;
  
  final leechHeal = (leechDamage * 0.5).toInt(); // or more with Big Root
  attacker.currentHp = (attacker.currentHp + leechHeal).clamp(0, attacker.maxHp);
  
  events.add(SimulationEvent(
    message: '${target.pokemonName} lost ${leechDamage} HP to Leech Seed!',
    type: SimulationEventType.statusDamage,
  ));
}
```

---

## Migration Status

### ✅ Completed:
- Added structuredEffects to all 15 HP-draining moves
- Properly categorized drain mechanics (damage-based vs recurring)
- Included all variations (50%, 75%, 12.5%)
- Documented special cases (Dark Void, Leech Seed, Matcha Gotcha)
- Preserved backward compatibility (old effect strings still present)

### 🔄 Next Steps:
1. Update Move model to include `List<dynamic> structuredEffects` field
2. Create MoveEffectFactory to parse JSON → MoveEffect objects
3. Implement LeechSeedEffect and StatusInflictionEffect classes
4. Integrate structured effects into BattleSimulationEngine
5. Wire up recurring effects for Leech Seed (turn-based, not move-based)
6. Test multi-target moves (Parabolic Charge, Matcha Gotcha with multiple defenders)

---

## Testing Coverage

Your existing `DrainHealingEffect` tests validate:
- ✅ 50% healing calculation
- ✅ Big Root +30% interaction
- ✅ Liquid Ooze reversal
- ✅ HP capping (don't exceed max)
- ✅ Multi-hit independence
- ✅ Edge cases (odd damage, zero damage, recoil safety)

These tests will apply directly to moves like Absorb, Drain Punch, Giga Drain, etc. once integrated!

For LeechSeed and StatusInfliction, additional test suites will be needed for:
- Recurring turn-based damage
- Type immunity (Leech Seed on Grass)
- Multi-target application (Dark Void on multiple opponents)
- Persistent state tracking (Leech Seed remains until switch)

