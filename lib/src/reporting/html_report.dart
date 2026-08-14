import 'package:frameguard/src/reporting/report.dart';

/// Builds a static, self-contained HTML report (no backend).
class HtmlReportBuilder {
  /// Creates a builder.
  HtmlReportBuilder(this.report);

  /// Source report.
  final FrameGuardReport report;

  /// Returns HTML document string.
  String build() {
    final r = report;
    final histBars = _histogramSvg();
    final regionRows = r.regions.map((reg) {
      return '<tr>'
          '<td>${_esc(reg.name)}</td>'
          '<td>${reg.rebuilds}</td>'
          '<td>${reg.averageRebuildsPerFrame.toStringAsFixed(2)}</td>'
          '<td>${reg.peakRebuildsInFrame}</td>'
          '</tr>';
    }).join();

    final budgetRows = (r.budgetEvaluation?.checks ?? const []).map((c) {
      final cls = c.passed ? 'pass' : 'fail';
      return '<tr class="$cls"><td>${_esc(c.name)}</td>'
          '<td>${c.passed ? 'PASS' : 'FAIL'}</td>'
          '<td>${_esc(c.actual)}</td><td>${_esc(c.limit)}</td></tr>';
    }).join();

    final slowRows = r.slowestFrames().map((f) {
      return '<tr><td>${f.frameNumber}</td>'
          '<td>${(f.totalDuration.inMicroseconds / 1000).toStringAsFixed(1)}</td>'
          '<td>${(f.buildDuration.inMicroseconds / 1000).toStringAsFixed(1)}</td>'
          '<td>${(f.rasterDuration.inMicroseconds / 1000).toStringAsFixed(1)}</td>'
          '<td>${f.bottleneck.name}</td>'
          '<td>${f.severity.name}</td></tr>';
    }).join();

    final evidence = (r.explanation?.evidence ?? const [])
        .map((e) => '<li>${_esc(e)}</li>')
        .join();
    final tips = (r.explanation?.recommendations ?? const [])
        .expand((rec) => rec.suggestions)
        .map((t) => '<li>${_esc(t)}</li>')
        .join();

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>FrameGuard — ${_esc(r.scenario)}</title>
<style>
  :root {
    --bg:#F4F6F5; --ink:#1A3A3A; --muted:#5C6B6B; --pass:#2F6F4E;
    --fail:#C45C26; --line:#D5DDD9; --paper:#ffffff; --slate:#2F4F4F;
  }
  body { margin:0; font:15px/1.5 "Segoe UI", system-ui, sans-serif; background:var(--bg); color:var(--ink); }
  main { max-width:960px; margin:0 auto; padding:2rem 1.25rem 4rem; }
  h1 { font-size:1.75rem; margin:0 0 .25rem; letter-spacing:-0.02em; color:var(--ink); }
  h2 { font-size:1.1rem; margin:2rem 0 .75rem; border-bottom:1px solid var(--line); padding-bottom:.35rem; color:var(--slate); }
  .meta { color:var(--muted); margin-bottom:1.5rem; }
  .badge { display:inline-block; padding:.25rem .65rem; font-weight:600; border:1px solid var(--line); border-radius:2px; }
  .badge.pass { color:var(--pass); border-color:var(--pass); } .badge.fail { color:var(--fail); border-color:var(--fail); }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(140px,1fr)); gap:1rem; }
  .metric { background:var(--paper); border:1px solid var(--line); padding:.85rem 1rem; }
  .metric strong { display:block; font-size:1.35rem; color:var(--ink); }
  table { width:100%; border-collapse:collapse; font-size:.92rem; background:var(--paper); }
  th, td { text-align:left; padding:.45rem .5rem; border-bottom:1px solid var(--line); }
  tr.fail td { color:var(--fail); }
  tr.pass td { color:var(--pass); }
  svg { width:100%; height:auto; background:var(--paper); border:1px solid var(--line); }
  ul { padding-left:1.2rem; }
  .warn { background:#FBF0E8; border:1px solid #E8C4A8; padding:.75rem 1rem; margin:1rem 0; color:var(--ink); }
  footer { margin-top:2.5rem; color:var(--muted); font-size:.85rem; }
</style>
</head>
<body>
<main>
  <h1>FrameGuard</h1>
  <p class="meta">Scenario: <strong>${_esc(r.scenario)}</strong> · ${_esc(r.device.summary())}</p>
  <p><span class="badge ${r.passed ? 'pass' : 'fail'}">${r.passed ? 'PASS' : 'FAIL'}</span></p>
  ${r.debugModeWarning != null ? '<div class="warn">${_esc(r.debugModeWarning!)}</div>' : ''}

  <h2>Summary</h2>
  <div class="grid">
    <div class="metric"><span>Frames</span><strong>${r.stats.totalFrames}</strong></div>
    <div class="metric"><span>Jank</span><strong>${r.stats.jankyFrames} (${(r.stats.jankRate * 100).toStringAsFixed(1)}%)</strong></div>
    <div class="metric"><span>P95</span><strong>${(r.stats.p95.inMicroseconds / 1000).toStringAsFixed(1)} ms</strong></div>
    <div class="metric"><span>P99</span><strong>${(r.stats.p99.inMicroseconds / 1000).toStringAsFixed(1)} ms</strong></div>
    <div class="metric"><span>Worst</span><strong>${(r.stats.max.inMicroseconds / 1000).toStringAsFixed(1)} ms</strong></div>
    <div class="metric"><span>Score</span><strong>${r.score.total}/100</strong></div>
  </div>

  <h2>Frame histogram</h2>
  $histBars

  <h2>Slowest frames</h2>
  <table>
    <thead><tr><th>#</th><th>Total ms</th><th>Build</th><th>Raster</th><th>Bottleneck</th><th>Severity</th></tr></thead>
    <tbody>$slowRows</tbody>
  </table>

  <h2>Build vs raster</h2>
  <p>Build-bound: ${r.stats.buildBoundFrames} · Raster-bound: ${r.stats.rasterBoundFrames} · Mixed: ${r.stats.mixedFrames}</p>

  <h2>Region rebuilds</h2>
  <table>
    <thead><tr><th>Region</th><th>Rebuilds</th><th>/frame</th><th>Peak</th></tr></thead>
    <tbody>$regionRows</tbody>
  </table>

  <h2>Budget</h2>
  <table>
    <thead><tr><th>Check</th><th>Result</th><th>Actual</th><th>Limit</th></tr></thead>
    <tbody>$budgetRows</tbody>
  </table>

  <h2>Explanation</h2>
  <p><strong>${_esc(r.explanation?.primaryFinding ?? 'n/a')}</strong></p>
  <ul>$evidence</ul>
  <h2>Recommendations</h2>
  <ul>$tips</ul>

  <p class="meta">schema v${r.schemaVersion} · FrameGuard ${r.frameguardVersion} · generated locally</p>
</main>
</body>
</html>''';
  }

  String _histogramSvg() {
    final h = report.stats.histogram;
    if (h.counts.isEmpty) return '<p>No histogram data.</p>';
    const w = 640.0;
    const hgt = 180.0;
    const pad = 24.0;
    final maxC = h.counts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final barW = (w - pad * 2) / h.counts.length;
    final rects = StringBuffer();
    for (var i = 0; i < h.counts.length; i++) {
      final bh = (h.counts[i] / maxC) * (hgt - pad * 2);
      final x = pad + i * barW + 2;
      final y = hgt - pad - bh;
      rects.writeln(
        '<rect x="$x" y="$y" width="${barW - 4}" height="$bh" fill="#2c4a6e"/>',
      );
      rects.writeln(
        '<text x="${x + (barW - 4) / 2}" y="${hgt - 6}" text-anchor="middle" font-size="9" fill="#5c5c5c">${_esc(h.buckets[i].split(' ').first)}</text>',
      );
    }
    return '<svg viewBox="0 0 $w $hgt" role="img" aria-label="Frame histogram">$rects</svg>';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
