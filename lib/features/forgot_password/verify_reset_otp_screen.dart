// lib/features/forgot_password/verify_reset_otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_dialougs.dart';
import '../../widgets/app_progress_dialoug.dart';
import 'provider/forgot_password_provider.dart';
import 'reset_password_screen.dart';

class VerifyResetOtpScreen extends ConsumerStatefulWidget {
  const VerifyResetOtpScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<VerifyResetOtpScreen> createState() =>
      _VerifyResetOtpScreenState();
}

class _VerifyResetOtpScreenState
    extends ConsumerState<VerifyResetOtpScreen> {
  final List<TextEditingController> _otpControllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  bool _isProgressVisible = false;
  Timer? _timer;
  int _seconds = 59;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Timer ─────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        t.cancel();
      }
    });
  }

  String get _timerDisplay {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  // ── Progress helpers ──────────────────────────────────────

  void _showProgressDialog() {
    if (_isProgressVisible) return;
    _isProgressVisible = true;
    AppProgressDialog.show(context, message: 'Verifying OTP...');
  }

  void _hideProgressDialog() {
    if (!_isProgressVisible) return;
    _isProgressVisible = false;
    AppProgressDialog.hide(context);
  }

  // ── State listener ────────────────────────────────────────

  void _handleStateChange(
      ForgotPasswordState? previous,
      ForgotPasswordState next,
      ) {
    if (!mounted) return;

    if (next.isVerifyLoading) {
      _showProgressDialog();
      return;
    }

    if (previous?.isVerifyLoading == true) {
      _hideProgressDialog();
    }

    if (next.isVerifyNoInternet) {
      AppDialogs.showNoInternet(context);
      return;
    }

    if (next.isVerifySuccess) {
      _navigateToResetPassword();
    }
  }

  // ── Navigation ────────────────────────────────────────────

  void _navigateToResetPassword() {
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ResetPasswordScreen(
          email: widget.email,
          otp: _otp,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────

  void _handleSubmit() {
    FocusScope.of(context).unfocus();
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit OTP.')),
      );
      return;
    }
    ref.read(forgotPasswordProvider.notifier).verifyOtp(
      email: widget.email,
      otp: _otp,
    );
  }

  void _handleResend() {
    if (_seconds > 0) return;
    // Re-trigger sendOtp through the same provider to keep state clean
    ref.read(forgotPasswordProvider.notifier).sendOtp(widget.email);
    for (final c in _otpControllers) {
      c.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes[0]);
    _startTimer();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);

    ref.listen<ForgotPasswordState>(
      forgotPasswordProvider,
      _handleStateChange,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            color: AppColors.textDark,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Verify Reset OTP',
            style: AppTextStyles.screenTitle.copyWith(fontSize: 17),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // ── Form card ────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textDark.withValues(alpha: 0.07),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Email (read-only, prefilled) ──
                      Text('Email', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: widget.email,
                        readOnly: true,
                        style: AppTextStyles.inputText
                            .copyWith(color: AppColors.textMuted),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.email_outlined,
                                size: 20, color: AppColors.textMuted),
                          ),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: _border(AppColors.border, 1.2),
                          enabledBorder: _border(AppColors.border, 1.2),
                          focusedBorder: _border(AppColors.border, 1.2),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── OTP label ─────────────────────
                      Text('Enter OTP', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 12),

                      // ── 6-digit OTP boxes ─────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                              (i) => _OtpBox(
                            controller: _otpControllers[i],
                            focusNode: _focusNodes[i],
                            nextFocus: i < 5 ? _focusNodes[i + 1] : null,
                            prevFocus: i > 0 ? _focusNodes[i - 1] : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Sent confirmation ─────────────────────
                Text(
                  'OTP sent to your registered email.',
                  style: AppTextStyles.screenSubtitle,
                ),
                const SizedBox(height: 8),

                // ── Resend timer ──────────────────────────
                GestureDetector(
                  onTap: _seconds == 0 ? _handleResend : null,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Resend OTP in ',
                          style: AppTextStyles.screenSubtitle,
                        ),
                        TextSpan(
                          text: _seconds > 0 ? _timerDisplay : 'Resend now',
                          style: AppTextStyles.screenSubtitle.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: _seconds == 0
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── API error banner ──────────────────────
                if (state.isVerifyError &&
                    state.verifyErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(state.verifyErrorMessage!),
                ],

                const SizedBox(height: 28),

                // ── Submit button ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                    state.isVerifyLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: AppTextStyles.buttonText,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

// ── Single OTP digit box ──────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    this.prevFocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTextStyles.screenTitle.copyWith(fontSize: 22),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: EdgeInsets.zero,
          border: _border(AppColors.border, 1.2),
          enabledBorder: _border(AppColors.border, 1.2),
          focusedBorder: _border(AppColors.primary, 2),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else if (value.isEmpty && prevFocus != null) {
            FocusScope.of(context).requestFocus(prevFocus);
          }
        },
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

// ── Shared error banner ───────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.errorText.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}