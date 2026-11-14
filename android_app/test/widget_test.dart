import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plastic_lens/app.dart';
import 'package:plastic_lens/models/classification.dart';
import 'package:plastic_lens/screens/result_screen.dart';

import 'helpers.dart';

void main() {
  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  testWidgets('all five tabs are reachable', (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(PlasticLensApp(services: await buildServices()));
    await tester.pumpAndSettle();

    expect(find.text('PlasticLens'), findsWidgets);
    expect(find.text('Scan plastic'), findsWidgets);

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('My collection'), findsOneWidget);
    expect(find.textContaining('of 6 polymer types found'), findsOneWidget);
    expect(find.text('points'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Scan history'), findsOneWidget);
    expect(find.text('Water bottle'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Cloud backup is not set up in this build'), findsOneWidget);
  });

  testWidgets('first launch with accounts offers sign-in or guest mode', (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(PlasticLensApp(services: await buildServices(auth: FakeAuth())));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to PlasticLens'), findsOneWidget);
    await tester.tap(find.textContaining('Continue without an account'));
    await tester.pumpAndSettle();
    expect(find.text('Scan plastic'), findsWidgets);
  });

  testWidgets('history search and filter narrow the list', (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(PlasticLensApp(services: await buildServices()));
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
    phoneScreen(tester);
    final services = await buildServices();
    await tester.pumpWidget(PlasticLensApp(services: services));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => ResultScreen(scanId: id)));
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

  testWidgets('low-confidence result is shown safely', (tester) async {
    await pumpResult(tester, 'demo-5');
    expect(find.text('Unable to identify reliably'), findsOneWidget);
    expect(find.text('Unsure'), findsWidgets);
  });

  testWidgets('non-plastic result is shown safely', (tester) async {
    await pumpResult(tester, 'demo-4');
    expect(find.text('No plastic detected'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('correcting the material marks the scan verified', (tester) async {
    await pumpResult(tester, 'demo-5');
    await tester.tap(find.text('Correct material'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polypropylene'));
    await tester.pumpAndSettle();
    expect(find.text('Verified by you'), findsWidgets);
  });

  testWidgets('learning library and quiz can be completed', (tester) async {
    phoneScreen(tester);
    final services = await buildServices();
    await tester.pumpWidget(PlasticLensApp(services: services));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learning library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What the ♲ numbers mean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(services.learning.isDone('resin-codes'), isTrue);
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
