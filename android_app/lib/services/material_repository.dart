import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/plastic_type.dart';

/// Material information. The bundled JSON is always available offline;
/// a newer copy from Firestore replaces it when one is fetched.
class MaterialRepository {
  MaterialRepository(this._materials, this.caveat);

  final Map<String, PlasticType> _materials;
  final String caveat;

  static const assetPath = 'assets/data/plastic_types.json';

  static Future<MaterialRepository> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return MaterialRepository.fromJsonString(raw);
  }

  factory MaterialRepository.fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['materials'] as List)
        .map((m) => PlasticType.fromJson(m as Map<String, dynamic>));
    return MaterialRepository(
      {for (final m in list) m.code: m},
      j['caveat'] as String,
    );
  }

  PlasticType? byCode(String? code) => code == null ? null : _materials[code];

  List<PlasticType> get all =>
      polymerCodes.map((c) => _materials[c]).whereType<PlasticType>().toList();

  /// Replace records with newer ones (e.g. from Firestore).
  void merge(Iterable<PlasticType> updates) {
    for (final m in updates) {
      _materials[m.code] = m;
    }
  }
}
