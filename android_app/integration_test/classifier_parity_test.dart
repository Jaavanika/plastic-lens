import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plastic_lens/services/onnx_classifier.dart';

import 'fixtures.g.dart';

/// PLAN Section 4 "done when", on a real Android runtime:
/// - the bundled ONNX model gives the same top-1 class as Python for the
///   same images, with probabilities close to Python's;
/// - it needs no network (run with airplane mode on).
///
/// `flutter test integration_test/classifier_parity_test.dart -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device ONNX matches Python for every class', (tester) async {
    final classifier = OnnxClassifier();
    final dir = await getTemporaryDirectory();
    final latencies = <int>[];

    for (final f in parityFixtures) {
      final path = '${dir.path}/${f['file']}';
      await File(path).writeAsBytes(base64Decode(f['jpeg']! as String));
      final result = await classifier.classify(path);
      latencies.add(result.latencyMs!);

      expect(result.topLabel, f['top1'], reason: '${f['file']} top-1');
      final expected = (f['probs']! as List).cast<num>();
      final got = result.probabilities.values.toList();
      for (var i = 0; i < expected.length; i++) {
        expect(got[i], closeTo(expected[i], 0.05), reason: '${f['file']} class $i');
      }
    }
    latencies.sort();
    // ignore: avoid_print
    print('PARITY OK · model ${classifier.modelVersion} · latency ms (preprocess+inference): $latencies');
  });
}
