import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Input spec from labels.json (`input` block).
class InputSpec {
  const InputSpec({this.size = 224, this.mean = const [0.485, 0.456, 0.406], this.std = const [0.229, 0.224, 0.225]});
  final int size;
  final List<double> mean;
  final List<double> std;

  factory InputSpec.fromJson(Map<String, dynamic> j) => InputSpec(
        size: j['size'] as int,
        mean: (j['mean'] as List).map((e) => (e as num).toDouble()).toList(),
        std: (j['std'] as List).map((e) => (e as num).toDouble()).toList(),
      );
}

class PreprocessException implements Exception {
  PreprocessException(this.message);
  final String message;
  @override
  String toString() => message;
}

const minImageSide = 64;

/// Same steps as Python's EVAL_TF (ai_model/training/dataset.py):
/// decode → EXIF rotate → RGB → resize straight to size×size → [0,1] →
/// ImageNet normalise → NCHW float32.
///
/// Pure Dart so it can run in a background isolate and in `flutter test`.
Float32List preprocessBytes(Uint8List bytes, InputSpec spec) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw PreprocessException('This file is not an image PlasticLens can read.');
  }
  final oriented = img.bakeOrientation(decoded);
  if (oriented.width < minImageSide || oriented.height < minImageSide) {
    throw PreprocessException('The image is too small (minimum $minImageSide × $minImageSide pixels).');
  }
  final s = spec.size;
  // Two-step resize approximates PIL's antialiased bilinear downscaling:
  // area-average down to ~2× the target, then bilinear to the target.
  var work = oriented;
  if (work.width > s * 2 || work.height > s * 2) {
    work = img.copyResize(work, width: s * 2, height: s * 2, interpolation: img.Interpolation.average);
  }
  final resized = img.copyResize(work, width: s, height: s, interpolation: img.Interpolation.linear);

  final out = Float32List(3 * s * s);
  final plane = s * s;
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final p = resized.getPixel(x, y);
      final i = y * s + x;
      out[i] = (p.r / 255.0 - spec.mean[0]) / spec.std[0];
      out[plane + i] = (p.g / 255.0 - spec.mean[1]) / spec.std[1];
      out[2 * plane + i] = (p.b / 255.0 - spec.mean[2]) / spec.std[2];
    }
  }
  return out;
}
