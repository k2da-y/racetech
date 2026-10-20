import 'package:flutter/material.dart';
import '../utils/password_rules.dart';

class PasswordRequirements extends StatelessWidget {
  final String password;
  final String? confirmation;
  const PasswordRequirements({
    super.key,
    required this.password,
    this.confirmation,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(passwordRequirementsMessage),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final item in [
            ...passwordRequirements(password),
            if (confirmation != null)
              (
                label: 'Passwords match',
                met:
                    validatePasswordConfirmation(password, confirmation!) ==
                    null,
              ),
          ])
            Semantics(
              label: '${item.label}: ${item.met ? 'met' : 'not met'}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.met
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: item.met
                        ? const Color(0xFF15803D)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
