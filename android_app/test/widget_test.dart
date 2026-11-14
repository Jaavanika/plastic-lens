import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plastic_lens/app.dart';
import 'package:plastic_lens/models/classification.dart';
import 'package:plastic_lens/screens/result_screen.dart';
import 'package:plastic_lens/services/classifier_service.dart';
import 'package:plastic_lens/services/material_repository.dart';
import 'package:plastic_lens/services/scan_store.dart';
import 'package:plastic_lens/utils/dummy_data.dart';
import 'package:provider/provider.dart';

// Synchronous read: async file I/O never completes inside testWidgets' fake zone.
Future<MaterialRepository> loadMaterials() async =>
    MaterialRepository.fromJsonString(File('assets/data/plastic_types.json').readAsStringSync());

Future<ScanStore> seededStore() async {
  final store = ScanStore(InMemoryScanStorage(dummyScans()));
  await store.load();
  return store;
}

void main() {
  testWidgets('all five tabs are reachable', (tester) async {
    final app = PlasticLensApp(materials: await loadMaterials(), store: await seededStore(), classifier: FakeClassifier());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('PlasticLens'), findsWidgets);
    expect(find.text('Scan plastic'), findsWidgets);

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('My collection'), findsOneWidget);
    expect(find.textContaining('of 6 polymer types found'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Scan history'), findsOneWidget);
    expect(find.text('Water bottle'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Guest'), findsOneWidget);
  });

  testWidgets('history search and filter narrow the list', (tester) async {
    final app = PlasticLensApp(materials: await loadMaterials(), store: await seededStore(), classifier: FakeClassifier());
    await tester.pumpWidget(app);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'HDPE'));
    await tester.pumpAndSettle();
    expect(find.text('Milk jug'), findsOneWidget);
    expect(find.text('Water bottle'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.enterText(find.byType(TextField), 'yog');
    await tester.pumpAndSettle();
    expect(find.text('Yoghurt pot'), findsOneWidget);
    expect(find.text('Milk jug'), findsNothing);
  });

  Future<void> pumpResult(WidgetTester tester, String id) async {
    // Phone-sized screen (Pixel 7) so the details card is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final materials = await loadMaterials();
    final store = await seededStore();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: materials),
        ChangeNotifierProvider.value(value: store),
      ],
      child: MaterialApp(home: ResultScreen(scanId: id)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('result screen shows the four result rows and material info', (tester) async {
    await pumpResult(tester, 'demo-1');
    expect(find.text('Object'), findsOneWidget);
    expect(find.text('Plastic presence'), findsOneWidget);
    expect(find.text('Plastic type'), findsOneWidget);
    expect(find.text('Confidence'), findsOneWidget);
    expect(find.text('94.0 %'), findsOneWidget);
    expect(find.text('Likely PET'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PET: Polyethylene Terephthalate'), 200);
    expect(find.text('PET: Polyethylene Terephthalate'), findsOneWidget);
  });

  testWidgets('low-confidence and non-plastic results are shown safely', (tester) async {
    await pumpResult(tester, 'demo-5');
    expect(find.text('Unable to identify reliably'), findsOneWidget);
    expect(find.text('Unsure'), findsWidgets);

    await pumpResult(tester, 'demo-4');
    expect(find.text('No plastic detected'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  test('threshold policy maps confidence to result states', () {
    Classification c(String top, double p) => Classification(
          probabilities: {top: p, 'a': (1 - p) / 3, 'b': (1 - p) / 3, 'c': (1 - p) / 3},
          modelVersion: 't',
          thresholds: const Thresholds(high: 0.8, medium: 0.5),
        );
    expect(c('PET', 0.9).state, ResultState.high);
    expect(c('PET', 0.6).state, ResultState.medium);
    expect(c('PET', 0.6).polymer, 'PET');
    expect(c('PET', 0.4).state, ResultState.low);
    expect(c('PET', 0.4).polymer, isNull);
    expect(c('PET', 0.4).containsPlastic, isNull);
    expect(c('non_plastic', 0.9).state, ResultState.nonPlastic);
    expect(c('non_plastic', 0.9).containsPlastic, isFalse);
  });
}
