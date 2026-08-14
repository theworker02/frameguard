import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:frameguard/src/cli/exit_codes.dart';
import 'package:frameguard/src/cli/io.dart';
import 'package:frameguard/src/core/config_loader.dart';
import 'package:frameguard/src/core/doctor.dart';
import 'package:frameguard/src/core/exceptions.dart';
import 'package:frameguard/src/core/project_init.dart';
import 'package:frameguard/src/core/version.dart';
import 'package:frameguard/src/diagnostics/diagnostic_id.dart';
import 'package:frameguard/src/diagnostics/explainability.dart';
import 'package:frameguard/src/metrics/budget_profile.dart';
import 'package:frameguard/src/metrics/budget_suggest.dart';
import 'package:frameguard/src/reporting/aggregate.dart';
import 'package:frameguard/src/reporting/baseline.dart';
import 'package:frameguard/src/reporting/comparison.dart';
import 'package:frameguard/src/reporting/drift.dart';
import 'package:frameguard/src/reporting/exporters.dart';
import 'package:frameguard/src/reporting/history.dart';
import 'package:frameguard/src/reporting/html_report.dart';
import 'package:frameguard/src/reporting/markdown_report.dart';
import 'package:frameguard/src/reporting/report.dart';
import 'package:frameguard/src/reporting/statistical.dart';
import 'package:path/path.dart' as p;

