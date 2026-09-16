import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/registration_group.dart';
import 'package:racetechph/widgets/registration_group_page.dart';
import 'package:racetechph/services/api_service.dart';

void main() {
  testWidgets('lock reloads permissions after a partial action response', (
    tester,
  ) async {
    var locked = false;
    var activityRefreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationGroupPage(
          groupId: '12',
          onChanged: () async {
            activityRefreshes++;
          },
          request: (action, _) async {
            if (action == 'lock') {
              locked = true;
              return const ApiDataResult.success({
                'data': {'status': 'locked'},
              });
            }
            return ApiDataResult.success({
              'data': {
                'name': 'Team',
                'status': locked ? 'locked' : 'ready',
                'can_pay': true,
                'can_lock': !locked,
              },
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Status: locked'), findsOneWidget);
    expect(find.text('Lock Group'), findsNothing);
    expect(activityRefreshes, 1);
  });

  testWidgets('leave refreshes registrations and closes the group page', (
    tester,
  ) async {
    var left = false;
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open group'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => RegistrationGroupPage(
                    groupId: '12',
                    onChanged: () async {
                      refreshed = true;
                    },
                    request: (action, _) async {
                      if (action == 'leave') {
                        left = true;
                        return const ApiDataResult.success({
                          'message': 'Left group',
                        });
                      }
                      return const ApiDataResult.success({
                        'data': {
                          'name': 'Team',
                          'can_leave': true,
                          'can_pay': true,
                        },
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(left, isTrue);
    expect(refreshed, isTrue);
    expect(find.text('Open group'), findsOneWidget);
    expect(find.text('Group Details'), findsNothing);
  });
  test(
    'create and join send only their matching fields; individual sends none',
    () {
      expect(
        groupRegistrationFields(
          action: 'create',
          name: ' Team ',
          code: 'unused',
        ),
        {'group_action': 'create', 'group_name': 'Team'},
      );
      expect(
        groupRegistrationFields(
          action: 'join',
          name: 'unused',
          code: ' ABCDE-23456 ',
        ),
        {'group_action': 'join', 'invitation_code': 'ABCDE-23456'},
      );
      expect(groupRegistrationFields(name: 'stale', code: 'stale'), isEmpty);
    },
  );

  testWidgets('rotate displays new code and reloads after confirmation', (
    tester,
  ) async {
    var changes = 0;
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationGroupPage(
          groupId: '12',
          onChanged: () async {
            changes++;
          },
          request: (action, _) async {
            calls.add(action);
            if (action == 'rotate') {
              return const ApiDataResult.success({
                'invitation_code': 'NEW-CODE',
                'data': {},
              });
            }
            return const ApiDataResult.success({
              'data': {
                'name': 'Team',
                'can_rotate_code': true,
                'can_pay': true,
              },
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    // The underlying page stays busy until the one-time code is dismissed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('NEW-CODE'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(calls, ['', 'rotate', '']);
    expect(find.text('NEW-CODE'), findsNothing);
  });
  test(
    'individual flow remains available; group payment requires permission',
    () {
      expect(isGroupCategory({'participation_mode': 'group'}), isTrue);
      expect(isGroupCategory({}), isFalse);
      expect(groupAllowsPayment({}), isTrue);
      expect(
        groupAllowsPayment({
          'registration_group': {'can_pay': false},
        }),
        isFalse,
      );
      expect(
        groupAllowsPayment({
          'registration_group': {'can_pay': true},
        }),
        isTrue,
      );
      expect(groupAllowsPayment({'registration_group': {}}), isFalse);
      expect(
        groupPaymentReason({
          'registration_group': {
            'payment_blocked_reason': '3 more members needed',
          },
        }),
        '3 more members needed',
      );
    },
  );

  testWidgets('member permissions hide management controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationGroupPage(
          groupId: '12',
          onChanged: () async {},
          request: (_, _) async => const ApiDataResult.success({
            'data': {
              'name': 'Weekend Warriors',
              'status': 'forming',
              'member_count': 1,
              'minimum_members': 4,
              'maximum_members': 6,
              'members_needed': 3,
              'can_pay': false,
              'payment_blocked_reason': '3 more members needed',
              'can_rotate_code': false,
              'can_lock': false,
              'can_remove_members': false,
              'members': [
                {'name': 'Juan', 'is_leader': true},
              ],
            },
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Juan (Leader)'), findsOneWidget);
    expect(find.text('3 more members needed'), findsOneWidget);
    expect(find.text('Rotate Code'), findsNothing);
    expect(find.text('Lock Group'), findsNothing);
    expect(find.byTooltip('Remove member'), findsNothing);
  });

  testWidgets('remove uses registration id and reloads group and activity', (
    tester,
  ) async {
    final calls = <String>[];
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationGroupPage(
          groupId: '12',
          onChanged: () async {
            refreshed++;
          },
          request: (action, memberId) async {
            calls.add('$action:$memberId');
            return const ApiDataResult.success({
              'data': {
                'name': 'Team',
                'can_remove_members': true,
                'can_pay': true,
                'members': [
                  {
                    'name': 'Leader',
                    'is_leader': true,
                    'registration_id': 41,
                    'user_id': 7,
                  },
                  {
                    'name': 'Member',
                    'is_leader': false,
                    'registration_id': 42,
                    'user_id': 8,
                  },
                ],
              },
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove member'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(calls, [':null', 'remove:42', ':null']);
    expect(refreshed, 1);
  });

  testWidgets('one-time invitation code can be copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showInvitationCode(context, 'ABCDE-23456'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Code'));
    await tester.pump();
    expect(copied, 'ABCDE-23456');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('ABCDE-23456'), findsNothing);
  });
}
