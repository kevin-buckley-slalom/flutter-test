# Battle Mechanics Documentation

This document explains the battle simulation system in ChampionDex, including formulas, turn order, damage calculation, and stat modifications. All mechanics follow main series Pokémon games (Generation VI+).

## Table of Contents

1. [Stat Calculation](#stat-calculation)
2. [Turn Order](#turn-order)
3. [Damage Calculation](#damage-calculation)
4. [Type Effectiveness](#type-effectiveness)
5. [Stat Stages](#stat-stages)
6. [Status Conditions](#status-conditions)
7. [Abilities](#abilities)
8. [Items](#items)
9. [Weather & Terrain](#weather--terrain)

---

## Stat Calculation

### HP Formula

```
HP = floor(((2 × Base + IV + floor(EV/4)) × Level) / 100) + Level + 10
```

**Special Cases:**
- **Shedinja**: Always has 1 HP regardless of stats
- **Level 1**: Minimum HP varies by base stat

**Example: Snorlax at Level 100**
```
Base HP: 160
IV: 31 (max)
EV: 252 (max)

HP = floor(((2 × 160 + 31 + floor(252/4)) × 100) / 100) + 100 + 10
   = floor(((320 + 31 + 63) × 100) / 100) + 110
   = floor(414) + 110
   = 524 + 20
   = 544 HP
```

### Other Stats Formula (Attack, Defense, Sp. Atk, Sp. Def, Speed)

```
Stat = floor(((2 × Base + IV + floor(EV/4)) × Level) / 100 + 5) × Nature
```

**Nature Modifiers:**
- Boosting nature: ×1.1 (e.g., Adamant boosts Attack)
- Hindering nature: ×0.9 (e.g., Adamant reduces Sp. Atk)
- Neutral nature: ×1.0

**Example: Garchomp Attack at Level 100 with Adamant**
```
Base Attack: 130
IV: 31 (max)
EV: 252 (max)
Nature: Adamant (+Atk)

Stat = floor(((2 × 130 + 31 + floor(252/4)) × 100) / 100 + 5) × 1.1
     = floor(((260 + 31 + 63) × 100) / 100 + 5) × 1.1
     = floor(354 + 5) × 1.1
     = 359 × 1.1
     = 394 Attack
```

### Stat Limits

- **IVs (Individual Values)**: 0-31 per stat
- **EVs (Effort Values)**: 0-252 per stat, max 510 total
- **Level**: 1-100
- **Base Stats**: Varies by species (e.g., Blissey HP = 255, highest in the game)

---

## Turn Order

Turn order is determined by:

1. **Priority bracket**: Moves with higher priority go first
2. **Speed stat**: Within the same priority, faster Pokémon go first
3. **Speed tie**: Random if both Pokémon have identical speed

### Priority Brackets

| Priority | Example Moves |
|----------|---------------|
| +5 | Helping Hand |
| +4 | Endure, Protect, Detect |
| +3 | Fake Out, Quick Guard |
| +2 | Extreme Speed, Feint |
| +1 | Aqua Jet, Mach Punch, Quick Attack |
| 0 | Most moves |
| -1 | Vital Throw |
| -3 | Focus Punch |
| -4 | Revenge, Avalanche |
| -5 | Counter, Mirror Coat |
| -6 | Circle Throw, Dragon Tail |
| -7 | Trick Room |

### Effective Speed Calculation

Speed can be modified by:
- **Stat stages**: -6 to +6 (see [Stat Stages](#stat-stages))
- **Status**: Paralysis halves speed in Gen VII+
- **Abilities**: Swift Swim (2× in Rain), Chlorophyll (2× in Sun), etc.
- **Items**: Choice Scarf (1.5×), Iron Ball (0.5×)
- **Trick Room**: Reverses turn order (slower goes first)

---

## Damage Calculation

### Base Damage Formula (Generation V+)

```
Damage = (((2 × Level / 5 + 2) × Power × Attack / Defense) / 50 + 2) × Modifiers
```

### Modifiers (Applied in Order)

1. **Random factor**: 85-100% (explains damage ranges)
2. **STAB (Same Type Attack Bonus)**: 1.5× if move type matches attacker's type
3. **Type effectiveness**: 0×, 0.5×, 1×, 2×, or 4× (see [Type Effectiveness](#type-effectiveness))
4. **Critical hit**: 1.5× (Generation VI+)
5. **Burn**: 0.5× to physical moves
6. **Weather**: 1.5× boost or 0.5× reduction
7. **Ability modifiers**: Varies by ability (e.g., Huge Power = 2×)
8. **Item modifiers**: Varies by item (e.g., Choice Band = 1.5×)

### Attack/Defense Selection

- **Physical moves** (category = "Physical"): Use Attack vs Defense
- **Special moves** (category = "Special"): Use Sp. Atk vs Sp. Def
- **Status moves**: Deal no damage

### Damage Formula Example

**Charizard's Fire Blast vs Ferrothorn**

```
Charizard (Level 50):
- Sp. Atk: 129 (with max IVs/EVs)
- Types: Fire/Flying

Ferrothorn (Level 50):
- Sp. Def: 116
- Types: Grass/Steel

Fire Blast:
- Type: Fire
- Category: Special
- Power: 110

Step 1: Base calculation
= (((2 × 50 / 5 + 2) × 110 × 129 / 116) / 50 + 2)
= (((20 + 2) × 110 × 129 / 116) / 50 + 2)
= ((307890 / 116) / 50 + 2)
= (2654 / 50 + 2)
= 53 + 2
= 55

Step 2: Apply modifiers
× Random (85-100%): 55 × 0.85 to 55 × 1.00 = 47-55
× STAB (Fire type): 47-55 × 1.5 = 70-82
× Type effectiveness (Fire vs Grass/Steel): 70-82 × 4.0 = 280-328 damage

Result: 280-328 damage (guaranteed OHKO on most Ferrothorn)
```

---

## Type Effectiveness

Type effectiveness follows a multiplication system:
- **Immune**: 0× (no damage)
- **Not very effective**: 0.5×
- **Neutral**: 1×
- **Super effective**: 2×

For dual-type Pokémon, multiply both types:
- Rock vs Fire/Flying: 2× × 2× = **4× (quad weakness)**
- Fighting vs Normal/Flying: 2× × 0.5× = **1× (neutral)**
- Ground vs Steel/Flying: 2× × 0× = **0× (immune)**

### Type Chart Reference

See [`assets/data/type_chart.json`](../assets/data/type_chart.json) for the complete 18×18 type matchup table.

**Common Matchups:**
- Fire → Grass, Ice, Bug, Steel
- Water → Fire, Ground, Rock
- Electric → Water, Flying
- Ice → Grass, Ground, Flying, Dragon
- Fighting → Normal, Ice, Rock, Dark, Steel
- Poison → Grass, Fairy
- Ground → Fire, Electric, Poison, Rock, Steel
- Flying → Grass, Fighting, Bug
- Psychic → Fighting, Poison
- Bug → Grass, Psychic, Dark
- Rock → Fire, Ice, Flying, Bug
- Ghost → Ghost, Psychic
- Dragon → Dragon
- Dark → Ghost, Psychic
- Steel → Ice, Rock, Fairy
- Fairy → Fighting, Dragon, Dark

**Immunities:**
- Normal/Fighting → Ghost
- Ghost → Normal
- Electric → Ground
- Ground → Flying
- Poison → Steel
- Psychic → Dark
- Dragon → Fairy

---

## Stat Stages

Stats can be modified during battle by stat stages ranging from **-6 to +6**.

### Stat Stage Multipliers

| Stage | Multiplier | Formula |
|-------|------------|---------|
| +6 | 4.0× | (2 + 6) / 2 = 8/2 |
| +5 | 3.5× | (2 + 5) / 2 = 7/2 |
| +4 | 3.0× | (2 + 4) / 2 = 6/2 |
| +3 | 2.5× | (2 + 3) / 2 = 5/2 |
| +2 | 2.0× | (2 + 2) / 2 = 4/2 |
| +1 | 1.5× | (2 + 1) / 2 = 3/2 |
| 0 | 1.0× | No change |
| -1 | 0.67× | 2 / (2 + 1) = 2/3 |
| -2 | 0.5× | 2 / (2 + 2) = 2/4 |
| -3 | 0.4× | 2 / (2 + 3) = 2/5 |
| -4 | 0.33× | 2 / (2 + 4) = 2/6 |
| -5 | 0.29× | 2 / (2 + 5) = 2/7 |
| -6 | 0.25× | 2 / (2 + 6) = 2/8 |

### Common Stat Stage Moves

| Move | Effect |
|------|--------|
| Swords Dance | +2 Attack |
| Dragon Dance | +1 Attack, +1 Speed |
| Calm Mind | +1 Sp. Atk, +1 Sp. Def |
| Belly Drum | +6 Attack (maximum) |
| Intimidate (Ability) | -1 Attack to opponent on switch-in |
| Sticky Web | -1 Speed to opponent on switch-in |
| Draco Meteor | -2 Sp. Atk to user after attacking |

### Accuracy/Evasion Stages

Accuracy and evasion use a **different formula**:

| Stage | Multiplier | Formula |
|-------|------------|---------|
| +6 | 3.0× | (3 + 6) / 3 = 9/3 |
| +1 | 1.33× | (3 + 1) / 3 = 4/3 |
| 0 | 1.0× | No change |
| -1 | 0.75× | 3 / (3 + 1) = 3/4 |
| -6 | 0.33× | 3 / (3 + 6) = 3/9 |

**Hit chance formula:**
```
Final Accuracy = Move Accuracy × Accuracy Modifier / Evasion Modifier
```

---

## Status Conditions

### Major Status (one at a time)

| Status | Effect |
|--------|--------|
| **Burn** | • 1/16 max HP damage per turn<br>• Physical attack halved |
| **Paralysis** | • Speed halved<br>• 25% chance to be fully paralyzed each turn |
| **Poison** | • 1/8 max HP damage per turn |
| **Toxic** | • Damage increases each turn (1/16, 2/16, 3/16, ...) |
| **Sleep** | • Cannot move for 1-3 turns |
| **Freeze** | • Cannot move<br>• 20% chance to thaw each turn<br>• Fire moves thaw immediately |

### Minor Status (multiple can apply)

| Status | Effect |
|--------|--------|
| **Confusion** | • 33% chance to hit self for 40 base power<br>• Lasts 1-4 turns |
| **Flinch** | • Skip turn (requires faster attacker) |
| **Infatuation** | • 50% chance to not attack |
| **Taunt** | • Can only use damaging moves for 3 turns |

---

## Abilities

### Damage-Modifying Abilities

| Ability | Effect |
|---------|--------|
| **Adaptability** | STAB becomes 2.0× instead of 1.5× |
| **Huge Power / Pure Power** | Physical attack doubled (2×) |
| **Tough Claws** | Contact moves boosted by 30% (1.3×) |
| **Dragon Maw** | Dragon-type moves boosted by 50% (1.5×) |
| **Torrent / Blaze / Overgrow / Swarm** | Type-specific moves boosted by 50% when at ≤1/3 HP |
| **Iron Fist** | Punching moves boosted by 20% (1.2×) |
| **Sheer Force** | Moves with secondary effects boosted by 30% (removes secondary effects) |
| **Reckless** | Recoil moves boosted by 20% (1.2×) |

### Entry Hazard Abilities

| Ability | Effect |
|---------|--------|
| **Intimidate** | Lower opponent's Attack by 1 stage on switch-in |
| **Drizzle / Drought / Snow Warning / Sand Stream** | Set weather on switch-in |

### Defensive Abilities

| Ability | Effect |
|---------|--------|
| **Regenerator** | Heal 1/3 max HP on switch-out |
| **Natural Cure** | Cure status condition on switch-out |
| **Synchronize** | Pass Burn, Poison, or Paralysis to attacker |

---

## Items

### Damage-Boosting Items

| Item | Effect |
|------|--------|
| **Choice Band** | Physical moves boosted by 50% (1.5×), locked to one move |
| **Choice Specs** | Special moves boosted by 50% (1.5×), locked to one move |
| **Life Orb** | All damaging moves boosted by 30% (1.3×), lose 10% HP per hit |
| **Expert Belt** | Super-effective moves boosted by 20% (1.2×) |
| **Muscle Band** | Physical moves boosted by 10% (1.1×) |
| **Wise Glasses** | Special moves boosted by 10% (1.1×) |
| **Type-boosting items** | Specific type moves boosted by 20% (1.2×)<br>(e.g., Charcoal for Fire, Mystic Water for Water) |

### HP Recovery Items

| Item | Effect |
|------|--------|
| **Leftovers** | Restore 1/16 max HP per turn |
| **Black Sludge** | Poison-types: heal 1/16 max HP<br>Non-Poison: lose 1/8 max HP |

### Recoil Items

| Item | Effect |
|------|--------|
| **Rocky Helmet** | Attacker loses 1/6 max HP when using contact move |
| **Life Orb** | User loses 1/10 max HP after dealing damage |

---

## Weather & Terrain

### Weather Effects

| Weather | Duration | Effects |
|---------|----------|---------|
| **Sun** | 5 turns | • Fire moves: 1.5× damage<br>• Water moves: 0.5× damage<br>• Thunder/Hurricane: 50% accuracy<br>• Solarbeam charges instantly |
| **Rain** | 5 turns | • Water moves: 1.5× damage<br>• Fire moves: 0.5× damage<br>• Thunder/Hurricane: always hit |
| **Sandstorm** | 5 turns | • Rock Sp. Def: 1.5×<br>• Non-Rock/Ground/Steel: 1/16 damage per turn |
| **Hail** | 5 turns | • Non-Ice types: 1/16 damage per turn<br>• Blizzard: always hit |

### Terrain Effects

| Terrain | Duration | Effects |
|---------|----------|---------|
| **Electric Terrain** | 5 turns | • Electric moves: 1.5× (grounded Pokémon)<br>• Sleep prevention |
| **Grassy Terrain** | 5 turns | • Grass moves: 1.5× (grounded Pokémon)<br>• 1/16 HP recovery per turn<br>• Earthquake/Magnitude/Bulldoze: 0.5× |
| **Psychic Terrain** | 5 turns | • Psychic moves: 1.5× (grounded Pokémon)<br>• Priority move prevention |
| **Misty Terrain** | 5 turns | • Dragon moves: 0.5× (grounded Pokémon)<br>• Status prevention |

---

## Implementation Notes

### Code Structure

The battle simulation system is organized into utilities and services:

**Utilities** (`lib/domain/utils/`):
- `battle_constants.dart`: All numeric constants and multipliers
- `pokemon_stat_calculator.dart`: Stat calculation formulas
- `stat_stage_calculator.dart`: Stat stage modifiers
- `type_chart.dart`: Type effectiveness lookup

**Services** (`lib/domain/services/`):
- `battle_simulation_engine.dart`: Main turn coordinator
- `damage_calculator.dart`: Damage calculation with all modifiers
- `turn_order_calculator.dart`: Determines action order
- `ability_effect_processor.dart`: Processes ability triggers
- `item_effect_processor.dart`: Processes item effects

**Data** (`assets/data/`):
- `type_chart.json`: 18×18 type effectiveness table

### Testing

Unit tests validate formula accuracy for:
- Stat calculations (HP, Attack, Defense, etc.)
- Type effectiveness (single and dual types)
- Stat stage multipliers
- Damage calculations with all modifiers

See `test/domain/utils/` for comprehensive test suites.

---

## References

- [Bulbapedia: Damage](https://bulbapedia.bulbagarden.net/wiki/Damage)
- [Bulbapedia: Stat](https://bulbapedia.bulbagarden.net/wiki/Stat)
- [Bulbapedia: Type Chart](https://bulbapedia.bulbagarden.net/wiki/Type/Type_chart)
- [Bulbapedia: Stat Modifier](https://bulbapedia.bulbagarden.net/wiki/Stat_modifier)
- [Pokémon Showdown Damage Calculator](https://calc.pokemonshowdown.com/)

---

**Last Updated**: January 30, 2026  
**Mechanics Version**: Generation VI+ (X/Y through current)