/// Runs the FrameGuard CLI. Returns a process exit code.
Future<int> runFrameGuardCli(List<String> args) async {
  final parser = _buildParser();
  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(_topUsage(parser));
    return FrameGuardExitCode.invalid;
  }

  final quiet = results['quiet'] == true;
  final verbose = results['verbose'] == true;

  if (results['help'] == true && results.command == null) {
    stdout.writeln(_topUsage(parser));
    return FrameGuardExitCode.pass;
  }

  final command = results.command;
  if (command == null) {
    stdout.writeln(_topUsage(parser));
    return FrameGuardExitCode.pass;
  }

  try {
    switch (command.name) {
      case 'help':
        return _help(command, parser);
      case 'version':
        return _version(quiet: quiet);
      case 'doctor':
        return _doctor(command, quiet: quiet);
      case 'init':
        return await _init(command, quiet: quiet);
      case 'inspect':
        return await _inspect(command, quiet: quiet, verbose: verbose);
      case 'report':
        return await _report(command, quiet: quiet);
      case 'compare':
      case 'diff':
        return await _compare(command, quiet: quiet);
      case 'check':
        return await _check(command, quiet: quiet);
      case 'suggest-budget':
        return await _suggestBudget(command, quiet: quiet);
      case 'history':
        return await _history(command, quiet: quiet);
      case 'baseline':
        return await _baseline(command, quiet: quiet);
      case 'merge':
        return await _merge(command, quiet: quiet);
      case 'export':
        return await _export(command, quiet: quiet);
      case 'summary':
        return await _summary(command, quiet: quiet);
      case 'config':
        return await _config(command, quiet: quiet);
      case 'migrate':
        return await _migrate(command, quiet: quiet);
      case 'list':
      case 'ls':
        return await _list(command, quiet: quiet);
      case 'explain':
        return await _explain(command, quiet: quiet);
      case 'frames':
        return await _frames(command, quiet: quiet);
      case 'regions':
        return await _regions(command, quiet: quiet);
      case 'tasks':
        return await _tasks(command, quiet: quiet);
      case 'stats':
        return await _stats(command, quiet: quiet);
      case 'top':
        return await _top(command, quiet: quiet);
      case 'histogram':
      case 'hist':
        return await _histogram(command, quiet: quiet);
      case 'validate':
        return await _validate(command, quiet: quiet);
      case 'drift':
        return await _drift(command, quiet: quiet);
      case 'profiles':
        return _profiles(command, quiet: quiet);
      case 'artifacts':
        return await _artifacts(command, quiet: quiet);
      case 'batch':
        return await _batch(command, quiet: quiet);
      case 'watch':
        return await _watch(command, quiet: quiet, verbose: verbose);
      case 'completions':
        return _completions(command);
      default:
        stderr.writeln('Unknown command: ${command.name}');
        stderr.writeln(_topUsage(parser));
        return FrameGuardExitCode.invalid;
    }
  } on FrameGuardException catch (e) {
    stderr.writeln(e.message);
    return FrameGuardExitCode.invalid;
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    return FrameGuardExitCode.invalid;
  } catch (e, st) {
    stderr.writeln('frameguard failed: $e');
    if (verbose) stderr.writeln(st);
    return FrameGuardExitCode.invalid;
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output.')
    ..addFlag('quiet', abbr: 'q', negatable: false, help: 'Minimal output.');

  parser.addCommand('help');
  parser.addCommand('version');
  parser.addCommand('doctor')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  parser.addCommand('init')
    ..addFlag(
      'yaml',
      defaultsTo: true,
      help: 'Write frameguard.yaml when missing.',
    );

  parser.addCommand('inspect')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  parser.addCommand('report')
    ..addOption(
      'format',
      allowed: ['text', 'json', 'html', 'markdown'],
      defaultsTo: 'text',
    )
    ..addOption('html', help: 'Also write HTML to this path.')
    ..addOption('out', help: 'Write output to this path.');

  void addCompareFlags(ArgParser c) {
    c
      ..addFlag(
        'require-matching-environment',
        negatable: false,
        help: 'Fail when environments differ.',
      )
      ..addOption(
        'format',
        allowed: ['text', 'json', 'markdown'],
        defaultsTo: 'text',
      )
      ..addOption('out', help: 'Write comparison output.');
  }

  addCompareFlags(parser.addCommand('compare'));
  addCompareFlags(parser.addCommand('diff'));

  parser.addCommand('check')
    ..addOption('baseline', help: 'Baseline JSON path or baselines/ dir.')
    ..addFlag(
      'require-matching-environment',
      negatable: false,
      help: 'Fail when environments differ.',
    )
    ..addFlag(
      'recursive',
      abbr: 'r',
      negatable: false,
      help: 'Recurse into directories.',
    )
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('profile', help: 'Built-in budget profile name to evaluate.')
    ..addFlag(
      'require-profile',
      negatable: false,
      help: 'Fail if --profile is omitted (CI safety).',
    )
    ..addFlag(
      'record-history',
      negatable: false,
      help: 'Append compact metrics to history/<scenario>.jsonl.',
    )
    ..addOption(
      'history-dir',
      defaultsTo: 'history',
      help: 'History directory.',
    );

  parser.addCommand('suggest-budget')
    ..addOption(
      'headroom',
      defaultsTo: '0.15',
      help: 'Relative headroom on percentile ceilings (e.g. 0.15 = +15%).',
    )
    ..addOption(
      'format',
      allowed: ['text', 'dart', 'yaml', 'json'],
      defaultsTo: 'text',
    )
    ..addOption('out', help: 'Write snippet to this path.');

  final history = parser.addCommand('history');
  history.addCommand('append')
    ..addOption(
      'dir',
      defaultsTo: 'history',
      help: 'History directory.',
    );
  history.addCommand('show')
    ..addOption(
      'dir',
      defaultsTo: 'history',
      help: 'History directory.',
    )
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('limit', help: 'Show only the last N entries.');
  history.addCommand('list')
    ..addOption(
      'dir',
      defaultsTo: 'history',
      help: 'History directory.',
    )
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  history.addCommand('drift')
    ..addOption(
      'dir',
      defaultsTo: 'history',
      help: 'History directory.',
    )
    ..addOption('threshold', defaultsTo: '0.20')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  history.addCommand('clear')
    ..addOption(
      'dir',
      defaultsTo: 'history',
      help: 'History directory.',
    )
    ..addFlag('all', negatable: false, help: 'Clear all scenario logs.');

  final baseline = parser.addCommand('baseline');
  baseline.addCommand('update')
    ..addFlag('force', negatable: false, help: 'Overwrite existing baseline.')
    ..addOption('out', help: 'Output baseline path.');
  baseline.addCommand('list')
    ..addOption('dir', defaultsTo: 'baselines', help: 'Baselines directory.')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  baseline.addCommand('show')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');

  parser.addCommand('merge')
    ..addOption('out', help: 'Write aggregate summary JSON.')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addFlag(
      'stats',
      negatable: false,
      help: 'Include statistical summary (median/MAD).',
    );

  parser.addCommand('export')
    ..addOption(
      'format',
      allowed: ['text', 'json', 'html', 'markdown', 'csv', 'junit', 'sarif'],
      defaultsTo: 'json',
    )
    ..addOption('out', help: 'Write output to this path.')
    ..addOption('baseline', help: 'Optional baseline for gated formats.');

  parser.addCommand('summary')
    ..addOption('format', allowed: ['text', 'markdown'], defaultsTo: 'text')
    ..addOption('out', help: 'Write summary to this path.');

  final config = parser.addCommand('config');
  config.addCommand('validate');
  config.addCommand('show')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');

  parser.addCommand('migrate')
    ..addOption('dir', defaultsTo: 'reports', help: 'Reports directory.')
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Report actions without writing.',
    );

  void addListFlags(ArgParser c) {
    c
      ..addOption('reports', defaultsTo: 'reports', help: 'Reports directory.')
      ..addOption(
        'baselines',
        defaultsTo: 'baselines',
        help: 'Baselines directory.',
      )
      ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
      ..addFlag('reports-only', negatable: false)
      ..addFlag('baselines-only', negatable: false);
  }

  addListFlags(parser.addCommand('list'));
  addListFlags(parser.addCommand('ls'));

  parser.addCommand('explain')
    ..addOption('format',
        allowed: ['text', 'json', 'markdown'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('frames')
    ..addOption('limit', defaultsTo: '15', help: 'Max frames to show.')
    ..addFlag('janky-only', negatable: false)
    ..addOption('format', allowed: ['text', 'json', 'csv'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('regions')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('tasks')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('stats')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('top')
    ..addOption('limit', defaultsTo: '10')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  parser.addCommand('histogram')
    ..addOption('width', defaultsTo: '40', help: 'ASCII bar width.')
    ..addOption('out');
  parser.addCommand('hist')
    ..addOption('width', defaultsTo: '40')
    ..addOption('out');
  parser.addCommand('validate')
    ..addFlag('recursive', abbr: 'r', negatable: false)
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  parser.addCommand('drift')
    ..addOption('threshold',
        defaultsTo: '0.20', help: 'Gradual regression threshold.')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text')
    ..addOption('out');
  parser.addCommand('profiles')
    ..addOption('format', allowed: ['text', 'json'], defaultsTo: 'text');
  parser.addCommand('artifacts')
    ..addOption('dir', defaultsTo: 'reports', help: 'Output directory.')
    ..addFlag('html', defaultsTo: true)
    ..addFlag('markdown', defaultsTo: true)
    ..addFlag('json', defaultsTo: true);
  parser.addCommand('batch')
    ..addOption(
      'format',
      allowed: ['junit', 'sarif', 'csv', 'markdown', 'json', 'text', 'html'],
      defaultsTo: 'junit',
    )
    ..addOption('out-dir', defaultsTo: 'reports/exports')
    ..addOption('baseline')
    ..addFlag('recursive', abbr: 'r', negatable: false)
    ..addFlag('check',
        negatable: false, help: 'Also run budget/baseline check.');
  parser.addCommand('watch')
    ..addOption('dir', defaultsTo: 'reports')
    ..addOption('baseline')
    ..addOption('interval', defaultsTo: '2', help: 'Poll seconds.')
    ..addOption('profile')
    ..addFlag(
      'once',
      negatable: false,
      help: 'Process existing files once and exit.',
    );
  parser.addCommand('completions')
    ..addOption(
      'shell',
      allowed: ['bash', 'zsh', 'powershell'],
      defaultsTo: 'bash',
    );

  return parser;
}

String _topUsage(ArgParser parser) => '''
FrameGuard CLI — local performance regression tooling

Usage:
  dart run frameguard <command> [arguments]
  dart run frameguard help [command]

Core:
  init          Scaffold reports/, baselines/, frameguard.yaml
  doctor        Local setup health checks
  version       Package + schema versions
  config        validate | show
  profiles      List built-in budget profiles

Reports:
  list (ls)     Inventory reports/ and baselines/
  inspect       Metadata + key metrics
  report        Render text/json/html/markdown
  explain       Findings, evidence, recommendations
  frames        Slowest / janky frames
  regions       Rebuild region stats
  tasks         Measured sync tasks
  stats         Full statistical dump
  top           Top offenders (frames + regions + tasks)
  histogram     ASCII frame-time histogram
  summary       One-liner or Markdown for CI / PRs
  validate      Schema validation (no budget gate)
  artifacts     Write JSON/HTML/Markdown bundle
  export        csv | junit | sarif | markdown | html | json | text
  batch         Export (and optionally check) many reports

Gates & history:
  check         CI gate (budget + optional baseline)
  suggest-budget Draft FrameBudget from a measured report
  compare/diff  Report↔report or baseline↔report
  merge         Aggregate multi-run reports
  drift         Gradual regression across baselines
  history       append | show | list | drift | clear
  baseline      update | list | show
  watch         Poll a directory and gate new reports

Shell:
  completions   Print bash/zsh/powershell completions
  help          Command help
  migrate       Re-encode reports to current package metadata

Global options:
${parser.usage}

Docs: https://theworker02.github.io/frameguard/cli.html
''';

int _help(ArgResults command, ArgParser parser) {
  if (command.rest.isEmpty) {
    stdout.writeln(_topUsage(parser));
    return FrameGuardExitCode.pass;
  }
  final name = command.rest.first;
  final sub = parser.commands[name];
  if (sub == null) {
    stderr.writeln('Unknown command: $name');
    return FrameGuardExitCode.invalid;
  }
  stdout.writeln('frameguard $name');
  stdout.writeln(sub.usage);
  return FrameGuardExitCode.pass;
}

int _version({required bool quiet}) {
  if (quiet) {
    stdout.writeln(frameGuardPackageVersion);
  } else {
    stdout.writeln('frameguard $frameGuardPackageVersion');
    stdout.writeln('report schema ${FrameGuardReport.currentSchemaVersion}');
    stdout
        .writeln('baseline schema ${FrameGuardBaseline.currentSchemaVersion}');
  }
  return FrameGuardExitCode.pass;
}

int _doctor(ArgResults command, {required bool quiet}) {
  final report = FrameGuardDoctor().run();
  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode({
        'ok': report.ok,
        'warningCount': report.warningCount,
        'checks': [
          for (final c in report.checks)
            {
              'name': c.name,
              'passed': c.passed,
              'warning': c.warning,
              'detail': c.detail,
            },
        ],
      }),
    );
  } else if (!quiet) {
    stdout.writeln(report.summary());
  }
  return report.ok ? FrameGuardExitCode.pass : FrameGuardExitCode.invalid;
}

Future<int> _init(ArgResults command, {required bool quiet}) async {
  final actions = await FrameGuardInit().run(
    writeYaml: command['yaml'] != false,
  );
  if (!quiet) {
    stdout.writeln('FrameGuard init');
    for (final a in actions) {
      stdout.writeln('  · $a');
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _inspect(
  ArgResults command, {
  required bool quiet,
  required bool verbose,
}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard inspect <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode({
        'scenario': report.scenario,
        'id': report.id,
        'frames': report.stats.totalFrames,
        'jankRate': report.stats.jankRate,
        'p50Ms': report.stats.p50.inMicroseconds / 1000.0,
        'p95Ms': report.stats.p95.inMicroseconds / 1000.0,
        'p99Ms': report.stats.p99.inMicroseconds / 1000.0,
        'maxMs': report.stats.max.inMicroseconds / 1000.0,
        'passed': report.passed,
        'score': report.score.toJson(),
        'device': report.device.toJson(),
        'diagnostics': [
          for (final d
              in report.explanation?.diagnostics ?? const <FrameDiagnostic>[])
            {'id': d.id, 'code': d.code},
        ],
      }),
    );
  } else if (!quiet) {
    stdout.writeln(report.summary());
    if (verbose) {
      stdout.writeln();
      stdout.writeln(report.stats.summary());
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _report(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard report <report.json> '
      '[--format text|json|html|markdown]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final format = command['format'] as String? ?? 'text';
  final htmlPath = command['html'] as String?;
  final outPath = command['out'] as String?;

  final output = switch (format) {
    'json' => report.toJsonString(),
    'html' => HtmlReportBuilder(report).build(),
    'markdown' => MarkdownReportBuilder(report).build(),
    _ => report.toText(),
  };

  if (htmlPath != null) {
    await File(htmlPath).writeAsString(HtmlReportBuilder(report).build());
    if (!quiet) stdout.writeln('Wrote HTML: $htmlPath');
  }
  if (outPath != null || htmlPath == null) {
    await CliIo.writeOut(output, out: outPath, quiet: quiet);
  }
  return FrameGuardExitCode.pass;
}

Future<int> _compare(ArgResults command, {required bool quiet}) async {
  if (command.rest.length < 2) {
    throw FrameGuardException(
      'Usage: dart run frameguard compare <a.json> <b.json>',
    );
  }
  final aPath = command.rest[0];
  final bPath = command.rest[1];
  final requireEnv = command['require-matching-environment'] == true;
  final aJson = jsonDecode(await File(aPath).readAsString()) as Map;
  final bReport = await CliIo.loadReport(bPath);

  final ComparisonResult result;
  if (aJson.containsKey('metrics') && aJson['schemaVersion'] != null) {
    final baseline =
        FrameGuardBaseline.fromJson(Map<String, Object?>.from(aJson));
    result = FrameGuardCompare(
      requireMatchingEnvironment: requireEnv,
    ).compareReportToBaseline(bReport, baseline);
  } else {
    final aReport = await CliIo.loadReport(aPath);
    result = FrameGuardCompare(
      requireMatchingEnvironment: requireEnv,
    ).compareReports(aReport, bReport);
  }

  final format = command['format'] as String? ?? 'text';
  final out = command['out'] as String?;
  late final String text;
  if (format == 'json') {
    text = const JsonEncoder.withIndent('  ').convert({
      'scenario': result.scenario,
      'isRegression': result.isRegression,
      'magnitude': result.magnitude.name,
      'passed': result.passed,
      'deltas': [
        for (final d in result.deltas)
          {
            'name': d.name,
            'baseline': d.baselineValue,
            'current': d.currentValue,
            'relativeChange': d.relativeChange,
            'regressed': d.regressed,
            'baselineLabel': d.baselineLabel,
            'currentLabel': d.currentLabel,
          },
      ],
    });
  } else if (format == 'markdown') {
    text = MarkdownReportBuilder(bReport, comparison: result).build();
  } else {
    text = result.summary();
  }

  if (!quiet || out != null) {
    await CliIo.writeOut(text, out: out, quiet: quiet);
  }

  return result.isRegression
      ? FrameGuardExitCode.regression
      : FrameGuardExitCode.pass;
}

Future<int> _check(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard check <report.json|dir> '
      '[--baseline path] [--profile mid_range] [--require-profile] '
      '[--record-history]',
    );
  }
  final loaded = await CliIo.loadReports(
    command.rest.first,
    recursive: command['recursive'] == true,
  );
  if (loaded.isEmpty) {
    throw FrameGuardException('No reports found at ${command.rest.first}');
  }

  final baselinePath = command['baseline'] as String?;
  final requireEnv = command['require-matching-environment'] == true;
  final requireProfile = command['require-profile'] == true;
  final recordHistory = command['record-history'] == true;
  final historyDir = command['history-dir'] as String? ?? 'history';
  final profileName = command['profile'] as String?;

  if (requireProfile && (profileName == null || profileName.isEmpty)) {
    throw FrameGuardException(
      '--require-profile was set but --profile was omitted.\n'
      'Pass an explicit profile (see: dart run frameguard profiles).',
    );
  }

  final profile =
      profileName == null ? null : BudgetProfile.byName(profileName);
  if (profileName != null && profile == null) {
    throw FrameGuardException(
      'Unknown budget profile: $profileName\n'
      'Try: dart run frameguard profiles',
    );
  }

  final history =
      recordHistory ? FrameGuardHistory(directory: historyDir) : null;

  var failed = false;
  final results = <Map<String, Object?>>[];

  for (final item in loaded) {
    final report = item.report;
    var itemFail = false;
    final messages = <String>[];

    if (profile != null) {
      final evaluation = report.evaluate(profile.budget);
      if (!evaluation.passed) {
        itemFail = true;
        messages.add(evaluation.summary());
      }
    } else if (report.budgetEvaluation != null &&
        !report.budgetEvaluation!.passed) {
      itemFail = true;
      messages.add(report.budgetEvaluation!.summary());
    }

    if (baselinePath != null) {
      final baselineEntity = FileSystemEntity.typeSync(baselinePath);
      FrameGuardBaseline? baseline;
      if (baselineEntity == FileSystemEntityType.directory) {
        final candidate = File(
          p.join(baselinePath, '${report.scenario}.json'),
        );
        if (candidate.existsSync()) {
          baseline = await FrameGuardBaseline.load(candidate);
        }
      } else {
        baseline = await CliIo.loadBaseline(baselinePath);
      }
      if (baseline != null) {
        final cmp = FrameGuardCompare(
          requireMatchingEnvironment: requireEnv,
        ).compareReportToBaseline(report, baseline);
        messages.add(cmp.summary());
        if (cmp.isRegression) itemFail = true;
      } else if (!quiet) {
        messages.add('No matching baseline for scenario ${report.scenario}');
      }
    }

    if (history != null) {
      await history.appendReport(report, sourcePath: item.path);
      messages.add('Recorded history → $historyDir/${report.scenario}.jsonl');
    }

    if (itemFail) failed = true;
    if (!quiet) {
      stdout.writeln('── ${CliIo.rel(item.path)} ──');
      if (messages.isEmpty) {
        stdout.writeln(report.summary());
      } else {
        for (final m in messages) {
          stdout.writeln(m);
        }
      }
      stdout.writeln(itemFail ? 'RESULT: FAIL' : 'RESULT: PASS');
      stdout.writeln();
    }
    results.add({
      'path': item.path,
      'scenario': report.scenario,
      'passed': !itemFail,
    });
  }

  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode({'failed': failed, 'results': results}),
    );
  }

  return failed ? FrameGuardExitCode.regression : FrameGuardExitCode.pass;
}

Future<int> _suggestBudget(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard suggest-budget <report.json> '
      '[--headroom 0.15] [--format text|dart|yaml|json]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final headroom =
      double.tryParse(command['headroom'] as String? ?? '0.15') ?? 0.15;
  final suggestion = BudgetSuggestion.fromReport(
    report,
    headroom: headroom,
  );
  final format = command['format'] as String? ?? 'text';
  late final String text;
  switch (format) {
    case 'dart':
      text = suggestion.toDartSnippet();
    case 'yaml':
      text = suggestion.toYamlSnippet();
    case 'json':
      text = const JsonEncoder.withIndent('  ').convert({
        'headroom': suggestion.headroom,
        'budget': suggestion.budget.toJson(),
        'rationale': suggestion.rationale,
      });
    default:
      text = suggestion.summary();
  }
  final out = command['out'] as String?;
  if (!quiet || out != null) {
    await CliIo.writeOut(text, out: out, quiet: quiet);
  }
  return FrameGuardExitCode.pass;
}

Future<int> _history(ArgResults command, {required bool quiet}) async {
  final sub = command.command;
  if (sub == null) {
    throw FrameGuardException(
      'Usage: dart run frameguard history <append|show|list|drift|clear> ...',
    );
  }
  final dir = (sub['dir'] as String?) ?? 'history';
  final store = FrameGuardHistory(directory: dir);

  switch (sub.name) {
    case 'append':
      if (sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard history append <report.json>',
        );
      }
      final report = await CliIo.loadReport(sub.rest.first);
      final file = await store.appendReport(
        report,
        sourcePath: sub.rest.first,
      );
      if (!quiet) {
        stdout.writeln('Appended ${report.scenario} → ${CliIo.rel(file.path)}');
      }
      return FrameGuardExitCode.pass;

    case 'list':
      final scenarios = store.listScenarios();
      if (sub['format'] == 'json') {
        stdout.writeln(jsonEncode({'scenarios': scenarios, 'dir': dir}));
      } else if (!quiet) {
        if (scenarios.isEmpty) {
          stdout.writeln('No history under $dir');
        } else {
          for (final s in scenarios) {
            final n = (await store.load(s)).length;
            stdout.writeln('${s.padRight(28)} $n entries');
          }
        }
      }
      return FrameGuardExitCode.pass;

    case 'show':
      if (sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard history show <scenario>',
        );
      }
      final scenario = sub.rest.first;
      var entries = await store.load(scenario);
      final limitRaw = sub['limit'] as String?;
      if (limitRaw != null) {
        final limit = int.tryParse(limitRaw);
        if (limit != null && limit > 0 && entries.length > limit) {
          entries = entries.sublist(entries.length - limit);
        }
      }
      if (sub['format'] == 'json') {
        stdout.writeln(
          jsonEncode({
            'scenario': scenario,
            'entries': [for (final e in entries) e.toJson()],
          }),
        );
      } else if (!quiet) {
        if (entries.isEmpty) {
          stdout.writeln('No history for $scenario');
        } else {
          stdout.writeln(
            'scenario=${scenario.padRight(20)} entries=${entries.length}',
          );
          for (final e in entries) {
            stdout.writeln(
              '${e.recordedAt.toIso8601String()}  '
              'p95=${e.p95Ms.toStringAsFixed(1)}ms  '
              'jank=${(e.jankRate * 100).toStringAsFixed(1)}%  '
              'frames=${e.totalFrames}  '
              'pass=${e.passed}',
            );
          }
        }
      }
      return FrameGuardExitCode.pass;

    case 'drift':
      if (sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard history drift <scenario>',
        );
      }
      final scenario = sub.rest.first;
      final threshold =
          double.tryParse(sub['threshold'] as String? ?? '0.20') ?? 0.20;
      final drift = await store.p95Drift(
        scenario,
        gradualThreshold: threshold,
      );
      if (sub['format'] == 'json') {
        stdout.writeln(
          jsonEncode({
            'scenario': scenario,
            'metric': drift.metric,
            'totalRelativeChange': drift.totalRelativeChange,
            'gradualRegression': drift.gradualRegression,
            'points': [
              for (final p in drift.points)
                {'label': p.label, 'value': p.value},
            ],
          }),
        );
      } else if (!quiet) {
        stdout.writeln(drift.summary());
      }
      return drift.gradualRegression
          ? FrameGuardExitCode.regression
          : FrameGuardExitCode.pass;

    case 'clear':
      final clearAll = sub['all'] == true;
      if (!clearAll && sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard history clear <scenario> | --all',
        );
      }
      final n = await store.clear(
        scenario: clearAll ? null : sub.rest.first,
      );
      if (!quiet) {
        stdout.writeln('Cleared $n history file(s) under $dir');
      }
      return FrameGuardExitCode.pass;

    default:
      throw FrameGuardException('Unknown history subcommand: ${sub.name}');
  }
}


