/// Battle calculation constants used throughout the battle simulation system.
/// These values are based on main series Pokémon game mechanics (Generation VI+).
///
/// References:
/// - https://bulbapedia.bulbagarden.net/wiki/Damage
/// - https://bulbapedia.bulbagarden.net/wiki/Stat
library;

// =============================================================================
// STAT CALCULATION CONSTANTS
// =============================================================================

/// Divisor for converting EVs to stat points (4 EVs = 1 stat point)
const int evDivisor = 4;

/// Divisor for level-based stat scaling
const int levelDivisor = 100;

/// Base bonus added to HP stat calculations: floor(((2 * Base + IV + EV/4) * Level) / 100) + Level + 10
const int hpLevelBonus = 10;

/// Base bonus added to non-HP stat calculations: floor(((2 * Base + IV + EV/4) * Level) / 100) + 5
const int statBaseBonus = 5;

/// Maximum value for a single EV (Effort Value)
const int maxEvValue = 252;

/// Maximum total EVs across all stats
const int maxTotalEvs = 510;

/// Maximum value for a single IV (Individual Value)
const int maxIvValue = 31;

// =============================================================================
// STAT STAGE CONSTANTS
// =============================================================================

/// Minimum stat stage modifier (-6 = 2/8 = 0.25× multiplier)
const int minStatStage = -6;

/// Maximum stat stage modifier (+6 = 8/2 = 4.0× multiplier)
const int maxStatStage = 6;

/// Increment used in stat stage calculations.
/// Formula: positive stages = 1 + (stage × 0.5), negative = 1 / (1 + (|stage| × 0.5))
/// Examples: +1 = 1.5×, +2 = 2.0×, -1 = 0.67×, -2 = 0.5×
const double statStageIncrement = 0.5;

// =============================================================================
// DAMAGE CALCULATION CONSTANTS
// =============================================================================

/// STAB (Same Type Attack Bonus) multiplier applied when move type matches attacker's type
const double stabMultiplier = 1.5;

/// Critical hit damage multiplier (Generation VI+)
const double criticalHitMultiplier = 1.5;

/// Minimum random damage roll factor (damage variance)
/// Actual damage = calculated damage × (random value from 85 to 100) / 100
const int minDamageRoll = 85;

/// Maximum random damage roll factor (no variance)
const int maxDamageRoll = 100;

/// Weather boost multiplier (e.g., Rain boosts Water, Sun boosts Fire)
const double weatherBoostMultiplier = 1.5;

/// Weather nerf multiplier (e.g., Sun reduces Water, Rain reduces Fire)
const double weatherNerfMultiplier = 0.5;

// =============================================================================
// TYPE EFFECTIVENESS CONSTANTS
// =============================================================================

/// Type immune (0× damage)
const double typeImmune = 0.0;

/// Not very effective (½× damage)
const double typeNotVeryEffective = 0.5;

/// Neutral effectiveness (1× damage)
const double typeNeutral = 1.0;

/// Super effective (2× damage)
const double typeSuperEffective = 2.0;

/// Double super effective (4× damage, e.g., Ground vs Electric/Rock)
const double typeDoubleSuperEffective = 4.0;

// =============================================================================
// ABILITY MULTIPLIERS
// =============================================================================

/// Adaptability boosts STAB from 1.5× to 2.0× (net 1.33× additional)
const double adaptabilityBoost = 2.0 / stabMultiplier;

/// Huge Power / Pure Power doubles physical attack
const double hugePowerBoost = 2.0;

/// Tough Claws boosts contact moves by 30%
const double toughClawsBoost = 1.3;

/// Dragon Maw / Steelworker boost type-specific moves by 50%
const double typeBoostingAbilityMultiplier = 1.5;

/// Torrent/Blaze/Overgrow/Swarm boost at ≤1/3 HP
const double pinchAbilityBoost = 1.5;

/// Threshold for pinch abilities (when HP ≤ 1/3 max HP)
const double pinchAbilityThreshold = 1.0 / 3.0;

/// Iron Fist boosts punching moves by 20%
const double ironFistBoost = 1.2;

/// Sheer Force boosts moves with secondary effects by 30% (removes secondary effect)
const double sheerForceBoost = 1.3;

/// Reckless boosts recoil moves by 20%
const double recklessBoost = 1.2;

