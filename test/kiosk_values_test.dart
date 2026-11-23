import 'package:flutter_test/flutter_test.dart';
import 'package:suho_angel/utils/kiosk_values.dart';

void main() {
  test('canonical and alternate IDs retain the assigned identity', () {
    expect(kioskIdentity({'kioskId': ' pet '}), 'pet');
    expect(kioskIdentity({'kioskID': 7}), '7');
    expect(kioskIdentity({'kioskId': ' ', 'kioskID': ' pet '}), 'pet');
    expect(kioskIdentity({'kioskId': 'other', 'kioskID': 'pet'}), 'other');
    expect(kioskIdentity({'kioskId': false}), isEmpty);
  });

  test(
      'mixed numeric capacity preserves zero and over-capacity without inventing values',
      () {
    for (final current in [0, '14', 1000, '1250']) {
      expect(
          kioskHasUsableCapacity(
              {'currentCapacity': current, 'maxCapacity': '1000'}),
          isTrue);
    }
    for (final row in [
      {'currentCapacity': '', 'maxCapacity': 1000},
      {'currentCapacity': true, 'maxCapacity': 1000},
      {'currentCapacity': -1, 'maxCapacity': 1000},
      {'currentCapacity': 14, 'maxCapacity': 0},
      {'currentCapacity': 'NaN', 'maxCapacity': 1000},
      {'currentCapacity': 1e308, 'maxCapacity': 1e-308},
    ]) {
      expect(kioskHasUsableCapacity(row), isFalse);
    }
    expect(kioskNumber(' 14 '), 14);
    expect(kioskNumber('Infinity'), isNull);
  });
}
