Map<String, dynamic>? readinessCertificate(Map<String, dynamic> readiness) {
  final current = readiness['certificate'];
  if (current is Map) {
    return Map<String, dynamic>.from(current);
  }

  for (final key in const ['e_badge', 'ebadge', 'eBadge']) {
    final legacy = readiness[key];
    if (legacy is Map) {
      return <String, dynamic>{
        ...Map<String, dynamic>.from(legacy),
        'legacy_e_badge': true,
      };
    }
  }
  return null;
}

String certificateStatus(Map<String, dynamic> certificate) {
  final raw = (certificate['status'] ?? certificate['state'] ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');
  return switch (raw) {
    'waiting_result' ||
    'pending_result' ||
    'result_pending' => 'waiting_for_result',
    'waiting_feedback' ||
    'pending_feedback' ||
    'feedback_pending' => 'waiting_for_feedback',
    'ready' || 'issued' || 'generated' || 'downloadable' => 'available',
    'invalidated' || 'cancelled' || 'canceled' => 'revoked',
    _ => raw,
  };
}

String certificateStatusLabel(Map<String, dynamic> certificate) {
  return switch (certificateStatus(certificate)) {
    'waiting_for_result' => 'Waiting for result',
    'waiting_for_feedback' => 'Waiting for feedback',
    'available' => 'Available',
    'revoked' => 'Revoked',
    _ => 'Pending',
  };
}

String certificateMessage(Map<String, dynamic> certificate) {
  final message = (certificate['message'] ?? certificate['description'] ?? '')
      .toString()
      .trim();
  if (message.isNotEmpty) return message;
  return switch (certificateStatus(certificate)) {
    'waiting_for_result' =>
      'Your official result must be published before your certificate is available.',
    'waiting_for_feedback' =>
      'Submit your event feedback to unlock your certificate.',
    'available' => 'Your official E-Certificate is ready.',
    'revoked' => 'This certificate has been revoked by the organizer.',
    _ => 'Your E-Certificate is being prepared.',
  };
}

String certificateDownloadUrl(Map<String, dynamic> certificate) {
  return _firstUrl(certificate, const [
    'download_url',
    'certificate_url',
    'file_url',
    'url',
  ]);
}

String certificateVerificationUrl(Map<String, dynamic> certificate) {
  return _firstUrl(certificate, const [
    'verification_url',
    'verify_url',
    'public_verification_url',
  ]);
}

String _firstUrl(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key]?.toString().trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http')) {
      return value;
    }
  }
  return '';
}
