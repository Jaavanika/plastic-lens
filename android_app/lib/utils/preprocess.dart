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
  final rgb = resizeLikePil(oriented, s, s);

  final out = Float32List(3 * s * s);
  final plane = s * s;
  for (var i = 0; i < plane; i++) {
    out[i] = (rgb[i * 3] / 255.0 - spec.mean[0]) / spec.std[0];
    out[plane + i] = (rgb[i * 3 + 1] / 255.0 - spec.mean[1]) / spec.std[1];
    out[2 * plane + i] = (rgb[i * 3 + 2] / 255.0 - spec.mean[2]) / spec.std[2];
  }
  return out;
}

/// Port of Pillow's `Image.resize(..., BILINEAR)` (ImagingResample): a
/// separable triangle filter whose support widens with the scale factor
/// (antialiasing), horizontal pass then vertical, rounded to 8 bits between
/// passes. torchvision's `Resize` uses exactly this, so the app sees the same
/// pixels as training/evaluation. Returns interleaved RGB bytes.
Uint8List resizeLikePil(img.Image src, int outW, int outH) {
  final inW = src.width, inH = src.height;
  final input = Uint8List(inW * inH * 3);
  for (final p in src) {
    final o = (p.y * inW + p.x) * 3;
    input[o] = p.r.toInt();
    input[o + 1] = p.g.toInt();
    input[o + 2] = p.b.toInt();
  }

  final (hBounds, hWeights) = _coefficients(inW, outW);
  final (vBounds, vWeights) = _coefficients(inH, outH);

  // Horizontal: inH rows × outW columns.
  final tmp = Uint8List(inH * outW * 3);
  for (var y = 0; y < inH; y++) {
    for (var x = 0; x < outW; x++) {
      final start = hBounds[x * 2], count = hBounds[x * 2 + 1];
      final w = hWeights[x];
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < count; k++) {
        final o = (y * inW + start + k) * 3;
        r += input[o] * w[k];
        g += input[o + 1] * w[k];
        b += input[o + 2] * w[k];
      }
      final t = (y * outW + x) * 3;
      tmp[t] = _clip8(r);
      tmp[t + 1] = _clip8(g);
      tmp[t + 2] = _clip8(b);
    }
  }

  // Vertical: outH rows × outW columns.
  final out = Uint8List(outH * outW * 3);
  for (var y = 0; y < outH; y++) {
    final start = vBounds[y * 2], count = vBounds[y * 2 + 1];
    final w = vWeights[y];
    for (var x = 0; x < outW; x++) {
      var r = 0.0, g = 0.0, b = 0.0;
      for (var k = 0; k < count; k++) {
        final o = ((start + k) * outW + x) * 3;
        r += tmp[o] * w[k];
        g += tmp[o + 1] * w[k];
        b += tmp[o + 2] * w[k];
      }
      final t = (y * outW + x) * 3;
      out[t] = _clip8(r);
      out[t + 1] = _clip8(g);
      out[t + 2] = _clip8(b);
    }
  }
  return out;
}

int _clip8(double v) => v <= 0 ? 0 : (v >= 255 ? 255 : (v + 0.5).floor());

/// Per output pixel: first input index, tap count, and normalised weights.
(Int32List, List<Float64List>) _coefficients(int inSize, int outSize) {
  final scale = inSize / outSize;
  final filterScale = scale < 1.0 ? 1.0 : scale;
  final support = 1.0 * filterScale; // bilinear filter support is 1
  final bounds = Int32List(outSize * 2);
  final weights = <Float64List>[];
  for (var x = 0; x < outSize; x++) {
    final center = (x + 0.5) * scale;
    final xmin = (center - support + 0.5).floor().clamp(0, inSize);
    final xmax = (center + support + 0.5).floor().clamp(0, inSize);
    final n = xmax - xmin;
    final w = Float64List(n);
    var total = 0.0;
    for (var k = 0; k < n; k++) {
      final t = ((k + xmin - center + 0.5) / filterScale).abs();
      w[k] = t < 1.0 ? 1.0 - t : 0.0;
      total += w[k];
    }
    if (total != 0) {
      for (var k = 0; k < n; k++) {
        w[k] /= total;
      }
    }
    bounds[x * 2] = xmin;
    bounds[x * 2 + 1] = n;
    weights.add(w);
  }
  return (bounds, weights);
}
