const passwordRequirementsMessage =
    'Use at least 12 characters with uppercase and lowercase letters, a number, and a symbol.';

List<({String label, bool met})> passwordRequirements(String password) => [
  (label: 'At least 12 characters', met: password.runes.length >= 12),
  (
    label: 'Uppercase letter',
    met: RegExp(r'\p{Lu}', unicode: true).hasMatch(password),
  ),
  (
    label: 'Lowercase letter',
    met: RegExp(r'\p{Ll}', unicode: true).hasMatch(password),
  ),
  (label: 'Number', met: RegExp(r'\p{N}', unicode: true).hasMatch(password)),
  (
    label: 'Symbol',
    met: RegExp(r'[\p{Z}\p{S}\p{P}]', unicode: true).hasMatch(password),
  ),
];

String? validateNewPassword(String password) =>
    passwordRequirements(password).every((item) => item.met)
    ? null
    : passwordRequirementsMessage;

String? validatePasswordConfirmation(String password, String confirmation) =>
    password == confirmation && confirmation.isNotEmpty
    ? null
    : 'Passwords do not match.';
