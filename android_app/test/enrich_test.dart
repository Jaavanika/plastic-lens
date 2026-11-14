import 'package:flutter_test/flutter_test.dart';
import 'package:plastic_lens/models/classification.dart';
import 'package:plastic_lens/screens/scan_flow.dart';
import 'package:plastic_lens/services/enrich_service.dart';

import 'helpers.dart';

/// Section 7 "done when": invalid LLM output never crashes the app.
void main() {
  group('EnrichResult.tryParse', () {
    test('accepts the documented JSON', () {
      final r = EnrichResult.tryParse({
        'object_name': 'Water Bottle',
        'contains_plastic': true,
        'resin_code_visible': 1,
        'likely_polymer': 'PET',
        'notes': 'Clear bottle',
      })!;
      expect(r.objectName, 'Water Bottle');
      expect(r.printedPolymer, 'PET');
    });

    test('rejects or sanitises malformed output', () {
      for (final bad in <Object?>[null, 'text', 42, [], {}, {'object_name': ''}, {'object_name': 7}, {'object_name': 'x' * 200}]) {
        expect(EnrichResult.tryParse(bad), isNull, reason: '$bad');
      }
      final r = EnrichResult.tryParse({
        'object_name': 'Cup',
        'contains_plastic': 'yes',
        'resin_code_visible': 12,
        'likely_polymer': 'NYLON',
        'notes': 5,
      })!;
      expect(r.containsPlastic, isNull);
      expect(r.resinCode, isNull);
      expect(r.likelyPolymer, isNull);
      expect(r.notes, isNull);
    });
  });

  group('applySecondOpinion', () {
    final materials = loadMaterials();

    test('printed resin code wins and both opinions are recorded', () {
      final s = scan('1', type: 'PET', state: ResultState.medium);
      applySecondOpinion(s, const EnrichResult(objectName: 'Yoghurt pot', resinCode: 5), materials);
      expect(s.itemName, 'Yoghurt pot');
      expect(s.plasticType, 'PP');
      expect(s.resinCode, 5);
      expect(s.llmUsed, isTrue);
      expect(s.secondOpinion, contains('PET'));
      expect(s.secondOpinion, contains('♲5'));
    });

    test('agreeing opinion only names the object', () {
      final s = scan('1', type: 'PET');
      applySecondOpinion(s, const EnrichResult(objectName: 'Water bottle', resinCode: 1, likelyPolymer: 'PET'), materials);
      expect(s.plasticType, 'PET');
      expect(s.secondOpinion, isNull);
    });

    test('a visual guess without a printed code does not override', () {
      final s = scan('1', type: 'HDPE');
      applySecondOpinion(s, const EnrichResult(objectName: 'Bottle', likelyPolymer: 'PP'), materials);
      expect(s.plasticType, 'HDPE');
      expect(s.secondOpinion, contains('PP'));
    });
  });
}
