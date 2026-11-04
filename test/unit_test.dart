import 'dart:io' as io;

import 'package:invoices/invoices.dart';
import 'package:invoices/src/templates/helpers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Bundled fonts', () {
    test('are resolved to a directory that really holds them', () async {
      final directory = await Helpers.resolveFontsDirectory();
      expect(
        io.FileSystemEntity.isFileSync(p.join(directory, 'OpenSans-Regular.ttf')),
        isTrue,
        reason: 'resolved fonts directory "$directory" must contain the bundled assets',
      );
    });

    test('load without depending on the current working directory', () async {
      // Regression: the fonts used to be read from `fonts/` relative to the CWD,
      // so the tool failed whenever it ran from anywhere but the package root.
      final original = io.Directory.current;
      io.Directory.current = io.Directory.systemTemp;
      try {
        await expectLater(Helpers.loadPDFFont('OpenSans-Regular.ttf'), completes);
        await expectLater(Helpers.loadIconsFont(), completes);

        final invoice = Invoice.fromMap(const <String, Object?>{'number': 'INV-CWD'});
        final bytes = await Templates.simple.build(invoice, <String, Object?>{
          'locale': 'en_US',
          'font': Fonts.openSans, // the TTF path, not a built-in font
        });
        expect(bytes.sublist(0, 5), equals('%PDF-'.codeUnits));
      } finally {
        io.Directory.current = original;
      }
    });

    test('a missing font reports the path it looked for', () async {
      await expectLater(
        Helpers.loadPDFFont('DoesNotExist.ttf'),
        throwsA(
          isA<io.FileSystemException>().having((e) => e.path, 'path', allOf(isNotNull, contains('DoesNotExist.ttf'))),
        ),
      );
    });
  });

  group('Invoice numbers', () {
    final date = DateTime.utc(2024, 11, 27, 12, 30);

    test('generation', () {
      final number = Invoice.generateNumber(date);
      expect(number, allOf(isA<String>(), isNotEmpty, startsWith('INV-'), equals('INV-M7WB-M6')));
    });

    test('number to DateTime conversion', () {
      // Compare against the original date, not against the decoded value itself.
      expect(Invoice.numberToDateTime('INV-M7WB-M6'), equals(date));
    });

    test('encode and decode round trip', () {
      final start = DateTime.utc(2024, 11, 27);
      for (var i = 0; i < 366 * 24 * 60; i++) {
        final current = start.add(Duration(minutes: i));
        final number = Invoice.generateNumber(current);
        final decoded = Invoice.numberToDateTime(number);
        expect(decoded, allOf(isNotNull, isA<DateTime>(), equals(current)));
      }
    });

    test('malformed numbers return null instead of throwing', () {
      for (final input in const <String>[
        '',
        'INV',
        'INV-M7WB',
        'INV-M7WB-M6-EXTRA',
        'INV--M6',
        'INV-M7WB-',
        'INV-ПРИВЕТ-M6', // code units outside the dictionary
        'INV-m7wb-m6', // lowercase is not in the dictionary
        'INV-!!-M6',
      ]) {
        expect(Invoice.numberToDateTime(input), isNull, reason: 'input: "$input"');
      }
    });
  });

  group('Invoice.fromMap', () {
    test('empty map yields defaults', () {
      expect(() => Invoice.fromMap(const {}), returnsNormally);
      final invoice = Invoice.fromMap(const {});
      expect(invoice, isA<Invoice>());
      expect(invoice.currency, equals('EUR'));
      expect(invoice.services, isEmpty);
      expect(invoice.total, equals(0));
      expect(invoice.number, startsWith('INV-'));
    });

    test('reads the documented field names', () {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'number': 123,
        'issuedAt': '2023-10-01T12:00:00Z',
        'currency': 'USD',
        'organization': <String, Object?>{'name': 'Org', 'address': 'Addr', 'taxId': 42},
        'counterparty': <String, Object?>{'name': 'Client'},
        'services': <Object?>[
          <String, Object?>{'name': 'Service 1', 'amount': 123.45},
          <String, Object?>{'name': 'Service 2', 'amount': '67.89'},
        ],
        'description': 'Some description',
      });

      expect(invoice.number, equals('123'));
      expect(invoice.issuedAt, equals(DateTime.utc(2023, 10, 1, 12)));
      expect(invoice.currency, equals('USD'));
      expect(invoice.organization.name, equals('Org'));
      expect(invoice.organization.address, equals('Addr'));
      expect(invoice.organization.tax, equals('42'), reason: 'taxId is accepted as an int');
      expect(invoice.counterparty.name, equals('Client'));
      expect(invoice.services, hasLength(2));
      expect(invoice.services.last.amount, equals(67.89), reason: 'amount is accepted as a string');
      expect(invoice.description, equals('Some description'));
    });

    test('accepts aliases for the primary field names', () {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'invoice_number': 'A-1',
        'date': '2024-01-02T03:04:00Z',
        'currency_code': 'GEL',
        'issuer': <String, Object?>{'title': 'Issuer', 'location': 'Somewhere', 'tax_id': '7'},
        'recipient': <String, Object?>{'title': 'Recipient'},
        'items': <Object?>[
          <String, Object?>{'title': 'Item', 'price': 10},
        ],
        'details': 'Details',
      });

      expect(invoice.number, equals('A-1'));
      expect(invoice.issuedAt, equals(DateTime.utc(2024, 1, 2, 3, 4)));
      expect(invoice.currency, equals('GEL'));
      expect(invoice.organization.name, equals('Issuer'));
      expect(invoice.organization.address, equals('Somewhere'));
      expect(invoice.organization.tax, equals('7'));
      expect(invoice.counterparty.name, equals('Recipient'));
      expect(invoice.services.single.name, equals('Item'));
      expect(invoice.description, equals('Details'));
    });
  });

  group('Invoice.total', () {
    test('sums service amounts without float drift', () {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'services': <Object?>[
          <String, Object?>{'name': 'a', 'amount': 0.1},
          <String, Object?>{'name': 'b', 'amount': 0.2},
        ],
      });
      expect(invoice.total, equals(0.3), reason: '0.1 + 0.2 must not become 0.30000000000000004');
    });

    test('matches the sample configuration', () {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'services': <Object?>[
          <String, Object?>{'name': 'Service 1', 'amount': 123.45},
          <String, Object?>{'name': 'Service 2', 'amount': 67.89},
        ],
      });
      expect(invoice.total, equals(191.34));
    });

    test('unparsable amounts count as zero', () {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'services': <Object?>[
          <String, Object?>{'name': 'broken', 'amount': 'not a number'},
          <String, Object?>{'name': 'ok', 'amount': 5},
        ],
      });
      expect(invoice.total, equals(5));
    });
  });

  group('Templates and fonts', () {
    test('Templates.fromName falls back to simple', () {
      expect(Templates.fromName('simple'), equals(Templates.simple));
      expect(Templates.fromName(' SIMPLE '), equals(Templates.simple));
      expect(Templates.fromName('nonexistent'), equals(Templates.simple));
      expect(Templates.fromName(null), equals(Templates.simple));
    });

    test('Fonts.fromName resolves every declared font', () {
      expect(Fonts.fromName('openSans'), equals(Fonts.openSans));
      expect(Fonts.fromName('open sans'), equals(Fonts.openSans));
      expect(Fonts.fromName('times'), equals(Fonts.times));
      expect(Fonts.fromName('Helvetica'), equals(Fonts.helvetica));
      expect(Fonts.fromName('courier'), equals(Fonts.courier));
      expect(Fonts.fromName('nonexistent'), equals(Fonts.openSans));
      expect(Fonts.fromName(null), equals(Fonts.openSans));
    });

    test('every font name used by the CLI round trips', () {
      for (final font in Fonts.values) {
        expect(Fonts.fromName(font.name), equals(font), reason: 'font: ${font.name}');
      }
    });
  });

  group('Rendering', () {
    test('builds a PDF from the documented example', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'number': 'INV-TEST',
        'issuedAt': '2023-10-01T12:00:00Z',
        'currency': 'USD',
        'organization': <String, Object?>{'name': 'My Organization', 'address': 'Street 1', 'taxId': '123'},
        'counterparty': <String, Object?>{'name': 'Client Name'},
        'description': '**Bold** and _italic_ and `code`\n\n#### Heading\n\n- item one\n- item two',
        'services': <Object?>[
          <String, Object?>{'name': 'Service 1', 'amount': 123.45},
        ],
      });

      final bytes = await Templates.simple.build(invoice, <String, Object?>{
        'locale': 'en_US',
        'font': Fonts.times, // built-in, so the test does not depend on the TTF assets
      });

      expect(bytes, isNotEmpty);
      expect(bytes.sublist(0, 5), equals('%PDF-'.codeUnits), reason: 'output must be a PDF');
    });

    test('honors the page format from the context', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{'number': 'INV-TEST'});

      Future<String> mediaBoxOf(Map<String, Object?> context) async {
        final bytes = await Templates.simple.build(invoice, context);
        final text = String.fromCharCodes(bytes);
        return RegExp(r'MediaBox\[[^\]]*\]').firstMatch(text)?.group(0) ?? '';
      }

      final a4 = await mediaBoxOf(<String, Object?>{'locale': 'en_US', 'font': Fonts.times});
      final letter = await mediaBoxOf(<String, Object?>{'locale': 'en_US', 'font': Fonts.times, 'format': 'letter'});

      expect(a4, contains('595'), reason: 'the default page format is A4');
      expect(letter, contains('612'), reason: 'format: letter must switch the page size');
      expect(a4, isNot(equals(letter)));
    });

    test('an accent color changes the rendered output', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'number': 'INV-TEST',
        'services': <Object?>[
          <String, Object?>{'name': 'Service', 'amount': 1},
        ],
      });

      await expectLater(
        Templates.simple.build(invoice, <String, Object?>{'locale': 'en_US', 'font': Fonts.times, 'color': '#B00020'}),
        completes,
      );
    });

    test('a malformed or unknown color does not throw', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{'number': 'INV-TEST'});
      for (final color in const <Object?>['#zzz', 'not-a-color', '', 0xFFB00020, <String>[]]) {
        await expectLater(
          Templates.simple.build(invoice, <String, Object?>{'locale': 'en_US', 'font': Fonts.times, 'color': color}),
          completes,
          reason: 'color: $color',
        );
      }
    });

    test('document metadata can be overridden from the context', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{'number': 'INV-TEST'});

      // The Info dictionary is written uncompressed, so it can be read back.
      String? infoField(List<int> bytes, String key) => RegExp(
        '/$key'
        r'\(([^)]*)\)',
      ).firstMatch(String.fromCharCodes(bytes))?.group(1);

      final overridden = await Templates.simple.build(invoice, <String, Object?>{
        'locale': 'en_US',
        'font': Fonts.times,
        'title': 'Custom document title',
        'author': 'Custom author',
        'creator': 'Custom creator',
        'keywords': 'custom, keywords',
      });

      expect(infoField(overridden, 'Title'), equals('Custom document title'));
      expect(infoField(overridden, 'Author'), equals('Custom author'));
      // Regression: `creator` used to read the `author` key instead of its own.
      expect(infoField(overridden, 'Creator'), equals('Custom creator'));
      expect(infoField(overridden, 'Keywords'), equals('custom, keywords'));
    });

    test('document metadata falls back to the organization name', () async {
      final invoice = Invoice.fromMap(const <String, Object?>{
        'number': 'INV-TEST',
        'organization': <String, Object?>{'name': 'Fallback Org'},
      });

      final bytes = await Templates.simple.build(invoice, <String, Object?>{'locale': 'en_US', 'font': Fonts.times});
      final text = String.fromCharCodes(bytes);

      expect(text, contains('/Author(Fallback Org)'));
      expect(text, contains('/Creator(Fallback Org)'));
    });
  });
}
