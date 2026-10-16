/// Display only. Keep distance_km untouched for rules and comparisons.
String categoryDistanceLabel(Map<String, dynamic> category) {
  double? number(dynamic value) {
    final parsed = double.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  String format(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');

  final value = number(category['distance_value']);
  final unit = (category['distance_unit'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (value != null) {
    if (const {
      'km',
      'kilometer',
      'kilometers',
      'kilometre',
      'kilometres',
    }.contains(unit)) {
      return '${format(value)} km';
    }
    if (const {'mi', 'mile', 'miles'}.contains(unit)) {
      return '${format(value)} ${value == 1 ? 'mile' : 'miles'}';
    }
  }

  // Never label the canonical kilometre value with a partial/new unit.
  final legacy = number(category['distance_km']);
  return legacy == null ? '' : '${format(legacy)} km';
}

List<Map<String, String>> _detailItems(dynamic source) {
  if (source is Map) {
    final nested = source['items'];
    if (nested is List) return _detailItems(nested);

    return source.entries.expand((entry) {
      if (entry.value is Map) return _detailItems(entry.value);
      final value = _distanceValue(entry.key.toString(), entry.value);
      return value.isEmpty
          ? const <Map<String, String>>[]
          : [
              {'label': entry.key.toString(), 'value': value},
            ];
    }).toList();
  }

  if (source is! List) return const [];
  return source
      .whereType<Map>()
      .map((item) {
        final label =
            item['label'] ?? item['name'] ?? item['title'] ?? item['key'];
        final value =
            item['formatted_value'] ??
            item['display_value'] ??
            item['value'] ??
            item['text'];
        return {
          'label': label?.toString().trim() ?? '',
          'value': _distanceValue(label?.toString() ?? '', value),
        };
      })
      .where((item) {
        return item['label']!.isNotEmpty && item['value']!.isNotEmpty;
      })
      .toList();
}

String _distanceValue(String label, dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';
  final looksNumeric = double.tryParse(raw) != null;
  final isDistance =
      label.toLowerCase().contains('distance') ||
      RegExp(
        r'(^|[_\s])(km|kilometers?)($|[_\s])',
      ).hasMatch(label.toLowerCase());
  return looksNumeric && isDistance ? '$raw km' : raw;
}

String _normalized(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

Map<String, String>? _find(
  List<Map<String, String>> items,
  bool Function(String label) matches,
) {
  for (final item in items) {
    if (matches(_normalized(item['label']!))) return item;
  }
  return null;
}

String categorySegmentDistanceLabel(
  Map<String, dynamic> category, {
  required dynamic eventType,
  dynamic eventTypeDetails,
  dynamic eventTypeDetailItems,
}) {
  final type = _normalized(eventType?.toString() ?? '');
  final isTriathlon = type.contains('triathlon');
  final isDuathlon = type.contains('duathlon');
  if (!isTriathlon && !isDuathlon) return '';

  var items = _detailItems(
    category['type_detail_items'] ??
        category['detail_items'] ??
        category['formatted_detail_items'],
  );
  if (items.isEmpty) items = _detailItems(category['type_details']);

  String result;
  if (isTriathlon) {
    final swim = _find(items, (label) => label.contains('swim'));
    final bike = _find(
      items,
      (label) => label.contains('bike') || label.contains('cycling'),
    );
    final run = _find(
      items,
      (label) =>
          label.contains('run') &&
          !label.contains('first') &&
          !label.contains('second'),
    );
    result = _joinSegments([('Swim', swim), ('Bike', bike), ('Run', run)]);
  } else {
    final firstRun = _find(
      items,
      (label) =>
          label.contains('run') &&
          (label.contains('first') ||
              label.contains('1st') ||
              label.contains('one') ||
              RegExp(r'(^| )1( |$)').hasMatch(label)),
    );
    final bike = _find(
      items,
      (label) => label.contains('bike') || label.contains('cycling'),
    );
    final secondRun = _find(
      items,
      (label) =>
          label.contains('run') &&
          (label.contains('second') ||
              label.contains('2nd') ||
              label.contains('two') ||
              RegExp(r'(^| )2( |$)').hasMatch(label)),
    );
    result = _joinSegments([
      ('First run', firstRun),
      ('Bike', bike),
      ('Second run', secondRun),
    ]);
  }

  if (result.isNotEmpty) return result;

  // Legacy events stored segment distances at event level.
  items = _detailItems(eventTypeDetailItems);
  if (items.isEmpty) items = _detailItems(eventTypeDetails);
  if (items.isEmpty) return '';
  return categorySegmentDistanceLabel({
    'type_detail_items': items,
  }, eventType: eventType);
}

String _joinSegments(List<(String name, Map<String, String>? item)> segments) {
  return segments
      .where((segment) => segment.$2 != null)
      .map((segment) => '${segment.$1} ${segment.$2!['value']}')
      .join(' \u2022 ');
}
