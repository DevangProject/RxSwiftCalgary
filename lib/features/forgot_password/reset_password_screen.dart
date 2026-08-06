// lib/features/forgot_password/reset_password_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_dialougs.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../auth/login_screen.dart';
import 'provider/forgot_password_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  final String email;
  final String otp;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends ConsumerState<ResetPasswordScreen> {
  final _newPasswordController    = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocus          = FocusNode();
  final _confirmPasswordFocus      = FocusNode();

  bool _showNewPassword     = false;
  bool _showConfirmPassword = false;
  bool _isProgressVisible   = false;
  bool _showSuccessBanner   = false;

  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────

  bool _validate() {
    bool valid = true;
    final newPwd     = _newPasswordController.text;
    final confirmPwd = _confirmPasswordController.text;

    if (newPwd.isEmpty) {
      setState(() => _newPasswordError = 'Please enter a new password.');
      valid = false;
    } else if (newPwd.length < 8) {
      setState(
              () => _newPasswordError = 'Password must be at least 8 characters.');
      valid = false;
    } else {
      setState(() => _newPasswordError = null);
    }

    if (confirmPwd.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password.');
      valid = false;
    } else if (newPwd != confirmPwd) {
      setState(() => _confirmPasswordError = 'Passwords do not match.');
      valid = false;
    } else {
      setState(() => _confirmPasswordError = null);
    }

    return valid;
  }

  // ── Progress helpers ──────────────────────────────────────

  void _showProgressDialog() {
    if (_isProgressVisible) return;
    _isProgressVisible = true;
    AppProgressDialog.show(context, message: 'Resetting password...');
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

    if (next.isResetLoading) {
      _showProgressDialog();
      return;
    }

    if (previous?.isResetLoading == true) {
      _hideProgressDialog();
    }

    if (next.isResetNoInternet) {
      AppDialogs.showNoInternet(context);
      return;
    }

    if (next.isResetSuccess) {
      setState(() => _showSuccessBanner = true);
      // Redirect to Login after 2 seconds — pop entire stack
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const LoginScreen(),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
              (_) => false,
        );
      });
    }
  }

  // ── Submit ────────────────────────────────────────────────

  void _handleSetPassword() {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;

    ref.read(forgotPasswordProvider.notifier).resetPassword(
      email:           widget.email,
      otp:             widget.otp,
      newPassword:     _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
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
            'Reset Password',
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
                      // ── Email (read-only) ─────────────
                      Text('Email', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      _ReadOnlyField(
                        value: widget.email,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),

                      // ── OTP (read-only) ───────────────
                      Text('OTP', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      _ReadOnlyField(
                        value: widget.otp,
                        icon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 20),

                      // ── New Password ──────────────────
                      Text('New Password', style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      _PasswordField(
                        controller: _newPasswordController,
                        focusNode: _newPasswordFocus,
                        nextFocus: _confirmPasswordFocus,
                        hintText: '••••••••',
                        showPassword: _showNewPassword,
                        errorText: _newPasswordError,
                        onToggle: () => setState(
                                () => _showNewPassword = !_showNewPassword),
                        onChanged: (_) {
                          if (_newPasswordError != null) _validate();
                        },
                      ),
                      const SizedBox(height: 20),

                      // ── Confirm Password ──────────────
                      Text('Confirm Password',
                          style: AppTextStyles.fieldLabel),
                      const SizedBox(height: 8),
                      _PasswordField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        hintText: '••••••••',
                        showPassword: _showConfirmPassword,
                        errorText: _confirmPasswordError,
                        onToggle: () => setState(() =>
                        _showConfirmPassword = !_showConfirmPassword),
                        onSubmitted: (_) => _handleSetPassword(),
                        onChanged: (_) {
                          if (_confirmPasswordError != null) _validate();
                        },
                      ),
                    ],
                  ),
                ),

                // ── API error banner ──────────────────────
                if (state.isResetError &&
                    state.resetErrorMessage != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(state.resetErrorMessage!),
                ],

                const SizedBox(height: 28),

                // ── Set Password button ───────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (state.isResetLoading || _showSuccessBanner)
                        ? null
                        : _handleSetPassword,
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
                      'Set Password',
                      style: AppTextStyles.buttonText,
                    ),
                  ),
                ),

                // ── Success banner ────────────────────────
                if (_showSuccessBanner) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password reset successful',
                              style: AppTextStyles.fieldLabel,
                            ),
                            Text(
                              'Redirecting to login...',
                              style: AppTextStyles.screenSubtitle
                                  .copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Read-only prefilled field ─────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, required this.icon});
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      style: AppTextStyles.inputText.copyWith(color: AppColors.textMuted),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, size: 20, color: AppColors.textMuted),
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(AppColors.border, 1.2),
        enabledBorder: _border(AppColors.border, 1.2),
        focusedBorder: _border(AppColors.border, 1.2),
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

// ── Password text field ───────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.showPassword,
    required this.onToggle,
    this.nextFocus,
    this.errorText,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final String hintText;
  final bool showPassword;
  final VoidCallback onToggle;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !showPassword,
      textInputAction:
      nextFocus != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (v) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        } else {
          onSubmitted?.call(v);
        }
      },
      onChanged: onChanged,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.inputHint,
        errorText: errorText,
        errorStyle: AppTextStyles.errorText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.lock_outline_rounded,
              size: 20, color: AppColors.textMuted),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(AppColors.border, 1.2),
        enabledBorder: _border(AppColors.border, 1.2),
        focusedBorder: _border(AppColors.primary, 2),
        errorBorder: _border(AppColors.error, 1.5),
        focusedErrorBorder: _border(AppColors.error, 2),
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
}

// ── Error banner ──────────────────────────────────────────────

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