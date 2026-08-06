import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationMarkerFactory {
  NavigationMarkerFactory._();
  static final instance = NavigationMarkerFactory._();

  BitmapDescriptor? _driverCached;
  final Map<int, BitmapDescriptor> _currentStopCache = {};
  final Map<int, BitmapDescriptor> _pendingStopCache = {};
  final Map<int, BitmapDescriptor> _deliveredStopCache = {};

  /// Driver marker — circular blue badge with a small arrow.
  Future<BitmapDescriptor> driverMarker({double devicePixelRatio = 3}) async {
    if (_driverCached != null) return _driverCached!;
    final size = (44 * devicePixelRatio).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    // Outer pulse ring
    canvas.drawCircle(
      center,
      size * 0.48,
      Paint()..color = const Color(0x332979FF),
    );
    // White stroke
    canvas.drawCircle(
      center,
      size * 0.34,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    // Blue inner
    canvas.drawCircle(
      center,
      size * 0.30,
      Paint()..color = const Color(0xFF2979FF),
    );

    // Up-arrow ("navigation") glyph inside the blue dot
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.navigation_rounded.codePoint),
        style: TextStyle(
          fontFamily: Icons.navigation_rounded.fontFamily,
          package: Icons.navigation_rounded.fontPackage,
          color: Colors.white,
          fontSize: size * 0.34,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final img = await recorder.endRecording().toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    _driverCached = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,   // <-- same fix
    );
    return _driverCached!;
  }

  /// The bold current destination pin
  Future<BitmapDescriptor> currentStopMarker(
      int stopNumber, {
        double devicePixelRatio = 3,
      }) async {
    if (_currentStopCache.containsKey(stopNumber)) {
      return _currentStopCache[stopNumber]!;
    }
    final descriptor = await _buildPin(
      label: '$stopNumber',
      fillColor: const Color(0xFFE53935),
      ringColor: Colors.white,
      large: true,
      devicePixelRatio: devicePixelRatio,
    );
    _currentStopCache[stopNumber] = descriptor;
    return descriptor;
  }

  /// Pending (upcoming) stops — small secondary pins.
  Future<BitmapDescriptor> pendingStopMarker(
      int stopNumber, {
        double devicePixelRatio = 3,
      }) async {
    if (_pendingStopCache.containsKey(stopNumber)) {
      return _pendingStopCache[stopNumber]!;
    }
    final descriptor = await _buildPin(
      label: '$stopNumber',
      fillColor: const Color(0xFF1565C0),
      ringColor: Colors.white,
      large: false,
      devicePixelRatio: devicePixelRatio,
    );
    _pendingStopCache[stopNumber] = descriptor;
    return descriptor;
  }

  /// Delivered stops — green check pin.
  Future<BitmapDescriptor> deliveredStopMarker(
      int stopNumber, {
        double devicePixelRatio = 3,
      }) async {
    if (_deliveredStopCache.containsKey(stopNumber)) {
      return _deliveredStopCache[stopNumber]!;
    }
    final descriptor = await _buildPin(
      label: null,
      iconCode: Icons.check_rounded,
      fillColor: const Color(0xFF2E7D32),
      ringColor: Colors.white,
      large: false,
      devicePixelRatio: devicePixelRatio,
    );
    _deliveredStopCache[stopNumber] = descriptor;
    return descriptor;
  }

  // ── internal pin builder ────────────────────────────────────
  Future<BitmapDescriptor> _buildPin({
    String? label,
    IconData? iconCode,
    required Color fillColor,
    required Color ringColor,
    required bool large,
    required double devicePixelRatio,
  }) async {
    final width = ((large ? 44 : 32) * devicePixelRatio).toInt();
    final height = ((large ? 58 : 42) * devicePixelRatio).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final w = width.toDouble();
    final h = height.toDouble();
    final radius = w * 0.42;
    final tipY = h - 2;

    // Pin body (teardrop): circle + triangle
    final bodyPaint = Paint()..color = fillColor;
    canvas.drawCircle(Offset(w / 2, radius + 4), radius, bodyPaint);

    final path = Path()
      ..moveTo(w / 2 - radius * 0.45, radius + radius * 0.55)
      ..lineTo(w / 2 + radius * 0.45, radius + radius * 0.55)
      ..lineTo(w / 2, tipY)
      ..close();
    canvas.drawPath(path, bodyPaint);

    // Inner white ring
    canvas.drawCircle(
      Offset(w / 2, radius + 4),
      radius * 0.70,
      Paint()..color = ringColor,
    );

    // Inner colored disc
    canvas.drawCircle(
      Offset(w / 2, radius + 4),
      radius * 0.60,
      Paint()..color = fillColor,
    );

    // Label or icon
    if (iconCode != null) {
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconCode.codePoint),
          style: TextStyle(
            fontFamily: iconCode.fontFamily,
            package: iconCode.fontPackage,
            color: Colors.white,
            fontSize: radius * 0.85,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(w / 2 - iconPainter.width / 2,
            radius + 4 - iconPainter.height / 2),
      );
    } else if (label != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.75,
            fontFamily: 'Poppins',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(w / 2 - textPainter.width / 2,
            radius + 4 - textPainter.height / 2),
      );
    }

    final img = await recorder.endRecording().toImage(width, height);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,   // <-- tells the map the bitmap is pre-scaled
    );
  }
}