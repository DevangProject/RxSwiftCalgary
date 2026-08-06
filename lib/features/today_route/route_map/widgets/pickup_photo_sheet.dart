// ============================================================================
// lib/features/today_route/route_map/widgets/pickup_photo_sheet.dart
//
// Bottom-sheet popup shown when the driver taps "Pickup" on a stop.
// Flow:
//   1. Sheet opens — location is fetched immediately in the background.
//   2. Driver taps "Take Pickup Photo" → camera opens.
//   3. Photo is shown as a preview thumbnail.
//   4. Location label shows lat/lon once available, or a warning if denied.
//   5. Driver taps "Confirm Pickup" → sheet closes and returns PickupPhotoResult.
//   6. Route map screen calls the API with photo + coords.
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../widgets/qr_scanner_screen.dart';
import '../theme/route_map_theme.dart';

// ── Result returned to the caller ─────────────────────────────────────────

class PickupPhotoResult {
  const PickupPhotoResult({
    required this.photoPath,
    required this.latitude,
    required this.longitude,
    this.qrCode,
  });

  final String photoPath;
  final double latitude;
  final double longitude;
  final String? qrCode;
}

// ── Public helper: show the sheet and await result ────────────────────────

Future<PickupPhotoResult?> showPickupPhotoSheet(
    BuildContext context, {
      required String stopAddress,
    }) {
  return showModalBottomSheet<PickupPhotoResult>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    // Constrain sheet to at most 85% of screen height so it never goes full screen.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => _PickupPhotoSheet(stopAddress: stopAddress),
  );
}

// ── Public helper: full-screen "Picked Up!" confirmation ──────────────────
//
// Shared by every screen that confirms a pickup (route map + route detail)
// so the success animation stays identical and isn't duplicated.

Future<void> showPickupSuccess(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: RouteColors.teal.withOpacity(0.96),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, _, _) => const PickupSuccessContent(),
  );
}

class PickupSuccessContent extends StatefulWidget {
  const PickupSuccessContent({super.key});

  @override
  State<PickupSuccessContent> createState() => _PickupSuccessContentState();
}

class _PickupSuccessContentState extends State<PickupSuccessContent> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 38, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text('Picked Up!',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('Moving to next stop…',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85))),
        ],
      ),
    );
  }
}

// ── Sheet widget ──────────────────────────────────────────────────────────

class _PickupPhotoSheet extends StatefulWidget {
  const _PickupPhotoSheet({required this.stopAddress});
  final String stopAddress;

  @override
  State<_PickupPhotoSheet> createState() => _PickupPhotoSheetState();
}

class _PickupPhotoSheetState extends State<_PickupPhotoSheet> {
  // ── State ──────────────────────────────────────────────────────────────
  String?  _photoPath;
  double?  _latitude;
  double?  _longitude;
  double?  _accuracy;
  String?  _qrCode;

