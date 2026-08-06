import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/route_details/route_detail_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../delivery_confirm/delivery_confirm_screen.dart';
import '../today_route/model/route_model.dart';
import '../today_route/provider/today_route_provider.dart';
import '../today_route/route_map/widgets/pickup_photo_sheet.dart';
import 'model/order_detail_model.dart';

// ─────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key, required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeDetailProvider(stop.orderId));
    final notifier = ref.read(routeDetailProvider(stop.orderId).notifier);

    final isPickup = stop.stopType == StopType.pickup;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // ── AppBar ─────────────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Tasks',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          titleSpacing: 0,
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                isPickup ? 'Pick up Task' : 'Drop off Task',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),

        // ── Fixed bottom buttons ────────────────────────────────
        bottomNavigationBar: _BottomActions(
          stop: stop,
          isNavigating: state.isNavigating,
          isArriving: state.isArriving,
          onNavigate: () => _onNavigate(context, ref, notifier),
          onArrived: () => _onArrived(context, ref, notifier),
        ),

        // ── Scrollable body ─────────────────────────────────────
        body: _buildBody(state, notifier, isPickup),
      ),
    );
  }

  Widget _buildBody(
      RouteDetailState state, RouteDetailNotifier notifier, bool isPickup) {
    final detail = state.orderDetail;

    if (state.isLoading && detail == null) {
      return const AppProgressLoader(message: 'Loading order details...');
    }

    if (state.isError && detail == null) {
      return _ErrorView(
        message: state.errorMessage ?? 'Something went wrong',
        onRetry: notifier.fetchOrderDetail,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const _SectionHeader(title: 'Details'),
          const SizedBox(height: 12),

          // Detail card
          _DetailCard(stop: stop, detail: detail, isPickup: isPickup),
        ],
      ),
    );
  }

  // ── Navigate: open Google Maps ──────────────────────────────────

  Future<void> _onNavigate(
      BuildContext context,
      WidgetRef ref,
      RouteDetailNotifier notifier,
      ) async {
    if (ref.read(routeDetailProvider(stop.orderId)).isNavigating) return;
    notifier.setNavigating(true);

    final opened = await notifier.openInGoogleMaps(stop);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps',
              style: TextStyle(fontFamily: 'Poppins')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    notifier.setNavigating(false);
  }

  // ── Arrived ──────────────────────────────────────────────────────

  Future<void> _onArrived(
      BuildContext context,
      WidgetRef ref,
      RouteDetailNotifier notifier,
      ) async {
    if (ref.read(routeDetailProvider(stop.orderId)).isArriving) return;

    // Pickup tasks run the same photo + location confirmation flow as the
    // route map screen instead of just popping back.
    if (stop.stopType == StopType.pickup) {
      await _handlePickup(context, ref, notifier);
      return;
    }

    // Drop-off tasks open the same delivery confirmation screen used by the
    // route map screen.
    await _openDeliveryConfirmation(context, notifier);
  }

  // ── Pickup: show photo + location sheet, then call API ───────────
  //
  // Mirrors RouteMapScreen._handlePickup so pickup confirmation behaves
  // identically whether it's triggered from the map or this detail screen.

  Future<void> _handlePickup(
      BuildContext context,
      WidgetRef ref,
      RouteDetailNotifier notifier,
      ) async {
    if (stop.orderId.isEmpty) {
      _toast(context, 'Invalid order. Please refresh and try again.');
      return;
    }

    notifier.setArriving(true);

    // 1. Show the pickup photo + location popup.
    final result = await showPickupPhotoSheet(context, stopAddress: stop.address);

    // Driver dismissed the sheet without confirming.
    if (result == null || !context.mounted) {
      notifier.setArriving(false);
      return;
    }

    // 2. Call the API with photo + coordinates.
    final success = await ref.read(todayRouteProvider.notifier).pickupOrder(
      orderId: stop.orderId,
      photoPath: result.photoPath,
      latitude: result.latitude,
      longitude: result.longitude,
    );

    if (!context.mounted) return;
    notifier.setArriving(false);

    // 3. Handle result.
    if (success) {
      await showPickupSuccess(context);
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } else {
      final errorMessage = ref.read(todayRouteProvider).pickupErrorMessage ??
          'Unable to confirm pickup. Please try again.';
      _toast(context, errorMessage);
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── Delivery: open confirmation screen ────────────────────────────
  //
  // Mirrors RouteMapScreen._openDeliveryConfirmation so drop-off
  // confirmation behaves identically whether it's triggered from the map
  // or this detail screen.

  Future<void> _openDeliveryConfirmation(
      BuildContext context,
      RouteDetailNotifier notifier,
      ) async {
    notifier.setArriving(true);

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliveryConfirmationScreen(
          orderId: stop.orderId,
          customerName: 'Patient Name:${stop.patientName}',
          deliveryAddress: stop.address,
          pharmacyName: stop.pharmacyName,
        ),
      ),
    );

    if (!context.mounted) return;
    notifier.setArriving(false);

    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Section Header  "Details"
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Detail Card
// ─────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.stop,
    required this.detail,
    required this.isPickup,
  });

  final RouteStop stop;
  final OrderDetail? detail;
  final bool isPickup;

  @override
  Widget build(BuildContext context) {
    // ── Field values — prefer fresh API detail, fall back to the stop
    //    summary already known from the route list ────────────────────
    final companyName = _firstNonEmpty([detail?.pharmacyName, stop.pharmacyName]);

    final address = _firstNonEmpty([
      isPickup ? detail?.pharmacyAddress : detail?.deliveryAddress,
      stop.address,
    ]);

    final orderTrackingNumber =
        _firstNonEmpty([detail?.orderNumber, stop.orderNumber]);

    final serviceType = _firstNonEmpty([detail?.handlingType]);

    final contactName = _firstNonEmpty([detail?.patientName, stop.patientName]);

    final phone = _firstNonEmpty([
      isPickup ? detail?.pharmacyPhone : detail?.patientPhone,
      stop.patientPhone,
    ]);

    final pickupOrDeliveryLabel = isPickup ? 'Pick up time' : 'Delivery window';
    final pickupOrDeliveryValue = _firstNonEmpty([detail?.pickupWindowLabel]);

    final notes = _firstNonEmpty(
        [isPickup ? null : detail?.deliveryNotes, stop.notes]);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Company / Pharmacy Name ──────────────────────────
          _DetailRow(label: 'Company Name', value: companyName),
          _Divider(),

          // ── Address ──────────────────────────────────────────
          _DetailRow(
            label: 'Address',
            value: address,
            trailing: address != 'N/A' ? _CopyIcon(text: address) : null,
          ),
          _Divider(),

          // ── Suite ────────────────────────────────────────────
          _DetailRow(label: 'Suite', value: 'N/A'),
          _Divider(),

          // ── Order Placed By ──────────────────────────────────
          _DetailRow(label: 'Order Placed By', value: companyName),
          _Divider(),

          // ── Order Tracking # ─────────────────────────────────
          _DetailRow(label: 'Order Tracking #', value: orderTrackingNumber),
          _Divider(),

          // ── Customer Reference # ─────────────────────────────
          _DetailRow(label: 'Customer Reference #', value: 'N/A'),
          _Divider(),

          // ── Service Type ─────────────────────────────────────
          _DetailRow(label: 'Service Type', value: serviceType),
          _Divider(),

          // ── Contact Name ─────────────────────────────────────
          _DetailRow(label: 'Contact Name', value: contactName),
          _Divider(),

          // ── Pick up time / Delivery window ───────────────────
          _DetailRow(
            label: pickupOrDeliveryLabel,
            value: pickupOrDeliveryValue,
          ),
          _Divider(),

          // ── Task ─────────────────────────────────────────────
          _DetailRow(
            label: 'Task',
            value: isPickup ? 'Pick up' : 'Drop off',
          ),
          _Divider(),

          // ── Package Size ─────────────────────────────────────
          _DetailRow(label: 'Package Size', value: 'N/A'),
          _Divider(),

          // ── Package Type ─────────────────────────────────────
          _DetailRow(label: 'Package Type', value: 'N/A'),
          _Divider(),

          // ── Weight ───────────────────────────────────────────
          _DetailRow(label: 'Weight', value: 'N/A'),
          _Divider(),

          // ── Package Description ──────────────────────────────
          _DetailRow(label: 'Package Description', value: 'N/A'),
          _Divider(),

          // ── Quantity ─────────────────────────────────────────
          _DetailRow(label: 'Quantity', value: 'N/A'),
          _Divider(),

          // ── Phone ────────────────────────────────────────────
          _DetailRow(
            label: 'Phone',
            value: phone,
            trailing: phone != 'N/A' ? _PhoneActions(phone: phone) : null,
          ),

          // ── Failure reason (only if the order failed) ────────
          if (detail?.failureReason != null &&
              detail!.failureReason!.isNotEmpty) ...[
            _Divider(),
            _DetailRow(
              label: 'Failure Reason',
              value: detail!.failureReason!,
              valueColor: Colors.red,
            ),
          ],

          // ── Notes (only if present) ───────────────────────────
          if (notes != 'N/A') ...[
            _Divider(),
            _DetailRow(
              label: 'Notes',
              value: notes,
              valueColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return 'N/A';
  }
}

// ─────────────────────────────────────────────────────────────
//  Error state — shown when the order detail call fails
// ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Single detail row
// ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Thin divider between rows
// ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Copy address icon
// ─────────────────────────────────────────────────────────────

class _CopyIcon extends StatelessWidget {
  const _CopyIcon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address copied', style: TextStyle(fontFamily: 'Poppins')),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Phone action icons (call + message)
// ─────────────────────────────────────────────────────────────

class _PhoneActions extends StatelessWidget {
  const _PhoneActions({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PhoneIconButton(
          icon: Icons.phone_rounded,
          onTap: () => _launch('tel:$phone'),
        ),
        const SizedBox(width: 8),
        _PhoneIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () => _launch('sms:$phone'),
        ),
      ],
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _PhoneIconButton extends StatelessWidget {
  const _PhoneIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Fixed bottom action bar
// ─────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.stop,
    required this.isNavigating,
    required this.isArriving,
    required this.onNavigate,
    required this.onArrived,
  });

  final RouteStop stop;
  final bool isNavigating;
  final bool isArriving;
  final VoidCallback onNavigate;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final isPickup = stop.stopType == StopType.pickup;
    final arrivedLabel = isPickup
        ? (isArriving ? 'Picking up…' : 'Order Pickup')
        : (isArriving ? 'Opening…' : 'Confirm Delivery');
    final arrivedIcon =
        isPickup ? Icons.inventory_2_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // ── Navigate ────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isNavigating ? null : onNavigate,
                icon: isNavigating
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Icon(Icons.navigation_rounded, size: 18),
                label: const Text(
                  'Navigate',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Arrived ─────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isArriving ? null : onArrived,
                icon: isArriving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : Icon(arrivedIcon, size: 18),
                label: Text(
                  arrivedLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  const Color(0xFF1A1A2E).withOpacity(0.55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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