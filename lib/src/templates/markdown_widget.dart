import 'dart:collection';

import 'package:intl/locale.dart';
import 'package:invoices/src/templates/markdown.dart';
import 'package:invoices/src/templates/nodes.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A widget that renders Markdown content in a PDF document.
/// This widget is designed to be used within a PDF context and requires
abstract interface class MarkdownWidget {
  /// Creates a MarkdownWidget from a plain text string.
  /// This factory constructor converts the text into a Markdown instance.
  static List<pw.Widget> build({required String text, required pw.ThemeData theme, required Locale locale}) {
    final markdown = Markdown.fromString(text);
    if (markdown.isEmpty) return const <pw.Widget>[];
    final widgets = _markdown2pdf(markdown, theme, locale);
    return widgets.isEmpty ? const <pw.Widget>[] : widgets;
  }
}

List<pw.Widget> _markdown2pdf(Markdown markdown, pw.ThemeData theme, Locale locale) {
  final widgets = <pw.Widget>[];
  for (final block in markdown.blocks) {
    switch (block) {
      case MD$Paragraph(:var spans):
        // Regular text
        if (spans.isEmpty) continue;
        widgets.add(
          pw.RichText(
            text: pw.TextSpan(
              children: _spans2pdf(spans, theme.defaultTextStyle, locale),
              style: theme.defaultTextStyle,
            ),
          ),
        );
      case MD$Heading(:var level, :var spans):
        // Headings
        final style =
            (<pw.TextStyle>[
              theme.header0,
              theme.header1,
              theme.header2,
              theme.header3,
              theme.header4,
              theme.header5,
            ][level.clamp(1, 6) - 1]);
        widgets.add(pw.RichText(text: pw.TextSpan(children: _spans2pdf(spans, style, locale), style: style)));
      case MD$Quote(:var spans):
        // Blockquote
        widgets.add(
          pw.DecoratedBox(
            decoration: const pw.BoxDecoration(
              shape: pw.BoxShape.rectangle,
              border: pw.Border(left: pw.BorderSide(color: PdfColors.grey400, width: 2)),
            ),
            child: pw.Stack(
              fit: pw.StackFit.loose,
              overflow: pw.Overflow.clip,
              children: <pw.Widget>[
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8.0),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: _spans2pdf(spans, theme.defaultTextStyle, locale),
                      style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        background: const pw.BoxDecoration(color: PdfColors.grey200),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case MD$Code(:var text):
        // Code block
        widgets.add(
          pw.RichText(
            text: pw.TextSpan(
              text: text,
              style: pw.TextStyle(
                background: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0x3CBDBDBD),
                  border: pw.Border.all(color: PdfColors.grey),
                ),
              ),
            ),
          ),
        );
      case MD$List(:var items):
        // List (unordered or ordered)
        final bulletStyle = theme.bulletStyle;
        void processItems(List<MD$ListItem> items) {
          for (final MD$ListItem(:indent, :marker, :spans, :children) in items) {
            widgets.add(
              pw.Padding(
                padding: pw.EdgeInsets.only(left: indent * 4.0),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: <pw.InlineSpan>[
                      pw.TextSpan(
                        text: switch (marker) {
                          '•' || '+' || '-' || '*' => '•\u00A0', // Bullet
                          _ => '$marker\u00A0', // Custom marker
                        },
                        style: bulletStyle,
                      ),
                      ..._spans2pdf(spans, theme.defaultTextStyle, locale),
                    ],
                  ),
                ),
              ),
            );
            // Process nested items
            if (children.isNotEmpty) processItems(children);
          }
        }
        processItems(items);
      case MD$Divider():
        // Horizontal rule
        widgets.add(pw.Divider(color: PdfColors.grey300, thickness: 1, height: theme.defaultTextStyle.fontSize));
      case MD$Table(:var header, :var rows):
        // Table data
        final tableData = <List<String>>[];

        // Add header row if present - check for null or empty
        if (header.cells.isNotEmpty) tableData.add(header.cells.map(_spansToPlainText).toList());

        // Add data rows
        for (final row in rows) tableData.add(row.cells.map(_spansToPlainText).toList());

        // Skip empty tables
        if (tableData.isEmpty) continue;

        // Create the table widget
        widgets.add(
          pw.TableHelper.fromTextArray(
            context: null,
            data: tableData,
            headerStyle: theme.tableHeader.copyWith(
              fontWeight: pw.FontWeight.bold,
              background: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            cellStyle: theme.tableCell,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: theme.tableCell.fontSize! * 2.5,
            cellAlignments: {for (var i in List.generate(tableData.first.length, (i) => i)) i: pw.Alignment.centerLeft},
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerCount: header.cells.isNotEmpty ? 1 : 0,
          ),
        );
      case MD$Spacer():
        // Line break
        widgets.add(pw.SizedBox(height: theme.defaultTextStyle.fontSize));
    }
  }

  return widgets;
}

