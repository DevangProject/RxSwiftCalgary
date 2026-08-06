// ============================================================================
// features/today_route/route_map/widgets/stop_bottom_sheet.dart
//
// Bottom sheet showing the selected stop (real API-backed RouteStop).
//
// Collapsed → peek row (number, name, badge, primary action).
// Expanded  → full details + 1 km warning gate + action buttons.
//
// Pickup button shows a spinner and disables itself while the pickup API is
// in flight. The screen tells us via `isPickupLoading`.
// ============================================================================

import 'package:flutter/material.dart';

import '../../today_route/model/route_model.dart';
import '../theme/route_map_theme.dart';
import 'route_map_atoms.dart';

class StopBottomSheet extends StatelessWidget {
  const StopBottomSheet({
    super.key,
    required this.stop,
    required this.indexLabel,
    required this.expanded,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    required this.onNavigate,
    required this.onPickup,
    required this.onDelivered,
    required this.onFailed,
    this.isPickupLoading = false,
  });

  final RouteStop stop;
  final String indexLabel;
  final bool expanded;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onToggle;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onNavigate;
  final VoidCallback onPickup;
  final VoidCallback onDelivered;
  final VoidCallback onFailed;

  /// True while the pickup API is in flight for THIS stop. Drives the
  /// Pickup button's spinner + disabled state.
  final bool isPickupLoading;

