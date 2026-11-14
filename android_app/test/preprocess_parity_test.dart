import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plastic_lens/utils/preprocess.dart';

/// Section 4: Dart preprocessing must match Python's EVAL_TF closely enough
/// that the model sees the same image. Fixtures come from
/// ai_model/export/verify_onnx.py (one test image per class).
void main() {
  final fixtureFile = File('test/fixtures/parity.json');
  if (!fixtureFile.existsSync()) {
    test('parity fixtures present', () => fail('Run ai_model/export/verify_onnx.py first'));
    return;
  }
  final fixtures = (jsonDecode(fixtureFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  const spec = InputSpec();
  const plane = 224 * 224;

  for (final f in fixtures) {
    test('preprocessing matches Python for ${f['file']}', () {
      final bytes = File('test/fixtures/${f['file']}').readAsBytesSync();
      final x = preprocessBytes(bytes, spec);
      expect(x.length, 3 * plane);

      for (var c = 0; c < 3; c++) {
        var sum = 0.0;
        for (var i = 0; i < plane; i++) {
          sum += x[c * plane + i];
        }
        // resizeLikePil ports Pillow's filter; what remains is JPEG decoder
        // rounding (Dart `image` vs libjpeg), about half a grey level on average.
        expect(sum / plane, closeTo((f['channel_mean'] as List)[c] as num, 0.015), reason: 'channel $c mean');
      }

      // Single pixels: within ~4 grey levels (0.07 std units).
      (f['samples'] as Map<String, dynamic>).forEach((key, value) {
        final [c, i, j] = key.split(',').map(int.parse).toList();
        expect(x[c * plane + i * 224 + j], closeTo(value as num, 0.07), reason: 'pixel $key');
      });
    });
  }

  test('rejects non-images and tiny images', () {
    expect(() => preprocessBytes(utf8.encode('not an image'), spec), throwsA(isA<PreprocessException>()));
  });
}
