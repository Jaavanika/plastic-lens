import '../models/classification.dart';
import '../models/scan_record.dart';

/// Example scans used by the Section 1 prototype and by widget tests.
List<ScanRecord> dummyScans() {
  final now = DateTime.now();
  ScanRecord s(String id, String name, String? type, int? code, double conf,
          ResultState st, int daysAgo, {bool collected = false}) =>
      ScanRecord(
        id: id,
        itemName: name,
        containsPlastic: st == ResultState.nonPlastic
            ? false
            : (st == ResultState.low ? null : true),
        plasticType: type,
        resinCode: code,
        confidence: conf,
        state: st,
        modelVersion: 'fake-0',
        imagePath: '',
        createdAt: now.subtract(Duration(days: daysAgo, hours: daysAgo * 3)),
        inCollection: collected,
      );
  return [
    s('demo-1', 'Water bottle', 'PET', 1, 0.94, ResultState.high, 0, collected: true),
    s('demo-2', 'Milk jug', 'HDPE', 2, 0.88, ResultState.high, 1, collected: true),
    s('demo-3', 'Yoghurt pot', 'PP', 5, 0.67, ResultState.medium, 2),
    s('demo-4', 'Glass jar', null, null, 0.91, ResultState.nonPlastic, 3),
    s('demo-5', 'Crushed cup', null, null, 0.38, ResultState.low, 5),
  ];
}
