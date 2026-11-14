import 'package:flutter/foundation.dart';

import '../models/scan_record.dart';

/// Where scans are persisted. Section 1 uses memory; Section 8 adds SQLite.
abstract class ScanStorage {
  Future<List<ScanRecord>> loadAll();
  Future<void> upsert(ScanRecord scan);
  Future<void> delete(String id);
  Future<void> clear();
}

class InMemoryScanStorage implements ScanStorage {
  InMemoryScanStorage([List<ScanRecord>? seed]) {
    for (final s in seed ?? const <ScanRecord>[]) {
      _rows[s.id] = s;
    }
  }
  final _rows = <String, ScanRecord>{};

  @override
  Future<List<ScanRecord>> loadAll() async => _rows.values.toList();
  @override
  Future<void> upsert(ScanRecord scan) async => _rows[scan.id] = scan;
  @override
  Future<void> delete(String id) async => _rows.remove(id);
  @override
  Future<void> clear() async => _rows.clear();
}

/// App-wide list of scans, newest first.
class ScanStore extends ChangeNotifier {
  ScanStore(this._storage);

  final ScanStorage _storage;
  List<ScanRecord> _scans = [];
  bool _loaded = false;

  /// Called after every local change so sync can push it.
  void Function(ScanRecord scan)? onChanged;
  void Function(String id)? onDeleted;

  bool get loaded => _loaded;
  List<ScanRecord> get scans => List.unmodifiable(_scans);
  List<ScanRecord> get collection =>
      _scans.where((s) => s.inCollection).toList();

  Future<void> load() async {
    _scans = await _storage.loadAll();
    _sort();
    _loaded = true;
    notifyListeners();
  }

  ScanRecord? byId(String id) {
    for (final s in _scans) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> save(ScanRecord scan, {bool fromSync = false}) async {
    if (!fromSync) {
      scan.updatedAt = DateTime.now();
      scan.syncStatus = SyncStatus.pending;
    }
    await _storage.upsert(scan);
    _scans.removeWhere((s) => s.id == scan.id);
    _scans.add(scan);
    _sort();
    notifyListeners();
    if (!fromSync) onChanged?.call(scan);
  }

  Future<void> markSynced(ScanRecord scan) async {
    scan.syncStatus = SyncStatus.synced;
    await _storage.upsert(scan);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _storage.delete(id);
    _scans.removeWhere((s) => s.id == id);
    notifyListeners();
    onDeleted?.call(id);
  }

  Future<void> clearLocal() async {
    await _storage.clear();
    _scans = [];
    notifyListeners();
  }

  /// Distinct polymers the user has reliably found.
  Set<String> get polymersFound => {
        for (final s in _scans)
          if (s.isReliable && s.plasticType != null) s.plasticType!,
      };

  void _sort() => _scans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
