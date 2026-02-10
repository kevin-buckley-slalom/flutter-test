import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:championdex/data/models/move.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identify which moves fail to parse', () async {
    // Load the raw JSON
    final jsonString = await rootBundle.loadString('assets/data/moves.json');
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    print('\nTesting move parsing...');
    print('Total moves in JSON: ${jsonData.length}');

    final failedMoves = <String, String>{};
    final successfulMoves = <String>[];

    jsonData.forEach((moveName, moveJson) {
      if (moveJson is Map<String, dynamic>) {
        try {
          final moveDataWithName = {...moveJson, 'name': moveName};
          Move.fromJson(moveDataWithName);
          successfulMoves.add(moveName);
        } catch (e) {
          failedMoves[moveName] = e.toString();
        }
      }
    });

    print('Successfully parsed: ${successfulMoves.length}');
    print('Failed to parse: ${failedMoves.length}');
    print('Difference: ${jsonData.length - successfulMoves.length}');

    if (failedMoves.isNotEmpty) {
      print('\nFailed moves:');
      failedMoves.entries.take(20).forEach((entry) {
        print('  - ${entry.key}: ${entry.value.split('\n').first}');
      });
      if (failedMoves.length > 20) {
        print('  ... and ${failedMoves.length - 20} more');
      }
    }

    expect(failedMoves, isEmpty,
        reason:
            'All moves should parse successfully. ${failedMoves.length} moves failed');
  });
}
