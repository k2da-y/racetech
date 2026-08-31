import 'event_schedule_formatter.dart';

const _joinedRegistrationStatuses = {
  'registered',
  'pending',
  'approved',
  'checked_in',
  'completed',
};

/// Converts the event API response into the common shape used by Home and
/// Search. Registration availability remains authoritative to the backend.
Map<String, dynamic> normalizeEventFromApi(Map<String, dynamic> source) {
  final event = Map<String, dynamic>.from(source);
  final states = _registrationStates(source['category_registration_states']);
  final statesByCategoryId = <String, Map<String, dynamic>>{
    for (final state in states)
      if (_id(state['category_id']).isNotEmpty)
        _id(state['category_id']): state,
  };
  final hasCategoryStates =
      source['category_registration_states'] is List ||
      source['category_registration_states'] is Map;
  final activeCategoryIds =
      ((source['active_registered_category_ids'] as List?) ?? const [])
          .map(_id)
          .toSet();

  final categories = ((source['categories'] as List?) ?? const [])
      .whereType<Map>()
      .map((value) {
        final category = Map<String, dynamic>.from(value);
        final state = statesByCategoryId[_id(category['id'])];

        // Legacy responses did not provide category states. Leaving their
        // categories untouched preserves the existing event-level fallback.
        if (state == null && !hasCategoryStates) return category;
        final stateValues = state ?? const <String, dynamic>{};

        final status =
            (stateValues['registration_status'] ??
                    stateValues['user_registration_status'] ??
                    stateValues['status'] ??
                    category['registration_status'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();
        final isRegistered = stateValues['is_registered'] is bool
            ? stateValues['is_registered'] == true
            : _joinedRegistrationStatuses.contains(status) ||
                  activeCategoryIds.contains(_id(category['id']));
        final conflictReason =
            (stateValues['conflict_reason'] ??
                    stateValues['registration_conflict_reason'] ??
                    category['conflict_reason'] ??
                    '')
                .toString()
                .trim();
        final canRegister =
            _firstBool(state ?? category, const [
              'can_register',
              'registration_allowed',
              'is_eligible',
            ]) ??
            (!isRegistered &&
                conflictReason.isEmpty &&
                (category['status'] ?? '').toString().toLowerCase() == 'open');

        return {
          ...category,
          'can_register': canRegister,
          'is_registered': isRegistered,
          'registration_status': status,
          'conflict_reason': conflictReason,
        };
      })
      .toList();
  final interest = (source['interest_type'] ?? '').toString();

  return {
    ...event,
    'id': source['id'],
    'event': interest.isEmpty ? 'Race Event' : interest,
    'title': source['title'] ?? 'Untitled Event',
    'participants': source['participants_count'] ?? 0,
    'event_start_date': source['event_start_date'],
    'event_end_date': source['event_end_date'],
    'legacy_event_date': source['event_date'],
    'date': formatEventDateRange(
      eventStartDate: source['event_start_date'],
      eventEndDate: source['event_end_date'],
      legacyEventDate: source['event_date'],
    ),
    'time': source['start_time'] ?? 'TBA',
    'end_time': source['end_time'],
    'image': source['image'] ?? 'assets/map.jpg',
    'banner_url': source['banner_url'],
    'venue': source['venue'] ?? '',
    'status': source['status'] ?? '',
    'is_registered': source['is_registered'] == true,
    'registration_status': source['registration_status'],
    'registered_category_id': source['registered_category_id'],
    'registered_category_ids': source['registered_category_ids'],
    'active_registered_category_ids': source['active_registered_category_ids'],
    'category_registration_states':
        source['category_registration_states'] ??
        (hasCategoryStates ? [] : null),
    'description': source['description'] ?? '',
    'type_details': source['type_details'],
    'type_detail_items':
        source['type_detail_items'] ??
        source['detail_items'] ??
        source['formatted_detail_items'],
    'category_label': source['category_label'],
    'payment_options': source['payment_options'],
    'payment_instructions': source['payment_instructions'],
    'tags': [
      if (interest.isNotEmpty) interest,
      ...categories.map((category) => (category['name'] ?? '').toString()),
    ],
    'categories': categories,
    'from_api': true,
  };
}

List<Map<String, dynamic>> _registrationStates(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((state) => Map<String, dynamic>.from(state))
        .toList();
  }

  if (value is Map) {
    return value.entries.where((entry) => entry.value is Map).map((entry) {
      final state = Map<String, dynamic>.from(entry.value as Map);
      state.putIfAbsent('category_id', () => entry.key);
      return state;
    }).toList();
  }

  return const [];
}

bool? _firstBool(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    if (values[key] is bool) return values[key] as bool;
  }
  return null;
}

String _id(dynamic value) => value?.toString().trim() ?? '';
