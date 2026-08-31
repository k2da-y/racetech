List<Map<String, dynamic>> enabledPaymentOptions({
  Map<String, dynamic>? registration,
  Map<String, dynamic>? category,
  Map<String, dynamic>? event,
}) {
  var hasExplicitOptions = false;
  for (final source in [registration, category, event]) {
    if (source == null) continue;
    if (source.containsKey('payment_options') &&
        source['payment_options'] != null) {
      hasExplicitOptions = true;
    }
    final parsed = _parseOptions(source['payment_options']);
    if (parsed.isNotEmpty) return parsed.where(_isEnabled).toList();
  }

  // Legacy responses exposed one manual method as payment_instructions.
  for (final source in [registration, category, event]) {
    final legacy = source?['payment_instructions'];
    if (legacy is! Map) continue;
    final option = Map<String, dynamic>.from(legacy);
    option['provider'] ??= 'manual';
    option['label'] ??= paymentProviderLabel(option['provider']);
    return [option];
  }
  return hasExplicitOptions
      ? const []
      : [
          {'provider': 'manual', 'label': 'Manual Payment'},
        ];
}

List<Map<String, dynamic>> _parseOptions(dynamic raw) {
  if (raw is List) {
    return raw.map((option) {
      if (option is Map) return _normalizeOption(option);
      return _normalizeOption({'provider': option.toString()});
    }).toList();
  }

  if (raw is Map) {
    return raw.entries.map((entry) {
      final value = entry.value;
      final option = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{'enabled': value == true};
      option['provider'] ??= entry.key.toString();
      return _normalizeOption(option);
    }).toList();
  }
  return const [];
}

Map<String, dynamic> _normalizeOption(Map<dynamic, dynamic> option) {
  final normalized = Map<String, dynamic>.from(option);
  normalized['provider'] ??=
      normalized['key'] ??
      normalized['code'] ??
      normalized['type'] ??
      normalized['name'];
  normalized['label'] ??= paymentProviderLabel(normalized['provider']);

  final details = normalized['details'];
  if (details is Map) {
    normalized['account_name'] ??= details['account_name'];
    normalized['account_number'] ??=
        details['account_number'] ?? details['number'];
    normalized['instructions'] ??= details['instructions'];
  }
  return normalized;
}

bool _isEnabled(Map<String, dynamic> option) {
  if (option['enabled'] is bool) return option['enabled'] == true;
  if (option['is_enabled'] is bool) return option['is_enabled'] == true;
  if (option['active'] is bool) return option['active'] == true;
  return true;
}

String paymentProviderKey(dynamic provider) {
  return provider?.toString().trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      ) ??
      '';
}

String paymentProviderLabel(dynamic provider) {
  return switch (paymentProviderKey(provider)) {
    'gcash' => 'GCash',
    'maya' || 'paymaya' => 'Maya',
    'bank' || 'bank_transfer' => 'Bank Transfer',
    'paymongo' || 'paymongo_checkout' => 'PayMongo',
    'manual' => 'Manual Payment',
    final value when value.isNotEmpty =>
      value
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
    _ => 'Payment',
  };
}

bool isPayMongoOption(Map<String, dynamic>? option) {
  if (option == null) return false;
  return paymentProviderKey(option['provider']).startsWith('paymongo');
}

Map<String, dynamic>? paymentOptionByProvider(
  List<Map<String, dynamic>> options,
  dynamic provider,
) {
  final key = paymentProviderKey(provider);
  for (final option in options) {
    if (paymentProviderKey(option['provider']) == key) return option;
  }
  return options.isEmpty ? null : options.first;
}
