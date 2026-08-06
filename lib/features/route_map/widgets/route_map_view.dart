import 'package:flutter/material.dart';


import '../../today_route/model/route_model.dart';
import '../provider/map_projection.dart';
import '../theme/route_map_theme.dart';
import 'route_map_atoms.dart';

/// ─────────────────────────────────────────────────────────────
///  Map view — stylised "map" canvas (grid + roads + blocks + dashed
///  route) with stop markers placed from REAL lat/lng via [MapProjection].
///  Swap the body for a real `GoogleMap` later; the markers/legend/controls
///  layering stays the same.
/// ─────────────────────────────────────────────────────────────
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.route,
    required this.selectedIndex,
    required this.projection,
    required this.onMarkerTap,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final TodayRoute route;
  final int selectedIndex;
  final MapProjection projection;
  final ValueChanged<int> onMarkerTap;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final stops = route.stops;
    final driver = projection.project(route.startLatitude, route.startLongitude);

    // Precompute projected positions once.
    final positions = [
      for (final s in stops)
        s.hasCoordinates
            ? projection.project(s.latitude, s.longitude)
            : (x: 0.5, y: 0.5),
    ];

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapCanvasPainter(
                    stopPositions: positions,
                    driver: Offset(driver.x, driver.y),
                  ),
                ),
              ),

              for (int i = 0; i < stops.length; i++)
                _PositionedMarker(
                  x: positions[i].x * w,
                  y: positions[i].y * h,
                  child: _StopMarker(
                    stop: stops[i],
                    isSelected: i == selectedIndex,
                    onTap: () => onMarkerTap(i),
                  ),
                ),

              _PositionedMarker(
                x: driver.x * w,
                y: driver.y * h,
                child: const _DriverMarker(),
              ),

              const Positioned(top: 12, left: 12, child: MapLegend()),

              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    MapControlButton(icon: Icons.add, onTap: onZoomIn),
                    const SizedBox(height: 6),
                    MapControlButton(icon: Icons.remove, onTap: onZoomOut),
                  ],
                ),
              ),

              Positioned(
                left: 12,
                bottom: 12,
                child: MapControlButton(
                  icon: Icons.my_location_rounded,
                  iconColor: RouteColors.teal,
                  onTap: onRecenter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PositionedMarker extends StatelessWidget {
  const _PositionedMarker({
    required this.x,
    required this.y,
    required this.child,
  });

  final double x;
  final double y;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }
}

/// Circular numbered stop marker. Colour depends on type + status.
class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.isSelected,
    required this.onTap,
  });

  final RouteStop stop;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = stop.status == StopStatus.inProgress;
    final bool done = stop.status == StopStatus.completed;

    late final Color bg;
    if (done) {
      bg = RouteColors.grayMid;
    } else if (active) {
      bg = RouteColors.teal;
    } else if (stop.stopType.isPickup) {
      bg = RouteColors.greenMid;
    } else {
      bg = RouteColors.blueMid;
    }

    final double size = active ? 32 : 28;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            if (isSelected || active)
              BoxShadow(
                color: RouteColors.teal.withOpacity(0.30),
                blurRadius: 0,
                spreadRadius: 4,
              ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : Text(
          '${stop.stopNumber}',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: RouteColors.teal, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.two_wheeler_rounded,
        size: 18,
        color: RouteColors.teal,
      ),
    );
  }
}

/// Paints grid, roads, building blocks and the dashed teal route polyline
/// through driver → every stop (in sequence).
class _MapCanvasPainter extends CustomPainter {
  _MapCanvasPainter({required this.stopPositions, required this.driver});

  final List<({double x, double y})> stopPositions;
  final Offset driver; // normalized

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = RouteColors.mapCanvas,
    );

    final grid = Paint()
      ..color = RouteColors.mapGridLine.withOpacity(0.30)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final block = Paint()..color = RouteColors.mapBlock;
    final blocks = <Rect>[
      _r(size, 0.05, 0.07, 0.17, 0.14),
      _r(size, 0.28, 0.10, 0.19, 0.18),
      _r(size, 0.56, 0.05, 0.15, 0.16),
      _r(size, 0.75, 0.21, 0.18, 0.13),
      _r(size, 0.08, 0.36, 0.14, 0.20),
      _r(size, 0.44, 0.39, 0.22, 0.14),
      _r(size, 0.78, 0.50, 0.15, 0.18),
      _r(size, 0.14, 0.63, 0.21, 0.14),
      _r(size, 0.50, 0.64, 0.17, 0.16),
      _r(size, 0.78, 0.75, 0.17, 0.14),
    ];
    for (final b in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(4)),
        block,
      );
    }

    final road = Paint()
      ..color = RouteColors.mapRoad.withOpacity(0.7)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * 0.29),
        Offset(size.width, size.height * 0.29), road);
    canvas.drawLine(Offset(0, size.height * 0.57),
        Offset(size.width, size.height * 0.57), road);
    canvas.drawLine(Offset(size.width * 0.39, 0),
        Offset(size.width * 0.39, size.height), road);
    canvas.drawLine(Offset(size.width * 0.69, 0),
        Offset(size.width * 0.69, size.height), road);

    final pts = <Offset>[
      Offset(driver.dx * size.width, driver.dy * size.height),
      for (final p in stopPositions)
        Offset(p.x * size.width, p.y * size.height),
    ];
    _drawDashedPolyline(canvas, pts);
  }

  Rect _r(Size s, double x, double y, double w, double h) => Rect.fromLTWH(
    x * s.width,
    y * s.height,
    w * s.width,
    h * s.height,
  );

  void _drawDashedPolyline(Canvas canvas, List<Offset> pts) {
    final paint = Paint()
      ..color = RouteColors.teal.withOpacity(0.75)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const dash = 7.0;
    const gap = 5.0;

    for (int i = 0; i < pts.length - 1; i++) {
      final start = pts[i];
      final end = pts[i + 1];
      final dist = (end - start).distance;
      if (dist == 0) continue;
      final dir = (end - start) / dist;
      double covered = 0;
      while (covered < dist) {
        final segStart = start + dir * covered;
        final double segLen = (covered + dash).clamp(0.0, dist).toDouble();
        final segEnd = start + dir * segLen;
        canvas.drawLine(segStart, segEnd, paint);
        covered += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter old) =>
      old.stopPositions != stopPositions || old.driver != driver;
}