Future<int> _baseline(ArgResults command, {required bool quiet}) async {
  final sub = command.command;
  if (sub == null) {
    throw FrameGuardException(
      'Usage: dart run frameguard baseline <update|list|show> ...',
    );
  }
  switch (sub.name) {
    case 'update':
      if (sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard baseline update <report.json> '
          '[--force] [--out path]',
        );
      }
      final report = await CliIo.loadReport(sub.rest.first);
      final force = sub['force'] == true;
      final out = sub['out'] as String? ??
          p.join('baselines', '${report.scenario}.json');
      final file = File(out);
      if (file.existsSync() && !force) {
        throw FrameGuardException(
          'Baseline already exists: $out\n'
          'Refusing to overwrite. Re-run with --force after review.',
        );
      }
      await file.parent.create(recursive: true);
      await FrameGuardBaseline.fromReport(report).write(file);
      if (!quiet) stdout.writeln('Updated baseline: $out');
      return FrameGuardExitCode.pass;
    case 'list':
      final dir = sub['dir'] as String? ?? 'baselines';
      final files = CliIo.listJsonFiles(dir);
      if (sub['format'] == 'json') {
        final rows = <Map<String, Object?>>[];
        for (final f in files) {
          try {
            final b = await FrameGuardBaseline.load(f);
            rows.add({
              'path': f.path,
              'scenario': b.scenario,
              'p95Ms': b.metrics.p95FrameMs,
              'jankRate': b.metrics.jankRate,
            });
          } catch (_) {}
        }
        stdout.writeln(jsonEncode(rows));
      } else if (!quiet) {
        if (files.isEmpty) {
          stdout.writeln('No baselines in $dir');
        } else {
          stdout.writeln(
            '${'SCENARIO'.padRight(28)} ${'P95'.padLeft(8)} '
            '${'JANK'.padLeft(8)}  PATH',
          );
          for (final f in files) {
            try {
              final b = await FrameGuardBaseline.load(f);
              stdout.writeln(
                '${b.scenario.padRight(28)} '
                '${b.metrics.p95FrameMs.toStringAsFixed(1).padLeft(8)} '
                '${CliIo.pct(b.metrics.jankRate).padLeft(8)}  '
                '${CliIo.rel(f.path)}',
              );
            } catch (_) {
              stdout
                  .writeln('${'(invalid)'.padRight(28)}  ${CliIo.rel(f.path)}');
            }
          }
        }
      }
      return FrameGuardExitCode.pass;
    case 'show':
      if (sub.rest.isEmpty) {
        throw FrameGuardException(
          'Usage: dart run frameguard baseline show <baseline.json>',
        );
      }
      final b = await CliIo.loadBaseline(sub.rest.first);
      if (sub['format'] == 'json') {
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert(b.toJson()),
        );
      } else if (!quiet) {
        stdout.writeln('Scenario: ${b.scenario}');
        stdout.writeln('Created:  ${b.createdAt ?? 'unknown'}');
        stdout
            .writeln('p50:      ${b.metrics.p50FrameMs.toStringAsFixed(1)} ms');
        stdout
            .writeln('p95:      ${b.metrics.p95FrameMs.toStringAsFixed(1)} ms');
        stdout
            .writeln('p99:      ${b.metrics.p99FrameMs.toStringAsFixed(1)} ms');
        stdout.writeln('jankRate: ${CliIo.pct(b.metrics.jankRate)}');
        stdout.writeln('janky:    ${b.metrics.jankyFrames}');
      }
      return FrameGuardExitCode.pass;
    default:
      throw FrameGuardException('Unknown baseline subcommand: ${sub.name}');
  }
}

