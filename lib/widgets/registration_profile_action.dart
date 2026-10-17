import 'package:flutter/material.dart';
import '../pages/profile_settings_page.dart';

/// Refresh backend eligibility after returning, including when settings was
/// dismissed without saving. Never reuse the old category permissions.
Future<void> openRegistrationProfileSettings(
  BuildContext context, {
  required Future<void> Function() onRefresh,
  WidgetBuilder? profileBuilder,
}) async {
  await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: profileBuilder ?? (_) => const ProfileSettingsPage(),
    ),
  );
  if (!context.mounted) return;
  await onRefresh();
}
