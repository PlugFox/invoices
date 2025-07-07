import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A collection of helper functions and classes for internal use.
/// This class is not intended for public use and should not be extended or instantiated directly.
@internal
abstract final class Helpers {
  /// Get the color from the template color
  static PdfColor decodeColor(Object? color) => switch (color) {
    PdfColor() => color,
    int() => PdfColor.fromInt(color),
    'red' => PdfColors.red,
    'pink' => PdfColors.pink,
    'purple' => PdfColors.purple,
    'deepPurple' => PdfColors.deepPurple,
    'indigo' => PdfColors.indigo,
    'blue' => PdfColors.blue,
    'lightBlue' => PdfColors.lightBlue,
    'cyan' => PdfColors.cyan,
    'teal' => PdfColors.teal,
    'green' => PdfColors.green,
    'lightGreen' => PdfColors.lightGreen,
    'lime' => PdfColors.lime,
    'yellow' => PdfColors.yellow,
    'amber' => PdfColors.amber,
    'orange' => PdfColors.orange,
    'deepOrange' => PdfColors.deepOrange,
    'brown' => PdfColors.brown,
    'grey' => PdfColors.grey,
    'blueGrey' => PdfColors.blueGrey,
    'redAccent' => PdfColors.redAccent,
    'pinkAccent' => PdfColors.pinkAccent,
    'purpleAccent' => PdfColors.purpleAccent,
    'deepPurpleAccent' => PdfColors.deepPurpleAccent,
    'indigoAccent' => PdfColors.indigoAccent,
    'blueAccent' => PdfColors.blueAccent,
    'lightBlueAccent' => PdfColors.lightBlueAccent,
    'cyanAccent' => PdfColors.cyanAccent,
    'tealAccent' => PdfColors.tealAccent,
    'greenAccent' => PdfColors.greenAccent,
    'lightGreenAccent' => PdfColors.lightGreenAccent,
    'limeAccent' => PdfColors.limeAccent,
    'yellowAccent' => PdfColors.yellowAccent,
    'amberAccent' => PdfColors.amberAccent,
    'orangeAccent' => PdfColors.orangeAccent,
    'deepOrangeAccent' => PdfColors.deepOrangeAccent,
    String hex when hex.startsWith('#') => PdfColor.fromHex(hex.substring(1)),
    _ => PdfColors.grey,
  };

  /// Get the page format from the template format
  static PdfPageFormat getPageFormat(Object? format) => switch (format) {
    'a4' => PdfPageFormat.a4,
    'letter' => PdfPageFormat.letter,
    'legal' => PdfPageFormat.legal,
    _ => PdfPageFormat.a4,
  };

  /// Cache for theme data to avoid loading the same font multiple times
  static final Map<String, pw.ThemeData> _themeDataCache = <String, pw.ThemeData>{};

  /// Get the theme data from the font
  static Future<pw.ThemeData> getThemeDataFromFont(Object? font) async {
    return switch (font) {
      'times' => _themeDataCache.putIfAbsent(
        'times',
        () => pw.ThemeData.withFont(
          base: pw.Font.times(),
          bold: pw.Font.timesBold(),
          italic: pw.Font.timesItalic(),
          boldItalic: pw.Font.timesBoldItalic(),
          icons: pw.Font.times(),
          fontFallback: <pw.Font>[pw.Font.times()],
        ),
      ),
      'helvetica' => _themeDataCache.putIfAbsent(
        'helvetica',
        () => pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
          icons: pw.Font.helvetica(),
          fontFallback: <pw.Font>[pw.Font.helvetica()],
        ),
      ),
      'courier' || _ => _themeDataCache.putIfAbsent(
        'courier',
        () => pw.ThemeData.withFont(
          base: pw.Font.courier(),
          bold: pw.Font.courierBold(),
          italic: pw.Font.courierOblique(),
          boldItalic: pw.Font.courierBoldOblique(),
          icons: pw.Font.courier(),
          fontFallback: <pw.Font>[pw.Font.courier()],
        ),
      ),
    };
  }
}
