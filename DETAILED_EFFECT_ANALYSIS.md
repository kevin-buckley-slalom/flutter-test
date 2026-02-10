# Detailed Move Effect Analysis

**Goal**: Carefully review each move's effect text to understand the full semantics, then map to appropriate effect classes or identify new ones needed.

**Methodology**: Read BOTH `secondary_effect` and `in_depth_effect` fields completely. Note:
- Conditional triggers (if X, then Y)
- Probability mechanics  
- Ability interactions
- Item interactions
- Special mechanics that bypass normal flow
- Multi-turn interactions
- Order-dependent effects

---

## Analysis By Category (DETAILED REVIEW ONLY)

### 1. Drain/Recovery Effects (DONE - 15 moves)
✅ Already processed: Absorb, Bitter Blade, Bouncy Bubble, Drain Punch, Draining Kiss, Dream Eater, Giga Drain, Horn Leech, Leech Life, Leech Seed, Matcha Gotcha, Mega Drain, Oblivion Wing, Parabolic Charge, Dark Void

---

### 2. Status Condition Effects (PRIORITY 2)

#### 2.1 Simple Status - 20% chance paralysis
- **Blue Flare**: "has a 20% chance of burning the target"
  - Type: `StatusConditionEffect`
  - Status: "burn"
  - Probability: 20%
  - Immunity: Fire-type, Water Veil ability
  
- **Body Slam**: "has a 30% chance of paralyzing the target"
  - Type: `StatusConditionEffect` 
  - Status: "paralysis"
  - Probability: 30%
  - Special: "If the target has used Minimize, Body Slam ignores accuracy and deals double damage"
    - This is a SEPARATE damage modifier that must be tracked (is this handled in battle engine already?)
  - Immunity: Electric-type, Limber ability
  
- **Bolt Strike**: "has a 20% chance of paralyzing the target"
  - Type: `StatusConditionEffect`
  - Status: "paralysis"
  - Probability: 20%
  - Immunity: Electric-type, Limber ability

#### 2.2 Status + Multi-turn delay
- **Bounce**: "On the second turn, Bounce deals damage and has a 30% chance of paralyzing the target"
  - This is actually TWO effects:
    1. Multi-turn invulnerability (first turn)
    2. StatusConditionEffect (paralysis, 30% chance) on second turn
  - Note: Can be bypassed with Power Herb item
  - Special interaction: Only hittable by Gust, Twister, Thunder, Sky Uppercut, Smack Down (and with No Guard ability)

---

### 3. Stat Modification Effects (PRIORITY 1)

#### 3.1 Single stat, defender, probabilistic
- **Acid**: "has a 10% chance of lowering the target's Special Defense by one stage"
  - Type: `StatChangeEffect`
  - Stats: {specialDefense: -1}
  - Target: opponent
  - Probability: 10%

- **Acid Spray**: "lowers the target's Special Defense by two stages"
  - Type: `StatChangeEffect`
  - Stats: {specialDefense: -2}
  - Target: opponent
  - Probability: 100% (guaranteed)

#### 3.2 Single stat, user, guaranteed
- **Acid Armor**: "raises the user's Defense by two stages"
  - Type: `StatChangeEffect`
  - Stats: {defense: 2}
  - Target: user
  - Probability: 100%

#### 3.3 Random stat selection
- **Acupressure**: "raises a random stat - Attack, Defense, Speed, Special Attack, Special Defense, Accuracy or Evasion - by two stages"
  - Type: `StatChangeEffect` (needs randomness support)
  - Stats: Random selection from {attack, defense, speed, spAtk, spDef, accuracy, evasion}
  - Amount: 2
  - Target: user or adjacent teammate
  - Probability: 100%
  - Note: "It will always choose a stat that is not already maximized"

---

### 4. Damage Modifier Effects (PRIORITY 3)

#### 4.1 Conditional on user item
- **Acrobatics**: "if the user is not holding an item, its power doubles to 110"
  - Type: NEW - DamageModifierEffect (item-based)
  - Condition: user has no item
  - Multiplier: 2.0x (power from 55 to 110)
  - Note: Flying Gem consumed before attack, gets both boosts

#### 4.2 Uses different stat for calculation
- **Body Press**: "Uses the user's Defense stat in damage calculation rather than Attack stat"
  - Type: NEW - DamageCalculationModifierEffect
  - Note: This changes the BASE damage calculation, not a post-effect
  - Impact: Not compatible with current DrainHealingEffect test (which assumes damage dealt is known)
  - This likely needs to be handled at DamageCalculator level, not here

#### 4.3 Conditional on move order
- **Bolt Beak**: "If the user attacks before the target, the power of this move is doubled"
  - Type: NEW - TurnOrderDamageModifierEffect
  - Condition: user Speed > opponent Speed (or priority advantage)
  - Multiplier: 2.0x
  - Note: Requires turn order context during execution

---

### 5. Multi-Hit Effects (PRIORITY 4)

#### 5.1 Fixed count
- **Bonemerang**: "will strike twice (with 50 base power each time)"
  - Type: Already in battle engine (handled by move data)
  - Hit count: 2
  - Per-hit power: 50

#### 5.2 Variable count with distribution
- **Bone Rush**: "hits 2-5 times per turn"
  - Probability: "37.5% 2, 37.5% 3, 12.5% 4, 12.5% 5 hits"
  - Type: MultiHitEffect (already designed)
  - Interaction: Skill Link ability always maximizes to 5 hits
  - Each hit is treated separately (Counter only affects final hit, Bide affects total)

---

### 6. Two-Turn/Charge Moves

- **Bounce**: 
  - Turn 1: User goes invulnerable (to specific moves only)
  - Turn 2: Deal damage + 30% paralysis chance
  - Has Power Herb override

---

## Next Steps

1. Start with **Stat Modification** (highest frequency, clearer semantics)
2. Process ~30-40 moves systematically
3. Document any NEW effect classes needed
4. Add structuredEffects to moves.json
5. Continue through other categories

