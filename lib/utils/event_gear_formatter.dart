String categoryGearLabel(
  Map<String, dynamic> category, {
  required dynamic eventType,
  dynamic eventTypeDetails,
  dynamic eventTypeDetailItems,
}) {
  final type = _normalized(eventType?.toString() ?? '');
  final heading = type.contains('trail run')
      ? 'Mandatory Gear'
      : type.contains('hiking')
      ? 'Required Gear'
      : '';
  if (heading.isEmpty) return '';

  var gear = _gearFrom(
    category['type_detail_items'] ??
        category['detail_items'] ??
        category['formatted_detail_items'],
  );
  if (gear.isEmpty) gear = _gearFrom(category['type_details']);
  if (gear.isEmpty) gear = _gearFrom(eventTypeDetailItems);
  if (gear.isEmpty) gear = _gearFrom(eventTypeDetails);

  return gear.isEmpty ? '' : '$heading: $gear';
}

String _gearFrom(dynamic source) {
  if (source is Map) {
    final nested = source['items'];
    if (nested is List) return _gearFrom(nested);

    for (final entry in source.entries) {
      if (isGearDetailLabel(entry.key)) {
        final value = _formatValue(entry.value);
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  if (source is! List) return '';
  for (final item in source.whereType<Map>()) {
    final label =
        item['label'] ?? item['name'] ?? item['title'] ?? item['key'] ?? '';
    if (!isGearDetailLabel(label)) continue;
    final value =
        item['formatted_value'] ??
        item['display_value'] ??
        item['value'] ??
        item['text'];
    final formatted = _formatValue(value);
    if (formatted.isNotEmpty) return formatted;
  }
  return '';
}

String _formatValue(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.map(_formatValue).where((item) => item.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.values
        .map(_formatValue)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  return value.toString().trim();
}

bool isGearDetailLabel(dynamic label) {
  final normalized = _normalized(label?.toString() ?? '');
  return normalized.contains('gear') ||
      normalized.contains('required equipment') ||
      normalized.contains('mandatory equipment');
}

String _normalized(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
