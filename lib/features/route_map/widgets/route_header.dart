import 'package:flutter/material.dart';
import '../../today_route/model/route_model.dart';
import '../../today_route/provider/today_route_provider.dart';
import '../theme/route_map_theme.dart';
import 'route_map_atoms.dart';

/// Teal header: back, "Route In Progress" + progress chip, next-stop chip,
/// and the 3-tile summary strip — all from the real route state.
class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.state,
    required this.onBack,
  });

  final TodayRouteState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final TodayRoute? route = state.route;
    final stops = route?.stops ?? const <RouteStop>[];

    final total = route?.totalStops ?? stops.length;
    final pickups = stops.where((s) => s.stopType.isPickup).length;
    final done = state.completedStops;

    final next = _nextStop(stops);
    final nextLabel = next == null
        ? 'All stops complete'
        : 'Next: ${next.stopType.label} — ${next.pharmacyName}';

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 14),
      decoration: const BoxDecoration(color: RouteColors.tealDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Route In Progress',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ProgressChip(done: done, total: total),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 13, color: Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(RouteRadius.sm),
                            ),
                            child: Text(
                              nextLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              HeaderSummaryCard(value: '$total', label: 'Total'),
              const SizedBox(width: 8),
              HeaderSummaryCard(value: '$pickups', label: 'Pickups'),
              const SizedBox(width: 8),
              HeaderSummaryCard(value: '$done', label: 'Done'),
            ],
          ),
        ],
      ),
    );
  }

  RouteStop? _nextStop(List<RouteStop> stops) {
    for (final s in stops) {
      if (s.status == StopStatus.inProgress) return s;
    }
    for (final s in stops) {
      if (s.status == StopStatus.pending) return s;
    }
    return null;
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(RouteRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(RouteRadius.md),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(RouteRadius.full),
      ),
      child: Text(
        '$done/$total',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}