import 'package:flutter/widgets.dart';
import 'package:frameguard/src/core/frameguard.dart';
import 'package:frameguard/src/metrics/image_diagnostics.dart';

/// Wraps an [ImageProvider] / [Image] and records oversized-decode warnings
/// when dimensions are known.
///
/// Does not claim decode thread affinity — only compares display vs decoded
/// pixel dimensions when both are observable.
class FrameGuardImage extends StatefulWidget {
  /// Creates a diagnostic image wrapper around a normal [Image].
  const FrameGuardImage({
    super.key,
    required this.image,
    this.description,
    this.width,
    this.height,
    this.fit,
  });

  /// Underlying image provider.
  final ImageProvider image;

  /// Optional description (asset path, URL, etc.).
  final String? description;

  /// Display width hint.
  final double? width;

  /// Display height hint.
  final double? height;

  /// Box fit.
  final BoxFit? fit;

  @override
  State<FrameGuardImage> createState() => _FrameGuardImageState();
}

class _FrameGuardImageState extends State<FrameGuardImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant FrameGuardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolve();
    }
  }

  void _resolve() {
    _teardown();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      final session =
          FrameGuard.isInitialized ? FrameGuard.instance.activeSession : null;
      if (session == null || !session.options.captureImages) return;

      final decodedW = info.image.width;
      final decodedH = info.image.height;
      final displayW =
          widget.width ?? context.size?.width ?? decodedW.toDouble();
      final displayH =
          widget.height ?? context.size?.height ?? decodedH.toDouble();
      final bytes = decodedW * decodedH * 4;
      final warning = ImageWarning(
        description: widget.description ?? widget.image.toString(),
        displayWidth: displayW,
        displayHeight: displayH,
        decodedWidth: decodedW,
        decodedHeight: decodedH,
        estimatedDecodedBytes: bytes,
      );
      if (warning.dramaticallyOversized) {
        session.addImageWarning(warning);
      }
    });
    stream.addListener(_listener!);
    _stream = stream;
  }

  void _teardown() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.image,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
