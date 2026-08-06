// ============================================================================
// presentation/widgets/camera_capture_area.dart
// Shows either the "Open Camera" prompt or the captured photo preview.
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';

import '../features/delivery_confirm/domain/delivery_state.dart';
import '../theme/app_theme.dart';

class CameraCaptureArea extends StatelessWidget {
  const CameraCaptureArea({
    super.key,
    required this.state,
    required this.onOpenCamera,
    required this.onRetake,
  });

  final DeliveryState state;
  final VoidCallback onOpenCamera;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final bool busy = state.status == DeliveryStatus.cameraOpening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
          child: Text(
            'Delivery proof',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: state.hasPhoto
              ? _PhotoPreview(
                  path: state.photoPath!,
                  onRetake: onRetake,
                  // Lock retake while uploading / after success.
                  enabled: state.canComplete ||
                      state.status == DeliveryStatus.uploadFailed ||
                      state.status == DeliveryStatus.offlinePendingUpload,
                )
              : _EmptyCameraSlot(busy: busy, onOpenCamera: onOpenCamera),
        ),
      ],
    );
  }
}

class _EmptyCameraSlot extends StatelessWidget {
  const _EmptyCameraSlot({required this.busy, required this.onOpenCamera});

  final bool busy;
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Center(
        child: busy
            ? const _Spinner(label: 'Opening camera…')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.infoBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_outlined,
                        size: 30, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No photo captured yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: onOpenCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Open Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.button),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl, vertical: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.path,
    required this.onRetake,
    required this.enabled,
  });

  final String path;
  final VoidCallback onRetake;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(path), fit: BoxFit.cover),
          // Subtle gradient so the retake button stays legible.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66000000)],
                stops: [0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: enabled ? onRetake : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh,
                          size: 16,
                          color: enabled
                              ? AppColors.primary
                              : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Retake Photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }
}
