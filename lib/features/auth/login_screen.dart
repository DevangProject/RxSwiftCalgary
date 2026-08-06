import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxswift/features/auth/provider/auth_provider.dart';

import '../../service/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialougs.dart';
import '../../widgets/app_progress_dialoug.dart';
import '../../widgets/rxswift_logo.dart';
import '../forgot_password/forgot_password_screen.dart';
import '../today_route/today_route_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _isProgressVisible = false;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
  );

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: LoginUiConstants.animationDuration,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();

    super.dispose();
  }

  void _submit() {
    _emailController.text = "vaghelacd99@gmail.com" ;
    _passwordController.text = "12345678";

    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    ref.read(authProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _handleAuthStateChange(AuthState? previous, AuthState next) {
    if (!mounted) return;

    if (next.isLoading) {
      _showProgressDialog();
      return;
    }

    if (previous?.isLoading == true) {
      _hideProgressDialog();
    }

    if (next.isNoInternet) {
      AppDialogs.showNoInternet(context);
      return;
    }

    if (next.isSuccess) {
      ref.read(notificationServiceProvider).registerDeviceToken();
      _navigateToTodayRoute();
    }
  }

  void _showProgressDialog() {
    if (_isProgressVisible) return;

    _isProgressVisible = true;

    AppProgressDialog.show(
      context,
      message: 'Signing you in...',
    );
  }

  void _hideProgressDialog() {
    if (!_isProgressVisible) return;

    _isProgressVisible = false;

    AppProgressDialog.hide(context);
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const ForgotPasswordScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _navigateToTodayRoute() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const TodayRouteScaffold(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: LoginUiConstants.routeTransitionDuration,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email.';
    }

    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(
      authProvider,
      _handleAuthStateChange,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 48),
                                const RxSwiftLogo(),
                                const SizedBox(height: 40),
                                const Text(
                                  'Welcome Back',
                                  style: AppTextStyles.screenTitle,
                                ),

                                const SizedBox(height: 6),

                                const Text(
                                  'Please login to continue',
                                  style: AppTextStyles.screenSubtitle,
                                ),

                                const SizedBox(height: 32),

                                _LoginFormCard(
                                  children: [
                                    const _FieldLabel('Email'),

                                    const SizedBox(height: 8),

                                    _AppTextField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      hintText: 'driver@rxswift.com',
                                      prefixIcon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: _validateEmail,
                                      onSubmitted: (_) {
                                        _passwordFocusNode.requestFocus();
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    const _FieldLabel('Password'),
                                    const SizedBox(height: 8),
                                    _AppTextField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocusNode,
                                      hintText: '••••••••',
                                      prefixIcon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      validator: _validatePassword,
                                      suffixIcon: IconButton(
                                        onPressed: _togglePasswordVisibility,
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                      ),
                                      onSubmitted: (_) => _submit(),
                                    ),

                                    const SizedBox(height: 8),

                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _navigateToForgotPassword,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot Password?',
                                          style: AppTextStyles.linkText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                if (authState.isError &&
                                    authState.errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorBanner(authState.errorMessage!),
                                ],

                                const SizedBox(height: 28),

                                _LoginButton(
                                  isLoading: authState.isLoading,
                                  onPressed: _submit,
                                ),

                                const SizedBox(height: 20),

                                const _SecureLoginDivider(),

                                const SizedBox(height: 32),

                                TextButton(
                                  onPressed: null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.textMuted,
                                  ),
                                  child: const Text(
                                    'Need help? Contact Support',
                                    style: AppTextStyles.supportText,
                                  ),
                                ),

                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginUiConstants {
  const LoginUiConstants._();

  static const String fontFamily = 'Poppins';

  static const Duration animationDuration = Duration(milliseconds: 600);
  static const Duration routeTransitionDuration = Duration(milliseconds: 400);
  static const Duration switcherDuration = Duration(milliseconds: 250);
}

class LoginColors {
  const LoginColors._();
}
class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.fieldLabel,
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.inputHint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            prefixIcon,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(AppColors.border, 1.2),
        enabledBorder: _inputBorder(AppColors.border, 1.2),
        focusedBorder: _inputBorder(AppColors.primary, 2),
        errorBorder: _inputBorder(AppColors.error, 1.5),
        focusedErrorBorder: _inputBorder(AppColors.error, 2),
        errorStyle: AppTextStyles.errorText,
      ),
    );
  }

  OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: color,
        width: width,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
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

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: LoginUiConstants.switcherDuration,
          child: isLoading
              ? const SizedBox(
            key: ValueKey('login_loader'),
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text(
            'Login',
            key: ValueKey('login_label'),
            style: AppTextStyles.buttonText,
          ),
        ),
      ),
    );
  }
}

class _SecureLoginDivider extends StatelessWidget {
  const _SecureLoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: AppColors.border,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Secure login',
            style: AppTextStyles.buttonText.copyWith(fontSize: 11),
          ),
        ),
        const Expanded(
          child: Divider(
            color: AppColors.border,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}