  /// 1 km action gate keys off the per-leg distance from the API.
  bool get _inRange => stop.distanceKm <= 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: RouteColors.surface,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(RouteRadius.sheet)),
        boxShadow: RouteShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onToggle,
                onVerticalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 0 && expanded) onToggle();
                  if (v < 0 && !expanded) onToggle();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: RouteColors.borderSecondary,
                      borderRadius: BorderRadius.circular(RouteRadius.full),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: expanded ? _buildExpanded() : _buildCollapsed(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Collapsed peek ─────────────────────────────────────────
  Widget _buildCollapsed() {
    final completed = stop.status == StopStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _NumberChip(stop: stop),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stop.patientName,
                        overflow: TextOverflow.ellipsis,
                        style: RouteText.title(RouteColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StopBadge(type: stop.stopType, completed: completed),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${stop.distanceKm.toStringAsFixed(1)} km from previous',
                  style: RouteText.label(RouteColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactActionButton(
            stop: stop,
            inRange: _inRange,
            isPickupLoading: isPickupLoading,
            onPickup: onPickup,
            onDelivered: onDelivered,
          ),
        ],
      ),
    );
  }

  // ── Expanded full detail ───────────────────────────────────
  Widget _buildExpanded() {
    final completed = stop.status == StopStatus.completed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(indexLabel,
                    style: RouteText.body(RouteColors.textSecondary)),
                const SizedBox(width: 8),
                StopBadge(type: stop.stopType, completed: completed),
                if (stop.priority) ...[
                  const SizedBox(width: 6),
                  const _PriorityChip(),
                ],
              ],
            ),
            Row(
              children: [
                _StepperButton(
                  icon: Icons.chevron_left_rounded,
                  enabled: canGoPrev,
                  onTap: onPrev,
                ),
                const SizedBox(width: 6),
                _StepperButton(
                  icon: Icons.chevron_right_rounded,
                  enabled: canGoNext,
                  onTap: onNext,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stop.patientName,
                      style: RouteText.title(RouteColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Order ${stop.orderNumber}',
                      style: RouteText.label(RouteColors.textSecondary)),
                ],
              ),
            ),
            Text(
              '${stop.distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RouteColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RouteColors.surfaceAlt,
            borderRadius: BorderRadius.circular(RouteRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: stop.stopType.addressLabel,
                value: stop.address,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.local_pharmacy_outlined,
                label: 'Pharmacy',
                value: stop.pharmacyName,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.phone_outlined,
                value: stop.patientPhone,
              ),
              if (stop.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.sticky_note_2_outlined,
                  value: stop.notes,
                  muted: true,
                ),
              ],
            ],
          ),
        ),
        if (!_inRange && !completed) ...[
          const SizedBox(height: 10),
          const _WarningBanner(),
        ],
        const SizedBox(height: 12),
        if (completed)
          _CompletedPill(type: stop.stopType)
        else
          _ActionButtons(
            stop: stop,
            inRange: true,
            isPickupLoading: isPickupLoading,
            onNavigate: onNavigate,
            onPickup: onPickup,
            onDelivered: onDelivered,
            onFailed: onFailed,
          ),
      ],
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({required this.stop});
  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final done = stop.status == StopStatus.completed;
    final active = stop.status == StopStatus.inProgress;
    final color = done
        ? RouteColors.grayMid
        : active
        ? RouteColors.teal
        : stop.stopType.isPickup
        ? RouteColors.greenMid
        : RouteColors.blueMid;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: done
          ? Icon(Icons.check_rounded, size: 16, color: color)
          : Text(
        '${stop.stopNumber}',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: RouteColors.amberLight,
        borderRadius: BorderRadius.circular(RouteRadius.sm),
      ),
      child: const Text(
        'Priority',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: RouteColors.amber,
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: RouteColors.surfaceAlt,
        borderRadius: BorderRadius.circular(RouteRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(RouteRadius.sm),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RouteRadius.sm),
              border:
              Border.all(color: RouteColors.borderTertiary, width: 0.5),
            ),
            child: Icon(icon, size: 18, color: RouteColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    this.label,
    required this.value,
    this.muted = false,
  });
  final IconData icon;
  final String? label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: RouteColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(label!,
                    style: RouteText.label(RouteColors.textSecondary)),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: muted
                      ? RouteColors.textSecondary
                      : RouteColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RouteColors.amberLight,
        borderRadius: BorderRadius.circular(RouteRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: RouteColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Action button will enable when you are within 1 km of this location.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: RouteColors.amber,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill({required this.type});
  final StopType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: RouteColors.tealLight,
        borderRadius: BorderRadius.circular(RouteRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: RouteColors.teal),
          const SizedBox(width: 8),
          Text(
            type.isPickup ? 'Picked up' : 'Delivered',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: RouteColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.stop,
    required this.inRange,
    required this.onNavigate,
    required this.onPickup,
    required this.onDelivered,
    required this.onFailed,
    this.isPickupLoading = false,
  });

  final RouteStop stop;
  final bool inRange;
  final bool isPickupLoading;
  final VoidCallback onNavigate;
  final VoidCallback onPickup;
  final VoidCallback onDelivered;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    if (stop.stopType.isPickup) {
      return Row(
        children: [
          Expanded(
            child: _Btn(
              label: 'Navigate',
              icon: Icons.navigation_rounded,
              kind: _BtnKind.secondary,
              onTap: onNavigate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Btn(
              label: isPickupLoading ? 'Picking up…' : 'Order Pickup',
              icon: Icons.inventory_2_rounded,
              kind: _BtnKind.primary,
              enabled: !isPickupLoading,
             /* enabled: inRange && !isPickupLoading,*/
              loading: isPickupLoading,
              onTap: onPickup,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _Btn(
            label: 'Delivered',
            icon: Icons.check_rounded,
            kind: _BtnKind.primary,
         /*   enabled: inRange,*/
            onTap: onDelivered,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Btn(
            label: 'Failed',
            icon: Icons.close_rounded,
            kind: _BtnKind.danger,
            enabled: inRange,
            onTap: onFailed,
          ),
        ),
      ],
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.stop,
    required this.inRange,
    required this.onPickup,
    required this.onDelivered,
    this.isPickupLoading = false,
  });

  final RouteStop stop;
  final bool inRange;
  final bool isPickupLoading;
  final VoidCallback onPickup;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    if (stop.status == StopStatus.completed) {
      return const Icon(Icons.check_circle_rounded,
          color: RouteColors.teal, size: 28);
    }
    final isPickup = stop.stopType.isPickup;
    final pickupBusy = isPickup && isPickupLoading;
    return _Btn(
      label: isPickup ? (pickupBusy ? 'Pickup…' : 'Pickup') : 'Deliver',
      icon: isPickup ? Icons.inventory_2_rounded : Icons.check_rounded,
      kind: _BtnKind.primary,
      enabled: inRange && !pickupBusy,
      loading: pickupBusy,
      compact: true,
      onTap: isPickup ? onPickup : onDelivered,
    );
  }
}

enum _BtnKind { primary, secondary, danger }

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.kind,
    required this.onTap,
    this.enabled = true,
    this.compact = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final _BtnKind kind;
  final VoidCallback onTap;
  final bool enabled;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg, border;
    switch (kind) {
      case _BtnKind.primary:
        bg = RouteColors.teal;
        fg = Colors.white;
        border = RouteColors.teal;
        break;
      case _BtnKind.secondary:
        bg = Colors.white;
        fg = RouteColors.teal;
        border = RouteColors.teal;
        break;
      case _BtnKind.danger:
        bg = RouteColors.red;
        fg = Colors.white;
        border = RouteColors.red;
        break;
    }

    final disabled = !enabled;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(RouteRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(RouteRadius.md),
          onTap: disabled ? null : onTap,
          child: Container(
            height: compact ? 40 : 46,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RouteRadius.md),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                else
                  Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}