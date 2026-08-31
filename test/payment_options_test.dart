import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/payment_options.dart';

void main() {
  test('returns only enabled event payment options', () {
    final options = enabledPaymentOptions(
      event: {
        'payment_options': [
          {'provider': 'gcash', 'enabled': true},
          {'provider': 'maya', 'enabled': false},
          {'provider': 'bank_transfer', 'enabled': true},
          {'provider': 'paymongo', 'enabled': true},
        ],
      },
    );

    expect(options.map((option) => option['provider']), [
      'gcash',
      'bank_transfer',
      'paymongo',
    ]);
  });

  test('category options take precedence over event options', () {
    final options = enabledPaymentOptions(
      category: {
        'payment_options': {
          'maya': {
            'enabled': true,
            'account_name': 'Race Organizer',
            'account_number': '09123456789',
          },
        },
      },
      event: {
        'payment_options': ['gcash'],
      },
    );

    expect(options.single['provider'], 'maya');
    expect(options.single['account_name'], 'Race Organizer');
  });

  test('supports legacy payment instructions', () {
    final options = enabledPaymentOptions(
      category: {
        'payment_instructions': {
          'provider': 'gcash',
          'account_name': 'Legacy Organizer',
        },
      },
    );

    expect(options.single['provider'], 'gcash');
    expect(options.single['account_name'], 'Legacy Organizer');
  });

  test('recognizes PayMongo and formats provider labels', () {
    expect(isPayMongoOption({'provider': 'paymongo'}), isTrue);
    expect(paymentProviderLabel('gcash'), 'GCash');
    expect(paymentProviderLabel('bank_transfer'), 'Bank Transfer');
  });
}
