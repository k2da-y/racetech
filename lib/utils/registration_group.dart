bool isGroupCategory(Map<String, dynamic>? category) =>
    category?['participation_mode'] == 'group';

Map<String, String> groupRegistrationFields({
  String? action,
  String? name,
  String? code,
}) => switch (action) {
  'create' => {'group_action': 'create', 'group_name': (name ?? '').trim()},
  'join' => {'group_action': 'join', 'invitation_code': (code ?? '').trim()},
  _ => {},
};

Map<String, dynamic>? registrationGroup(Map<String, dynamic>? registration) {
  final value = registration?['registration_group'];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

bool groupAllowsPayment(Map<String, dynamic>? registration) {
  final group = registrationGroup(registration);
  return group == null || group['can_pay'] == true;
}

String groupPaymentReason(Map<String, dynamic>? registration) =>
    (registrationGroup(registration)?['payment_blocked_reason'] ??
            'Payment is unavailable until your group is ready.')
        .toString();
