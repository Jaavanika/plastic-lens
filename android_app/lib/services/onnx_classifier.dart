import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../models/classification.dart';
import '../utils/preprocess.dart';
import 'classifier_service.dart';

/// On-device classifier: assets/models/plasticlens.onnx + labels.json.
/// The ONNX graph already applies temperature scaling and softmax.
class OnnxClassifier implements ClassifierService {
  OnnxClassifier({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const modelAsset = 'assets/models/plasticlens.onnx';
  static const labelsAsset = 'assets/models/labels.json';

  final AssetBundle _bundle;
  Future<void>? _loading;
  OrtSession? _session;
  late List<String> _classes;
  late Thresholds _thresholds;
  late InputSpec _spec;
  String _version = 'unknown';

  /// Latency of the most recent classification (preprocess + inference).
  int? lastLatencyMs;

  @override
  String get modelVersion => _version;

  /// Loads the model once; later calls reuse the same future.
  Future<void> warmUp() => _loading ??= _load().catchError((Object e) {
        _loading = null; // allow a retry on the next scan
        throw ClassifierException('The AI model could not be loaded ($e).');
      });

  Future<void> _load() async {
    final labels = jsonDecode(await _bundle.loadString(labelsAsset)) as Map<String, dynamic>;
    _classes = List<String>.from(labels['classes'] as List);
    _thresholds = Thresholds.fromJson(labels['thresholds'] as Map<String, dynamic>);
    _spec = InputSpec.fromJson(labels['input'] as Map<String, dynamic>);
    _version = labels['model_version'] as String;

    OrtEnv.instance.init();
    final raw = await _bundle.load(modelAsset);
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(math.min(4, Platform.numberOfProcessors))
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    _session = OrtSession.fromBuffer(raw.buffer.asUint8List(), options);
  }

  @override
  Future<Classification> classify(String imagePath) async {
    await warmUp();
    final sw = Stopwatch()..start();
    final bytes = await File(imagePath).readAsBytes();
    final spec = _spec;
    final Float32List input;
    try {
      input = await Isolate.run(() => preprocessBytes(bytes, spec));
    } on PreprocessException catch (e) {
      throw ClassifierException(e.message);
    }

    final tensor = OrtValueTensor.createTensorWithDataList(input, [1, 3, spec.size, spec.size]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await _session!.runAsync(runOptions, {'input': tensor});
      final probs = (outputs!.first!.value as List).first as List;
      sw.stop();
      lastLatencyMs = sw.elapsedMilliseconds;
      return Classification(
        probabilities: {for (var i = 0; i < _classes.length; i++) _classes[i]: (probs[i] as num).toDouble()},
        modelVersion: _version,
        thresholds: _thresholds,
        latencyMs: lastLatencyMs,
      );
    } catch (e) {
      throw ClassifierException('The AI model failed on this image ($e).');
    } finally {
      tensor.release();
      runOptions.release();
      for (final o in outputs ?? const <OrtValue?>[]) {
        o?.release();
      }
    }
  }
}
