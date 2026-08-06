// lib/features/forgot_password/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_dialougs.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../../widgets/rxswift_logo.dart';
import 'provider/forgot_password_provider.dart';
import 'verify_reset_otp_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;

  // Progress-dialog guard — same pattern as LoginScreen._isProgressVisible
  bool _isProgressVisible = false;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────

  bool _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email.');
      return false;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  // ── Progress helpers ──────────────────────────────────────

  void _showProgressDialog() {
    if (_isProgressVisible) return;
    _isProgressVisible = true;
    AppProgressDialog.show(context, message: 'Sending OTP...');
  }

  void _hideProgressDialog() {
    if (!_isProgressVisible) return;
    _isProgressVisible = false;
    AppProgressDialog.hide(context);
  }

  // ── State listener (mirrors _handleAuthStateChange) ───────

  void _handleStateChange(
      ForgotPasswordState? previous,
      ForgotPasswordState next,
      ) {
    if (!mounted) return;

    if (next.isForgotLoading) {
      _showProgressDialog();
      return;
    }

    if (previous?.isForgotLoading == true) {
      _hideProgressDialog();
    }

    if (next.isForgotNoInternet) {
      AppDialogs.showNoInternet(context);
      return;
    }

    if (next.isForgotSuccess) {
      _navigateToVerifyOtp();
    }
  }

  // ── Navigation ────────────────────────────────────────────

  void _navigateToVerifyOtp() {
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => VerifyResetOtpScreen(
          email: _emailController.text.trim(),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────

  void _handleSendOtp() {
    FocusScope.of(context).unfocus();
    if (!_validateEmail()) return;
    ref.read(forgotPasswordProvider.notifier).sendOtp(
      _emailController.text.trim(),
    );
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
            'Forgot Password',
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ── Logo ─────────────────────────────────
                const RxSwiftLogo(),
                const SizedBox(height: 32),

                // ── Subtitle ─────────────────────────────
                Text(
                  'Enter your registered email to receive an OTP.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenSubtitle,
                ),
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
                      Text('Email', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSendOtp(),
                        onChanged: (_) {
                          if (_emailError != null) _validateEmail();
                        },
                        style: AppTextStyles.inputText,
                        decoration: InputDecoration(
                          hintText: 'driver@rxswift.com',
                          hintStyle: AppTextStyles.inputHint,
                          errorText: _emailError,
                          errorStyle: AppTextStyles.errorText,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                          ),
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: _border(AppColors.border, 1.2),
                          enabledBorder: _border(AppColors.border, 1.2),
                          focusedBorder: _border(AppColors.primary, 2),
                          errorBorder: _border(AppColors.error, 1.5),
                          focusedErrorBorder: _border(AppColors.error, 2),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── API error banner ──────────────────────
                if (state.isForgotError &&
                    state.forgotErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(state.forgotErrorMessage!),
                ],

                const SizedBox(height: 28),

                // ── Send OTP button ───────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                    state.isForgotLoading ? null : _handleSendOtp,
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
                      'Send OTP',
                      style: AppTextStyles.buttonText,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Back to Login ─────────────────────────
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text(
                    'Back to Login',
                    style: AppTextStyles.supportText,
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

// ── Shared error banner (same as LoginScreen._ErrorBanner) ───

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