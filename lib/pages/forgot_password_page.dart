import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  bool isLoading = false;
  bool codeSent = false;
  bool codeVerified = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> sendResetCode() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage("Please enter your email address");
      return;
    }

    setState(() => isLoading = true);
    final result = await ApiService().forgotPassword(email);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      codeSent = result == ForgotPasswordResult.success;
    });

    if (result == ForgotPasswordResult.success) {
      showMessage("Reset code sent to your email.");
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

    showMessage(message);
  }

  Future<void> verifyCode() async {
    final email = emailController.text.trim();
    final code = codeController.text.trim();

    if (code.length != 6) {
      showMessage("Please enter the 6-digit code");
      return;
    }

    setState(() => isLoading = true);
    final result = await ApiService().verifyResetCode(email: email, code: code);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      codeVerified = result == VerifyResetCodeResult.success;
    });

    if (result == VerifyResetCodeResult.success) {
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

    showMessage(message);
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

    if (password.isEmpty || confirmPassword.isEmpty) {
      showMessage("Please complete all fields");
      return;
    }

    if (password != confirmPassword) {
      showMessage("Passwords do not match");
      return;
    }

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
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Password Updated"),
          content: const Text("You can now log in with your new password."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
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

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/login_bg.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5)),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    Icon(
                      codeVerified
                          ? Icons.lock_outline
                          : codeSent
                          ? Icons.password_outlined
                          : Icons.lock_reset,
                      size: 54,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      codeVerified
                          ? "Create New Password"
                          : codeSent
                          ? "Enter Reset Code"
                          : "Forgot Password",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      codeSent
                          ? codeVerified
                                ? "Use at least 8 characters for your new password."
                                : "Check your email for the 6-digit code."
                          : "Enter your email and we will send a reset code.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),
                    if (!codeSent)
                      _emailStep()
                    else if (!codeVerified)
                      _codeStep()
                    else
                      _passwordStep(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep() {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: fieldDecoration("Email", Icons.email_outlined),
        ),
        const SizedBox(height: 20),
        actionButton(
          isLoading ? "Sending..." : "Send Reset Code",
          sendResetCode,
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      children: [
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: fieldDecoration("6-digit code", Icons.pin_outlined),
        ),
        const SizedBox(height: 20),
        actionButton(isLoading ? "Verifying..." : "Verify Code", verifyCode),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isLoading ? null : sendResetCode,
          child: const Text("Send Code Again"),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: fieldDecoration(
            "New Password",
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => obscurePassword = !obscurePassword);
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: confirmPasswordController,
          obscureText: obscureConfirm,
          decoration: fieldDecoration(
            "Confirm Password",
            Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() => obscureConfirm = !obscureConfirm);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        actionButton(
          isLoading ? "Updating..." : "Update Password",
          resetPassword,
        ),
      ],
    );
  }

  InputDecoration fieldDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey[100],
      counterText: "",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.redAccent,
        ),
        onPressed: isLoading ? null : onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
