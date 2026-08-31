String categoryTrailDifficultyLabel(
  Map<String, dynamic> category, {
  required dynamic eventType,
  dynamic eventTypeDetails,
  dynamic eventTypeDetailItems,
}) {
  final type = _normalized(eventType?.toString() ?? '');
  if (!type.contains('trail run')) return '';

  var difficulty = _difficultyFrom(
    category['type_detail_items'] ??
        category['detail_items'] ??
        category['formatted_detail_items'],
  );
  if (difficulty.isEmpty) {
    difficulty = _difficultyFrom(category['type_details']);
  }
  if (difficulty.isEmpty) difficulty = _difficultyFrom(eventTypeDetailItems);
  if (difficulty.isEmpty) difficulty = _difficultyFrom(eventTypeDetails);

  return difficulty.isEmpty ? '' : 'Trail Difficulty: $difficulty';
}

String _difficultyFrom(dynamic source) {
  if (source is Map) {
    final nested = source['items'];
    if (nested is List) return _difficultyFrom(nested);

    for (final entry in source.entries) {
      if (isTrailDifficultyDetailLabel(entry.key)) {
        return entry.value?.toString().trim() ?? '';
      }
    }
    return '';
  }

  if (source is! List) return '';
  for (final item in source.whereType<Map>()) {
    final label =
        item['label'] ?? item['name'] ?? item['title'] ?? item['key'] ?? '';
    if (!isTrailDifficultyDetailLabel(label)) continue;
    final value =
        item['formatted_value'] ??
        item['display_value'] ??
        item['value'] ??
        item['text'];
    final formatted = value?.toString().trim() ?? '';
    if (formatted.isNotEmpty) return formatted;
  }
  return '';
}

bool isTrailDifficultyDetailLabel(dynamic label) {
  final normalized = _normalized(label?.toString() ?? '');
  return normalized == 'trail difficulty' ||
      normalized == 'trail difficulty level';
}

String _normalized(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
