import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/registration_group.dart';

Future<bool> checkGroupPayment(
  BuildContext context,
  Map<String, dynamic>? registration,
) async {
  final group = registrationGroup(registration);
  if (group == null) return true;
  final result = await ApiService().groupRequest('${group['id']}');
  if (!context.mounted) return false;
  final data = result.data?['data'];
  if (!result.success || data is! Map) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
    return false;
  }
  final updated = {'registration_group': data};
  if (groupAllowsPayment(updated)) return true;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(groupPaymentReason(updated))));
  return false;
}

Future<void> showInvitationCode(
  BuildContext context,
  String code,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: const Text('Group invitation code'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(code),
        const SizedBox(height: 12),
        const Text(
          'This code is shown only once. Copy it to invite members. You can rotate it if lost; the previous code will stop working.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Code copied')));
          }
        },
        child: const Text('Copy Code'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  ),
);

class RegistrationGroupPage extends StatefulWidget {
  final Future<ApiDataResult<Map<String, dynamic>>> Function(
    String action,
    String? memberId,
  )?
  request;
  final String groupId;
  final Future<void> Function() onChanged;
  const RegistrationGroupPage({
    this.request,
    super.key,
    required this.groupId,
    required this.onChanged,
  });
  @override
  State<RegistrationGroupPage> createState() => _RegistrationGroupPageState();
}

class _RegistrationGroupPageState extends State<RegistrationGroupPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? group;
  bool busy = false;
  String? error;
  Future<ApiDataResult<Map<String, dynamic>>> request(
    String action, {
    String? memberId,
  }) =>
      widget.request?.call(action, memberId) ??
      ApiService().groupRequest(
        widget.groupId,
        action: action,
        memberRegistrationId: memberId,
      );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    final result = await request('');
    if (!mounted) return;
    setState(() {
      busy = false;
      group = result.success && result.data?['data'] is Map
          ? Map<String, dynamic>.from(result.data!['data'])
          : null;
      if (group == null) error = result.message;
    });
  }

  Future<void> act(String action, String label, {String? memberId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text(switch (action) {
          'rotate' => 'The previous invitation code will stop working.',
          'lock' =>
            'Lock this group roster? Member management will no longer be available.',
          'leave' => 'Your category registration will be withdrawn.',
          _ => 'Remove this participant from the group?',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    final result = await request(action, memberId: memberId);
    if (!mounted) return;
    if (result.success) {
      final code = result.data?['invitation_code']?.toString() ?? '';
      if (code.isNotEmpty) await showInvitationCode(context, code);
      await widget.onChanged();
      if (!mounted) return;
      if (action == 'leave') {
        Navigator.pop(context);
        return;
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    }
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data = group;
    return Scaffold(
      appBar: AppBar(title: const Text('Group Details')),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : data == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error ?? 'Group unavailable'),
                  TextButton(onPressed: refresh, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await refresh();
                await widget.onChanged();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${data['name'] ?? 'Group'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Status: ${data['status'] ?? ''}'),
                  Text(
                    'Members: ${data['member_count']} • Minimum: ${data['minimum_members']} • Maximum: ${data['maximum_members']}',
                  ),
                  Text('Members needed: ${data['members_needed'] ?? 0}'),
                  if (data['can_pay'] != true)
                    Text(
                      '${data['payment_blocked_reason'] ?? 'Waiting for group readiness.'}',
                    ),
                  const Text('Each member pays for their own registration.'),
                  for (final member
                      in ((data['members'] as List?) ?? []).whereType<Map>())
                    ListTile(
                      title: Text(
                        '${member['name'] ?? 'Participant'}${member['is_leader'] == true ? ' (Leader)' : ''}',
                      ),
                      subtitle: Text(
                        '${member['registration_status']} • Payment: ${member['payment_status']}',
                      ),
                      trailing:
                          data['can_remove_members'] == true &&
                              member['is_leader'] != true &&
                              member['registration_id'] != null
                          ? IconButton(
                              tooltip: 'Remove member',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => act(
                                'remove',
                                'Remove member',
                                memberId: '${member['registration_id']}',
                              ),
                            )
                          : null,
                    ),
                  if (data['can_rotate_code'] == true)
                    OutlinedButton(
                      onPressed: () => act('rotate', 'Rotate invitation code'),
                      child: const Text('Rotate Code'),
                    ),
                  if (data['can_lock'] == true)
                    OutlinedButton(
                      onPressed: () => act('lock', 'Lock group'),
                      child: const Text('Lock Group'),
                    ),
                  if (data['can_leave'] == true)
                    OutlinedButton(
                      onPressed: () => act('leave', 'Leave group'),
                      child: const Text('Leave Group'),
                    ),
                ],
              ),
            ),
    );
  }
}
