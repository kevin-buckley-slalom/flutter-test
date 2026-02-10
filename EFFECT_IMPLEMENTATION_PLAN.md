# Move Effects Implementation Plan

## Overview
Systematically transform 200+ moves from string-based effects to structured, type-safe effect objects.

## Phase 1: Effect Class Design

### Effect Categories Identified

**1. Stat Modification Effects** (~80 moves)
- Single stat changes (raise/lower ATK, DEF, SPATK, SPDEF, SPD, ACC, EVA)
- Multi-stat changes (raise/lower multiple stats)
- Random stat changes
- User-targeted vs opponent-targeted vs ally-targeted

Examples:
- Growl: Lower opponent ATK by 1
- Swords Dance: Raise user ATK by 2
- Calm Mind: Raise user SPATK & SPDEF by 1
- Ancient Power: Raise all user stats randomly by 1

**2. Status Condition Effects** (~50 moves)
- Standard: Burn, Poison, Paralyze, Sleep, Freeze
- Special: Badly Poisoned (Toxic), Confusion, Infatuation, Flinch, Trap/Immobilize

Examples:
- Growl: Lowers ATK
- Toxic: Applies bad poison (recurring damage)
- Thunder Wave: Applies paralysis
- Confusion moves: Apply confusion

**3. Drain/Recovery Effects** (~20 moves, 15 already done)
- Simple drain: 50%, 75%
- Conditional drain: Dream Eater (only on sleep)
- Recurring drain: Leech Seed (1/8 per turn)

**4. Recoil Effects** (~10 moves)
- Fixed percent recoil: 1/3, 1/4 damage dealt
- Fixed damage: Loses X HP

Examples:
- Brave Bird: 1/3 recoil
- Double-Edge: 1/3 recoil

**5. Multi-hit Effects** (~20 moves)
- Fixed hits: 2x, 3x, 4x
- Variable hits: 2-5 with probability distribution
- Consecutive hits: Different mechanics

**6. Damage Modifier Effects** (~40 moves)
- Speed-based: Electro Ball (higher speed = more damage)
- HP-based: Payback (if hit first), False Swipe (depends on target HP)
- Conditional: Earthquake (2x on Dig), Weather-based
- Stat-based: Stored Power (based on stat boosts)

**7. Protection/Evasion Effects** (~15 moves)
- Protection: Protect, Detect, Endure (with declining success)
- Evasion: Increase user evasion

**8. Terrain/Weather/Field Effects** (~20 moves)
- Setup: Stealth Rock, Spikes, Toxic Spikes, Reflect, Light Screen
- Terrain: Electric Terrain, Grassy Terrain, Misty Terrain, Psychic Terrain
- Weather: Sunny Day, Rain Dance, Hail, Sandstorm

**9. Switching/Substitution Effects** (~15 moves)
- Force switch: Circle Throw, Dragon Tail
- User switch: U-turn, Volt Switch
- Stat-preserving switch

**10. Complex/Conditional Effects** (~30 moves)
- Type/gender dependent: Curse, Moongeist Beam
- Move interaction: Counter, Mirror Coat, Encore
- Ability interaction: Copycat, Mimic

**11. Item/Ability Interactions** (~15 moves)
- Consume item: Consume berry, Trick, Thief
- Ability suppression

## Phase 2: Implementation Strategy

### Approach: Work in Effect Type Blocks

1. **Stat Modification** (highest frequency)
   - Create `StatModificationEffect` class
   - Handle single/multi-stat, raise/lower, amount, target
   - Process ~80 moves at once

2. **Status Conditions** (second highest)
   - Create `StatusConditionEffect` class
   - Handle: burn, poison, paralysis, sleep, freeze, confusion, infatuation, flinch
   - Handle special cases: Toxic (recurring), Freeze (thaw on fire move), etc.
   - Process ~50 moves

3. **Recoil/Damage Cost** (medium frequency)
   - Create `RecoilEffect` class
   - Fraction-based recoil (1/3, 1/4, etc.)
   - Process ~10 moves

4. **Remaining complex types** in order of frequency

## Phase 3: JSON Structuring

Each move gets a `structuredEffects` array. Examples:

```json
{
  "name": "Growl",
  "structuredEffects": [
    {
      "type": "StatModification",
      "statName": "attack",
      "changeAmount": -1,
      "target": "opponent"
    }
  ]
}
```

```json
{
  "name": "Swords Dance",
  "structuredEffects": [
    {
      "type": "StatModification",
      "statName": "attack",
      "changeAmount": 2,
      "target": "user"
    }
  ]
}
```

```json
{
  "name": "Thunder Wave",
  "structuredEffects": [
    {
      "type": "StatusCondition",
      "status": "paralysis",
      "probabilityPercent": 100,
      "target": "opponent"
    }
  ]
}
```

```json
{
  "name": "Brave Bird",
  "structuredEffects": [
    {
      "type": "Recoil",
      "recoilPercent": 0.33,
      "appliesTo": "user"
    }
  ]
}
```

## Phase 4: Example Moves by Type

### Stat Modifications
- Growl: -1 ATK opponent
- Swords Dance: +2 ATK user
- Calm Mind: +1 SPATK, +1 SPDEF user
- Screech: -2 DEF opponent
- Close Combat: -1 DEF user, -1 SPDEF user
- Acrobatics: different if no item (conditional)
- Bulk Up: +1 ATK, +1 DEF user
- Dragon Dance: +1 ATK, +1 SPD user
- Ancient Power: random +1 all user
- Metronome: random move

### Status Conditions
- Thunder Wave: paralysis, 100% hit
- Toxic: poison (special recurring), 90% hit
- Burn moves: burn, various %
- Sleep moves: sleep, various %
- Confusion moves: confusion, various %
- Infatuation: infatuation, 100% on opposite gender

### Damage Modifiers
- Earthquake: 2x damage on Dig opponent
- Electro Ball: speed-based (range 60-150 BP)
- Payback: 2x if hit this turn
- Pursuit: 2x if switching
- Stored Power: +20 BP per stat boost
- Synchronoise: STAB on same type

### Multi-hit
- Double Kick: 2 hits × 30 BP
- Fury Attack: 2-5 hits with probability
- Triple Kick: 3 hits, power increases

### Recoil
- Brave Bird: 1/3 recoil
- Double-Edge: 1/3 recoil
- Head Smash: 1/2 recoil
- Jump Kick: Recoil on miss

## Phase 5: Processing Order

1. ✓ Drain Healing (15 moves) - DONE
2. Stat Modifications (80 moves) - NEXT
3. Status Conditions (50 moves)
4. Recoil (10 moves)
5. Multi-hit (20 moves)
6. Damage Modifiers (40 moves)
7. Protection (15 moves)
8. Terrain/Weather/Field (20 moves)
9. Switching (15 moves)
10. Complex/Conditional (30 moves)
11. Item/Ability (15 moves)
12. Remaining moves (25 moves)

---

## Implementation Progress

- [x] Phase 1: Designed effect categories
- [x] Phase 2: Identified 200+ moves with effects
- [ ] Create StatModificationEffect class
- [ ] Create StatusConditionEffect class
- [ ] Create RecoilEffect class
- [ ] Process stat modification moves (80)
- [ ] Process status condition moves (50)
- [ ] ... continue with remaining types

