// ============================================================================
// lib/features/delivery_confirm/presentation/screens/delivery_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/delivery_confirm/provider/delivery_confirmation_provider.dart';

import '../../widgets/camera_capture_area.dart';
import '../../widgets/instruction_card.dart';
import '../../widgets/location_info_card.dart';
import '../../widgets/order_summary_card.dart';
import '../../widgets/qr_scan_card.dart';
import '../../widgets/qr_scanner_screen.dart';
import '../../widgets/upload_status_banner.dart';
import '../route_map/theme/route_map_theme.dart';
import 'domain/delivery_state.dart';

class DeliveryConfirmationScreen extends ConsumerWidget {
  const DeliveryConfirmationScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.deliveryAddress,
    required this.pharmacyName,
    this.orderArgs,
  });

  final String orderId;
  final String customerName;
  final String deliveryAddress;
  final String pharmacyName;

  final DeliveryOrderArgs? orderArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the per-orderId family provider instances.
    final state = ref.watch(deliveryControllerProvider(orderId));
    final controller =
    ref.read(deliveryControllerProvider(orderId).notifier);

    final effectiveArgs = orderArgs ??
        DeliveryOrderArgs(
          orderId: orderId,
          customerName: customerName,
          address: deliveryAddress,
          pharmacyName: pharmacyName,
        );
    final order = ref.watch(deliveryOrderProvider(effectiveArgs));

    ref.listen<DeliveryState>(deliveryControllerProvider(orderId),
            (prev, next) {
          if (prev?.status != DeliveryStatus.uploadSuccess &&
              next.status == DeliveryStatus.uploadSuccess) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  backgroundColor: RouteColors.tealDark,
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Delivery confirmed successfully.',
                    style: RouteText.body(Colors.white),
                  ),
                ),
              );
          }
        });

    return Scaffold(
      backgroundColor: RouteColors.background,
      appBar: AppBar(
        backgroundColor: RouteColors.tealDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Delivery Confirmation',
          style: RouteText.appBar(Colors.white),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW =
            constraints.maxWidth > 520 ? 520.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    RouteSpacing.lg,
                    RouteSpacing.lg,
                    RouteSpacing.lg,
                    RouteSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrderSummaryCard(orderId: orderId,customerName: order.customerName,address: order.address,pharmacyName: order.pharmacyName),
                      const SizedBox(height: RouteSpacing.lg),
                      const InstructionCard(),
                      const SizedBox(height: RouteSpacing.lg),
                      CameraCaptureArea(
                        state: state,
                        onOpenCamera: controller.openCamera,
                        onRetake: controller.retakePhoto,
                      ),
                      if (state.hasPhoto) ...[
                        const SizedBox(height: RouteSpacing.lg),
                        QrScanCard(
                          state: state,
                          onScan: () async {
                            final code = await scanQrCode(context);
                            if (code != null && code.isNotEmpty) {
                              controller.setQrCode(code);
                            }
                          },
                        ),
                        const SizedBox(height: RouteSpacing.lg),
                        LocationInfoCard(
                          state: state,
                          onRetryLocation: controller.retryLocation,
                        ),
                      ],
                      const SizedBox(height: RouteSpacing.lg),
                      UploadStatusBanner(
                        state: state,
                        onRetry: state.isOfflinePending
                            ? controller.retryPendingUpload
                            : controller.retryUpload,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomActionBar(
        state: state,
        onOpenCamera: controller.openCamera,
        onComplete: controller.uploadAndComplete,
        // Returns `true` → route_map_screen advances the stop.
        onDone: () => Navigator.of(context).maybePop(true),
      ),
    );
  }
}

// ── Bottom action bar (unchanged) ─────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.state,
    required this.onOpenCamera,
    required this.onComplete,
    required this.onDone,
  });

  final DeliveryState state;
  final VoidCallback onOpenCamera;
  final VoidCallback onComplete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (state.isSuccess) {
      return _BarWrapper(
        child: _PrimaryButton(
          label: 'Done',
          icon: Icons.check_rounded,
          color: RouteColors.accentGreen,
          onPressed: onDone,
        ),
      );
    }

    if (!state.hasPhoto) {
      return _BarWrapper(
        child: _PrimaryButton(
          label: 'Take Photo',
          icon: Icons.camera_alt_rounded,
          color: RouteColors.primary,
          onPressed: state.status == DeliveryStatus.cameraOpening
              ? null
              : onOpenCamera,
        ),
      );
    }

    final bool enabled = state.canComplete;
    return _BarWrapper(
      child: _PrimaryButton(
        label: state.isUploading
            ? 'Uploading…'
            : !state.hasQrCode
            ? 'Scan QR code to continue'
            : 'Upload & Complete Delivery',
        icon:
        state.isUploading ? null : Icons.check_circle_outline_rounded,
        color: RouteColors.accentGreen,
        loading: state.isUploading,
        onPressed: enabled ? onComplete : null,
      ),
    );
  }
}

class _BarWrapper extends StatelessWidget {
  const _BarWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          RouteSpacing.lg,
          RouteSpacing.md,
          RouteSpacing.lg,
          RouteSpacing.md,
        ),
        decoration: BoxDecoration(
          color: RouteColors.surface,
          border: Border(top: BorderSide(color: RouteColors.cardBorder)),
          boxShadow: RouteShadows.sheet,
        ),
        child: child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.color,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: RouteColors.disabledFill,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (loading || icon != null) const SizedBox(width: RouteSpacing.sm),
            Text(label, style: RouteText.button(Colors.white)),
          ],
        ),
      ),
    );
  }
}