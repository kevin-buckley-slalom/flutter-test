/// Result of a multi-hit move's damage calculation.
///
/// Represents the outcome of moves that hit multiple times in one turn,
/// such as Fury Attack (2-5 hits) or Double Kick (2 hits).
class MultiHitResult {
  /// The number of hits that were attempted.
  final int hitCount;

  /// List of damage values for each successful hit.
  /// Index corresponds to hit number (0-based).
  final List<int> hitDamages;

  /// Total damage dealt across all hits.
  final int totalDamage;

  /// Indices of hits that missed (0-based).
  /// Empty if all hits connected.
  final List<int> missedHits;

  /// Reason the combo was interrupted, if applicable.
  /// Examples: "target_fainted", "accuracy_miss", "substitute_broken"
  final String? breakReason;

  MultiHitResult({
    required this.hitCount,
    required this.hitDamages,
    required this.missedHits,
    this.breakReason,
  }) : totalDamage = hitDamages.fold(0, (sum, dmg) => sum + dmg);

  /// Whether all attempted hits connected successfully.
  bool get allHitsConnected =>
      missedHits.isEmpty && hitDamages.length == hitCount;

  /// Number of hits that successfully dealt damage.
  int get successfulHits => hitDamages.length;

  /// Whether the combo was interrupted before all hits could be attempted.
  bool get wasInterrupted => breakReason != null;

  @override
  String toString() {
    return 'MultiHitResult(hits: $successfulHits/$hitCount, '
        'damage: ${hitDamages.join('+')}, total: $totalDamage'
        '${wasInterrupted ? ', interrupted: $breakReason' : ''})';
  }

  /// Creates a result for a move that missed entirely on the first hit.
  factory MultiHitResult.firstHitMissed({required int plannedHits}) {
    return MultiHitResult(
      hitCount: plannedHits,
      hitDamages: [],
      missedHits: [0],
      breakReason: 'first_hit_missed',
    );
  }

  /// Creates a result for a fully successful multi-hit combo.
  factory MultiHitResult.allHitsConnected({
    required int hitCount,
    required List<int> damages,
  }) {
    return MultiHitResult(
      hitCount: hitCount,
      hitDamages: damages,
      missedHits: [],
    );
  }
}

/// Type of multi-hit pattern for a move.
enum MultiHitType {
  /// Always hits exactly 2 times (e.g., Double Kick, Bonemerang).
  fixed2,

  /// Always hits exactly 3 times with escalating power (e.g., Triple Kick, Triple Axel).
  fixed3,

  /// Hits 2-5 times with probability distribution:
  /// 2 hits: 37.5%, 3 hits: 37.5%, 4 hits: 12.5%, 5 hits: 12.5%
  /// (e.g., Fury Attack, Bullet Seed, Rock Blast).
  variable2to5,
}
