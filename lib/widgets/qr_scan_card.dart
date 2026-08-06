// ============================================================================
// presentation/widgets/qr_scan_card.dart
// Shows either the "Scan QR Code" prompt or the scanned value.
// ============================================================================

import 'package:flutter/material.dart';

import '../features/delivery_confirm/domain/delivery_state.dart';
import '../theme/app_theme.dart';

class QrScanCard extends StatelessWidget {
  const QrScanCard({
    super.key,
    required this.state,
    required this.onScan,
  });

  final DeliveryState state;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    // Only relevant once a photo has been captured.
    if (!state.hasPhoto) return const SizedBox.shrink();

    final bool hasCode = state.hasQrCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
          child: Text(
            'QR code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: hasCode ? AppColors.successBg : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: hasCode
                ? null
                : Border.all(
                    color: AppColors.primary.withOpacity(0.35),
                    width: 1.5,
                  ),
          ),
          child: hasCode
              ? Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        color: AppColors.successDark, size: 22),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        state.qrCode!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onScan,
                      child: const Text('Rescan'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.infoBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          size: 28, color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Scan the package QR code to confirm delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Scan QR Code'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: 12),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
