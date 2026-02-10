import '../../domain/models/multi_hit_result.dart';

class Move {
  final String name;
  final String type;
  final String category; // Physical, Special, Status
  final int? power;
  final int? accuracy;
  final int pp;
  final int? maxPp;
  final String effect;
  final String? detailedEffect;
  final dynamic effectChanceRaw; // Raw value from JSON: int, "-- %", or null
  final int?
      effectChancePercent; // Parsed percentage (null means guaranteed/-- %)
  final bool makesContact;
  final String? targets;
  final int generation;
  final bool? switchesOut;
  final int
      priority; // Move priority: 0 = normal, 1+ = higher priority, -1 = lower priority
  final String?
      secondaryEffect; // Natural language description of secondary effect
  final dynamic inDepthEffect; // Detailed mechanics explanation (String or Map)
  final List<Map<String, dynamic>>?
      structuredEffects; // Structured effect definitions for battle simulation

  Move({
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    this.maxPp,
    required this.effect,
    this.detailedEffect,
    this.effectChanceRaw,
    this.effectChancePercent,
    required this.makesContact,
    this.targets,
    required this.generation,
    this.switchesOut,
    this.priority = 0,
    this.secondaryEffect,
    this.inDepthEffect,
    this.structuredEffects,
  });

  factory Move.fromJson(Map<String, dynamic> json) {
    final rawEffectChance = json['effect_chance'];
    final int? parsedChance = _parseEffectChance(rawEffectChance);

    // Parse structured effects
    List<Map<String, dynamic>>? structuredEffects;
    if (json['structuredEffects'] != null) {
      structuredEffects = (json['structuredEffects'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      structuredEffects = _normalizeStructuredEffects(structuredEffects);
    }

    return Move(
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'Unknown',
      category: json['category'] as String? ?? 'Status',
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      pp: json['pp'] as int? ?? 0,
      maxPp: json['max_pp'] as int?,
      effect: json['effect'] as String? ?? '',
      detailedEffect: json['detailed_effect'] as String?,
      effectChanceRaw: rawEffectChance,
      effectChancePercent: parsedChance,
      makesContact: json['makes_contact'] as bool? ?? false,
      targets: json['targets'] as String? ?? 'Unknown',
      generation: json['generation'] as int? ?? 0,
      switchesOut: json['switches_out'] as bool?,
      priority: json['priority'] as int? ?? 0,
      secondaryEffect: json['secondary_effect'] as String?,
      inDepthEffect: json['in_depth_effect'],
      structuredEffects: structuredEffects,
    );
  }

  /// Parses effect_chance field which can be int, "-- %", or null
  /// Returns: int percentage (0-100), or null if "-- %" (guaranteed)
  static int? _parseEffectChance(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String && value == '-- %') return null; // null = guaranteed
    if (value is String) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  static List<Map<String, dynamic>> _normalizeStructuredEffects(
    List<Map<String, dynamic>> effects,
  ) {
    return effects.map((effect) {
      final normalized = Map<String, dynamic>.from(effect);
      if (normalized['type'] == 'StatChangeEffect') {
        normalized.putIfAbsent('probability', () => 100);

        final Map<String, dynamic> statMap = {};

        final stats = normalized['stats'];
        if (stats is Map) {
          for (final entry in stats.entries) {
            final canonicalKey = _canonicalStatKey(entry.key.toString());
            if (canonicalKey != null) {
              statMap[canonicalKey] = entry.value;
            }
          }
        }

        const directKeys = {
          'attack',
          'atk',
          'defense',
          'def',
          'spAtk',
          'sp_atk',
          'spa',
          'spDef',
          'sp_def',
          'spd',
          'speed',
          'spe',
          'accuracy',
          'acc',
          'evasion',
          'eva',
        };

        for (final entry in normalized.entries) {
          if (!directKeys.contains(entry.key)) {
            continue;
          }
          final canonicalKey = _canonicalStatKey(entry.key.toString());
          if (canonicalKey != null) {
            statMap[canonicalKey] = entry.value;
          }
        }

        if (statMap.isNotEmpty) {
          normalized['stats'] = statMap;
        }

        for (final key in directKeys) {
          normalized.remove(key);
        }
      }

      return normalized;
    }).toList();
  }

  static String? _canonicalStatKey(String rawKey) {
    final normalized =
        rawKey.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
    switch (normalized) {
      case 'attack':
      case 'atk':
        return 'attack';
      case 'defense':
      case 'def':
        return 'defense';
      case 'spatk':
      case 'specialattack':
      case 'spa':
        return 'spAtk';
      case 'spdef':
      case 'specialdefense':
      case 'spd':
        return 'spDef';
      case 'speed':
      case 'spe':
        return 'speed';
      case 'accuracy':
      case 'acc':
        return 'accuracy';
      case 'evasion':
      case 'eva':
        return 'evasion';
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'category': category,
        'power': power,
        'accuracy': accuracy,
        'pp': pp,
        'max_pp': maxPp,
        'effect': effect,
        'detailed_effect': detailedEffect,
        'effect_chance': effectChanceRaw,
        'makes_contact': makesContact,
        'targets': targets,
        'generation': generation,
        'switches_out': switchesOut,
        'priority': priority,
        'secondary_effect': secondaryEffect,
        'in_depth_effect': inDepthEffect,
        'structuredEffects': structuredEffects,
      };

  /// Returns true if this move's effect is guaranteed (-- % in JSON)
  bool get isEffectGuaranteed =>
      effectChancePercent == null &&
      (effectChanceRaw == '-- %' || effectChanceRaw == null);

  /// Returns true if this move has a secondary effect (either probabilistic or guaranteed)
  bool get hasSecondaryEffect =>
      secondaryEffect != null || inDepthEffect != null;

  /// Returns true if this is a multi-hit move (hits multiple times per turn)
  bool get isMultiHit => _detectMultiHit();

  /// Returns the type of multi-hit pattern, or null if not a multi-hit move
  MultiHitType? get multiHitType => _parseMultiHitType();

  /// Returns power values per hit for moves with escalating power (like Triple Kick)
  /// Returns null for moves with constant power per hit
  List<int>? get powerPerHit => _parsePowerPattern();

  bool _detectMultiHit() {
    // Get inDepthEffect as string - if it's a Map, extract the 'text' field
    String inDepthEffectStr = '';
    if (inDepthEffect != null) {
      if (inDepthEffect is String) {
        inDepthEffectStr = inDepthEffect;
      } else if (inDepthEffect is Map && inDepthEffect.containsKey('text')) {
        inDepthEffectStr = inDepthEffect['text']?.toString() ?? '';
      }
    }

    final combinedText =
        (effect + (secondaryEffect ?? '') + inDepthEffectStr).toLowerCase();
    return combinedText.contains('hits twice') ||
        combinedText.contains('hits 2-5') ||
        combinedText.contains('attacks twice') ||
        combinedText.contains('user attacks twice') ||
        combinedText.contains('two separate hits') ||
        combinedText.contains('hits 2 times') ||
        combinedText.contains('attacks 2-5') ||
        (name.toLowerCase().contains('triple') &&
            (combinedText.contains('three times') ||
                combinedText.contains('hits three')));
  }

  MultiHitType? _parseMultiHitType() {
    final combinedText = (effect + (secondaryEffect ?? '')).toLowerCase();

    if (combinedText.contains('hits 2-5') ||
        combinedText.contains('attacks 2-5')) {
      return MultiHitType.variable2to5;
    } else if (name.toLowerCase().contains('triple')) {
      return MultiHitType.fixed3;
    } else if (combinedText.contains('hits twice') ||
        combinedText.contains('attacks twice') ||
        combinedText.contains('user attacks twice')) {
      return MultiHitType.fixed2;
    }

    return null;
  }

  List<int>? _parsePowerPattern() {
    if (multiHitType != MultiHitType.fixed3 || power == null) {
      return null;
    }

    // Triple Kick: 10, 20, 30 (base power 10)
    if (name.toLowerCase() == 'triple kick') {
      return [10, 20, 30];
    }

    // Triple Axel: 20, 40, 60 (base power 20)
    if (name.toLowerCase() == 'triple axel') {
      return [20, 40, 60];
    }

    // Default for other 3-hit moves: constant power
    return null;
  }
}

/// Represents a move as learned by a pokemon in a specific game/generation
class PokemonMove {
  final String name;
  final String? tmId; // e.g., "TM00" or null for non-TM moves
  final String learnType; // "level_up", "tm", "egg", "tutor", "transfer", etc.
  final String level; // "15", "Evolve", "—", etc.

  PokemonMove({
    required this.name,
    required this.tmId,
    required this.learnType,
    required this.level,
  });

  factory PokemonMove.fromJson(Map<String, dynamic> json, String learnType) {
    return PokemonMove(
      name: json['name'] as String? ?? 'Unknown',
      tmId: json['tm_id'] as String?,
      learnType: learnType,
      level: json['level'] as String? ?? '—',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tm_id': tmId,
        'learnType': learnType,
        'level': level,
      };
}
