import 'package:flutter/material.dart';
import 'login_page.dart';
import '../services/api_service.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final codeController = TextEditingController();

  bool isLoading = false;
  bool isResending = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> verifyEmail() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      showMessage("Please enter the 6-digit code");
      return;
    }

    setState(() => isLoading = true);
    final result = await ApiService().verifyEmail(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result == VerifyEmailResult.success) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Email Verified"),
          content: const Text("Your account is ready. Please log in."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
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

    showMessage(message);
  }

  Future<void> resendCode() async {
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
                        onPressed: isLoading || isResending
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 54,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Verify Your Email",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter the 6-digit code sent to ${widget.email}.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: fieldDecoration(
                        "6-digit code",
                        Icons.pin_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    actionButton(
                      isLoading ? "Verifying..." : "Verify Email",
                      verifyEmail,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: isLoading || isResending ? null : resendCode,
                      child: Text(
                        isResending ? "Sending..." : "Send Code Again",
                      ),
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

  InputDecoration fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
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
        onPressed: isLoading || isResending ? null : onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
