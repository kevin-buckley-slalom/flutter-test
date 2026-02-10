# Stat Modification Effects - Complete Analysis

**Purpose**: Document every variant of stat modification effects to ensure proper structuredEffects creation.

## Patterns Identified

### Pattern 1: Single Stat Raise (User)
Target: User | Stat: Various | Amount: +1 or +2 | Probability: 100%

Examples:
- **Agility**: Raises user's Speed by 2 stages
- **Acid Armor**: Raises user's Defense by 2 stages  
- **Amnesia**: Raises user's Special Defense by 2 stages
- **Barrier**: Raises user's Defense by 2 stages

Structured Format:
```json
{
  "type": "StatChangeEffect",
  "statName": "speed",
  "changeAmount": 2,
  "target": "user",
  "probability": 100
}
```

### Pattern 2: Single Stat Lower (Opponent)
Target: Opponent | Stat: Various | Amount: -1 or -2 | Probability: 10%-100%

Examples:
- **Acid**: Has 10% chance of lowering target's Special Defense by 1
- **Acid Spray**: Lowers target's Special Defense by 2 stages (guaranteed)
- **Aurora Beam**: Has 10% chance of lowering target's Attack by 1
- **Bitter Malice**: Lowers opponent's Attack by 1 stage (guaranteed)

Structured Format:
```json
{
  "type": "StatChangeEffect",
  "statName": "spDefense",
  "changeAmount": -1,
  "target": "opponent",
  "probability": 10
}
```

### Pattern 3: Multi-Stat (User)
Target: User | Multiple Stats | Amount: Various | Probability: 100%

Examples:
- **Bulk Up**: Raises user's Attack and Defense by 1 each
- **Calm Mind**: Raises user's Sp.Atk and Sp.Def by 1 each
- **Dragon Dance**: Raises user's Attack and Speed by 1 each
- **Swords Dance**: Raises user's Attack by 2

Structured Format:
```json
{
  "type": "StatChangeEffect",
  "statChanges": {
    "attack": 1,
    "defense": 1
  },
  "target": "user",
  "probability": 100
}
```

### Pattern 4: Multi-Stat (Opponent)
Target: Opponent | Multiple Stats | Amount: Various | Probability: 100%

Examples:
- **Close Combat**: Lowers user's Defense and Sp.Def by 1 each (COST, not attack effect!)
- **Screech**: Lowers opponent's Defense by 2 stages

Note: Be careful about costs vs effects. Close Combat lowers USER's stats as a COST.

### Pattern 5: Random Stat Selection
Target: User or Ally | Random Selection | Amount: +1 or +2 | Probability: 100%

Examples:
- **Acupressure**: Raises a random stat by 2
  - Can select: Attack, Defense, Speed, Sp.Atk, Sp.Def, Accuracy, Evasion
  - Special rule: "Will always choose a stat that is not already maximized"

Structured Format:
```json
{
  "type": "StatChangeEffect",
  "statName": "RANDOM",
  "statPool": ["attack", "defense", "speed", "spAtk", "spDef", "accuracy", "evasion"],
  "changeAmount": 2,
  "target": "user",
  "probability": 100,
  "avoidMaxedStats": true
}
```

### Pattern 6: All Stats Raise
Target: User | All Stats | Amount: +1 | Probability: 10%-100%

Examples:
- **Ancient Power**: 10% chance to raise ALL user's stats by 1
  - Stats: Attack, Defense, Sp.Atk, Sp.Def, Speed

Structured Format:
```json
{
  "type": "StatChangeEffect",
  "statChanges": {
    "attack": 1,
    "defense": 1,
    "spAtk": 1,
    "spDef": 1,
    "speed": 1
  },
  "target": "user",
  "probability": 10
}
```

### Pattern 7: Conditional - Probabilistic with Effect Chance
Some moves have effect_chance in the JSON that determines probability:

- **Ancient Power**: effect_chance: 10
- **Aurora Beam**: effect_chance: 10  
- **Acid**: effect_chance: 10

But some are guaranteed:
- **Acid Spray**: effect_chance: "-- %" (guaranteed)
- **Acid Armor**: effect_chance: "-- %" (guaranteed)

Must check both `effect_chance` field AND the detailed_effect text.

### Pattern 8: Move-Specific Conditions

**Aura Wheel** special case:
- Secondary: "Raises user's Speed by 1 stage. Changes type to Dark-type if user is in Hangry Mode"
- Note: Type change is NOT a stat modification effect
- Stat change is: {speed: 1, target: user}
- Type change needs separate handling

**Body Press**:
- NOT a stat change at all
- "Uses the user's Defense stat in damage calculation rather than Attack stat"
- This is a damage MODIFIER, needs DamageCalculationEffect, not StatChangeEffect

---

## Moves to Process (High Priority)

### Guaranteed Single Stat Raises (15 moves)
1. Acid Armor - Defense +2
2. Agility - Speed +2
3. Amnesia - Sp.Def +2
4. Aqua Ring - (need to check)
5. Barrier - Defense +2
6. Iron Defense - Defense +2
7. Swords Dance - Attack +2
8. Cosmic Power - (need to check)
9. Calm Mind - Sp.Atk +1, Sp.Def +1
10. Dragon Dance - Attack +1, Speed +1
11. Bulk Up - Attack +1, Defense +1
12. Growth - (probably conditional on weather)
13. Nasty Plot - Sp.Atk +2
14. Curse - (complex, user type-dependent)
15. More...

### Probabilistic Single Stat Lowers (20+ moves)
- Acid (10% Sp.Def -1)
- Aurora Beam (10% Attack -1)
- Bubble/Bubble Beam (10% Speed -1)
- Bug Buzz (10% Sp.Def -1)
- Icy Wind (possibly 100% Speed -1 for all?)
- More...

### Guaranteed Single Stat Lowers (10+ moves)
- Acid Spray (Sp.Def -2)
- Bitter Malice (Attack -1)
- Growl (Attack -1)
- More...

### Random Stats (5-10 moves)
- Acupressure (random +2)
- More...

### Multi-Target Stat Changes (10+ moves)
- Ancient Power (all user stats +1, 10% chance)
- Charge (Sp.Def +1, Power +2)
- More...

---

## Next Action
Carefully read 30-40 representative stat modification moves from moves.json, document each one completely, then add structuredEffects in a single batch operation.

