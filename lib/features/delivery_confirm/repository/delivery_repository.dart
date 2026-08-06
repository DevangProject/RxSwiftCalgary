// ============================================================================
// lib/features/delivery_confirm/repository/delivery_repository.dart
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart' show TextAlign;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_result.dart';
import '../data/delivery_remote_datasource.dart';
import '../domain/delivery_state.dart';

// ── Typed exceptions ──────────────────────────────────────────────────────

class NoInternetException implements Exception {}

class UploadFailedException implements Exception {
  UploadFailedException(this.message);
  final String message;
}

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
}

// ── Offline-queue value object ────────────────────────────────────────────

class PendingUpload {
  const PendingUpload({required this.photoPath, this.location});
  final String photoPath;
  final CaptureLocation? location;
}

// ── Repository ────────────────────────────────────────────────────────────

class DeliveryRepository {
  DeliveryRepository({required DeliveryRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final DeliveryRemoteDataSource _remote;
  final _picker = ImagePicker();

  static const _kPendingPhoto   = 'pending_delivery_photo';
  static const _kPendingLat     = 'pending_delivery_lat';
  static const _kPendingLon     = 'pending_delivery_lon';
  static const _kPendingAddress = 'pending_delivery_address';

  // ── Connectivity stream ───────────────────────────────────────────────────

  Stream<bool> get onConnectivityChanged => Connectivity()
      .onConnectivityChanged
      .map((r) => r != ConnectivityResult.none);

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<String?> captureFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,   // first-pass reduction before upload compression
    );
    return xFile?.path;
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<CaptureLocation> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw LocationException('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Location permission permanently denied. Enable it in Settings.');
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    return CaptureLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      formattedAddress:
      '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
    );
  }

  // ── Location stamp ────────────────────────────────────────────────────────

  Future<String> stampLocationOnImage({
    required String photoPath,
    required CaptureLocation location,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src   = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas   = ui.Canvas(recorder);
    canvas.drawImage(src, ui.Offset.zero, ui.Paint());

    final stamp =
        '${location.formattedAddress}  ±${location.accuracy.toStringAsFixed(0)} m';

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: src.height * 0.025,
        fontFamily: 'sans-serif',
        textAlign: TextAlign.left,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const ui.Color(0xFFFFFFFF),
        background: ui.Paint()..color = const ui.Color(0xAA000000),
      ))
      ..addText('  $stamp  ');

    final para = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: src.width.toDouble()));

    canvas.drawParagraph(
      para,
      ui.Offset(0, src.height - para.height - src.height * 0.015),
    );

    final picture    = recorder.endRecording();
    final stampedImg = await picture.toImage(src.width, src.height);
    final pngBytes   =
    await stampedImg.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) throw Exception('Failed to encode stamped image.');

    final dir     = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/stamped_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(pngBytes.buffer.asUint8List());
    return outPath;
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  //
  // onProgress parameter removed — DioClient.post() does not expose
  // onSendProgress. The loading indicator is still shown via DeliveryStatus.uploading.

  Future<void> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
    CaptureLocation? location,
  }) async {
    final result = await _remote.uploadDeliveryPhoto(
      orderId: orderId,
      photoPath: photoPath,
    );

    result.when(
      success: (_) async {
        await _clearPending();
      },
      failure: (exception) {
        final msg = exception.toString().toLowerCase();
        if (exception.runtimeType.toString().contains('NoInternet') ||
            msg.contains('internet') ||
            msg.contains('connection') ||
            msg.contains('network')) {
          _savePending(photoPath: photoPath, location: location);
          throw NoInternetException();
        }
        String? readable;
        try {
          readable = (exception as dynamic).message as String?;
        } catch (_) {}
        final message = (readable != null && readable.isNotEmpty)
            ? readable
            : (exception.toString().isNotEmpty
            ? exception.toString()
            : 'Upload failed. Please retry.');

        throw UploadFailedException(message);
      },
    );
  }

  // ── Offline queue ─────────────────────────────────────────────────────────

  Future<void> _savePending({
    required String photoPath,
    CaptureLocation? location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingPhoto, photoPath);
    if (location != null) {
      await prefs.setDouble(_kPendingLat, location.latitude);
      await prefs.setDouble(_kPendingLon, location.longitude);
      await prefs.setString(_kPendingAddress, location.formattedAddress);
    }
  }

  Future<void> _clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingPhoto);
    await prefs.remove(_kPendingLat);
    await prefs.remove(_kPendingLon);
    await prefs.remove(_kPendingAddress);
  }

  Future<PendingUpload?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString(_kPendingPhoto);
    if (path == null) return null;

    final lat  = prefs.getDouble(_kPendingLat);
    final lon  = prefs.getDouble(_kPendingLon);
    final addr = prefs.getString(_kPendingAddress);

    CaptureLocation? loc;
    if (lat != null && lon != null) {
      loc = CaptureLocation(
        latitude: lat,
        longitude: lon,
        accuracy: 0,
        formattedAddress: addr ?? '$lat, $lon',
      );
    }
    return PendingUpload(photoPath: path, location: loc);
  }
}