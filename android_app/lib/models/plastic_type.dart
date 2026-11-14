/// One polymer record from `assets/data/plastic_types.json`
/// (mirrored in the Firestore `plastic_types` collection).
class PlasticType {
  const PlasticType({
    required this.code,
    required this.fullName,
    required this.resinCode,
    required this.description,
    required this.properties,
    required this.commonItems,
    required this.otherMaterials,
    required this.recyclingGuidance,
    required this.recyclabilityRating,
    required this.recyclabilityNote,
    required this.fact,
    required this.ecoTip,
    required this.sources,
  });

  final String code; // "PET"
  final String fullName; // "Polyethylene Terephthalate"
  final int resinCode; // 1
  final String description;
  final List<String> properties;
  final List<String> commonItems;
  final List<String> otherMaterials;
  final List<String> recyclingGuidance;
  final int recyclabilityRating; // 1-5, contextual only
  final String recyclabilityNote;
  final String fact;
  final String ecoTip;
  final List<String> sources;

  factory PlasticType.fromJson(Map<String, dynamic> j) => PlasticType(
        code: j['material'] as String,
        fullName: j['full_name'] as String,
        resinCode: j['resin_code'] as int,
        description: j['description'] as String,
        properties: List<String>.from(j['properties'] as List),
        commonItems: List<String>.from(j['common_items'] as List),
        otherMaterials: List<String>.from(j['other_materials'] as List? ?? []),
        recyclingGuidance:
            List<String>.from(j['recycling_guidance'] as List),
        recyclabilityRating: j['recyclability_rating'] as int,
        recyclabilityNote: j['recyclability_note'] as String,
        fact: j['fact'] as String,
        ecoTip: j['eco_tip'] as String,
        sources: List<String>.from(j['sources'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'material': code,
        'full_name': fullName,
        'resin_code': resinCode,
        'description': description,
        'properties': properties,
        'common_items': commonItems,
        'other_materials': otherMaterials,
        'recycling_guidance': recyclingGuidance,
        'recyclability_rating': recyclabilityRating,
        'recyclability_note': recyclabilityNote,
        'fact': fact,
        'eco_tip': ecoTip,
        'sources': sources,
      };
}

/// The six polymers the model knows, in class-index order.
const polymerCodes = ['PET', 'HDPE', 'PVC', 'LDPE', 'PP', 'PS'];
const nonPlasticLabel = 'non_plastic';
