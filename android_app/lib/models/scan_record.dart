import 'classification.dart';

enum SyncStatus { pending, synced }

/// A saved scan (identification spec §10 "Example scan record").
class ScanRecord {
  ScanRecord({
    required this.id,
    required this.itemName,
    required this.containsPlastic,
    required this.plasticType,
    required this.resinCode,
    required this.confidence,
    required this.state,
    required this.modelVersion,
    required this.imagePath,
    required this.createdAt,
    this.llmUsed = false,
    this.userVerified = false,
    this.inCollection = false,
    this.remoteImagePath,
    this.syncStatus = SyncStatus.pending,
    this.updatedAt,
    this.secondOpinion,
  });

  final String id; // stable UUID; also the Firestore document id
  String itemName;
  bool? containsPlastic;
  String? plasticType;
  int? resinCode;
  double confidence;
  ResultState state;
  final String modelVersion;
  final String imagePath; // local file
  final DateTime createdAt;
  bool llmUsed;
  bool userVerified;
  bool inCollection;
  String? remoteImagePath;
  SyncStatus syncStatus;
  DateTime? updatedAt;

  /// Note from the online check when it disagreed with the on-device model.
  String? secondOpinion;

  /// Whether this scan counts towards points and badges (identification spec §14).
  /// Medium ("please verify") and low results only count once verified.
  bool get isReliable =>
      userVerified || state == ResultState.high || state == ResultState.nonPlastic;

  Map<String, Object?> toMap() => {
        'id': id,
        'item_name': itemName,
        'contains_plastic':
            containsPlastic == null ? null : (containsPlastic! ? 1 : 0),
        'plastic_type': plasticType,
        'resin_code': resinCode,
        'confidence': confidence,
        'state': state.name,
        'model_version': modelVersion,
        'image_path': imagePath,
        'created_at': createdAt.toUtc().toIso8601String(),
        'llm_used': llmUsed ? 1 : 0,
        'user_verified': userVerified ? 1 : 0,
        'in_collection': inCollection ? 1 : 0,
        'remote_image_path': remoteImagePath,
        'sync_status': syncStatus.name,
        'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
        'second_opinion': secondOpinion,
      };

  factory ScanRecord.fromMap(Map<String, Object?> m) => ScanRecord(
        id: m['id'] as String,
        itemName: m['item_name'] as String,
        containsPlastic: m['contains_plastic'] == null
            ? null
            : (m['contains_plastic'] as int) == 1,
        plasticType: m['plastic_type'] as String?,
        resinCode: m['resin_code'] as int?,
        confidence: (m['confidence'] as num).toDouble(),
        state: ResultState.values.byName(m['state'] as String),
        modelVersion: m['model_version'] as String,
        imagePath: m['image_path'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        llmUsed: (m['llm_used'] as int? ?? 0) == 1,
        userVerified: (m['user_verified'] as int? ?? 0) == 1,
        inCollection: (m['in_collection'] as int? ?? 0) == 1,
        remoteImagePath: m['remote_image_path'] as String?,
        syncStatus: SyncStatus.values.byName(m['sync_status'] as String),
        updatedAt: m['updated_at'] == null
            ? null
            : DateTime.parse(m['updated_at'] as String).toLocal(),
        secondOpinion: m['second_opinion'] as String?,
      );

  factory ScanRecord.fromFirestore(Map<String, dynamic> m) => ScanRecord(
        id: m['scan_id'] as String,
        itemName: m['item_name'] as String,
        containsPlastic: m['contains_plastic'] as bool?,
        plasticType: m['plastic_type'] as String?,
        resinCode: (m['resin_code'] as num?)?.toInt(),
        confidence: (m['confidence'] as num).toDouble(),
        state: ResultState.values.byName(m['state'] as String),
        modelVersion: m['model_version'] as String,
        imagePath: '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        llmUsed: m['llm_used'] as bool? ?? false,
        userVerified: m['user_verified'] as bool? ?? false,
        inCollection: m['in_collection'] as bool? ?? false,
        remoteImagePath: m['image_path'] as String?,
        syncStatus: SyncStatus.synced,
        updatedAt: m['updated_at'] == null ? null : DateTime.parse(m['updated_at'] as String).toLocal(),
        secondOpinion: m['second_opinion'] as String?,
      );

  /// Shape stored in Firestore `users/{uid}/scans/{id}`.
  Map<String, Object?> toFirestore(String uid) => {
        'scan_id': id,
        'user_id': uid,
        'item_name': itemName,
        'contains_plastic': containsPlastic,
        'plastic_type': plasticType,
        'resin_code': resinCode,
        'confidence': confidence,
        'state': state.name,
        'model_version': modelVersion,
        'llm_used': llmUsed,
        'user_verified': userVerified,
        'in_collection': inCollection,
        'image_path': remoteImagePath,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
        'second_opinion': secondOpinion,
      };
}
