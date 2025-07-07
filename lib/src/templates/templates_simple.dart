import 'dart:typed_data';

import 'package:invoices/src/invoice.dart';

Future<Uint8List> pdfBuilderSimple(Invoice invoice, Map<String, Object?> context) async {
  throw UnimplementedError(
    'The simple PDF template is not implemented yet. '
    'Please use the advanced template or implement the simple template.',
  );
}
