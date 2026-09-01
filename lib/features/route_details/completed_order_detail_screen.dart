// ============================================================================
// lib/features/route_details/completed_order_detail_screen.dart
//
// Read-only "Delivered" summary shown when a driver taps a completed order
// on the Tasks screen's Completed tab. Fetches GET /driver/orders/{orderId}
// via the existing routeDetailProvider (same one RouteDetailScreen uses) and
// renders the pickup/delivery photos plus a proof-of-completion timeline.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../uttils/app_constants.dart';
import '../../widgets/app_progress_dialoug.dart';
import 'model/order_detail_model.dart';
import 'route_detail_provider.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_monthNames[local.month - 1]} ${local.day}, $hour12:$minute $period';
}

/// Opens the completed-order summary for [orderId] as a tall draggable
/// bottom sheet, matching the mockup's rounded-top card look.
Future<void> showCompletedOrderDetail(BuildContext context, String orderId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompletedOrderDetailSheet(orderId: orderId),
  );
}

class _CompletedOrderDetailSheet extends ConsumerWidget {
  const _CompletedOrderDetailSheet({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeDetailProvider(orderId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Expanded(
                child: _buildBody(context, state, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, RouteDetailState state,
      ScrollController scrollController) {
    final detail = state.orderDetail;

    if (state.isLoading && detail == null) {
      return const AppProgressLoader(message: 'Loading order details...');
    }

    if (state.isError && detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (detail == null) return const SizedBox.shrink();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _Header(detail: detail),
        const SizedBox(height: 20),
        if (detail.pickupImageUrl != null) ...[
          _PhotoSection(
            label: 'Pickup',
            timestamp: _formatTimestamp(detail.pickedUpAt),
            imageUrl: ApiConstants.resolveImageUrl(detail.pickupImageUrl),
          ),
          const SizedBox(height: 20),
        ],
        if (detail.deliveryPhotoUrl != null) ...[
          _PhotoSection(
            label: 'Delivery',
            timestamp: _formatTimestamp(detail.deliveredAt),
            imageUrl: ApiConstants.resolveImageUrl(detail.deliveryPhotoUrl),
          ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Proof of completion',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _Timeline(entries: detail.timeline),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Header  "kolj / Delivered"
// ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.detail});
  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final isDelivered = detail.status.toUpperCase() == 'DELIVERED';
    final color = isDelivered ? AppColors.success : AppColors.danger;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            isDelivered ? Icons.check_rounded : Icons.close_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.patientName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                detail.statusLabel.isNotEmpty ? detail.statusLabel : 'Delivered',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Photo section  (Pickup / Delivery)
// ─────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.label,
    required this.timestamp,
    required this.imageUrl,
  });

  final String label;
  final String timestamp;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (timestamp.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                timestamp,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: imageUrl == null
                ? Container(
                    color: AppColors.background,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textHint),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.background,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textHint),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.background,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Proof-of-completion timeline
// ─────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});
  final List<OrderTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text(
        'No status history available.',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        return _TimelineRow(entry: entry, isLast: isLast);
      }),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});
  final OrderTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: const BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: AppColors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.statusLabel.isNotEmpty ? entry.statusLabel : entry.status,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(entry.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