/// Helper function to convert markdown spans to plain text
String _spansToPlainText(List<MD$Span> spans) => spans.map((span) => span.text).join('');

/// Converts a list of markdown spans to PDF inline spans with appropriate styles.
List<pw.InlineSpan> _spans2pdf(List<MD$Span> spans, pw.TextStyle style, Locale locale) {
  final cache = HashMap<int, pw.TextStyle>()..[0] = style;
  return spans
      .map<pw.InlineSpan>((e) {
        final spanStyle = cache.putIfAbsent(
          e.style,
          () => style.copyWith(
            font: e.style.contains(MD$Style.monospace) ? pw.Font.courier() : null,
            fontWeight: switch (e.style) {
              MD$Style s when s.contains(MD$Style.bold) => pw.FontWeight.bold,
              MD$Style s when s.contains(MD$Style.highlight) => pw.FontWeight.bold,
              MD$Style s when s.contains(MD$Style.monospace) => pw.FontWeight.normal,
              _ => null, // Default weight
            },
            fontStyle: e.style.contains(MD$Style.italic) ? pw.FontStyle.italic : pw.FontStyle.normal,
            background: switch (e.style) {
              MD$Style s when s.contains(MD$Style.highlight) => const pw.BoxDecoration(color: PdfColors.yellow300),
              MD$Style s when s.contains(MD$Style.monospace) => pw.BoxDecoration(
                color: const PdfColor.fromInt(0x3CBDBDBD),
                border: pw.Border.all(color: PdfColors.grey),
              ),
              _ => null, // Default background
            },
            decoration: switch (e.style) {
              MD$Style s when s.contains(MD$Style.strikethrough) => pw.TextDecoration.lineThrough,
              MD$Style s when s.contains(MD$Style.underline) => pw.TextDecoration.underline,
              _ => null,
            },
            color: switch (e.style) {
              MD$Style s when s.contains(MD$Style.link) => PdfColors.blue,
              MD$Style s when s.contains(MD$Style.monospace) => PdfColors.grey800,
              MD$Style s when s.contains(MD$Style.highlight) => PdfColors.black,
              _ => null, // Default color
            },
          ),
        );
        if (e.style.contains(MD$Style.link)) {
          if (e.extra case <String, Object?>{'url': String href} when href.isNotEmpty && href.startsWith('https://')) {
            // Valid link, create a text span with a URL
            return pw.WidgetSpan(
              annotation: pw.AnnotationLink(href),
              baseline: -3,
              child: pw.UrlLink(
                destination: href,
                child: pw.RichText(text: pw.TextSpan(text: e.text, style: spanStyle)),
              ),
            );
          } else {
            // Invalid link, treat as regular text
            return pw.TextSpan(text: e.text, style: style);
          }
        }
        return pw.TextSpan(text: e.text, style: spanStyle);
      })
      .toList(growable: false);
}
