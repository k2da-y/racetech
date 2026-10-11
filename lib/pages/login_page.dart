import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_gate_page.dart';
import 'email_verification_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as the rest of the app)
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

const _danger = Color(0xFFEF4444);
const _dangerSoft = Color(0xFFFEF2F2);

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_primaryDeep, _primary, _accent],
);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordFocus = FocusNode();

  bool isLoading = false;
  bool obscurePassword = true;

  // Inline errors (UI only)
  String? emailError;
  String? passwordError;
  String? formError;
  String _lastEmail = "";
  String _lastPassword = "";

  @override
  void initState() {
    super.initState();
    emailController.addListener(_clearEmailError);
    passwordController.addListener(_clearPasswordError);
  }

  void _clearEmailError() {
    // Ignore cursor/selection changes; only react to real edits.
    if (emailController.text == _lastEmail) return;
    _lastEmail = emailController.text;
    if (emailError == null && formError == null) return;
    setState(() {
      emailError = null;
      formError = null;
      if (passwordError == "Invalid email or password") passwordError = null;
    });
  }

  void _clearPasswordError() {
    if (passwordController.text == _lastPassword) return;
    _lastPassword = passwordController.text;
    if (passwordError == null && formError == null) return;
    setState(() {
      passwordError = null;
      formError = null;
    });
  }

  @override
  void dispose() {
    emailController.removeListener(_clearEmailError);
    passwordController.removeListener(_clearPasswordError);
    emailController.dispose();
    passwordController.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN LOGIC
  // Same API call and navigation as before; errors are shown
  // inline instead of only in a snackbar.
  // ============================================================

  Future<void> handleLogin() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        emailError = email.isEmpty ? "Please enter your email" : null;
        passwordError = password.isEmpty ? "Please enter your password" : null;
        formError = null;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      emailError = null;
      passwordError = null;
      formError = null;
    });

    final result = await ApiService().login(email, password);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    if (result == LoginResult.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGatePage()),
      );
    } else if (result == LoginResult.emailVerificationRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Please verify your email first."),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationPage(email: email),
        ),
      );
    } else {
      final message = switch (result) {
        LoginResult.invalidCredentials => "Invalid email or password",
        LoginResult.emailVerificationRequired =>
          "Please verify your email first.",
        LoginResult.webOnlyAccount =>
          "This account is for the admin web portal only.",
        LoginResult.networkError =>
          "Cannot connect to the server. Check your API address and Wi-Fi.",
        LoginResult.serverError => "Server error. Please try again.",
        LoginResult.success => "",
      };

      HapticFeedback.heavyImpact();
      setState(() {
        if (result == LoginResult.invalidCredentials) {
          // Red on both boxes, message under the password.
          emailError = "";
          passwordError = message;
        } else {
          formError = message;
        }
      });
    }
  }

  // ============================================================
  // FIELDS
  // ============================================================

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    String? errorText,
    Widget? suffix,
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
      suffixIcon: suffix,
      // An empty string still turns the box red without adding text.
      errorText: errorText,
      errorStyle: errorText != null && errorText.isEmpty
          ? const TextStyle(height: 0, fontSize: 0)
          : const TextStyle(color: _danger, fontWeight: FontWeight.w700),
      errorMaxLines: 2,
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

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
    );
  }

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
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _fieldDecoration(
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
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => handleLogin(),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          decoration: _fieldDecoration(
            hint: "Enter your password",
            icon: Icons.lock_outline_rounded,
            errorText: passwordError,
            suffix: IconButton(
              tooltip: obscurePassword ? "Show password" : "Hide password",
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 21,
                color: _muted,
              ),
              onPressed: () {
                setState(() => obscurePassword = !obscurePassword);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUTTONS
  // ============================================================

  Widget _buildLoginButton() {
    return AnimatedOpacity(
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
            onTap: isLoading ? null : handleLogin,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const Row(
                        key: ValueKey("loading"),
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
                          SizedBox(width: 12),
                          Text(
                            "Signing in...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        key: ValueKey("login"),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Sign in",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
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
  // LOGIN CARD
  // ============================================================

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
          mainAxisSize: MainAxisSize.min,
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
                    Icons.waving_hand_rounded,
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 13,
                        color: _primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "Secure sign in",
                        style: TextStyle(
                          color: _primaryDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Text(
              "Welcome back",
              style: TextStyle(
                fontSize: 27,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Sign in to continue to your Racetech account.",
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),

            const SizedBox(height: 26),

            _buildFormError(),

            _buildEmailField(),

            const SizedBox(height: 18),

            _buildPasswordField(),

            const SizedBox(height: 4),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),

            const SizedBox(height: 8),

            _buildLoginButton(),

            const SizedBox(height: 24),

            const Row(
              children: [
                Expanded(child: Divider(color: _border, height: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    "NEW TO RACETECH?",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w800,
                      color: _faint,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: _border, height: 1)),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryDeep,
                  backgroundColor: _primarySoft.withValues(alpha: 0.5),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: const Text(
                  "Create an account",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
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
              // Background image (falls back to the gradient if missing)
              Image.asset(
                "assets/login_bg.jpg",
                fit: BoxFit.cover,
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
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        children: [
                          // Brand above card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.speed_rounded,
                                  color: Colors.white,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                "RACETECH",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  letterSpacing: 2.4,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          _buildLoginCard(),

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
    );
  }
}
