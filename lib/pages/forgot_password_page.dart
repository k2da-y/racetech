import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Landing / Verify Email)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _dark = Color(0xFF0F172A);
const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _fieldFill = Color(0xFFF8FAFC);
const _success = Color(0xFF16A34A);
const _successSoft = Color(0xFFDCFCE7);
const _warning = Color(0xFFF59E0B);
const _error = Color(0xFFE11D48);

const int _codeLength = 6;
const int _minPasswordLength = 8;
const int _resendCooldownSeconds = 60;

enum _ResetStep { email, code, password }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeFocusNode = FocusNode();

  bool isLoading = false;
  bool codeSent = false;
  bool codeVerified = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  /// Inline error messages (shown under the relevant field).
  String? emailError;
  String? codeError;
  bool showPasswordErrors = false;

  int resendCooldown = 0;
  Timer? cooldownTimer;

  _ResetStep get step => codeVerified
      ? _ResetStep.password
      : codeSent
      ? _ResetStep.code
      : _ResetStep.email;

  @override
  void initState() {
    super.initState();
    codeController.addListener(onCodeChanged);
    emailController.addListener(() {
      if (emailError != null) setState(() => emailError = null);
    });
    passwordController.addListener(() => setState(() {}));
    confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    cooldownTimer?.cancel();
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // STEP 1 — SEND CODE (same API call)
  // ============================================================

  bool looksLikeEmail(String value) =>
      RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value);

  Future<void> sendResetCode({bool isResend = false}) async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() => emailError = "Please enter your email address");
      return;
    }

    if (!looksLikeEmail(email)) {
      setState(() => emailError = "Enter a valid email address");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    final result = await ApiService().forgotPassword(email);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      // Only move forward on success. A failed *resend* no longer kicks the
      // user back to the email step (the old code reset codeSent to false).
      if (result == ForgotPasswordResult.success) codeSent = true;
    });

    if (result == ForgotPasswordResult.success) {
      startCooldown();
      clearCode();
      showMessage(
        isResend
            ? "A new reset code was sent to your email."
            : "Reset code sent to your email.",
      );
      WidgetsBinding.instance.addPostFrameCallback(
            (_) => codeFocusNode.requestFocus(),
      );
      return;
    }

    final message = switch (result) {
      ForgotPasswordResult.invalidEmail =>
      "We could not find an account with that email.",
      ForgotPasswordResult.networkError =>
      "Cannot connect to the server. Check your API connection.",
      ForgotPasswordResult.serverError => "Server error. Please try again.",
      ForgotPasswordResult.success => "",
    };

    if (result == ForgotPasswordResult.invalidEmail && !codeSent) {
      setState(() => emailError = message);
    } else {
      showMessage(message);
    }
  }

  void startCooldown() {
    cooldownTimer?.cancel();
    setState(() => resendCooldown = _resendCooldownSeconds);

    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() => resendCooldown--);
      if (resendCooldown <= 0) timer.cancel();
    });
  }

  // ============================================================
  // STEP 2 — VERIFY CODE (same API call)
  // ============================================================

  void onCodeChanged() {
    setState(() => codeError = null);

    if (step == _ResetStep.code &&
        codeController.text.length == _codeLength &&
        !isLoading) {
      verifyCode();
    }
  }

  void clearCode() {
    codeController.removeListener(onCodeChanged);
    codeController.clear();
    codeController.addListener(onCodeChanged);
  }

  Future<void> verifyCode() async {
    final email = emailController.text.trim();
    final code = codeController.text.trim();

    if (code.length != _codeLength) {
      setState(() => codeError = "Please enter the 6-digit code");
      codeFocusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    final result = await ApiService().verifyResetCode(email: email, code: code);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      codeVerified = result == VerifyResetCodeResult.success;
    });

    if (result == VerifyResetCodeResult.success) {
      HapticFeedback.mediumImpact();
      showMessage("Code verified. Enter your new password.");
      return;
    }

    final message = switch (result) {
      VerifyResetCodeResult.invalidCode => "Invalid or expired reset code.",
      VerifyResetCodeResult.networkError =>
      "Cannot connect to the server. Check your API connection.",
      VerifyResetCodeResult.serverError => "Server error. Please try again.",
      VerifyResetCodeResult.success => "",
    };

    if (result == VerifyResetCodeResult.invalidCode) {
      HapticFeedback.heavyImpact();
      clearCode();
      setState(() => codeError = message);
      codeFocusNode.requestFocus();
    } else {
      showMessage(message);
    }
  }

  // ============================================================
  // STEP 3 — RESET PASSWORD (same API call and values sent)
  // ============================================================

  String? get passwordError {
    if (!showPasswordErrors) return null;
    final password = passwordController.text.trim();
    if (password.isEmpty) return "Enter a new password";
    if (password.length < _minPasswordLength) {
      return "Use at least $_minPasswordLength characters";
    }
    return null;
  }

  String? get confirmError {
    if (!showPasswordErrors) return null;
    final confirm = confirmPasswordController.text.trim();
    if (confirm.isEmpty) return "Re-enter your new password";
    if (confirm != passwordController.text.trim()) {
      return "Passwords do not match";
    }
    return null;
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final code = codeController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (!codeVerified) {
      showMessage("Please verify your reset code first");
      return;
    }

    if (password.isEmpty ||
        confirmPassword.isEmpty ||
        password.length < _minPasswordLength ||
        password != confirmPassword) {
      setState(() => showPasswordErrors = true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);
    final result = await ApiService().resetPassword(
      email: email,
      code: code,
      password: password,
      passwordConfirmation: confirmPassword,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result == ResetPasswordResult.success) {
      HapticFeedback.mediumImpact();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PasswordUpdatedDialog(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    final message = switch (result) {
      ResetPasswordResult.invalidCodeOrPassword =>
      "Invalid code, expired code, or password is too short.",
      ResetPasswordResult.networkError =>
      "Cannot connect to the server. Check your API connection.",
      ResetPasswordResult.serverError => "Server error. Please try again.",
      ResetPasswordResult.success => "",
    };

    showMessage(message);
  }

  // ============================================================
  // NAVIGATION BETWEEN STEPS
  // ============================================================

  /// Back goes to the previous step first, then leaves the page.
  void goBack() {
    if (isLoading) return;

    switch (step) {
      case _ResetStep.password:
        setState(() {
          codeVerified = false;
          passwordController.clear();
          confirmPasswordController.clear();
          showPasswordErrors = false;
        });
        clearCode();
        codeFocusNode.requestFocus();
      case _ResetStep.code:
        changeEmail();
      case _ResetStep.email:
        Navigator.pop(context);
    }
  }

  void changeEmail() {
    if (isLoading) return;
    clearCode();
    setState(() {
      codeSent = false;
      codeError = null;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading && step == _ResetStep.email,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _dark,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                "assets/login_bg.jpg",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryDeep, _dark],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _dark.withValues(alpha: 0.45),
                      _dark.withValues(alpha: 0.6),
                      _dark.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -110,
                right: -90,
                child: _Glow(color: _primary.withValues(alpha: 0.28), size: 280),
              ),
              Positioned(
                bottom: 80,
                left: -130,
                child: _Glow(color: _accent.withValues(alpha: 0.16), size: 260),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: "Back",
                            onTap: isLoading ? null : goBack,
                          ),
                          const Expanded(child: _Brand()),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: resetCard(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget resetCard() {
    final (icon, title, subtitle) = switch (step) {
      _ResetStep.email => (
      Icons.lock_reset_rounded,
      "Forgot password?",
      "Enter your email and we'll send you a 6-digit reset code.",
      ),
      _ResetStep.code => (
      Icons.mark_email_unread_outlined,
      "Enter reset code",
      null,
      ),
      _ResetStep.password => (
      Icons.lock_outline_rounded,
      "Create new password",
      "Use at least $_minPasswordLength characters for your new password.",
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIndicator(current: step.index),

          const SizedBox(height: 22),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(step),
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: _primary, size: 32),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          if (subtitle != null)
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            )
          else
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(text: "We sent a 6-digit code to\n"),
                  TextSpan(
                    text: emailController.text.trim(),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 24),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(step),
              child: switch (step) {
                _ResetStep.email => emailStep(),
                _ResetStep.code => codeStep(),
                _ResetStep.password => passwordStep(),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Step widgets ----------------

  Widget emailStep() {
    return Column(
      children: [
        TextField(
          controller: emailController,
          enabled: !isLoading,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          onSubmitted: (_) => sendResetCode(),
          cursorColor: _primary,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: "Email address",
            icon: Icons.email_outlined,
            errorText: emailError,
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: isLoading ? "Sending..." : "Send Reset Code",
          isLoading: isLoading,
          onPressed: isLoading ? null : () => sendResetCode(),
        ),
      ],
    );
  }

  Widget codeStep() {
    final canResend = !isLoading && resendCooldown == 0;

    return Column(
      children: [
        _CodeInput(
          controller: codeController,
          focusNode: codeFocusNode,
          enabled: !isLoading,
          hasError: codeError != null,
        ),
        _InlineError(message: codeError, centered: true),
        const SizedBox(height: 22),
        _PrimaryButton(
          label: isLoading ? "Verifying..." : "Verify Code",
          isLoading: isLoading,
          onPressed: isLoading ? null : verifyCode,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Didn't get the code?",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: canResend
                    ? () => sendResetCode(isResend: true)
                    : null,
                style: _linkButtonStyle,
                child: Text(
                  resendCooldown > 0
                      ? "Resend in ${resendCooldown}s"
                      : "Send again",
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: isLoading ? null : changeEmail,
          style: _linkButtonStyle,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text("Use a different email"),
        ),
      ],
    );
  }

  Widget passwordStep() {
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();
    final matches = confirm.isNotEmpty && confirm == password;

    return Column(
      children: [
        TextField(
          controller: passwordController,
          enabled: !isLoading,
          autofocus: true,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          cursorColor: _primary,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: "New password",
            icon: Icons.lock_outline_rounded,
            errorText: passwordError,
            suffixIcon: _VisibilityToggle(
              obscured: obscurePassword,
              onTap: () => setState(() => obscurePassword = !obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PasswordStrength(password: password),
        const SizedBox(height: 14),
        TextField(
          controller: confirmPasswordController,
          enabled: !isLoading,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => resetPassword(),
          cursorColor: _primary,
          style: _fieldTextStyle,
          decoration: _fieldDecoration(
            label: "Confirm password",
            icon: Icons.lock_outline_rounded,
            errorText: confirmError,
            helperText: matches ? "Passwords match" : null,
            suffixIcon: _VisibilityToggle(
              obscured: obscureConfirm,
              onTap: () => setState(() => obscureConfirm = !obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: isLoading ? "Updating..." : "Update Password",
          isLoading: isLoading,
          onPressed: isLoading ? null : resetPassword,
        ),
      ],
    );
  }
}

// ============================================================
// SHARED STYLES
// ============================================================

const _fieldTextStyle = TextStyle(
  color: _ink,
  fontSize: 14.5,
  fontWeight: FontWeight.w600,
);

final ButtonStyle _linkButtonStyle = TextButton.styleFrom(
  foregroundColor: _primary,
  disabledForegroundColor: _faint,
  padding: const EdgeInsets.symmetric(horizontal: 10),
  minimumSize: const Size(0, 36),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
);

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? errorText,
  String? helperText,
  Widget? suffixIcon,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    errorText: errorText,
    helperText: helperText,
    labelStyle: const TextStyle(
      color: _muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
        color: states.contains(WidgetState.error) ? _error : _primary,
        fontWeight: FontWeight.w700,
      ),
    ),
    helperStyle: const TextStyle(
      color: _success,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    ),
    errorStyle: const TextStyle(
      color: _error,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
    ),
    prefixIcon: Icon(icon, color: _primary, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: _fieldFill,
    counterText: "",
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
    enabledBorder: outline(_border),
    disabledBorder: outline(_border),
    focusedBorder: outline(_primary, 1.5),
    errorBorder: outline(_error.withValues(alpha: 0.6)),
    focusedErrorBorder: outline(_error, 1.5),
    border: outline(_border),
  );
}

// ============================================================
// STEP INDICATOR
// ============================================================

class _StepIndicator extends StatelessWidget {
  final int current;

  const _StepIndicator({required this.current});

  static const _labels = ["Email", "Code", "Password"];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? _primary : _border,
              ),
            ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current
                      ? _primary
                      : i == current
                      ? _primarySoft
                      : _fieldFill,
                  border: Border.all(
                    color: i <= current ? _primary : _border,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: i < current
                      ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  )
                      : Text(
                    "${i + 1}",
                    style: TextStyle(
                      color: i == current ? _primaryDeep : _faint,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  color: i <= current ? _primaryDeep : _faint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ============================================================
// 6-BOX CODE INPUT (same as Verify Email page)
// ============================================================

class _CodeInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;

  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "6-digit reset code",
      textField: true,
      child: GestureDetector(
        onTap: enabled ? focusNode.requestFocus : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: "",
                  ),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final code = controller.text;
                final focused = focusNode.hasFocus;

                return Row(
                  children: [
                    for (var i = 0; i < _codeLength; i++) ...[
                      if (i > 0) SizedBox(width: i == 3 ? 14 : 8),
                      Expanded(
                        child: _CodeBox(
                          digit: i < code.length ? code[i] : "",
                          isActive:
                          focused &&
                              (i == code.length ||
                                  (code.length == _codeLength &&
                                      i == _codeLength - 1)),
                          hasError: hasError,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String digit;
  final bool isActive;
  final bool hasError;

  const _CodeBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    final borderColor = hasError
        ? _error
        : isActive
        ? _primary
        : filled
        ? _primary.withValues(alpha: 0.4)
        : _border;

    return AspectRatio(
      aspectRatio: 0.82,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasError
              ? _error.withValues(alpha: 0.05)
              : filled
              ? _primarySoft
              : _fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isActive || hasError ? 1.8 : 1.2,
          ),
        ),
        child: filled
            ? Text(
          digit,
          style: TextStyle(
            color: hasError ? _error : _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        )
            : isActive
            ? Container(
          width: 2,
          height: 22,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2),
          ),
        )
            : null,
      ),
    );
  }
}

// ============================================================
// PASSWORD STRENGTH
// ============================================================

class _PasswordStrength extends StatelessWidget {
  final String password;

  const _PasswordStrength({required this.password});

  @override
  Widget build(BuildContext context) {
    final longEnough = password.length >= _minPasswordLength;
    final hasNumber = RegExp(r"\d").hasMatch(password);
    final hasLetter = RegExp(r"[A-Za-z]").hasMatch(password);
    final hasMixedCase =
        RegExp(r"[a-z]").hasMatch(password) &&
            RegExp(r"[A-Z]").hasMatch(password);
    final hasSymbol = RegExp(r"[^A-Za-z0-9]").hasMatch(password);

    var score = 0;
    if (longEnough) score++;
    if (hasLetter && hasNumber) score++;
    if (hasMixedCase || hasSymbol) score++;

    final (label, color) = password.isEmpty
        ? ("", _border)
        : !longEnough
        ? ("Too short", _error)
        : switch (score) {
      1 => ("Fair", _warning),
      2 => ("Good", _primary),
      _ => ("Strong", _success),
    };
    final filledBars = password.isEmpty ? 0 : (!longEnough ? 1 : score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < filledBars ? color : _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Requirement(
              met: longEnough,
              label: "$_minPasswordLength+ characters",
            ),
            const SizedBox(width: 12),
            _Requirement(met: hasLetter && hasNumber, label: "Letters & numbers"),
            const Spacer(),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  final bool met;
  final String label;

  const _Requirement({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 13,
          color: met ? _success : _faint,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: met ? _success : _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SMALL PIECES
// ============================================================

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: disabled
              ? null
              : const LinearGradient(colors: [_primaryDeep, _primary]),
          color: disabled ? _primary.withValues(alpha: 0.55) : null,
          boxShadow: disabled
              ? null
              : [
            BoxShadow(
              color: _primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String? message;
  final bool centered;

  const _InlineError({required this.message, this.centered = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: _error,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message!,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: const TextStyle(
                  color: _error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onTap;

  const _VisibilityToggle({required this.obscured, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: obscured ? "Show password" : "Hide password",
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: _faint,
        size: 20,
      ),
    );
  }
}

class _PasswordUpdatedDialog extends StatelessWidget {
  const _PasswordUpdatedDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: _successSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.verified_user_rounded, color: _success, size: 34),
      ),
      title: const Text(
        "Password updated",
        style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
      ),
      content: const Text(
        "You can now log in with your new password.",
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Back to Login",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.flag_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text(
          "RACETECH",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;

  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}