// =============================================================================
// ITEM MULTIPLIERS
// =============================================================================

/// Choice Band boosts physical moves by 50%
const double choiceBandBoost = 1.5;

/// Choice Specs boosts special moves by 50%
const double choiceSpecsBoost = 1.5;

/// Life Orb boosts all damaging moves by 30% (with 10% recoil)
const double lifeOrbBoost = 1.3;

/// Expert Belt boosts super effective moves by 20%
const double expertBeltBoost = 1.2;

/// Muscle Band boosts physical moves by 10%
const double muscleBandBoost = 1.1;

/// Wise Glasses boosts special moves by 10%
const double wiseGlassesBoost = 1.1;

/// Type-boosting items (e.g., Charcoal, Mystic Water) boost by 20%
const double typeBoostingItemMultiplier = 1.2;

/// Light Ball doubles Pikachu's Attack and Sp. Atk
const double lightBallBoost = 2.0;

/// Thick Club doubles Cubone/Marowak's Attack
const double thickClubBoost = 2.0;

// =============================================================================
// HP FRACTION CONSTANTS (for items, abilities, weather, etc.)
// =============================================================================

/// Leftovers healing per turn (1/16 of max HP)
const double leftoversHealing = 1.0 / 16.0;

/// Black Sludge healing per turn for Poison types (1/16 of max HP)
const double blackSludgeHealing = 1.0 / 16.0;

/// Black Sludge damage per turn for non-Poison types (1/8 of max HP)
const double blackSludgeDamage = 1.0 / 8.0;

/// Regenerator ability healing on switch-out (1/3 of max HP)
const double regeneratorHealing = 1.0 / 3.0;

/// Life Orb recoil damage (1/10 of max HP)
const double lifeOrbRecoil = 1.0 / 10.0;

/// Rocky Helmet damage when hit by contact move (1/6 of attacker's max HP)
const double rockyHelmetDamage = 1.0 / 6.0;

/// Poison damage per turn (1/8 of max HP)
const double poisonDamage = 1.0 / 8.0;

/// Burn damage per turn (1/16 of max HP in Gen VII+)
const double burnDamage = 1.0 / 16.0;

/// Burn attack reduction (halves physical attack)
const double burnAttackMultiplier = 0.5;

/// Weather damage per turn (1/16 of max HP)
const double weatherDamage = 1.0 / 16.0;

// =============================================================================
// ACCURACY AND EVASION CONSTANTS
// =============================================================================

/// Minimum accuracy value (after all modifiers)
const double minAccuracy = 0.0;

/// Maximum accuracy value (after all modifiers)
const double maxAccuracy = 1.0;

/// Base critical hit chance (1/24 in Gen VI+)
const double baseCriticalHitChance = 1.0 / 24.0;

/// Critical hit chance with high crit ratio move or Focus Energy (1/8)
const double highCriticalHitChance = 1.0 / 8.0;

/// Critical hit chance with Super Luck or Scope Lens (1/12)
const double scopeLensCriticalHitChance = 1.0 / 12.0;

// =============================================================================
// PRIORITY CONSTANTS
// =============================================================================

/// Lowest priority bracket (e.g., Trick Room makes slower Pokémon go first)
const int minPriority = -7;

/// Normal move priority (most moves)
const int normalPriority = 0;

/// Highest priority bracket (e.g., Extreme Speed)
const int maxPriority = 5;

// =============================================================================
// BATTLE STATUS CONSTANTS
// =============================================================================

/// Paralysis speed reduction in Gen VII+ (50% speed)
const double paralysisSpeedMultiplier = 0.5;

/// Paralysis chance to be fully paralyzed (25%)
const double paralysisChance = 0.25;

/// Sleep minimum duration in turns
const int minSleepDuration = 1;

/// Sleep maximum duration in turns (Gen VI+)
const int maxSleepDuration = 3;

/// Confusion minimum duration in turns (Gen VII+)
const int minConfusionDuration = 1;

/// Confusion maximum duration in turns (Gen VII+)
const int maxConfusionDuration = 4;

/// Confusion self-hit chance (33%)
const double confusionSelfHitChance = 0.33;

/// Freeze thaw chance per turn (20%)
const double freezeThawChance = 0.2;
