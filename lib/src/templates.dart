import 'dart:typed_data';

import 'package:invoices/src/invoice.dart';
import 'package:invoices/src/templates/templates_simple.dart';

/// Enum representing different invoice templates.
/// Each template is associated with a function that builds a PDF from an invoice.
enum Templates {
  simple(build: pdfBuilderSimple, description: 'A simple invoice template with basic layout and styling.');

  const Templates({required this.build, required this.description});

  /// Factory constructor to get a template by its name.
  factory Templates.fromName(String? name) => switch (name?.trim().toLowerCase()) {
    'simple' => simple,
    _ => simple,
  };

  /// The function that builds a PDF from an invoice.
  final Future<Uint8List> Function(Invoice invoice, Map<String, Object?> context) build;

  /// Description of the template.
  final String description;
}

/// Enum representing different fonts used in the templates.
/// Each font is associated with a name that can be used to retrieve it.
enum Fonts {
  /// Open Sans font (from fonts/OpenSans-*.ttf).
  openSans(description: 'Open Sans font, a humanist sans-serif typeface designed by Steve Matteson.'),

  /// Times New Roman font (built-in PDF font).
  times(description: 'Times New Roman font, a classic serif typeface commonly used in documents.'),

  /// Helvetica font (built-in PDF font).
  helvetica(description: 'Helvetica font, a widely used sans-serif typeface.'),

  /// Courier New font (built-in PDF font).
  courier(description: 'Courier New font, a monospaced font commonly used for code and technical documents.');

  const Fonts({required this.description});

  /// Description of the font.
  final String description;

  /// Factory constructor to get a template by its name.
  factory Fonts.fromName(String? name) => switch (name?.trim().toLowerCase().replaceAll(' ', '')) {
    'opensans' => openSans,
    'times' => times,
    'helvetica' => helvetica,
    'courier' => courier,
    _ => openSans,
  };
}
