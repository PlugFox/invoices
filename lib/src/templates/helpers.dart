import 'dart:io' as io;
import 'dart:typed_data';

import 'package:invoices/src/templates.dart';
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
  static final Map<Fonts, pw.TextStyle> _textStyleCache = <Fonts, pw.TextStyle>{};

  // Load a PDF font from the given path
  static pw.Font loadPDFFont(String path) {
    final data = io.File(path).readAsBytesSync();
    return pw.Font.ttf(ByteData.view(data.buffer));
  }

  /// Load the icons font for emojis
  static final pw.Font iconsFont = loadPDFFont('fonts/NotoEmoji.ttf');

  /// Get the theme data from the font
  static Future<pw.TextStyle> getTextStyle(Object? font) async => switch (font) {
    Fonts.times || 'times' => _textStyleCache.putIfAbsent(Fonts.times, () {
      final regular = pw.Font.times();
      return pw.TextStyle.defaultStyle().copyWith(
        font: regular,
        fontNormal: regular,
        fontBold: pw.Font.timesBold(),
        fontItalic: pw.Font.timesItalic(),
        fontBoldItalic: pw.Font.timesBoldItalic(),
        fontFallback: <pw.Font>[iconsFont],
      );
    }),
    Fonts.helvetica || 'helvetica' => _textStyleCache.putIfAbsent(Fonts.helvetica, () {
      final regular = pw.Font.helvetica();
      return pw.TextStyle.defaultStyle().copyWith(
        font: regular,
        fontNormal: regular,
        fontBold: pw.Font.helveticaBold(),
        fontItalic: pw.Font.helveticaOblique(),
        fontBoldItalic: pw.Font.helveticaBoldOblique(),
        fontFallback: <pw.Font>[iconsFont],
      );
    }),
    Fonts.courier || 'courier' => _textStyleCache.putIfAbsent(Fonts.courier, () {
      final regular = pw.Font.courier();
      return pw.TextStyle.defaultStyle().copyWith(
        font: regular,
        fontNormal: regular,
        fontBold: pw.Font.courierBold(),
        fontItalic: pw.Font.courierOblique(),
        fontBoldItalic: pw.Font.courierBoldOblique(),
        fontFallback: <pw.Font>[iconsFont],
      );
    }),
    Fonts.openSans || 'opensans' || _ => _textStyleCache.putIfAbsent(Fonts.openSans, () {
      final regular = loadPDFFont('fonts/OpenSans-Regular.ttf');
      return pw.TextStyle.defaultStyle().copyWith(
        font: regular,
        fontNormal: regular,
        fontBold: loadPDFFont('fonts/OpenSans-Bold.ttf'),
        fontItalic: loadPDFFont('fonts/OpenSans-Italic.ttf'),
        fontBoldItalic: loadPDFFont('fonts/OpenSans-BoldItalic.ttf'),
        fontFallback: <pw.Font>[iconsFont],
      );
    }),
  };
}
