import 'package:invoices/invoices.dart';
import 'package:test/test.dart';

void main() => group('Unit Tests', () {
  final date = DateTime.utc(2024, 11, 27, 12, 30);

  test('Invoice number generation', () {
    final number = Invoice.generateNumber(date);
    expect(number, allOf(isA<String>(), isNotEmpty, startsWith('INV-'), equals('INV-M7WB-M6')));
  });

  test('Invoice number to DateTime conversion', () {
    final date = Invoice.numberToDateTime('INV-M7WB-M6');
    expect(date, allOf(isNotNull, isA<DateTime>(), equals(date)));
  });

  test('Encode and decode invoice number', () {
    final date = DateTime.utc(2024, 11, 27, 0, 0);
    for (var i = 0; i < 366 * 24 * 60; i++) {
      final current = date.add(Duration(minutes: i));
      final number = Invoice.generateNumber(current);
      final decoded = Invoice.numberToDateTime(number);
      expect(decoded, allOf(isNotNull, isA<DateTime>(), equals(current)));
    }
  });

  test('Invoice from empty map', () {
    expect(() => Invoice.fromMap(const {}), returnsNormally);
    expect(Invoice.fromMap(const {}), isA<Invoice>());
  });
});
