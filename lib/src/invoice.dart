import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// {@template organization}
/// Represents an organization involved in the invoice.
/// Contains details such as name, address, tax information, and description.
/// {@endtemplate}
@immutable
class Organization {
  /// Creates an instance of [Organization].
  /// Requires [name], [address], [tax], and [description] to be provided.
  /// [address], [tax], and [description] can be null.
  /// {@macro organization}
  const Organization({
    required this.name,
    required this.address,
    required this.tax,
    required this.description,
    this.extra = const {},
  });

  /// Factory constructor to create an [Organization] from a map.
  factory Organization.fromMap(Map<String, Object?> map) => Organization(
    name: switch (map['name'] ?? map['title']) {
      String text => text,
      _ => 'Unknown Organization',
    },
    address: switch (map['address'] ?? map['location']) {
      String text => text,
      _ => null,
    },
    tax: switch (map['tax'] ?? map['tax_id'] ?? map['taxId']) {
      String text => text,
      int number => number.toString(),
      _ => null,
    },
    description: switch (map['description'] ?? map['details'] ?? map['info']) {
      String text => text,
      _ => null,
    },
    extra: map,
  );

  /// Name of the organization.
  final String name;

  /// Address of the organization.
  final String? address;

  /// Tax information of the organization.
  final String? tax;

  /// Description of the organization.
  final String? description;

  /// Extra information
  final Map<String, Object?> extra;

  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Organization &&
          name == other.name &&
          address == other.address &&
          tax == other.tax &&
          description == other.description);

  @override
  String toString() => 'Organization{name: $name}';
}

/// {@template provided_service}
/// Represents a service provided in the invoice.
/// Contains details such as service name, and amount.
/// {@endtemplate}
@immutable
class ProvidedService implements Comparable<ProvidedService> {
  /// Creates an instance of [ProvidedService].
  /// Requires [name] and [amount] to be provided.
  /// [amount] can be a decimal number.
  /// {@macro provided_service}
  const ProvidedService({required this.name, required this.amount, this.extra = const {}});

  /// Factory constructor to create a [ProvidedService] from a map.
  /// It tries to extract the service name and amount from the map.
  /// If the name or amount is not found, it defaults to 'Unknown Service' and 0 respectively.
  /// {@macro provided_service}
  factory ProvidedService.fromMap(Map<String, Object?> map) => ProvidedService(
    name: switch (map['name'] ?? map['title']) {
      String text => text,
      _ => 'Unknown Service',
    },
    amount: switch (map['amount'] ?? map['price'] ?? map['cost']) {
      num number => number,
      String text => num.tryParse(text) ?? 0,
      _ => 0,
    },
    extra: map,
  );

  /// Name of the service.
  /// This is a descriptive name for the service provided.
  final String name;

  /// Amount charged for the service.
  /// This can be a decimal number representing the cost of the service.
  final num amount;

  /// Extra information
  final Map<String, Object?> extra;

  @override
  int compareTo(covariant ProvidedService other) => name.compareTo(other.name);

  @override
  int get hashCode => name.hashCode ^ amount.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProvidedService && name == other.name && amount == other.amount;

  @override
  String toString() => 'ProvidedService{name: $name}';
}

/// {@template invoice}
/// Represents an invoice.
/// Contains details such as invoice number, issued date, currency, organization,
/// counterparty, services provided, and an optional description.
/// The invoice can be compared based on the issued date.
/// {@endtemplate}
@immutable
class Invoice implements Comparable<Invoice> {
  /// Creates an instance of [Invoice].
  /// Requires [number], [issuedAt], [currency], [organization], [counterparty], [services], and [description].
  /// [number] is generated if not provided.
  /// {@macro invoice}
  const Invoice({
    required this.number,
    required this.issuedAt,
    required this.currency,
    required this.organization,
    required this.counterparty,
    required this.services,
    required this.description,
    this.extra = const {},
  });

  static const String _numberDictionary = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Generate invoice number based on the issued date.
  /// The format is 'INV-DATE-TIME', where DATE is encoded from the year, month, and day,
  /// and TIME is encoded from the hour and minute.
  static String generateNumber(DateTime issuedAt) {
    final dt = issuedAt.toUtc();
    // Object().hashCode.toRadixString(36)
    final dic = _numberDictionary.codeUnits;
    String num2string(int num) {
      if (num < 0) return '-${num2string(-num)}';
      if (num == 0) return '0';
      final sb = StringBuffer();
      while (num > 0) {
        sb.write(String.fromCharCode(dic[num % dic.length]));
        num ~/= dic.length;
      }
      return sb.toString().split('').reversed.join();
    }

    return 'INV-${num2string((dt.year << 9) | (dt.month << 5) | (dt.day))}-${num2string(dt.hour << 6 | dt.minute)}';
  }

