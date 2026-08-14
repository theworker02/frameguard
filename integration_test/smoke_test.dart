import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scroll scenario produces a FrameGuard report', (tester) async {
    FrameGuard.initialize(
      config: FrameGuardConfig(
        defaultBudget: FrameBudget.forRefreshRate(60, maxJankRate: 0.5),
      ),
    );

    await tester.pumpWidget(
      FrameGuardScope(
        child: MaterialApp(
          home: Scaffold(
            body: FrameGuardRegion(
              name: 'feed_list',
              child: ListView.builder(
                itemCount: 200,
                itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
              ),
            ),
          ),
        ),
      ),
    );

    final report = await FrameGuardTest.measure(
      tester,
      name: 'feed_scroll',
      action: () async {
        await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
        await tester.pumpAndSettle();
      },
    );

    expect(report.scenario, 'feed_scroll');
    expect(report.stats.totalFrames, greaterThanOrEqualTo(0));
    // Integration environments vary; assert structure rather than strict budgets.
    expect(report.toJson()['schemaVersion'], 1);
  });
}
