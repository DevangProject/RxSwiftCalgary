// ============================================================================
// presentation/widgets/upload_status_banner.dart
// Renders the contextual status banner for each upload state.
// ============================================================================

import 'package:flutter/material.dart';

import '../features/delivery_confirm/domain/delivery_state.dart';
import '../theme/app_theme.dart';

class UploadStatusBanner extends StatelessWidget {
  const UploadStatusBanner({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final DeliveryState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DeliveryStatus.uploading:
        return _Banner(
          bg: AppColors.infoBg,
          icon: Icons.cloud_upload_outlined,
          iconColor: AppColors.info,
          title: 'Uploading photo…',
          subtitle:
              '${(state.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}% complete',
          trailing: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: state.uploadProgress > 0 ? state.uploadProgress : null,
            ),
          ),
        );

      case DeliveryStatus.uploadSuccess:
        return const _Banner(
          bg: AppColors.successBg,
          icon: Icons.check_circle,
          iconColor: AppColors.success,
          title: 'Delivery confirmed',
          subtitle: 'Photo uploaded successfully. Order marked as delivered.',
        );

      case DeliveryStatus.uploadFailed:
        return _Banner(
          bg: AppColors.errorBg,
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Upload failed',
          subtitle: state.errorMessage ?? 'Please try again.',
          action: _RetryButton(onRetry: onRetry, color: AppColors.error),
        );

      case DeliveryStatus.offlinePendingUpload:
        return _Banner(
          bg: AppColors.warningBg,
          icon: Icons.wifi_off_rounded,
          iconColor: AppColors.warning,
          title: 'No internet connection',
          subtitle: state.errorMessage ??
              'Photo saved locally. It will upload when internet is restored.',
          action: _RetryButton(onRetry: onRetry, color: AppColors.warning),
        );

      case DeliveryStatus.initial:
      case DeliveryStatus.cameraOpening:
      case DeliveryStatus.photoCaptured:
        return const SizedBox.shrink();
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.action,
  });

  final Color bg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onRetry, required this.color});
  final VoidCallback onRetry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Retry upload'),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ),
    );
  }
}