  /// Convert a number string to a [DateTime].
  /// The number string should be in the format 'INV-DATE-TIME',
  /// where DATE is encoded from the year, month, and day,
  /// and TIME is encoded from the hour and minute.
  static DateTime? numberToDateTime(String number) {
    final parts = number.split('-');
    if (parts.length != 3) return null;
    final [_, $date, $time] = parts;
    final dic = Uint8List(255);
    const length = _numberDictionary.length;
    for (final (i, c) in _numberDictionary.codeUnits.indexed) dic[c] = i;
    int string2num(String str) {
      int num = 0;
      for (var i = 0; i < str.length; i++) num = num * length + dic[str.codeUnitAt(i)];
      return num;
    }

    final date = string2num($date);
    final time = string2num($time);
    return DateTime.utc(
      (date >> 9) & 0x1FFF, // Year
      (date >> 5) & 0xF, // Month
      date & 0x1F, // Day
      (time >> 6) & 0x1F, // Hour
      time & 0x3F, // Minute
    );
  }

  /// Factory constructor to create an [Invoice] from a map.
  /// It tries to extract the invoice number, issued date, currency, organization,
  /// counterparty, services provided, and description from the map.
  /// {@macro invoice}
  factory Invoice.fromMap(Map<String, Object?> map) {
    final issuedAt =
        switch (map['issuedAt'] ?? map['issued_at'] ?? map['issued'] ?? map['date'] ?? map['timestamp']) {
          String text => DateTime.tryParse(text),
          int timestamp => DateTime.fromMillisecondsSinceEpoch(timestamp),
          DateTime dateTime => dateTime,
          _ => null,
        } ??
        DateTime.now();
    return Invoice(
      number: switch (map['number'] ?? map['invoiceNumber'] ?? map['invoice_number'] ?? map['id']) {
        String text => text,
        int number => number.toString(),
        _ => Invoice.generateNumber(issuedAt),
      },
      issuedAt: issuedAt,
      currency: switch (map['currency'] ?? map['currency_code'] ?? map['currencyCode']) {
        String text => text,
        _ => 'EUR', // Default currency
      },
      organization: switch (map['organization'] ?? map['issuer'] ?? map['company'] ?? map['from']) {
        Map<String, Object?> org => Organization.fromMap(org),
        Organization org => org,
        _ => Organization.fromMap(const {}),
      },
      counterparty: switch (map['counterparty'] ?? map['recipient'] ?? map['customer'] ?? map['to']) {
        Map<String, Object?> org => Organization.fromMap(org),
        Organization org => org,
        _ => Organization.fromMap(const {}),
      },
      services: switch (map['services'] ?? map['items'] ?? map['products']) {
        List<Object?> list => list
            .map<ProvidedService>(
              (e) => switch (e) {
                Map<String, Object?> service => ProvidedService.fromMap(service),
                ProvidedService service => service,
                _ => ProvidedService.fromMap(const {}),
              },
            )
            .toList(growable: false),
        _ => const [],
      },
      description: switch (map['description'] ?? map['details'] ?? map['info']) {
        String text => text,
        _ => null,
      },
      extra: map,
    );
  }

  /// Invoice number
  final String number;

  /// Issued at
  final DateTime issuedAt;

  /// Currency
  final String currency;

  /// Organization
  final Organization organization;

  /// Counterparty
  final Organization counterparty;

  /// Services provided
  final List<ProvidedService> services;

  /// Description
  final String? description;

  /// Extra information
  /// This can include additional metadata or custom fields related to the invoice.
  final Map<String, Object?> extra;

  /// Total amount of the invoice, calculated as the sum of all service amounts.
  double get total {
    var total = 0;
    for (final service in services) total += (service.amount * 100).round(); // Round to 2 decimal places
    return total / 100; // Convert back to floating point
  }

  @override
  int compareTo(covariant Invoice other) => other.issuedAt.compareTo(issuedAt);

  @override
  int get hashCode => number.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Invoice &&
          issuedAt == other.issuedAt &&
          organization == other.organization &&
          counterparty == other.counterparty &&
          number == other.number &&
          description == other.description &&
          const ListEquality<ProvidedService>().equals(services, other.services);

  @override
  String toString() => 'Invoice{number: $number}';
}
