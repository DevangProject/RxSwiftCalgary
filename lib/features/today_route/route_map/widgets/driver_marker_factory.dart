// ============================================================================
// lib/features/today_route/route_map/widgets/driver_marker_factory.dart
//
// Draws a professional flat vehicle icon (arrow + body) as a BitmapDescriptor.
// The icon is cached, so it is only rasterised once regardless of how many
// position updates arrive.
//
// Design: flat teardrop-arrow shape in teal — clearly a moving vehicle,
// not a static pin. Use flat: true + anchor(0.5, 0.5) on the Marker so the
// rotation origin is the centre of the icon (like Ola/Uber).
// ============================================================================

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverMarkerFactory {
  DriverMarkerFactory._();
  static final instance = DriverMarkerFactory._();

  BitmapDescriptor? _cached;

  /// Returns the cached (or freshly rasterised) driver icon.
  Future<BitmapDescriptor> get icon async {
    if (_cached != null) return _cached!;
    _cached = await _build();
    return _cached!;
  }

  Future<BitmapDescriptor> _build() async {
    // Logical size 48×48, scaled 3× for crispness on high-DPR screens.
    const double scale = 3.0;
    const double logicalSize = 48.0;
    final double size = logicalSize * scale;
    final double cx = size / 2;
    final double cy = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // ── Shadow ───────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0 * scale / 3);

    canvas.drawCircle(Offset(cx, cy + 2 * scale / 3), size * 0.38, shadowPaint);

    // ── Car body (rounded rect, pointing "up" = north = 0°) ─────────────
    const Color bodyColor = Color(0xFF00897B); // teal 600
    const Color arrowColor = Colors.white;
    const Color outlineColor = Colors.white;

    final bodyPaint = Paint()..color = bodyColor;
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale / 3;

    // Body: rounded rect
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy + 2 * scale / 3),
          width: size * 0.52,
          height: size * 0.72),
      Radius.circular(size * 0.16),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    // ── Arrow head (triangle pointing up = forward direction) ─────────────
    final arrowPaint = Paint()..color = arrowColor;
    final arrowPath = Path()
      ..moveTo(cx, cy - size * 0.42)              // tip
      ..lineTo(cx - size * 0.22, cy - size * 0.10) // bottom-left
      ..lineTo(cx + size * 0.22, cy - size * 0.10) // bottom-right
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    // Windshield line (decorative detail)
    final detailPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5 * scale / 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - size * 0.15, cy - size * 0.02),
      Offset(cx + size * 0.15, cy - size * 0.02),
      detailPaint,
    );

    final image = await recorder
        .endRecording()
        .toImage(size.ceil(), size.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}