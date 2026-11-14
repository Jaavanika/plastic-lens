import 'plastic_type.dart';

/// How much the app trusts a prediction (README §7.5).
enum ResultState { high, medium, low, nonPlastic }

/// Confidence cut-offs. Defaults are provisional; Section 3 replaces them
/// with values chosen on the validation set (see assets/models/labels.json).
class Thresholds {
  const Thresholds({this.high = 0.80, this.medium = 0.55});
  final double high;
  final double medium;

  factory Thresholds.fromJson(Map<String, dynamic> j) => Thresholds(
        high: (j['high'] as num).toDouble(),
        medium: (j['medium'] as num).toDouble(),
      );
}

class Classification {
  Classification({
    required this.probabilities,
    required this.modelVersion,
    this.thresholds = const Thresholds(),
    this.latencyMs,
  });

  /// label -> calibrated probability, for every class the model outputs.
  final Map<String, double> probabilities;
  final String modelVersion;
  final Thresholds thresholds;
  final int? latencyMs;

  List<MapEntry<String, double>> get ranked =>
      probabilities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  String get topLabel => ranked.first.key;
  double get confidence => ranked.first.value;

  ResultState get state {
    if (topLabel == nonPlasticLabel) return ResultState.nonPlastic;
    if (confidence >= thresholds.high) return ResultState.high;
    if (confidence >= thresholds.medium) return ResultState.medium;
    return ResultState.low;
  }

  /// Polymer code to show, or null when no polymer should be claimed.
  String? get polymer =>
      state == ResultState.high || state == ResultState.medium
          ? topLabel
          : null;

  /// Yes / No / null (= Unsure).
  bool? get containsPlastic => switch (state) {
        ResultState.nonPlastic => false,
        ResultState.low => null,
        _ => true,
      };
}
