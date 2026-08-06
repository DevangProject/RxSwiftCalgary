import 'package:flutter/material.dart';

/// Reusable dialog/snackbar helpers used throughout the app.
///
/// Always call these with a valid [BuildContext] from the widget tree.
class AppDialogs {
  AppDialogs._();

  // ── No-internet dialog ───────────────────────────────────────

  static Future<void> showNoInternet(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NoInternetDialog(),
    );
  }

  // ── Generic error dialog ─────────────────────────────────────

  static Future<void> showError(
      BuildContext context, {
        required String message,
        String title = 'Something went wrong',
      }) {
    return showDialog(
      context: context,
      builder: (_) => _AlertDialog(title: title, message: message),
    );
  }

  // ── SnackBar (lighter-weight) ────────────────────────────────

  static void showSnackBar(
      BuildContext context,
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

// ── Private widgets ──────────────────────────────────────────

class _NoInternetDialog extends StatelessWidget {
  const _NoInternetDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          const Text(
            'No Internet',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: const Text(
        'You are not connected to the internet.\nPlease check your network settings and try again.',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'OK',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlertDialog extends StatelessWidget {
  const _AlertDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'OK',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}