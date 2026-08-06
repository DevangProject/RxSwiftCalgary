// ============================================================================
// presentation/widgets/location_info_card.dart
// Shows the captured GPS coordinates + address, or a warning with a retry
// action when location could not be obtained.
// ============================================================================

import 'package:flutter/material.dart';

import '../features/delivery_confirm/domain/delivery_state.dart';
import '../theme/app_theme.dart';

class LocationInfoCard extends StatelessWidget {
  const LocationInfoCard({
    super.key,
    required this.state,
    required this.onRetryLocation,
  });

  final DeliveryState state;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    // Only relevant once a photo has been captured.
    if (!state.hasPhoto) return const SizedBox.shrink();

    final bool hasLoc = state.hasLocation;
    final Color bg = hasLoc ? AppColors.infoBg : AppColors.warningBg;
    final Color iconColor = hasLoc ? AppColors.info : AppColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasLoc ? Icons.my_location : Icons.location_off_outlined,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: hasLoc
                    ? _LocationDetails(location: state.location!)
                    : _LocationWarning(
                        message: state.locationWarning ??
                            'Location not captured.',
                      ),
              ),
            ],
          ),
          if (!hasLoc) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onRetryLocation,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({required this.location});
  final CaptureLocation location;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location stamped on photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          location.coordinatesLabel,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        if (location.address != null && location.address!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            location.address!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationWarning extends StatelessWidget {
  const _LocationWarning({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location not captured',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$message You can retry, or proceed without location.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
