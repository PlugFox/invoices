import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:invoices/src/invoice.dart';
import 'package:invoices/src/templates/helpers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a simple PDF invoice using the provided [Invoice] and [context].
/// The [context] can contain additional information such as title, subject,
/// producer, author, creator, keywords, theme, page format, color, and logo.
/// Returns a [Uint8List] containing the PDF data.
Future<Uint8List> pdfBuilderSimple(Invoice invoice, Map<String, Object?> context) async {
  T extract<T>(String key, T Function() fallback) {
    final path = key.split('.');
    if (path.isEmpty) return fallback();
    Object? obj = context;
    for (final part in path) {
      if (obj is Map) {
        obj = obj[part];
      } else {
        return fallback();
      }
    }
    return switch (obj) {
      final T value => value,
      _ => fallback(),
    };
  }

  // Get the color from the context
  final color = Helpers.decodeColor(context['color']);

  // Locale for formatting
  final locale = switch (context['locale'] ?? context['language'] ?? context['lang']) {
    String locale when locale.isNotEmpty => locale,
    _ => 'en_US',
  };

  // Default date formatter
  final dateFormat = DateFormat('d MMMM yyyy', locale);

  // Create the PDF document
  final doc = pw.Document(
    title: extract('title', () => '${invoice.organization.name} - ${dateFormat.format(invoice.issuedAt)} invoice'),
    subject: extract(
      'subject',
      () => '${invoice.organization.name} - ${dateFormat.format(invoice.issuedAt)} invoice ${invoice.number}',
    ),
    producer: extract('producer', () => invoice.organization.name),
    author: extract('author', () => invoice.organization.name),
    creator: extract('author', () => invoice.organization.name),
    keywords: extract('keywords', () => 'invoice, ${invoice.organization.name}, ${invoice.number}'),
    theme: await Helpers.getThemeDataFromFont(context['font'] ?? context['theme'] ?? 'courier'),
    /* compress: ,
      deflate: ,
      metadata: ,
      pageMode: ,
      verbose: , */
  );

  // Create theme
  final pageTheme = pw.PageTheme(
    pageFormat: Helpers.getPageFormat(context['format'] ?? context['page'] ?? 'a4'),
    orientation: pw.PageOrientation.portrait,
    margin: pw.EdgeInsets.zero,
    /* margin: const pw.EdgeInsets.fromLTRB(
        PdfPageFormat.inch * 0.5,
        PdfPageFormat.inch * 0.25,
        PdfPageFormat.inch * 0.5,
        PdfPageFormat.inch * 0.25,
      ), */
  );

  // Load the logo
  pw.ImageProvider? logo;
  try {
    switch (context['logo']) {
      case final Uint8List value:
        logo = pw.MemoryImage(value);
      case final pw.MemoryImage value:
        logo = value;
      case final pw.ImageProvider value:
        logo = value;
      default:
        context['logo'] = logo;
    }
  } on Object catch (_, _) {
    logo = null;
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      // --- Page Header --- //
      header: (context) => pw.SizedBox(height: PdfPageFormat.inch * 0.5),
      // --- Page Footer --- //
      footer:
          (context) =>
              context.pagesCount == 1
                  ? pw.SizedBox(height: PdfPageFormat.inch * 0.75)
                  : pw.Padding(
                    padding: const pw.EdgeInsets.only(
                      bottom: PdfPageFormat.inch * 0.5,
                      top: PdfPageFormat.inch * 0.25,
                      right: PdfPageFormat.inch * 0.5,
                      left: PdfPageFormat.inch * 0.5,
                    ),
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        '${context.pageNumber}/${context.pagesCount}',
                        style: const pw.TextStyle(color: PdfColors.black),
                      ),
                    ),
                  ),
      // --- Body --- //
      build:
          (context) => <pw.Widget>[
            // --- Invoice Header --- //
            _InvoiceTemplate$Simple$PageHeader(invoice: invoice, logo: logo, color: color, dateFormatter: dateFormat),

            pw.SizedBox(height: PdfPageFormat.inch * 0.25),

            // --- Organization --- //
            if (invoice.organization case Organization organization)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: PdfPageFormat.inch * 0.5),
                child: _InvoiceTemplate$Simple$InvoiceOrganization(organization: organization),
              ),

            pw.SizedBox(height: PdfPageFormat.inch * 0.25),

            // --- Invoice description --- //
            if (invoice.description case String description when description.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: PdfPageFormat.inch * 0.5),
                child: _InvoiceTemplate$Simple$InvoiceDescription(text: description),
              ),

            pw.SizedBox(height: PdfPageFormat.inch * 0.25),

            // --- Invoices table --- //
            if (invoice.services.isNotEmpty) ...<pw.Widget>[
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: PdfPageFormat.inch * 0.5),
                child: _InvoiceTemplate$Simple$InvoicesTable(invoice: invoice),
              ),
              pw.SizedBox(height: PdfPageFormat.inch * 0.25),
              _InvoiceTemplate$Simple$InvoicesTotal(invoice: invoice),
            ],

            // --- Terms and conditions --- //
            /* if (data['termsAndConditions'] case final String? value)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: _InvoiceTemplate$Simple$TextBlock(
                label: 'Terms and conditions',
                text: value,
              ),
            ), */

            // --- Notes --- //
            /* if (data['notes'] case final String value)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: _InvoiceTemplate$Simple$TextBlock(
                label: 'Notes',
                text: value,
              ),
            ), */
          ],
    ),
  );
  return doc.save();
}

