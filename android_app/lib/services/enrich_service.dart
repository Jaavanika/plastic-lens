import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/plastic_type.dart';

/// Validated result of the backend's vision-LLM check (README §6).
class EnrichResult {
  const EnrichResult({required this.objectName, this.containsPlastic, this.resinCode, this.likelyPolymer, this.notes});
  final String objectName;
  final bool? containsPlastic;
  final int? resinCode; // 1-7 if a printed code was read
  final String? likelyPolymer;
  final String? notes;

  /// Polymer implied by a printed resin code 1-6, if any.
  String? get printedPolymer =>
      resinCode != null && resinCode! >= 1 && resinCode! <= 6 ? polymerCodes[resinCode! - 1] : null;

  /// Defensive parsing: anything malformed returns null instead of throwing.
  static EnrichResult? tryParse(Object? json) {
    if (json is! Map) return null;
    final name = json['object_name'];
    if (name is! String || name.trim().isEmpty || name.length > 80) return null;
    final code = json['resin_code_visible'];
    final polymer = json['likely_polymer'];
    final plastic = json['contains_plastic'];
    final notes = json['notes'];
    return EnrichResult(
      objectName: name.trim(),
      containsPlastic: plastic is bool ? plastic : null,
      resinCode: code is int && code >= 1 && code <= 7 ? code : null,
      likelyPolymer: polymer is String && polymerCodes.contains(polymer) ? polymer : null,
      notes: notes is String && notes.length <= 300 ? notes : null,
    );
  }
}

abstract class EnrichService {
  bool get enabled;

  /// Returns null on any failure (offline, timeout, bad output, rate limit).
  Future<EnrichResult?> enrich(String imagePath, String idToken);
}

class DisabledEnrichService implements EnrichService {
  const DisabledEnrichService();
  @override
  bool get enabled => false;
  @override
  Future<EnrichResult?> enrich(String imagePath, String idToken) async => null;
}

/// Calls POST {baseUrl}/api/identify/enrich with a Firebase ID token.
/// The base URL comes from `--dart-define=ENRICH_URL=https://...`.
class HttpEnrichService implements EnrichService {
  HttpEnrichService(this.baseUrl, {http.Client? client, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client();

  static const configuredUrl = String.fromEnvironment('ENRICH_URL');

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  bool get enabled => baseUrl.isNotEmpty;

  @override
  Future<EnrichResult?> enrich(String imagePath, String idToken) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/identify/enrich'))
        ..headers['Authorization'] = 'Bearer $idToken'
        ..files.add(await http.MultipartFile.fromPath('image', imagePath));
      final streamed = await _client.send(req).timeout(timeout);
      final body = await streamed.stream.bytesToString().timeout(timeout);
      if (streamed.statusCode != HttpStatus.ok) return null;
      return EnrichResult.tryParse(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }
}
