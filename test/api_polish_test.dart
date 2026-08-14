import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';

void main() {
  tearDown(FrameGuard.reset);

  group('MarkdownReportBuilder', () {
    test('builds PR-friendly markdown', () {
      FrameGuard.initialize(force: true);
      final report = _sampleReport(passed: false);
      final md = MarkdownReportBuilder(report).build();
      expect(md, contains('## FrameGuard'));
      expect(md, contains('sample'));
      expect(md, contains('Budget'));
      expect(MarkdownReportBuilder(report).oneLiner(), contains('FAIL'));
    });
  });

  group('BudgetProfile', () {
    test('builtins and byName', () {
      expect(BudgetProfile.builtins, isNotEmpty);
      expect(BudgetProfile.byName('mid_range')?.name, 'mid_range');
      expect(BudgetProfile.byName('animation')?.name, 'animation');
      expect(BudgetProfile.byName('missing'), isNull);
    });
  });

  group('FrameGuardDoctor', () {
    test('runs locally', () {
      final report =
          FrameGuardDoctor(workingDirectory: Directory.current.path).run();
      expect(report.ok, isTrue);
      expect(report.summary(), contains('frameguard_version'));
    });
  });

  group('FrameGuardSuppress', () {
    testWidgets('mounts and unsuppresses on dispose', (tester) async {
      FrameGuard.initialize(force: true);
      await tester.pumpWidget(
        const FrameGuardSuppress(
          diagnostics: {FrameDiagnostic.excessiveRebuilds},
          child: SizedBox(),
        ),
      );
      expect(
        DiagnosticSuppression.isSuppressed(FrameDiagnostic.excessiveRebuilds),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      expect(
        DiagnosticSuppression.isSuppressed(FrameDiagnostic.excessiveRebuilds),
        isFalse,
      );
    });
  });

  group('FrameGuardOverlay', () {
    testWidgets('renders compact overlay', (tester) async {
      FrameGuard.initialize(force: true);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FrameGuardOverlay(
            compact: true,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      expect(find.textContaining('FG', findRichText: true), findsOneWidget);
    });
  });

  group('FrameGuard.runSession', () {
    testWidgets('returns a report', (tester) async {
      FrameGuard.initialize(force: true);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(),
        ),
      );
      final report = await FrameGuard.runSession(
        name: 'run_session_demo',
        body: () async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
        },
      );
      expect(report.scenario, 'run_session_demo');
      expect(report.frameguardVersion, '0.6.0');
    });
  });

  group('FrameGuardInit', () {
    test('scaffolds directories under tmp', () async {
      final dir =
          await Directory('tmp_check/init_demo').create(recursive: true);
      final actions = await FrameGuardInit(workingDirectory: dir.path).run();
      expect(actions, isNotEmpty);
      expect(Directory('${dir.path}/reports').existsSync(), isTrue);
      expect(Directory('${dir.path}/baselines').existsSync(), isTrue);
      expect(Directory('${dir.path}/history').existsSync(), isTrue);
      expect(File('${dir.path}/frameguard.yaml').existsSync(), isTrue);
    });
  });

  group('writeMarkdown / writeArtifacts', () {
    test('writes markdown artifact', () async {
      FrameGuard.initialize(force: true);
      final report = _sampleReport(passed: true);
      final dir = Directory('tmp_check/artifacts');
      final arts = await report.writeArtifacts(
        dir,
        html: false,
        markdown: true,
      );
      expect(arts.markdown!.existsSync(), isTrue);
      expect(await arts.markdown!.readAsString(), contains('## FrameGuard'));
    });
  });

  group('FrameGuardGolden', () {
    test('missing baseline message mentions report path', () async {
      FrameGuard.initialize(force: true);
      final report = _sampleReport(passed: true);
      expect(
        () => FrameGuardGolden.expectMatches(
          report,
          'does_not_exist_golden_xyz',
          directory: 'tmp_check/missing_baselines',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('baseline update <report.json>'),
          ),
        ),
      );
    });
  });
}

FrameGuardReport _sampleReport({required bool passed}) {
  final budget = FrameBudget.forRefreshRate(
    60,
    maxJankRate: passed ? 0.5 : 0.01,
    maxJankFrames: passed ? 100 : 0,
  );
  final frames = [
    for (var i = 0; i < 20; i++)
      FrameSample(
        frameNumber: i,
        buildDuration: Duration(milliseconds: passed ? 4 : 30),
        rasterDuration: const Duration(milliseconds: 2),
        totalDuration: Duration(milliseconds: passed ? 6 : 32),
        vsyncOverhead: Duration.zero,
        timestamp: DateTime.utc(2026, 1, 1).add(Duration(milliseconds: i * 16)),
        severity: passed ? JankSeverity.healthy : JankSeverity.major,
        janky: !passed,
        bottleneck: FrameBottleneck.buildBound,
      ),
  ];
  final stats = FrameStats.compute(frames);
  final evaluation = BudgetEvaluation.evaluate(stats, budget);
  return FrameGuardReport(
    schemaVersion: FrameGuardReport.currentSchemaVersion,
    id: 'sample',
    scenario: 'sample',
    startedAt: DateTime.utc(2026, 1, 1),
    endedAt: DateTime.utc(2026, 1, 1, 0, 0, 1),
    frameguardVersion: FrameGuard.packageVersion,
    device: const DeviceMetadata(
      platform: 'test',
      buildMode: FrameGuardBuildMode.profile,
      refreshRateHz: 60,
    ),
    frameBudgetTarget: const Duration(milliseconds: 16),
    refreshRateHz: 60,
    refreshRateFallback: false,
    frames: frames,
    warmupFrameCount: 0,
    stats: stats,
    markers: const [],
    traces: const [],
    tasks: const [],
    regions: const [],
    customMetrics: const {},
    imageWarnings: const [],
    budget: budget,
    budgetEvaluation: evaluation,
  );
}
