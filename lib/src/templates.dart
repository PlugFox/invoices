import 'dart:typed_data';

import 'package:invoices/src/invoice.dart';
import 'package:invoices/src/templates/templates_simple.dart';

/// Enum representing different invoice templates.
/// Each template is associated with a function that builds a PDF from an invoice.
enum Templates {
  simple(pdfBuilderSimple);

  const Templates(this.build);

  /// Factory constructor to get a template by its name.
  factory Templates.fromName(String? name) {
    return switch (name?.trim().toLowerCase()) {
      'simple' => simple,
      _ => simple,
    };
  }

  /// The function that builds a PDF from an invoice.
  final Future<Uint8List> Function(Invoice invoice, Map<String, Object?> context) build;
}