class _InvoiceTemplate$Simple$PageHeader extends pw.StatelessWidget {
  _InvoiceTemplate$Simple$PageHeader({required this.invoice, this.logo, this.color, this.dateFormatter});

  final pw.ImageProvider? logo;
  final PdfColor? color;
  final Invoice invoice;
  final DateFormat? dateFormatter;

  @override
  pw.Widget build(pw.Context context) => pw.DecoratedBox(
    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
    child: pw.SizedBox(
      width: double.infinity,
      height: 124,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
          vertical: PdfPageFormat.inch * 0.25,
          horizontal: PdfPageFormat.inch * 0.5,
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.max,
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: <pw.Widget>[
            if (logo case pw.ImageProvider image)
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: const pw.Alignment(-.75, 0),
                  child: pw.FittedBox(child: pw.Image(image), fit: pw.BoxFit.contain),
                ),
              )
            else
              pw.Spacer(flex: 1),
            pw.Expanded(
              flex: 1,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.max,
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Text(
                    'INVOICE',
                    maxLines: 1,
                    textAlign: pw.TextAlign.right,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 42,
                      fontWeight: pw.FontWeight.bold,
                      height: 1,
                      letterSpacing: -.5,
                    ),
                  ),
                  pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text(
                        invoice.number,
                        maxLines: 1,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      pw.Text(
                        dateFormatter?.format(invoice.issuedAt) ?? DateFormat('d MMMM yyyy').format(invoice.issuedAt),
                        maxLines: 1,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InvoiceTemplate$Simple$InvoiceOrganization extends pw.StatelessWidget {
  _InvoiceTemplate$Simple$InvoiceOrganization({required this.organization});

  final Organization organization;

  @override
  pw.Widget build(pw.Context context) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(organization.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, height: 1)),
      if (organization.address case String address when address.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              text: 'Address: ',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, height: 1),
              children: <pw.TextSpan>[
                pw.TextSpan(text: address, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              ],
            ),
          ),
        ),
      if (organization.tax case String tax when tax.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.RichText(
            text: pw.TextSpan(
              text: 'Tax identification number: ',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, height: 1),
              children: <pw.TextSpan>[
                pw.TextSpan(text: tax, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal)),
              ],
            ),
          ),
        ),
    ],
  );
}

class _InvoiceTemplate$Simple$InvoiceDescription extends pw.StatelessWidget {
  _InvoiceTemplate$Simple$InvoiceDescription({required this.text});

  final String text;

  @override
  pw.Widget build(pw.Context context) => pw.Text(
    text,
    textAlign: pw.TextAlign.justify,
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.normal),
  );
}

class _InvoiceTemplate$Simple$InvoicesTable extends pw.StatelessWidget {
  _InvoiceTemplate$Simple$InvoicesTable({required this.invoice});

  final Invoice invoice;

  @override
  pw.Widget build(pw.Context context) => pw.DefaultTextStyle(
    style: pw.TextStyle(fontSize: 12, height: 1, fontWeight: pw.FontWeight.normal),
    child: pw.TableHelper.fromTextArray(
      context: context,
      defaultColumnWidth: const pw.IntrinsicColumnWidth(flex: 1),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(50),
        1: const pw.FlexColumnWidth(5),
        2: const pw.FixedColumnWidth(150),
      },
      border: pw.TableBorder.all(color: PdfColors.white, width: 2, style: pw.BorderStyle.solid),
      headerAlignments: <int, pw.AlignmentGeometry>{
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },
      rowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red600),
      headers: <pw.Widget>[
        pw.Text(
          'No.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 14, height: 1, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
        pw.Text(
          'Description',
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(fontSize: 14, height: 1, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
        pw.Text(
          'Amount',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 14, height: 1, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      ],
      cellAlignments: <int, pw.AlignmentGeometry>{
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
      data: <List<pw.Widget>>[
        // --- Rows --- //
        for (final (number, service) in invoice.services.indexed)
          <pw.Widget>[
            pw.Text(
              number.toString(),
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 12, height: 1),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Text(
                service.name,
                maxLines: 1,
                textAlign: pw.TextAlign.left,
                style: const pw.TextStyle(fontSize: 12, height: 1),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 8),
              child: pw.Text(
                service.amount.toStringAsFixed(2),
                maxLines: 1,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 12, height: 1),
              ),
            ),
          ],
      ],
    ),
  );
}

class _InvoiceTemplate$Simple$InvoicesTotal extends pw.StatelessWidget {
  _InvoiceTemplate$Simple$InvoicesTotal({required this.invoice});

  final Invoice invoice;

  @override
  pw.Widget build(pw.Context context) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      height: 40,
      child: pw.DecoratedBox(
        decoration: const pw.BoxDecoration(
          color: PdfColors.blueGrey800,
          shape: pw.BoxShape.rectangle,
          borderRadius: pw.BorderRadius.horizontal(left: pw.Radius.circular(20)),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(16, 8, PdfPageFormat.inch * 0.5, 8),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            mainAxisAlignment: pw.MainAxisAlignment.end,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: <pw.Widget>[
              pw.Text(
                'Total:',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                invoice.total.toStringAsFixed(2),
                style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