  bool    _locationLoading = true;
  String? _locationError;
  bool    _isConfirming    = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  // ── Location ───────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError   = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationLoading = false;
          _locationError   = 'Location services are off. Please enable GPS.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationLoading = false;
          _locationError   = permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable it in Settings.'
              : 'Location permission denied. Please allow access.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit:       const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _latitude        = pos.latitude;
          _longitude       = pos.longitude;
          _accuracy        = pos.accuracy;
          _locationLoading = false;
          _locationError   = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _locationError   = 'Could not get location. Tap retry to try again.';
        });
      }
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    final XFile? file = await _picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 72,
      maxWidth:     1920,
    );
    if (file != null && mounted) {
      setState(() => _photoPath = file.path);
    }
  }

  // ── QR scan ────────────────────────────────────────────────────────────

  Future<void> _scanQrCode() async {
    final code = await scanQrCode(context);
    if (code != null && code.isNotEmpty && mounted) {
      setState(() => _qrCode = code);
    }
  }

  // ── Confirm ────────────────────────────────────────────────────────────

  void _confirm() {
    if (_photoPath == null || _latitude == null || _longitude == null) {
      return;
    }
    setState(() => _isConfirming = true);
    Navigator.of(context).pop(
      PickupPhotoResult(
        photoPath: _photoPath!,
        latitude:  _latitude!,
        longitude: _longitude!,
        qrCode:    _qrCode,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  bool get _hasPhoto     => _photoPath != null;
  bool get _hasLocation  => _latitude != null && _longitude != null;
  bool get _hasQrCode    => _qrCode != null && _qrCode!.isNotEmpty;
  bool get _canConfirm   =>
      _hasPhoto && _hasLocation && !_isConfirming;

  String get _locationLabel {
    if (_locationLoading) return 'Getting location…';
    if (_locationError != null) return _locationError!;
    if (_hasLocation) {
      final lat = _latitude!.toStringAsFixed(5);
      final lon = _longitude!.toStringAsFixed(5);
      final acc = _accuracy?.toStringAsFixed(0) ?? '?';
      return '$lat, $lon  ±${acc}m';
    }
    return 'Location unavailable';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Container(
        decoration: const BoxDecoration(
          color:        RouteColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Let the sheet be as tall as its content needs, but scrollable if content
        // overflows (e.g. on small phones).
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisSize:      MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Handle ──────────────────────────────────────────────────
              Center(
                child: Container(
                  margin:      const EdgeInsets.only(top: 12, bottom: 8),
                  width:       40,
                  height:      4,
                  decoration:  BoxDecoration(
                    color:        RouteColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding:     const EdgeInsets.all(8),
                      decoration:  BoxDecoration(
                        color:        RouteColors.tealDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_pharmacy_rounded,
                        color: RouteColors.tealDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Pickup',
                            style: RouteText.title(RouteColors.textPrimary),
                          ),
                          Text(
                            widget.stopAddress.isNotEmpty
                                ? widget.stopAddress
                                : 'Take a photo to confirm pickup',
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis,
                            style: RouteText.body(RouteColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: RouteColors.cardBorder),
              const SizedBox(height: 12),

              // ── Photo section ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _hasPhoto
                    ? _PhotoPreview(
                  path:       _photoPath!,
                  onRetake:   _openCamera,
                )
                    : _CameraButton(onTap: _openCamera),
              ),

              const SizedBox(height: 12),

              // ── QR code section ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _hasQrCode
                    ? _QrCodeRow(
                  code:     _qrCode!,
                  onRescan: _scanQrCode,
                )
                    : _QrScanButton(onTap: _scanQrCode),
              ),

              const SizedBox(height: 12),

              // ── Location section ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LocationRow(
                  label:       _locationLabel,
                  isLoading:   _locationLoading,
                  hasError:    _locationError != null,
                  hasLocation: _hasLocation,
                  onRetry:     _fetchLocation,
                ),
              ),

              const SizedBox(height: 16),

              // ── Confirm button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canConfirm ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:         RouteColors.accentGreen,
                      disabledBackgroundColor: RouteColors.disabledFill,
                      foregroundColor:         Colors.white,
                      disabledForegroundColor: Colors.white70,
                      elevation:  0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isConfirming
                        ? const SizedBox(
                      width:  20,
                      height: 20,
                      child:  CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:  AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          !_hasPhoto
                              ? 'Take photo first'
                              : !_hasLocation
                              ? 'Waiting for location…'
                              : 'Confirm Pickup',
                          style: RouteText.button(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
    }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height:     110,
        decoration: BoxDecoration(
          color:        RouteColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: RouteColors.cardBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding:    const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:        RouteColors.tealDark.withOpacity(0.08),
                shape:        BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: RouteColors.tealDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Take Pickup Photo',
              style: RouteText.body(RouteColors.tealDark).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Required for pickup confirmation',
              style: RouteText.body(RouteColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.path, required this.onRetake});
  final String       path;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(path),
            height:  110,
            width:   double.infinity,
            fit:     BoxFit.cover,
          ),
        ),
        Positioned(
          top:   8,
          right: 8,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('Retake', style: RouteText.body(Colors.white)),
                ],
              ),
            ),
          ),
        ),
        // Green checkmark badge
        Positioned(
          bottom: 8,
          left:   8,
          child: Container(
            padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        RouteColors.accentGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text('Photo ready', style: RouteText.body(Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QrScanButton extends StatelessWidget {
  const _QrScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        RouteColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: RouteColors.cardBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:    const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RouteColors.tealDark.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: RouteColors.tealDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan QR Code',
                    style: RouteText.body(RouteColors.tealDark).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Optional',
                    style: RouteText.body(RouteColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: RouteColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCodeRow extends StatelessWidget {
  const _QrCodeRow({required this.code, required this.onRescan});
  final String       code;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        RouteColors.accentGreen.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RouteColors.accentGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            color: RouteColors.accentGreen,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:    RouteText.body(RouteColors.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: onRescan,
            child: Text(
              'Rescan',
              style: RouteText.body(RouteColors.tealDark).copyWith(
                fontWeight:  FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.isLoading,
    required this.hasError,
    required this.hasLocation,
    required this.onRetry,
  });

  final String       label;
  final bool         isLoading;
  final bool         hasError;
  final bool         hasLocation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = hasError
        ? Colors.orange
        : hasLocation
        ? RouteColors.accentGreen
        : RouteColors.textSecondary;

    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        hasError
            ? Colors.orange.withOpacity(0.07)
            : hasLocation
            ? RouteColors.accentGreen.withOpacity(0.07)
            : RouteColors.background,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: hasError
              ? Colors.orange.withOpacity(0.3)
              : hasLocation
              ? RouteColors.accentGreen.withOpacity(0.3)
              : RouteColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          isLoading
              ? SizedBox(
            width:  16,
            height: 16,
            child:  CircularProgressIndicator(
              strokeWidth: 2,
              color:       iconColor,
            ),
          )
              : Icon(
            hasError
                ? Icons.location_off_rounded
                : Icons.location_on_rounded,
            color: iconColor,
            size:  18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: RouteText.body(
                hasError ? Colors.orange.shade800 : RouteColors.textPrimary,
              ),
            ),
          ),
          if (hasError || (!hasLocation && !isLoading))
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Retry',
                style: RouteText.body(RouteColors.tealDark).copyWith(
                  fontWeight:  FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}