import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:frameguard/frameguard.dart';
import 'package:frameguard/frameguard_test.dart';

void main() {
  FrameGuard.initialize(
    config: FrameGuardConfig(
      samplingMode: SamplingMode.full,
      refreshRate: const RefreshRate.hz(60),
      defaultBudget: FrameBudget.forRefreshRate(60, maxJankRate: 0.05),
      warnOnDebugMode: true,
    ),
  );
  runApp(
    const FrameGuardScope(
      child: FrameGuardOverlay(
        compact: true,
        child: FrameGuardExampleApp(),
      ),
    ),
  );
}

/// Demo app with intentional performance scenarios.
class FrameGuardExampleApp extends StatelessWidget {
  /// Creates the example app.
  const FrameGuardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrameGuard Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3A3A),
          primary: const Color(0xFF1A3A3A),
          secondary: const Color(0xFFC45C26),
          surface: const Color(0xFFF4F6F5),
        ),
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    final scenarios = <_Scenario>[
      _Scenario('Healthy List', const _HealthyListPage()),
      _Scenario('Rebuild Storm', const _RebuildStormPage()),
      _Scenario('Oversized Images', const _OversizedImagesPage()),
      _Scenario('Heavy Layout', const _HeavyLayoutPage()),
      _Scenario('CPU Stall', const _CpuStallPage()),
      _Scenario('Raster Stress', const _RasterStressPage()),
      _Scenario('Animation Jank', const _AnimationJankPage()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FrameGuard'),
        backgroundColor: const Color(0xFF1A3A3A),
        foregroundColor: const Color(0xFFF4F6F5),
      ),
      body: ListView.separated(
        itemCount: scenarios.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance regressions, testable.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A3A3A),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Open a scenario, interact, then pop back for a session report.',
                    style: TextStyle(color: Color(0xFF5C6B6B)),
                  ),
                ],
              ),
            );
          }
          final s = scenarios[i - 1];
          return ListTile(
            title: Text(s.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final session = FrameGuard.startSession(name: s.title);
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => s.page),
              );
              final report = await session.stop();
              final slug = s.title.toLowerCase().replaceAll(' ', '_');
              final out = File('reports${Platform.pathSeparator}$slug.json');
              await out.parent.create(recursive: true);
              await report.writeJson(out);
              if (context.mounted) {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(report.passed ? 'PASS' : 'FAIL'),
                    content: SingleChildScrollView(
                      child: Text(
                        '${report.summary()}\n\nSaved ${out.path}',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _Scenario {
  const _Scenario(this.title, this.page);
  final String title;
  final Widget page;
}

class _HealthyListPage extends StatelessWidget {
  const _HealthyListPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Healthy List')),
      body: FrameGuardRegion(
        name: 'healthy_list',
        child: ListView.builder(
          itemCount: 200,
          itemBuilder: (_, i) => ListTile(
            title: Text('Item $i'),
            subtitle: const Text('Lightweight row'),
          ),
        ),
      ),
    );
  }
}

class _RebuildStormPage extends StatefulWidget {
  const _RebuildStormPage();

  @override
  State<_RebuildStormPage> createState() => _RebuildStormPageState();
}

class _RebuildStormPageState extends State<_RebuildStormPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rebuild Storm')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return FrameGuardRegion(
            name: 'rebuild_storm',
            child: ListView.builder(
              itemCount: 80,
              itemBuilder: (_, i) => ListTile(
                title: Text('Tick ${_controller.value.toStringAsFixed(3)} #$i'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OversizedImagesPage extends StatelessWidget {
  const _OversizedImagesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oversized Images')),
      body: FrameGuardRegion(
        name: 'oversized_images',
        child: ListView(
          children: [
            for (var i = 0; i < 12; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: FrameGuardImage(
                  description: 'placeholder_$i',
                  width: 120,
                  height: 80,
                  image: const NetworkImage(
                    'https://via.placeholder.com/2000x2000.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeavyLayoutPage extends StatelessWidget {
  const _HeavyLayoutPage();

  @override
  Widget build(BuildContext context) {
    final indices = SyntheticJank.heavyLayoutIndices(count: 300);
    return Scaffold(
      appBar: AppBar(title: const Text('Heavy Layout')),
      body: FrameGuardRegion(
        name: 'heavy_layout',
        measureBuild: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final i in indices)
                Row(
                  children: [
                    for (var j = 0; j < 8; j++)
                      Expanded(
                        child: Container(
                          height: 28,
                          margin: const EdgeInsets.all(1),
                          color: Colors
                              .primaries[(i + j) % Colors.primaries.length]
                              .shade200,
                          child: Center(child: Text('$i,$j')),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CpuStallPage extends StatelessWidget {
  const _CpuStallPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CPU Stall')),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            await FrameGuard.trace('cpu_stall', () async {
              await FrameGuard.measureTask('busy_loop', () {
                SyntheticJank.cpu(
                  duration: const Duration(milliseconds: 40),
                );
              });
            });
          },
          child: const Text('Stall UI isolate 40ms'),
        ),
      ),
    );
  }
}

class _RasterStressPage extends StatelessWidget {
  const _RasterStressPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raster Stress')),
      body: FrameGuardRegion(
        name: 'raster_stress',
        child: ListView.builder(
          itemCount: 40,
          itemBuilder: (_, i) => Container(
            height: 120,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.primaries[i % Colors.primaries.length],
                  Colors.primaries[(i + 3) % Colors.primaries.length],
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 24,
                  spreadRadius: 4,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: const Center(child: Text('Shadow + filter')),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimationJankPage extends StatefulWidget {
  const _AnimationJankPage();

  @override
  State<_AnimationJankPage> createState() => _AnimationJankPageState();
}

class _AnimationJankPageState extends State<_AnimationJankPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animation Jank')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Occasional sync hitch during animation.
          if (_controller.value > 0.48 && _controller.value < 0.52) {
            SyntheticJank.cpu(duration: const Duration(milliseconds: 25));
          }
          return Center(
            child: Transform.rotate(
              angle: _controller.value * 6.28,
              child: child,
            ),
          );
        },
        child: Container(
          width: 160,
          height: 160,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
