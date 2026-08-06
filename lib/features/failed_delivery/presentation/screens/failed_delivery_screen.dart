import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/order_summary_card.dart';
import '../../../route_map/theme/route_map_theme.dart';
import '../../domain/failed_delivery_state.dart';
import '../providers/failed_delivery_providers.dart';
import '../widgets/notes_field.dart';
import '../widgets/photo_grid.dart';
import '../widgets/reason_dropdown.dart';
import '../widgets/submit_status_banner.dart';

class FailedDeliveryScreen extends ConsumerWidget {
  const FailedDeliveryScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
  });

  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = FailedDeliveryArgs(
      orderId: orderId,
      customerName: customerName,
      address: address,
      pharmacyName: pharmacyName,
    );

    final state = ref.watch(failedDeliveryControllerProvider(args));

    final controller =
    ref.read(failedDeliveryControllerProvider(args).notifier);

    final order = ref.watch(failedDeliveryOrderProvider(args));

    ref.listen<FailedDeliveryState>(
      failedDeliveryControllerProvider(args),
          (prev, next) {
        if (prev?.status != SubmitStatus.submitSuccess &&
            next.status == SubmitStatus.submitSuccess) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: RouteColors.tealDark,
                behavior: SnackBarBehavior.floating,
                content: Text(
                  'Failed delivery report submitted.',
                  style: RouteText.body(Colors.white),
                ),
              ),
            );

          Future.delayed(const Duration(milliseconds: 800), () {
            if (context.mounted) {
              Navigator.of(context).maybePop(true);
            }
          });
        }
      },
    );

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
          'Delivery Failed',
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

                      OrderSummaryCard(orderId: order.orderId,customerName: order.customerName,address: order.address,pharmacyName: order.pharmacyName,),

                      const SizedBox(height: RouteSpacing.lg),

                      ReasonDropdown(
                        value: state.reason,
                        onChanged: controller.selectReason,
                      ),

                      const SizedBox(height: RouteSpacing.lg),

                      NotesField(
                        initialValue: state.notes,
                        onChanged: controller.updateNotes,
                      ),

                      const SizedBox(height: RouteSpacing.lg),

                      PhotoGrid(
                        photoPaths: state.photoPaths,
                        isCapturing: state.isCapturing,
                        onAdd: controller.addPhoto,
                        onRemove: controller.removePhoto,
                      ),

                      const SizedBox(height: RouteSpacing.lg),

                      SubmitStatusBanner(
                        state: state,
                        onRetry: state.isOfflinePending
                            ? controller.retryPendingSubmit
                            : controller.retrySubmit,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _SubmitBar(
        state: state,
        onSubmit: controller.submit,
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.state,
    required this.onSubmit,
  });

  final FailedDeliveryState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final enabled = state.canSubmit;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          RouteSpacing.lg,
          RouteSpacing.md,
          RouteSpacing.lg,
          RouteSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: RouteColors.surface,
          border: Border(
            top: BorderSide(color: RouteColors.cardBorder),
          ),
          boxShadow: RouteShadows.sheet,
        ),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: RouteColors.danger,
              disabledBackgroundColor: const Color(0xFFEBC9C9),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: state.isSubmitting
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              'Submit Report',
              style: RouteText.button(Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}