import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _success = Color(0xFF16A34A);
const _warning = Color(0xFFF59E0B);
const _error = Color(0xFFE11D48);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({super.key});

  @override
  State<EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSaving = false;

  /// Missing/mismatched fields are only highlighted after the first Save tap.
  bool showErrors = false;

  /// Errors returned by the server (e.g. wrong current password), shown in
  /// red under the matching field. Cleared as soon as that field is edited.
  String? currentServerError;
  String? newServerError;
  String? confirmServerError;

  @override
  void initState() {
    super.initState();

    currentPasswordController.addListener(() {
      setState(() => currentServerError = null);
    });
    newPasswordController.addListener(() {
      setState(() {
        newServerError = null;
        confirmServerError = null;
      });
    });
    confirmPasswordController.addListener(() {
      setState(() => confirmServerError = null);
    });
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String get currentPass => currentPasswordController.text.trim();
  String get newPass => newPasswordController.text.trim();
  String get confirmPass => confirmPasswordController.text.trim();

  bool get hasTypedAnything =>
      currentPasswordController.text.isNotEmpty ||
      newPasswordController.text.isNotEmpty ||
      confirmPasswordController.text.isNotEmpty;

  String? get currentError {
    if (currentServerError != null) return currentServerError;
    return showErrors && currentPass.isEmpty
        ? "Enter your current password"
        : null;
  }

  String? get newError {
    if (newServerError != null) return newServerError;
    if (!showErrors) return null;
    if (newPass.isEmpty) return "Enter a new password";
    if (newPass == currentPass) {
      return "New password must be different from the current one";
    }
    return null;
  }

  String? get confirmError {
    if (confirmServerError != null) return confirmServerError;
    if (!showErrors) return null;
    if (confirmPass.isEmpty) return "Re-enter your new password";
    if (confirmPass != newPass) return "Passwords do not match";
    return null;
  }

  // ============================================================
  // SAVE — same API call and values sent
  // ============================================================

  Future<void> _handleEditPasswordPage() async {
    FocusScope.of(context).unfocus();

    if (currentPass.isEmpty ||
        newPass.isEmpty ||
        confirmPass.isEmpty ||
        newPass != confirmPass ||
        newPass == currentPass) {
      setState(() => showErrors = true);
      return;
    }

    setState(() => isSaving = true);

    final result = await ApiService().changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
      passwordConfirmation: confirmPass,
    );

    if (!mounted) return;

    setState(() => isSaving = false);

    if (result.success) {
      showMessage(result.message);
      // pop (not maybePop) so the "discard changes?" guard is skipped.
      Navigator.pop(context);
      return;
    }

    showServerError(result.message);
  }

  /// Puts the server's error message under the field it is about, so the
  /// box turns red with the reason (e.g. "Current password is incorrect").
  void showServerError(String message) {
    final text = message.toLowerCase();
    final fallback = message.trim().isEmpty
        ? "Something went wrong. Please try again."
        : message;

    final isNetworkOrServer =
        text.contains("connect") ||
        text.contains("network") ||
        text.contains("server") ||
        text.contains("timeout");

    if (isNetworkOrServer) {
      // Not a problem with what the user typed — keep it as a snackbar.
      showMessage(fallback);
      return;
    }

    setState(() {
      if (text.contains("current") ||
          text.contains("old password") ||
          text.contains("incorrect") ||
          text.contains("wrong")) {
        currentServerError = fallback;
      } else if (text.contains("confirm") || text.contains("match")) {
        confirmServerError = fallback;
      } else {
        // Length / format / "must be different" rules are about the new one.
        newServerError = fallback;
      }
    });

    HapticFeedback.heavyImpact();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Future<bool> confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: _primary,
            size: 30,
          ),
        ),
        title: const Text(
          "Leave without saving?",
          style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
        ),
        content: const Text(
          "Your password has not been changed yet.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Stay"),
          ),
        ],
      ),
    );

    return discard == true;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final matches = confirmPass.isNotEmpty && confirmPass == newPass;

    return PopScope(
      canPop: !isSaving && !hasTypedAnything,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isSaving) return;
        if (await confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _PasswordHero(
                  isSaving: isSaving,
                  onBack: () => Navigator.maybePop(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---------------- CURRENT ----------------
                          _SectionCard(
                            title: "Current Password",
                            icon: Icons.lock_outline_rounded,
                            children: [
                              passwordField(
                                controller: currentPasswordController,
                                label: "Current password",
                                icon: Icons.key_outlined,
                                obscure: obscureCurrent,
                                errorText: currentError,
                                autofillHints: const [AutofillHints.password],
                                onToggle: () => setState(
                                  () => obscureCurrent = !obscureCurrent,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------- NEW ----------------
                          _SectionCard(
                            title: "New Password",
                            icon: Icons.password_rounded,
                            children: [
                              passwordField(
                                controller: newPasswordController,
                                label: "New password",
                                icon: Icons.lock_outline_rounded,
                                obscure: obscureNew,
                                errorText: newError,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onToggle: () =>
                                    setState(() => obscureNew = !obscureNew),
                              ),
                              const SizedBox(height: 10),
                              _PasswordStrength(password: newPass),
                              const SizedBox(height: 16),
                              passwordField(
                                controller: confirmPasswordController,
                                label: "Confirm new password",
                                icon: Icons.verified_user_outlined,
                                obscure: obscureConfirm,
                                errorText: confirmError,
                                helperText: matches ? "Passwords match" : null,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleEditPasswordPage(),
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                onToggle: () => setState(
                                  () => obscureConfirm = !obscureConfirm,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: _primaryDeep,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Use a strong password that is hard to guess and avoid reusing old passwords.",
                                    style: TextStyle(
                                      color: _primaryDeep,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
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
                ),
              ),
            ],
          ),
          bottomNavigationBar: saveBar(),
        ),
      ),
    );
  }

  Widget passwordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    String? errorText,
    String? helperText,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    Iterable<String>? autofillHints,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: controller,
      enabled: !isSaving,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      enableSuggestions: false,
      autocorrect: false,
      cursorColor: _primary,
      style: const TextStyle(
        color: _ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
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
        suffixIcon: IconButton(
          tooltip: obscure ? "Show password" : "Hide password",
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _faint,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 17,
        ),
        enabledBorder: outline(_border),
        disabledBorder: outline(_border),
        focusedBorder: outline(_primary, 1.5),
        errorBorder: outline(_error.withValues(alpha: 0.6)),
        focusedErrorBorder: outline(_error, 1.5),
        border: outline(_border),
      ),
    );
  }

  Widget saveBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A94A3B8),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isSaving ? null : _handleEditPasswordPage,
                  icon: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isSaving ? "Updating..." : "Update Password",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO HEADER
// ============================================================

class _PasswordHero extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onBack;

  const _PasswordHero({required this.isSaving, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDeep, _primary, _accent],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: isSaving ? null : onBack,
                      borderRadius: BorderRadius.circular(14),
                      child: const Tooltip(
                        message: "Back",
                        child: SizedBox(
                          height: 44,
                          width: 44,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Change Password",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Keep your account safe",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSaving
                    ? "Saving your new password..."
                    : "Enter your current password, then choose a new one.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION CARD
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================
// PASSWORD STRENGTH (guide only — the server decides what's allowed)
// ============================================================

class _PasswordStrength extends StatelessWidget {
  final String password;

  const _PasswordStrength({required this.password});

  @override
  Widget build(BuildContext context) {
    final longEnough = password.length >= 8;
    final lettersAndNumbers =
        RegExp(r"[A-Za-z]").hasMatch(password) &&
        RegExp(r"\d").hasMatch(password);
    final mixedOrSymbol =
        (RegExp(r"[a-z]").hasMatch(password) &&
            RegExp(r"[A-Z]").hasMatch(password)) ||
        RegExp(r"[^A-Za-z0-9]").hasMatch(password);

    var score = 0;
    if (longEnough) score++;
    if (lettersAndNumbers) score++;
    if (mixedOrSymbol) score++;

    final (label, color) = password.isEmpty
        ? ("", _border)
        : switch (score) {
            0 || 1 => ("Weak", _error),
            2 => ("Good", _warning),
            _ => ("Strong", _success),
          };
    final bars = password.isEmpty ? 0 : score.clamp(1, 3);

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
                    color: i < bars ? color : _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Requirement(met: longEnough, label: "8+ characters"),
            _Requirement(met: lettersAndNumbers, label: "Letters & numbers"),
            _Requirement(met: mixedOrSymbol, label: "Upper case or symbol"),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
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
            color: met ? _success : _body,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
