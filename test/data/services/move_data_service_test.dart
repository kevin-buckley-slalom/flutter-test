import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/services/move_data_service.dart';

void main() {
  // Initialize Flutter test binding first
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoveDataService', () {
    late MoveDataService moveDataService;

    setUp(() {
      moveDataService = MoveDataService();
    });

    test('loads all moves successfully', () async {
      await moveDataService.loadData();
      final moves = moveDataService.getAllMoves();
      expect(moves, isNotEmpty);
      expect(moves.length, greaterThan(700), reason: 'Should load moves');
    });

    test('each move has required fields', () async {
      await moveDataService.loadData();
      final moves = moveDataService.getAllMoves();

      for (final move in moves) {
        expect(move.name, isNotEmpty, reason: 'Move should have a name');
        expect(move.type, isNotEmpty, reason: 'Move should have a type');
        expect(move.category, isNotEmpty,
            reason: 'Move should have a category');
        expect(move.pp, greaterThanOrEqualTo(0),
            reason: 'Move should have PP >= 0');
      }
    });

    test('handles structuredEffects correctly', () async {
      await moveDataService.loadData();
      final moves = moveDataService.getAllMoves();

      int movesWithStructuredEffects = 0;
      int movesWithValidStructuredEffects = 0;
      List<String> errorMoves = [];

      for (final move in moves) {
        if (move.structuredEffects != null &&
            move.structuredEffects!.isNotEmpty) {
          movesWithStructuredEffects++;

          try {
            // Verify each effect is a valid map
            for (final effect in move.structuredEffects!) {
              // Check for required 'type' field
              if (!effect.containsKey('type')) {
                errorMoves.add('${move.name}: effect missing type field');
              }
            }
            movesWithValidStructuredEffects++;
          } catch (e) {
            errorMoves.add('${move.name}: $e');
          }
        }
      }

      print('Found ${moves.length} total moves');
      print('$movesWithStructuredEffects moves with structuredEffects');
      print(
          '$movesWithValidStructuredEffects moves with valid structuredEffects');

      if (errorMoves.isNotEmpty) {
        print('Errors found in ${errorMoves.length} moves:');
        for (final error in errorMoves.take(10)) {
          print('  - $error');
        }
        if (errorMoves.length > 10) {
          print('  ... and ${errorMoves.length - 10} more');
        }
      }

      expect(errorMoves, isEmpty,
          reason:
              'All structuredEffects should be valid. Errors: ${errorMoves.join(", ")}');
    });

    test('can retrieve moves by name', () async {
      await moveDataService.loadData();

      final absorb = moveDataService.getMoveByName('Absorb');
      expect(absorb, isNotNull);
      expect(absorb!.name, equals('Absorb'));
      expect(absorb.type, equals('Grass'));

      final nonExistent = moveDataService.getMoveByName('NonExistentMove');
      expect(nonExistent, isNull);
    });

    test('parses effect chance correctly', () async {
      await moveDataService.loadData();

      // Test moves with different effect chance values
      final testCases = [
        ('Absorb', null), // "-- %" means guaranteed
        ('Ember', 10), // Should parse "10 %" style
      ];

      for (final (moveName, expectedChance) in testCases) {
        final move = moveDataService.getMoveByName(moveName);
        if (move != null) {
          expect(
            move.effectChancePercent,
            equals(expectedChance),
            reason:
                '$moveName should have effect chance of $expectedChance, got ${move.effectChancePercent} (raw: ${move.effectChanceRaw})',
          );
        }
      }
    });

    test('detects multi-hit moves correctly', () async {
      await moveDataService.loadData();

      // Some known multi-hit moves
      final multiHitMoves = ['Double Hit', 'Double Kick', 'Fury Swipes'];

      for (final moveName in multiHitMoves) {
        final move = moveDataService.getMoveByName(moveName);
        if (move != null) {
          expect(move.isMultiHit, true,
              reason: '$moveName should be detected as multi-hit');
        }
      }
    });

    test('handles all moves without exceptions', () async {
      await moveDataService.loadData();
      final moves = moveDataService.getAllMoves();

      int errorCount = 0;
      List<String> errors = [];

      for (final move in moves) {
        try {
          // Access all properties to ensure no exceptions
          move.name;
          move.type;
          move.category;
          move.power;
          move.accuracy;
          move.pp;
          move.effect;
          move.isMultiHit;
          move.multiHitType;
          move.hasSecondaryEffect;
          move.powerPerHit;
          move.isEffectGuaranteed;

          // Convert to JSON and back
          move.toJson();
        } catch (e) {
          errorCount++;
          errors.add('${move.name}: $e');
        }
      }

      expect(errorCount, equals(0),
          reason:
              'All $errorCount moves should be loadable. First errors: ${errors.take(5).join(", ")}');
    });
  });
}