Future<int> _merge(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard merge <report1.json> [report2.json ...]',
    );
  }
  final reports = [
    for (final path in command.rest) await CliIo.loadReport(path),
  ];
  final aggregate = FrameGuardAggregate.fromReports(reports);
  final out = command['out'] as String?;
  if (command['format'] == 'json') {
    final map = <String, Object?>{
      'runs': reports.length,
      'medianP95Ms': aggregate.medianP95.inMicroseconds / 1000.0,
      'medianP99Ms': aggregate.medianP99.inMicroseconds / 1000.0,
      'medianJankRate': aggregate.medianJankRate,
      'consistencyScore': aggregate.consistencyScore,
      'bestRunId': aggregate.bestRun.id,
      'worstRunId': aggregate.worstRun.id,
    };
    if (command['stats'] == true) {
      map['statistical'] = StatisticalSummary.fromReports(reports).toJson();
    }
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert(map),
      out: out,
      quiet: quiet,
    );
  } else if (!quiet) {
    stdout.writeln(aggregate.summary());
    if (command['stats'] == true) {
      final s = StatisticalSummary.fromReports(reports);
      stdout.writeln(
        'p95 stats: median=${s.medianP95Ms.toStringAsFixed(1)} '
        'mad=${s.madP95Ms.toStringAsFixed(1)} '
        'mean=${s.meanP95Ms.toStringAsFixed(1)}',
      );
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _export(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard export <report.json> --format <fmt> [--out path]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final formatName = command['format'] as String? ?? 'json';
  final format = ReportExportFormat.values.firstWhere(
    (f) => f.name == formatName,
    orElse: () => ReportExportFormat.json,
  );
  ComparisonResult? comparison;
  final baselinePath = command['baseline'] as String?;
  if (baselinePath != null) {
    final baseline = await CliIo.loadBaseline(baselinePath);
    comparison = const FrameGuardCompare().compareReportToBaseline(
      report,
      baseline,
    );
  }
  final output = ReportExporter(report, comparison: comparison).export(format);
  await CliIo.writeOut(
    output,
    out: command['out'] as String?,
    quiet: quiet,
    wroteLabel: 'Wrote $formatName: ${command['out']}',
  );
  return FrameGuardExitCode.pass;
}

Future<int> _summary(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard summary <report.json> [--format text|markdown]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final md = MarkdownReportBuilder(report);
  final text = command['format'] == 'markdown' ? md.build() : md.oneLiner();
  await CliIo.writeOut(
    text,
    out: command['out'] as String?,
    quiet: quiet && command['out'] == null,
  );
  return FrameGuardExitCode.pass;
}

Future<int> _config(ArgResults command, {required bool quiet}) async {
  final sub = command.command;
  if (sub == null) {
    throw FrameGuardException(
      'Usage: dart run frameguard config <validate|show> [frameguard.yaml]',
    );
  }
  final path = sub.rest.isEmpty ? 'frameguard.yaml' : sub.rest.first;
  final file = File(path);
  if (!file.existsSync()) {
    throw FrameGuardException(
      'Config file not found: $path\n'
      'Run: dart run frameguard init',
    );
  }
  final config = FrameGuardConfigLoader.fromYaml(await file.readAsString());
  if (sub.name == 'validate') {
    if (!quiet) {
      stdout.writeln('OK: $path');
      stdout.writeln('sampling_mode: ${config.samplingMode.name}');
      stdout.writeln(
        'refresh_rate: ${config.refreshRate.runtimeType} '
        '(fallback ${config.refreshRateFallbackHz} Hz)',
      );
      stdout.writeln('profiles: ${config.profiles.keys.join(', ')}');
      if (config.defaultBudget != null) {
        stdout.writeln('default budget: ${config.defaultBudget!.toJson()}');
      }
    }
    return FrameGuardExitCode.pass;
  }
  if (sub.name == 'show') {
    if (sub['format'] == 'json') {
      stdout.writeln(
        jsonEncode({
          'path': path,
          'samplingMode': config.samplingMode.name,
          'refreshRateFallbackHz': config.refreshRateFallbackHz,
          'profiles': config.profiles.keys.toList(),
          'defaultBudget': config.defaultBudget?.toJson(),
        }),
      );
    } else if (!quiet) {
      stdout.writeln(file.readAsStringSync());
    }
    return FrameGuardExitCode.pass;
  }
  throw FrameGuardException('Unknown config subcommand: ${sub.name}');
}

Future<int> _migrate(ArgResults command, {required bool quiet}) async {
  final dir = command['dir'] as String? ?? 'reports';
  final dryRun = command['dry-run'] == true;
  final files = CliIo.listJsonFiles(dir);
  if (files.isEmpty) {
    if (!quiet) {
      stdout.writeln('No reports under $dir');
    }
    return FrameGuardExitCode.pass;
  }

  var rewritten = 0;
  var skipped = 0;
  for (final file in files) {
    try {
      final report = await CliIo.loadReport(file.path);
      if (report.frameguardVersion == frameGuardPackageVersion &&
          report.schemaVersion == FrameGuardReport.currentSchemaVersion) {
        skipped++;
        continue;
      }
      if (!dryRun) {
        final updated = report.copyWith(
          frameguardVersion: frameGuardPackageVersion,
          schemaVersion: FrameGuardReport.currentSchemaVersion,
        );
        await updated.writeJson(file);
      }
      rewritten++;
      if (!quiet) {
        stdout.writeln(
          '${dryRun ? 'would rewrite' : 'rewrote'} ${CliIo.rel(file.path)}',
        );
      }
    } on FrameGuardException catch (e) {
      skipped++;
      if (!quiet) {
        stderr.writeln('skip ${CliIo.rel(file.path)}: $e');
      }
    }
  }

  if (!quiet) {
    stdout.writeln(
      'migrate: ${dryRun ? 'would rewrite' : 'rewrote'} $rewritten, '
      'skipped $skipped '
      '(schema ${FrameGuardReport.currentSchemaVersion}, '
      'package $frameGuardPackageVersion)',
    );
  }
  return FrameGuardExitCode.pass;
}

Future<int> _list(ArgResults command, {required bool quiet}) async {
  final reportsDir = command['reports'] as String? ?? 'reports';
  final baselinesDir = command['baselines'] as String? ?? 'baselines';
  final reportsOnly = command['reports-only'] == true;
  final baselinesOnly = command['baselines-only'] == true;
  final asJson = command['format'] == 'json';

  final reportRows = <Map<String, Object?>>[];
  final baselineRows = <Map<String, Object?>>[];

  if (!baselinesOnly) {
    for (final f in CliIo.listJsonFiles(reportsDir)) {
      try {
        final r = await CliIo.loadReport(f.path);
        reportRows.add({
          'path': CliIo.rel(f.path),
          'scenario': r.scenario,
          'frames': r.stats.totalFrames,
          'p95Ms': r.stats.p95.inMicroseconds / 1000.0,
          'jankRate': r.stats.jankRate,
          'passed': r.passed,
        });
      } catch (_) {
        reportRows.add({'path': CliIo.rel(f.path), 'error': true});
      }
    }
  }
  if (!reportsOnly) {
    for (final f in CliIo.listJsonFiles(baselinesDir)) {
      try {
        final b = await FrameGuardBaseline.load(f);
        baselineRows.add({
          'path': CliIo.rel(f.path),
          'scenario': b.scenario,
          'p95Ms': b.metrics.p95FrameMs,
          'jankRate': b.metrics.jankRate,
        });
      } catch (_) {
        baselineRows.add({'path': CliIo.rel(f.path), 'error': true});
      }
    }
  }

  if (asJson) {
    stdout.writeln(
      jsonEncode({'reports': reportRows, 'baselines': baselineRows}),
    );
    return FrameGuardExitCode.pass;
  }
  if (quiet) return FrameGuardExitCode.pass;

  if (!baselinesOnly) {
    stdout.writeln('Reports ($reportsDir)');
    if (reportRows.isEmpty) {
      stdout.writeln('  (none)');
    } else {
      for (final r in reportRows) {
        if (r['error'] == true) {
          stdout.writeln('  ! ${r['path']}');
          continue;
        }
        final pass = r['passed'] == true ? 'PASS' : 'FAIL';
        stdout.writeln(
          '  ${r['scenario']}  p95=${(r['p95Ms'] as double).toStringAsFixed(1)}ms  '
          'jank=${CliIo.pct(r['jankRate'] as double)}  $pass  ${r['path']}',
        );
      }
    }
    stdout.writeln();
  }
  if (!reportsOnly) {
    stdout.writeln('Baselines ($baselinesDir)');
    if (baselineRows.isEmpty) {
      stdout.writeln('  (none)');
    } else {
      for (final b in baselineRows) {
        if (b['error'] == true) {
          stdout.writeln('  ! ${b['path']}');
          continue;
        }
        stdout.writeln(
          '  ${b['scenario']}  p95=${(b['p95Ms'] as double).toStringAsFixed(1)}ms  '
          'jank=${CliIo.pct(b['jankRate'] as double)}  ${b['path']}',
        );
      }
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _explain(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard explain <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final explanation =
      report.explanation ?? ScenarioExplanation.fromReport(report);
  final format = command['format'] as String? ?? 'text';
  if (format == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert(explanation.toJson()),
      out: command['out'] as String?,
      quiet: quiet,
    );
    return FrameGuardExitCode.pass;
  }
  if (format == 'markdown') {
    await CliIo.writeOut(
      MarkdownReportBuilder(
        report.copyWith(explanation: explanation),
      ).build(),
      out: command['out'] as String?,
      quiet: quiet,
    );
    return FrameGuardExitCode.pass;
  }
  final buf = StringBuffer();
  buf.writeln('PRIMARY: ${explanation.primaryFinding}');
  buf.writeln();
  buf.writeln('Evidence');
  for (final e in explanation.evidence) {
    buf.writeln('  · $e');
  }
  if (explanation.diagnostics.isNotEmpty) {
    buf.writeln();
    buf.writeln('Diagnostics');
    for (final d in explanation.diagnostics) {
      buf.writeln('  · ${d.id} ${d.code}');
    }
  }
  if (explanation.recommendations.isNotEmpty) {
    buf.writeln();
    buf.writeln('Recommendations');
    for (final r in explanation.recommendations) {
      for (final s in r.suggestions) {
        buf.writeln('  · $s');
      }
    }
  }
  await CliIo.writeOut(
    buf.toString().trimRight(),
    out: command['out'] as String?,
    quiet: quiet,
  );
  return FrameGuardExitCode.pass;
}

Future<int> _frames(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard frames <report.json> [--limit 15] [--janky-only]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final limit = int.tryParse(command['limit'] as String? ?? '15') ?? 15;
  final jankyOnly = command['janky-only'] == true;
  var frames = [...report.frames]
    ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
  if (jankyOnly) {
    frames = frames.where((f) => f.janky).toList();
  }
  frames = frames.take(limit).toList();

  final format = command['format'] as String? ?? 'text';
  if (format == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert([
        for (final f in frames) f.toJson(),
      ]),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else if (format == 'csv') {
    final buf = StringBuffer(
        'frame,total_ms,build_ms,raster_ms,severity,bottleneck,janky\n');
    for (final f in frames) {
      buf.writeln(
        '${f.frameNumber},${CliIo.ms(f.totalDuration)},${CliIo.ms(f.buildDuration)},'
        '${CliIo.ms(f.rasterDuration)},${f.severity.name},${f.bottleneck.name},${f.janky}',
      );
    }
    await CliIo.writeOut(
      buf.toString(),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else if (!quiet || command['out'] != null) {
    final buf = StringBuffer(
      '${'#'.padLeft(5)} ${'TOTAL'.padLeft(8)} ${'BUILD'.padLeft(8)} '
      '${'RASTER'.padLeft(8)}  SEV        BOTTLENECK\n',
    );
    for (final f in frames) {
      buf.writeln(
        '${f.frameNumber.toString().padLeft(5)} '
        '${CliIo.ms(f.totalDuration).padLeft(8)} '
        '${CliIo.ms(f.buildDuration).padLeft(8)} '
        '${CliIo.ms(f.rasterDuration).padLeft(8)}  '
        '${f.severity.name.padRight(10)} ${f.bottleneck.name}',
      );
    }
    await CliIo.writeOut(
      buf.toString().trimRight(),
      out: command['out'] as String?,
      quiet: quiet,
    );
  }
  return FrameGuardExitCode.pass;
}

Future<int> _regions(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard regions <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  if (command['format'] == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert([
        for (final r in report.regions)
          {
            'name': r.name,
            'rebuilds': r.rebuilds,
            'framesObserved': r.framesObserved,
            'averageRebuildsPerFrame': r.averageRebuildsPerFrame,
            'peakRebuildsInFrame': r.peakRebuildsInFrame,
          },
      ]),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else if (!quiet || command['out'] != null) {
    if (report.regions.isEmpty) {
      await CliIo.writeOut(
        'No regions recorded.',
        out: command['out'] as String?,
        quiet: quiet,
      );
    } else {
      final buf = StringBuffer();
      for (final r in report.regions) {
        buf.writeln(r.summary());
        buf.writeln();
      }
      await CliIo.writeOut(
        buf.toString().trimRight(),
        out: command['out'] as String?,
        quiet: quiet,
      );
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _tasks(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard tasks <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  if (command['format'] == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert([
        for (final t in report.tasks) t.toJson(),
      ]),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else if (!quiet || command['out'] != null) {
    if (report.tasks.isEmpty) {
      await CliIo.writeOut(
        'No tasks recorded.',
        out: command['out'] as String?,
        quiet: quiet,
      );
    } else {
      final buf = StringBuffer();
      for (final t in report.tasks) {
        buf.writeln(
          '${t.name}  ${CliIo.ms(t.duration)} ms  '
          'exceeded=${t.exceededBudget}  slowFrames=${t.overlappingSlowFrames}',
        );
      }
      await CliIo.writeOut(
        buf.toString().trimRight(),
        out: command['out'] as String?,
        quiet: quiet,
      );
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _stats(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard stats <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  if (command['format'] == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert({
        'stats': report.stats.toJson(),
        'score': report.score.toJson(),
        'budgetEvaluation': report.budgetEvaluation?.toJson(),
      }),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else {
    final buf = StringBuffer()
      ..writeln(report.stats.summary())
      ..writeln()
      ..writeln('Score: ${report.score.toJson()}');
    if (report.budgetEvaluation != null) {
      buf
        ..writeln()
        ..writeln(report.budgetEvaluation!.summary());
    }
    await CliIo.writeOut(
      buf.toString().trimRight(),
      out: command['out'] as String?,
      quiet: quiet,
    );
  }
  return FrameGuardExitCode.pass;
}

Future<int> _top(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard top <report.json> [--limit 10]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final limit = int.tryParse(command['limit'] as String? ?? '10') ?? 10;
  final frames = report.slowestFrames(count: limit);
  final regions = [...report.regions]
    ..sort((a, b) => b.peakRebuildsInFrame.compareTo(a.peakRebuildsInFrame));
  final tasks = [...report.tasks]
    ..sort((a, b) => b.duration.compareTo(a.duration));

  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode({
        'frames': [for (final f in frames) f.toJson()],
        'regions': [
          for (final r in regions.take(limit))
            {'name': r.name, 'peak': r.peakRebuildsInFrame},
        ],
        'tasks': [for (final t in tasks.take(limit)) t.toJson()],
      }),
    );
    return FrameGuardExitCode.pass;
  }
  if (quiet) return FrameGuardExitCode.pass;

  stdout.writeln('Top frames');
  for (final f in frames) {
    stdout.writeln(
      '  #${f.frameNumber}  ${CliIo.ms(f.totalDuration)} ms  '
      '${f.bottleneck.name}  ${f.severity.name}',
    );
  }
  stdout.writeln('Top regions');
  if (regions.isEmpty) {
    stdout.writeln('  (none)');
  } else {
    for (final r in regions.take(limit)) {
      stdout.writeln(
        '  ${r.name}  peak=${r.peakRebuildsInFrame}  rebuilds=${r.rebuilds}',
      );
    }
  }
  stdout.writeln('Top tasks');
  if (tasks.isEmpty) {
    stdout.writeln('  (none)');
  } else {
    for (final t in tasks.take(limit)) {
      stdout.writeln('  ${t.name}  ${CliIo.ms(t.duration)} ms');
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _histogram(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard histogram <report.json>',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final width = int.tryParse(command['width'] as String? ?? '40') ?? 40;
  await CliIo.writeOut(
    report.stats.histogram.toAscii(width: width),
    out: command['out'] as String?,
    quiet: quiet,
  );
  return FrameGuardExitCode.pass;
}

Future<int> _validate(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard validate <report.json|dir>',
    );
  }
  final target = command.rest.first;
  final entity = FileSystemEntity.typeSync(target);
  final files = <File>[];
  if (entity == FileSystemEntityType.directory) {
    final loaded = await CliIo.loadReports(
      target,
      recursive: command['recursive'] == true,
    );
    // loadReports already validates; rebuild file list from success
    if (command['format'] == 'json') {
      stdout.writeln(
        jsonEncode({
          'valid': loaded.length,
          'paths': [for (final i in loaded) i.path],
        }),
      );
    } else if (!quiet) {
      stdout.writeln('OK: ${loaded.length} report(s)');
      for (final i in loaded) {
        stdout.writeln('  · ${CliIo.rel(i.path)} (${i.report.scenario})');
      }
    }
    return FrameGuardExitCode.pass;
  }
  files.add(File(target));
  final report = await CliIo.loadReport(target);
  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode({
        'valid': true,
        'scenario': report.scenario,
        'schemaVersion': report.schemaVersion,
        'frames': report.stats.totalFrames,
      }),
    );
  } else if (!quiet) {
    stdout.writeln(
      'OK: ${CliIo.rel(target)}  scenario=${report.scenario}  '
      'frames=${report.stats.totalFrames}  schema=${report.schemaVersion}',
    );
  }
  return FrameGuardExitCode.pass;
}

Future<int> _drift(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard drift <baseline1.json> [baseline2.json ...]\n'
      '   or: dart run frameguard drift baselines/',
    );
  }
  final paths = <String>[];
  if (command.rest.length == 1 &&
      FileSystemEntity.typeSync(command.rest.first) ==
          FileSystemEntityType.directory) {
    paths.addAll(CliIo.listJsonFiles(command.rest.first).map((f) => f.path));
  } else {
    paths.addAll(command.rest);
  }
  if (paths.length < 2) {
    throw FrameGuardException('Drift requires at least 2 baselines.');
  }
  final baselines = [
    for (final path in paths) await CliIo.loadBaseline(path),
  ];
  final threshold =
      double.tryParse(command['threshold'] as String? ?? '0.20') ?? 0.20;
  final drift = BaselineDrift.p95(baselines, gradualThreshold: threshold);

  if (command['format'] == 'json') {
    await CliIo.writeOut(
      const JsonEncoder.withIndent('  ').convert({
        'metric': drift.metric,
        'totalRelativeChange': drift.totalRelativeChange,
        'gradualRegression': drift.gradualRegression,
        'points': [
          for (final p in drift.points) {'label': p.label, 'value': p.value},
        ],
      }),
      out: command['out'] as String?,
      quiet: quiet,
    );
  } else {
    final buf = StringBuffer()
      ..writeln('Drift (${drift.metric})')
      ..writeln(
        'Total Δ: ${(drift.totalRelativeChange * 100).toStringAsFixed(1)}%',
      )
      ..writeln(
        'Gradual regression: ${drift.gradualRegression ? 'YES' : 'no'}',
      );
    for (final p in drift.points) {
      buf.writeln('  · ${p.label}: ${p.value.toStringAsFixed(1)} ms');
    }
    await CliIo.writeOut(
      buf.toString().trimRight(),
      out: command['out'] as String?,
      quiet: quiet,
    );
  }
  return drift.gradualRegression
      ? FrameGuardExitCode.regression
      : FrameGuardExitCode.pass;
}

int _profiles(ArgResults command, {required bool quiet}) {
  final profiles = BudgetProfile.builtins;
  if (command['format'] == 'json') {
    stdout.writeln(
      jsonEncode([
        for (final p in profiles)
          {
            'name': p.name,
            'description': p.description,
            'budget': p.budget.toJson(),
          },
      ]),
    );
  } else if (!quiet) {
    for (final p in profiles) {
      stdout.writeln('${p.name}');
      if (p.description != null) stdout.writeln('  ${p.description}');
      stdout.writeln('  budget: ${p.budget.toJson()}');
      stdout.writeln();
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _artifacts(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard artifacts <report.json> [--dir reports]',
    );
  }
  final report = await CliIo.loadReport(command.rest.first);
  final dir = Directory(command['dir'] as String? ?? 'reports');
  final arts = await report.writeArtifacts(
    dir,
    json: command['json'] != false,
    html: command['html'] != false,
    markdown: command['markdown'] != false,
  );
  if (!quiet) {
    stdout.writeln('Artifacts for ${report.scenario}');
    if (arts.json != null) stdout.writeln('  json:      ${arts.json!.path}');
    if (arts.html != null) stdout.writeln('  html:      ${arts.html!.path}');
    if (arts.markdown != null) {
      stdout.writeln('  markdown:  ${arts.markdown!.path}');
    }
  }
  return FrameGuardExitCode.pass;
}

Future<int> _batch(ArgResults command, {required bool quiet}) async {
  if (command.rest.isEmpty) {
    throw FrameGuardException(
      'Usage: dart run frameguard batch <reports-dir|files...> '
      '[--format junit] [--out-dir reports/exports]',
    );
  }
  final formatName = command['format'] as String? ?? 'junit';
  final format = ReportExportFormat.values.firstWhere(
    (f) => f.name == formatName,
    orElse: () => ReportExportFormat.junit,
  );
  final outDir = Directory(command['out-dir'] as String? ?? 'reports/exports');
  await outDir.create(recursive: true);

  final items = <({String path, FrameGuardReport report})>[];
  for (final target in command.rest) {
    items.addAll(
      await CliIo.loadReports(
        target,
        recursive: command['recursive'] == true,
      ),
    );
  }
  if (items.isEmpty) {
    throw FrameGuardException('No reports found for batch export.');
  }

  ComparisonResult? Function(FrameGuardReport)? cmpFor;
  final baselinePath = command['baseline'] as String?;
  if (baselinePath != null) {
    final baseline = await CliIo.loadBaseline(baselinePath);
    cmpFor =
        (r) => const FrameGuardCompare().compareReportToBaseline(r, baseline);
  }

  var failed = false;
  for (final item in items) {
    final comparison = cmpFor?.call(item.report);
    final body = ReportExporter(
      item.report,
      comparison: comparison,
    ).export(format);
    final out = File(
      p.join(outDir.path, '${item.report.scenario}.$formatName'),
    );
    await out.writeAsString(body);
    if (!quiet) stdout.writeln('Wrote ${CliIo.rel(out.path)}');

    if (command['check'] == true) {
      final budgetFail = item.report.budgetEvaluation != null &&
          !item.report.budgetEvaluation!.passed;
      final regressed = comparison?.isRegression ?? false;
      if (budgetFail || regressed) failed = true;
    }
  }

  return failed ? FrameGuardExitCode.regression : FrameGuardExitCode.pass;
}

Future<int> _watch(
  ArgResults command, {
  required bool quiet,
  required bool verbose,
}) async {
  final dirPath = command['dir'] as String? ?? 'reports';
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final interval =
      ((double.tryParse(command['interval'] as String? ?? '2') ?? 2) * 1000)
          .round()
          .clamp(250, 60000);
  final baselinePath = command['baseline'] as String?;
  final profileName = command['profile'] as String?;
  final profile =
      profileName == null ? null : BudgetProfile.byName(profileName);
  final seen = <String, DateTime>{};

  Future<int> processFile(File file) async {
    try {
      final report = await CliIo.loadReport(file.path);
      var fail = false;
      if (profile != null) {
        final ev = report.evaluate(profile.budget);
        if (!ev.passed) fail = true;
        if (!quiet) stdout.writeln(ev.summary());
      } else if (report.budgetEvaluation != null &&
          !report.budgetEvaluation!.passed) {
        fail = true;
        if (!quiet) stdout.writeln(report.budgetEvaluation!.summary());
      }
      if (baselinePath != null) {
        final baseline = await CliIo.loadBaseline(baselinePath);
        final cmp =
            const FrameGuardCompare().compareReportToBaseline(report, baseline);
        if (!quiet) stdout.writeln(cmp.summary());
        if (cmp.isRegression) fail = true;
      }
      if (!quiet) {
        stdout.writeln(
          '${fail ? 'FAIL' : 'PASS'}  ${CliIo.rel(file.path)}  '
          '${MarkdownReportBuilder(report).oneLiner()}',
        );
      }
      return fail ? FrameGuardExitCode.regression : FrameGuardExitCode.pass;
    } catch (e) {
      if (verbose) stderr.writeln('watch skip ${file.path}: $e');
      return FrameGuardExitCode.pass;
    }
  }

  // Seed + optional once mode.
  var exitCode = FrameGuardExitCode.pass;
  for (final f in CliIo.listJsonFiles(dirPath)) {
    seen[f.path] = f.lastModifiedSync();
    if (command['once'] == true) {
      final code = await processFile(f);
      if (code != FrameGuardExitCode.pass) exitCode = code;
    }
  }
  if (command['once'] == true) return exitCode;

  if (!quiet) {
    stdout.writeln(
      'Watching $dirPath every ${interval}ms  (Ctrl+C to stop)',
    );
  }
  while (true) {
    await Future<void>.delayed(Duration(milliseconds: interval));
    for (final f in CliIo.listJsonFiles(dirPath)) {
      final mod = f.lastModifiedSync();
      final prev = seen[f.path];
      if (prev == null || mod.isAfter(prev)) {
        seen[f.path] = mod;
        await processFile(f);
      }
    }
  }
}

int _completions(ArgResults command) {
  final shell = command['shell'] as String? ?? 'bash';
  const commands = [
    'help',
    'version',
    'doctor',
    'init',
    'inspect',
    'report',
    'compare',
    'diff',
    'check',
    'suggest-budget',
    'history',
    'baseline',
    'merge',
    'export',
    'summary',
    'config',
    'migrate',
    'list',
    'ls',
    'explain',
    'frames',
    'regions',
    'tasks',
    'stats',
    'top',
    'histogram',
    'hist',
    'validate',
    'drift',
    'profiles',
    'artifacts',
    'batch',
    'watch',
    'completions',
  ];
  switch (shell) {
    case 'zsh':
      stdout.writeln('#compdef frameguard');
      stdout.writeln(
        'compctl -k "(${commands.join(' ')})" frameguard',
      );
    case 'powershell':
      stdout.writeln(
        'Register-ArgumentCompleter -CommandName frameguard -ScriptBlock {',
      );
      stdout.writeln(
        "  param(\$wordToComplete); @('${commands.join("','")}') |",
      );
      stdout.writeln(
        '    Where-Object { \$_ -like "\$wordToComplete*" } | ForEach-Object { \$_ }',
      );
      stdout.writeln('}');
    default:
      stdout.writeln('_frameguard_completions() {');
      stdout.writeln(
        "  local cmds='${commands.join(' ')}'",
      );
      stdout.writeln(
        r'  COMPREPLY=($(compgen -W "$cmds" -- "${COMP_WORDS[1]}"))',
      );
      stdout.writeln('}');
      stdout.writeln('complete -F _frameguard_completions frameguard');
      stdout.writeln('complete -F _frameguard_completions dart');
  }
  return FrameGuardExitCode.pass;
}
