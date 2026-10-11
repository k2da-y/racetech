import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_page.dart';
import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Landing page)
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
const _error = Color(0xFFE11D48);

const int _codeLength = 6;
const int _resendCooldownSeconds = 60;

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final codeController = TextEditingController();
  final codeFocusNode = FocusNode();

  bool isLoading = false;
  bool isResending = false;

  /// Shown under the code boxes (and turns them red) after a failed attempt.
  String? codeError;

  /// Seconds left before "Send Code Again" can be tapped again.
  int resendCooldown = 0;
  Timer? cooldownTimer;

  bool get isBusy => isLoading || isResending;

  @override
  void initState() {
    super.initState();
    codeController.addListener(onCodeChanged);
  }

  @override
  void dispose() {
    cooldownTimer?.cancel();
    codeController.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  void onCodeChanged() {
    setState(() => codeError = null);

    // Submit automatically once all 6 digits are in (typed or pasted).
    if (codeController.text.length == _codeLength && !isBusy) {
      verifyEmail();
    }
  }

  // ============================================================
  // VERIFY — same API call and result handling
  // ============================================================

  Future<void> verifyEmail() async {
    final code = codeController.text.trim();

    if (code.length != _codeLength) {
      setState(() => codeError = "Please enter the 6-digit code");
      codeFocusNode.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => isLoading = true);

    final result = await ApiService().verifyEmail(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result == VerifyEmailResult.success) {
      HapticFeedback.mediumImpact();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _VerifiedDialog(),
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
      return;
    }

    final message = switch (result) {
      VerifyEmailResult.invalidCode => "Invalid or expired verification code.",
      VerifyEmailResult.networkError =>
      "Cannot connect to the server. Check your API connection.",
      VerifyEmailResult.serverError => "Server error. Please try again.",
      VerifyEmailResult.success => "",
    };

    if (result == VerifyEmailResult.invalidCode) {
      // Clear the boxes so the user can type the code again right away.
      HapticFeedback.heavyImpact();
      codeController.removeListener(onCodeChanged);
      codeController.clear();
      codeController.addListener(onCodeChanged);
      setState(() => codeError = message);
      codeFocusNode.requestFocus();
    } else {
      showMessage(message);
    }
  }

  // ============================================================
  // RESEND — same API call, plus a cooldown so it can't be spammed
  // ============================================================

  Future<void> resendCode() async {
    if (isBusy || resendCooldown > 0) return;

    setState(() => isResending = true);
    final result = await ApiService().resendVerificationCode(widget.email);

    if (!mounted) return;

    setState(() => isResending = false);

    final message = switch (result) {
      ResendVerificationCodeResult.success =>
      "A new verification code was sent to your email.",
      ResendVerificationCodeResult.invalidEmail =>
      "We could not find an account with that email.",
      ResendVerificationCodeResult.networkError =>
      "Cannot connect to the server. Check your API connection.",
      ResendVerificationCodeResult.serverError =>
      "Server error. Please try again.",
    };

    if (result == ResendVerificationCodeResult.success) {
      startCooldown();
      codeController.removeListener(onCodeChanged);
      codeController.clear();
      codeController.addListener(onCodeChanged);
      setState(() => codeError = null);
    }

    showMessage(message);
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
      canPop: !isBusy,
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
                    // ---- Top bar ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: "Back",
                            onTap: isBusy ? null : () => Navigator.pop(context),
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
                            child: verificationCard(),
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

  Widget verificationCard() {
    final canResend = !isBusy && resendCooldown == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
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
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: _primary,
              size: 32,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            "Verify your email",
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              children: [
                const TextSpan(text: "Enter the 6-digit code we sent to\n"),
                TextSpan(
                  text: widget.email,
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

          _CodeInput(
            controller: codeController,
            focusNode: codeFocusNode,
            enabled: !isBusy,
            hasError: codeError != null,
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: codeError == null
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      codeError!,
                      textAlign: TextAlign.center,
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
          ),

          const SizedBox(height: 22),

          // ---- Verify ----
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isBusy
                    ? null
                    : const LinearGradient(colors: [_primaryDeep, _primary]),
                color: isBusy ? _primary.withValues(alpha: 0.55) : null,
                boxShadow: isBusy
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
                onPressed: isBusy ? null : verifyEmail,
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
                      isLoading ? "Verifying..." : "Verify Email",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ---- Resend ----
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  onPressed: canResend ? resendCode : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    disabledForegroundColor: _faint,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    isResending
                        ? "Sending..."
                        : resendCooldown > 0
                        ? "Resend in ${resendCooldown}s"
                        : "Send again",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "Check your spam or promotions folder if it's not in your inbox.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _faint,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 6-BOX CODE INPUT
// One real (invisible) TextField drives six display boxes, so typing,
// backspace and pasting a whole code all work naturally.
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
      label: "6-digit verification code",
      textField: true,
      child: GestureDetector(
        onTap: enabled ? focusNode.requestFocus : null,
        child: Stack(
          children: [
            // Invisible input that actually receives keystrokes / paste.
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
                  enableInteractiveSelection: true,
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
          boxShadow: isActive && !hasError
              ? [
            BoxShadow(
              color: _primary.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
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
// SUCCESS DIALOG
// ============================================================

class _VerifiedDialog extends StatelessWidget {
  const _VerifiedDialog();

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
        child: const Icon(Icons.verified_rounded, color: _success, size: 34),
      ),
      title: const Text(
        "Email verified",
        style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
      ),
      content: const Text(
        "Your account is ready. Please log in.",
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
              "Go to Login",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SMALL PIECES
// ============================================================

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