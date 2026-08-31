Map<String, dynamic>? registrationReadiness(Map<String, dynamic> registration) {
  final value = registration['readiness'];
  return value is Map && value.isNotEmpty
      ? Map<String, dynamic>.from(value)
      : null;
}

String readinessRegistrationStatus(
  Map<String, dynamic> readiness,
  dynamic fallback,
) {
  return (readiness['registration_status'] ??
          readiness['current_status'] ??
          readiness['status'] ??
          fallback ??
          '')
      .toString()
      .trim();
}

Map<String, String> readinessNextStep(Map<String, dynamic> readiness) {
  final value = readiness['next_step'];
  if (value is Map) {
    return {
      'title': (value['title'] ?? value['label'] ?? 'Next Step')
          .toString()
          .trim(),
      'message': (value['message'] ?? value['description'] ?? '')
          .toString()
          .trim(),
      'action': (value['action'] ?? value['action_key'] ?? '')
          .toString()
          .trim(),
      'action_label':
          (value['action_label'] ?? value['button_label'] ?? 'Continue')
              .toString()
              .trim(),
    };
  }
  final text = value?.toString().trim() ?? '';
  if (text.isNotEmpty) {
    return {
      'title': 'Next Step',
      'message': text,
      'action': (readiness['next_action'] ?? readiness['action'] ?? '')
          .toString(),
      'action_label':
          (readiness['action_label'] ??
                  readiness['next_action_label'] ??
                  'Continue')
              .toString(),
    };
  }
  return const {};
}

String readinessText(Map<String, dynamic>? readiness, List<String> keys) {
  if (readiness == null) return '';
  for (final key in keys) {
    final value = readiness[key];
    if (value is List) {
      final text = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', ');
      if (text.isNotEmpty) return text;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

List<Map<String, String>> readinessChecklist(Map<String, dynamic> readiness) {
  final raw =
      readiness['checklist'] ?? readiness['progress'] ?? readiness['items'];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) {
          return _normalizeChecklistItem(
            item['key']?.toString() ?? '',
            Map<String, dynamic>.from(item),
          );
        })
        .where((item) {
          return item['label']!.isNotEmpty;
        })
        .toList();
  }

  if (raw is Map) {
    return raw.entries.map((entry) {
      final value = entry.value;
      if (value is Map) {
        return _normalizeChecklistItem(
          entry.key.toString(),
          Map<String, dynamic>.from(value),
        );
      }
      return _normalizeChecklistItem(entry.key.toString(), {
        'status': value is bool ? (value ? 'complete' : 'pending') : value,
      });
    }).toList();
  }

  const knownKeys = [
    'payment',
    'approval',
    'bib',
    'waiver',
    'medical_certificate',
    'first_aid_kit',
    'check_in',
    'race_kit',
    'result',
    'certificate',
    'e_badge',
  ];
  final inferred = <Map<String, String>>[];
  for (final key in knownKeys) {
    if (key == 'e_badge' && readiness['certificate'] != null) continue;
    final value = readiness[key];
    if (value is Map) {
      inferred.add(
        _normalizeChecklistItem(key, Map<String, dynamic>.from(value)),
      );
    } else if (value is bool || value is String) {
      inferred.add(
        _normalizeChecklistItem(key, {
          'status': value is bool ? (value ? 'complete' : 'pending') : value,
        }),
      );
    }
  }
  return inferred;
}

Map<String, String> _normalizeChecklistItem(
  String fallbackKey,
  Map<String, dynamic> item,
) {
  final key = (item['key'] ?? fallbackKey).toString().trim();
  final isCertificate = const {
    'certificate',
    'e_badge',
    'ebadge',
  }.contains(key.toLowerCase());
  return {
    'key': key,
    'label': isCertificate
        ? 'E-Certificate'
        : (item['label'] ?? _humanize(key)).toString().trim(),
    'status': (item['status'] ?? item['state'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase(),
    'message': (item['message'] ?? item['description'] ?? '').toString().trim(),
  };
}

String _humanize(String value) {
  return value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
