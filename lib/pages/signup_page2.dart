import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'email_verification_page.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as login_page.dart / signup_page.dart)
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF6366F1);
const _primaryDeep = Color(0xFF4F46E5);
const _accent = Color(0xFF0EA5E9);
const _primarySoft = Color(0xFFEEF2FF);

const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);

const _border = Color(0xFFE2E8F0);
const _fieldFill = Color(0xFFF8FAFC);

const _success = Color(0xFF16A34A);
const _danger = Color(0xFFEF4444);
const _dangerSoft = Color(0xFFFEF2F2);

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_primaryDeep, _primary, _accent],
);

class SignUpPage2 extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String gender;
  final String birthday;

  const SignUpPage2({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.birthday,
  });

  @override
  State<SignUpPage2> createState() => _SignUpPage2State();
}

class _SignUpPage2State extends State<SignUpPage2> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final passwordFocus = FocusNode();
  final confirmFocus = FocusNode();

  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool isLoading = false;

  /// Inline validation shows after the first "Create Account" tap.
  bool showErrors = false;

  // Errors returned by the server, shown under the matching field.
  String? emailServerError;
  String? passwordServerError;
  String? formError;

  String _lastEmail = "";
  String _lastPassword = "";
  String _lastConfirm = "";

  @override
  void initState() {
    super.initState();
    emailController.addListener(_onEmailChanged);
    passwordController.addListener(_onPasswordChanged);
    confirmPasswordController.addListener(_onConfirmChanged);
  }

  void _onEmailChanged() {
    if (emailController.text == _lastEmail) return;
    _lastEmail = emailController.text;
    setState(() {
      emailServerError = null;
      formError = null;
    });
  }

  void _onPasswordChanged() {
    if (passwordController.text == _lastPassword) return;
    _lastPassword = passwordController.text;
    // Rebuild every time so the requirement checklist stays live.
    setState(() {
      passwordServerError = null;
      formError = null;
    });
  }

  void _onConfirmChanged() {
    if (confirmPasswordController.text == _lastConfirm) return;
    _lastConfirm = confirmPasswordController.text;
    setState(() => formError = null);
  }

  @override
  void dispose() {
    emailController.removeListener(_onEmailChanged);
    passwordController.removeListener(_onPasswordChanged);
    confirmPasswordController.removeListener(_onConfirmChanged);
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    passwordFocus.dispose();
    confirmFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATION (same rules as before, shown inline)
  // ============================================================

  String get _email => emailController.text.trim();
  String get _password => passwordController.text.trim();
  String get _confirm => confirmPasswordController.text.trim();

  bool get _hasMinLength => _password.length >= 8;
  bool get _passwordsMatch => _confirm.isNotEmpty && _password == _confirm;

  String? get emailError {
    if (emailServerError != null) return emailServerError;
    if (showErrors && _email.isEmpty) return "Please enter your email";
    return null;
  }

  String? get passwordError {
    if (passwordServerError != null) return passwordServerError;
    if (!showErrors) return null;
    if (_password.isEmpty) return "Please create a password";
    if (!_hasMinLength) return "Password must be at least 8 characters.";
    return null;
  }

  String? get confirmError {
    if (!showErrors) return null;
    if (_confirm.isEmpty) return "Please re-enter your password";
    if (_password != _confirm) return "Passwords do not match.";
    return null;
  }

  // ============================================================
  // REGISTRATION — same API call and navigation as before
  // ============================================================

  Future<void> createAccount() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    final invalid =
        email.isEmpty ||
            password.isEmpty ||
            confirmPassword.isEmpty ||
            password != confirmPassword ||
            password.length < 8;

    if (invalid) {
      HapticFeedback.heavyImpact();
      setState(() {
        showErrors = true;
        emailServerError = null;
        passwordServerError = null;
        formError = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      emailServerError = null;
      passwordServerError = null;
      formError = null;
    });

    final result = await ApiService().register(
      firstName: widget.firstName,
      lastName: widget.lastName,
      gender: widget.gender,
      birthday: widget.birthday,
      email: email,
      password: password,
      passwordConfirmation: confirmPassword,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (!result.success) {
      HapticFeedback.heavyImpact();
      _showServerError(result.message);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => EmailVerificationPage(email: email),
      ),
          (route) => false,
    );
  }

  /// Puts the server message under the field it is about, or in a banner.
  void _showServerError(String message) {
    final text = message.toLowerCase();
    final isConnection =
        text.contains("network") ||
            text.contains("connect") ||
            text.contains("timeout") ||
            text.contains("server");

    setState(() {
      if (!isConnection && text.contains("email")) {
        emailServerError = message;
      } else if (!isConnection && text.contains("password")) {
        passwordServerError = message;
      } else {
        formError = message.isEmpty ? "Signup failed. Please try again." : message;
      }
    });
  }

  // ============================================================
  // FIELDS
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    final hasError = errorText != null;

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _faint, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, size: 21, color: hasError ? _danger : _muted),
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(color: _danger, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: hasError ? _dangerSoft : _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: outline(_border),
      enabledBorder: outline(_border),
      disabledBorder: outline(_border),
      focusedBorder: outline(_primary, 1.6),
      errorBorder: outline(_danger),
      focusedErrorBorder: outline(_danger, 1.6),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? "Show password" : "Hide password",
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 21,
        color: _muted,
      ),
    );
  }

  TextStyle get _inputStyle => const TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: _ink,
  );

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Email address"),
        TextField(
          controller: emailController,
          enabled: !isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => passwordFocus.requestFocus(),
          style: _inputStyle,
          decoration: _inputDecoration(
            hint: "Enter your email",
            icon: Icons.mail_outline_rounded,
            errorText: emailError,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Password"),
        TextField(
          controller: passwordController,
          focusNode: passwordFocus,
          enabled: !isLoading,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => confirmFocus.requestFocus(),
          style: _inputStyle,
          decoration: _inputDecoration(
            hint: "Create a password",
            icon: Icons.lock_outline_rounded,
            errorText: passwordError,
            suffixIcon: _visibilityToggle(
              obscured: obscurePassword,
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel("Confirm password"),
        TextField(
          controller: confirmPasswordController,
          focusNode: confirmFocus,
          enabled: !isLoading,
          obscureText: obscureConfirm,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => createAccount(),
          style: _inputStyle,
          decoration: _inputDecoration(
            hint: "Re-enter your password",
            icon: Icons.lock_reset_rounded,
            errorText: confirmError,
            suffixIcon: _visibilityToggle(
              obscured: obscureConfirm,
              onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RequirementRow(
            label: "At least 8 characters",
            met: _hasMinLength,
          ),
          const SizedBox(height: 6),
          _RequirementRow(label: "Passwords match", met: _passwordsMatch),
        ],
      ),
    );
  }

  Widget _buildFormError() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: formError == null
          ? const SizedBox(width: double.infinity)
          : Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: _dangerSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  formError!,
                  style: const TextStyle(
                    color: Color(0xFF991B1B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS + SUMMARY
  // ============================================================

  Widget _buildProgress() {
    Widget step(int number, String label, {required bool done, required bool active}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: _heroGradient,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  height: 18,
                  width: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: done ? _success : _primary,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  )
                      : Text(
                    "$number",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: active ? _primaryDeep : _muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        step(1, "Personal details", done: true, active: false),
        const SizedBox(width: 10),
        step(2, "Account details", done: false, active: true),
      ],
    );
  }

  Widget _buildPersonSummary() {
    final fullName = "${widget.firstName} ${widget.lastName}".trim();
    final initial = fullName.isEmpty ? "?" : fullName[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: _heroGradient,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Signing up as",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              "Edit",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCOUNT CARD
  // ============================================================

  Widget _buildAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40312E81),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _heroGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x406366F1),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_person_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    "Step 2 of 2",
                    style: TextStyle(
                      color: _primaryDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const Text(
              "Account details",
              style: TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              "Set up your login credentials to complete your Racetech account.",
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),

            const SizedBox(height: 22),

            _buildProgress(),

            const SizedBox(height: 20),

            _buildPersonSummary(),

            const SizedBox(height: 22),

            _buildFormError(),

            _buildEmailField(),

            const SizedBox(height: 17),

            _buildPasswordField(),

            const SizedBox(height: 17),

            _buildConfirmPasswordField(),

            const SizedBox(height: 12),

            _buildRequirements(),

            const SizedBox(height: 24),

            // CREATE ACCOUNT
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isLoading ? 0.75 : 1,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _heroGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D6366F1),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isLoading ? null : createAccount,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isLoading
                            ? const Row(
                          key: ValueKey("creating"),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 11),
                            Text(
                              "Creating account...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        )
                            : const Row(
                          key: ValueKey("create"),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Create Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.check_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // BACK
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  "Back to personal details",
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // Don't leave in the middle of creating the account.
      canPop: !isLoading,
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: _primary,
            error: _danger,
            surfaceTint: Colors.transparent,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: _primary,
            selectionColor: Color(0x336366F1),
            selectionHandleColor: _primary,
          ),
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: const Color(0xFF1E1B4B),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  "assets/login_bg.jpg",
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) =>
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: _heroGradient),
                  ),
                ),

                // Indigo overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xB34F46E5),
                        Color(0xCC312E81),
                        Color(0xF21E1B4B),
                      ],
                    ),
                  ),
                ),

                // Soft glows
                Positioned(
                  top: -90,
                  right: -70,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -110,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primary.withValues(alpha: 0.25),
                    ),
                  ),
                ),

                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          children: [
                            // TOP BAR
                            Row(
                              children: [
                                Tooltip(
                                  message: "Back",
                                  child: Opacity(
                                    opacity: isLoading ? 0.45 : 1,
                                    child: Material(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      shape: CircleBorder(
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.24,
                                          ),
                                        ),
                                      ),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: isLoading
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const SizedBox(
                                          height: 42,
                                          width: 42,
                                          child: Icon(
                                            Icons.arrow_back_rounded,
                                            color: Colors.white,
                                            size: 21,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.speed_rounded,
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "RACETECH",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 42, height: 42),
                              ],
                            ),

                            const SizedBox(height: 24),

                            _buildAccountCard(),

                            const SizedBox(height: 22),

                            Text(
                              "Train smarter. Perform better.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
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
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUIREMENT ROW
// ─────────────────────────────────────────────────────────────────────────────

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            key: ValueKey(met),
            size: 16,
            color: met ? _success : _faint,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: met ? _success : _muted,
            fontSize: 12,
            fontWeight: met ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}