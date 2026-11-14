import 'dart:math';

import '../models/classification.dart';
import '../models/plastic_type.dart';

abstract class ClassifierService {
  /// Classify the image at [imagePath]. Throws [ClassifierException] when
  /// the image cannot be read or the model fails.
  Future<Classification> classify(String imagePath);

  String get modelVersion;
}

class ClassifierException implements Exception {
  ClassifierException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stand-in used before the real model exists and in widget tests.
/// Returns a deterministic pseudo-result derived from the file path.
class FakeClassifier implements ClassifierService {
  FakeClassifier({this.delay = const Duration(milliseconds: 600)});
  final Duration delay;

  @override
  String get modelVersion => 'fake-0';

  @override
  Future<Classification> classify(String imagePath) async {
    await Future<void>.delayed(delay);
    final rnd = Random(imagePath.hashCode);
    final labels = [...polymerCodes, nonPlasticLabel];
    final top = labels[rnd.nextInt(polymerCodes.length)];
    final topP = 0.6 + rnd.nextDouble() * 0.35;
    final rest = (1 - topP) / (labels.length - 1);
    return Classification(
      probabilities: {for (final l in labels) l: l == top ? topP : rest},
      modelVersion: modelVersion,
    );
  }
}
