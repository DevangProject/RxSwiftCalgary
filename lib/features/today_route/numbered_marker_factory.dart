// ============================================================================
// features/today_route/route_map/widgets/numbered_marker_factory.dart
//
// ADDITIVE — builds custom NUMBERED map-pin bitmaps for the GoogleMap view,
// colored to match the route_map palette (pickup green / drop blue / active
// teal / completed grey / start). Drawn with Canvas → BitmapDescriptor.
//
// Cached per (number,color,size) so repeated stops don't re-rasterize.
// ============================================================================

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../route_map/theme/route_map_theme.dart';
import 'model/route_model.dart';


class NumberedMarkerFactory {
  NumberedMarkerFactory._();
  static final instance = NumberedMarkerFactory._();

  final Map<String, BitmapDescriptor> _cache = {};

  /// Pin for a stop, colored + numbered by its type/status.
  Future<BitmapDescriptor> stopPin(
      RouteStop stop, {
        required double devicePixelRatio,
        bool selected = false,
      }) {
    final bool done = stop.status == StopStatus.completed;
    final bool active = stop.status == StopStatus.inProgress;

    final Color color = done
        ? RouteColors.grayMid
        : active
        ? RouteColors.teal
        : stop.stopType.isPickup
        ? RouteColors.greenMid
        : RouteColors.blueMid;

    return _pin(
      label: '${stop.stopNumber}',
      color: color,
      devicePixelRatio: devicePixelRatio,
      enlarged: active || selected,
      check: done,
    );
  }

  /// Start / driver pin (rose dot with a bike glyph).
  Future<BitmapDescriptor> startPin({required double devicePixelRatio}) {
    return _dot(
      color: const Color(0xFFC2407A),
      devicePixelRatio: devicePixelRatio,
      key: 'start',
    );
  }

  // ── Drawing ────────────────────────────────────────────────

  Future<BitmapDescriptor> _pin({
    required String label,
    required Color color,
    required double devicePixelRatio,
    bool enlarged = false,
    bool check = false,
  }) async {
    final cacheKey =
        'pin_${label}_${color.value}_${enlarged}_${check}_$devicePixelRatio';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    // Logical sizes; scaled by DPR for crisp rendering.
    final double w = (enlarged ? 44 : 38) * devicePixelRatio;
    final double h = (enlarged ? 58 : 50) * devicePixelRatio;
    final double r = w / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * devicePixelRatio;

    // Teardrop pin: circle head + triangle tail.
    final cx = w / 2;
    final cy = r;
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r - stroke.strokeWidth))
      ..moveTo(cx - r * 0.45, cy + r * 0.75)
      ..lineTo(cx, h - 2 * devicePixelRatio)
      ..lineTo(cx + r * 0.45, cy + r * 0.75)
      ..close();

    // Soft shadow.
    canvas.drawShadow(path, Colors.black.withOpacity(0.4),
        3 * devicePixelRatio, false);
    canvas.drawPath(path, fill);
    canvas.drawCircle(Offset(cx, cy), r - stroke.strokeWidth, stroke);

    if (check) {
      // Draw a check glyph instead of a number for completed stops.
      _drawText(canvas, '✓', Offset(cx, cy), color: Colors.white,
          fontSize: r * 0.95 * 1.0, devicePixelRatio: 1.0, bold: true);
    } else {
      _drawText(canvas, label, Offset(cx, cy), color: Colors.white,
          fontSize: r * 0.9, devicePixelRatio: 1.0, bold: true);
    }

    final img =
    await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor =
    BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  Future<BitmapDescriptor> _dot({
    required Color color,
    required double devicePixelRatio,
    required String key,
  }) async {
    final cacheKey = 'dot_${key}_${color.value}_$devicePixelRatio';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final double size = 34 * devicePixelRatio;
    final r = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * devicePixelRatio;

    final center = Offset(r, r);
    canvas.drawCircle(center, r - ring.strokeWidth, fill);
    canvas.drawCircle(center, r - ring.strokeWidth, ring);
    _drawText(canvas, '●', center,
        color: Colors.white, fontSize: r * 0.7, devicePixelRatio: 1.0);

    final img =
    await recorder.endRecording().toImage(size.ceil(), size.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor =
    BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    _cache[cacheKey] = descriptor;
    return descriptor;
  }

  void _drawText(
      Canvas canvas,
      String text,
      Offset center, {
        required Color color,
        required double fontSize,
        required double devicePixelRatio,
        bool bold = false,
      }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }
}