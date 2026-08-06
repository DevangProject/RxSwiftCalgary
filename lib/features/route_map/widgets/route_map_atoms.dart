import 'package:flutter/material.dart';

import '../../today_route/model/route_model.dart';
import '../theme/route_map_theme.dart';

/// Pickup / Drop / Done pill badge.
class StopBadge extends StatelessWidget {
  const StopBadge({super.key, required this.type, this.completed = false});

  final StopType type;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    late final Color bg, fg;
    late final String text;
    if (completed) {
      bg = RouteColors.grayLight;
      fg = RouteColors.gray;
      text = 'Done';
    } else if (type.isPickup) {
      bg = RouteColors.greenLight;
      fg = RouteColors.green;
      text = 'Pickup';
    } else {
      bg = RouteColors.blueLight;
      fg = RouteColors.blue;
      text = 'Drop';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RouteRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// A single translucent summary tile in the header strip.
class HeaderSummaryCard extends StatelessWidget {
  const HeaderSummaryCard({
    super.key,
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(RouteRadius.md),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating legend (top-left of the map).
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(RouteRadius.sm),
        boxShadow: RouteShadows.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LegendItem(color: RouteColors.greenMid, label: 'Pickup'),
          SizedBox(height: 4),
          _LegendItem(color: RouteColors.blueMid, label: 'Drop'),
          SizedBox(height: 4),
          _LegendItem(color: RouteColors.teal, label: 'Active'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: RouteColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Square map-control button (zoom +/-, recenter).
class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = RouteColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(RouteRadius.sm),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(RouteRadius.sm),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RouteRadius.sm),
            border: Border.all(color: RouteColors.borderTertiary, width: 0.5),
            boxShadow: RouteShadows.floating,
          ),
          child: Icon(icon, size: 19, color: iconColor),
        ),
      ),
    );
  }
}