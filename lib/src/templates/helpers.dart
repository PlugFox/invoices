import 'dart:io' as io;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:invoices/src/templates.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A collection of helper functions and classes for internal use.
/// This class is not intended for public use and should not be extended or instantiated directly.
@internal
abstract final class Helpers {
  /// Get the color from the template color.
  /// Returns `null` when the value is absent or not recognized,
  /// so the caller can fall back to its own default.
  static PdfColor? decodeColor(Object? color) => switch (color) {
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
    String hex when hex.startsWith('#') => _tryParseHex(hex.substring(1)),
    _ => null,
  };

  /// Parse a hex color, returning `null` instead of throwing on malformed input.
  static PdfColor? _tryParseHex(String hex) {
    try {
      return PdfColor.fromHex(hex);
    } on Object {
      return null;
    }
  }

  /// Get the page format from the template format
  static PdfPageFormat getPageFormat(Object? format) => switch (format) {
    'a4' => PdfPageFormat.a4,
    'letter' => PdfPageFormat.letter,
    'legal' => PdfPageFormat.legal,
    _ => PdfPageFormat.a4,
  };

  /// Cache for theme data to avoid loading the same font multiple times
  static final Map<Fonts, pw.TextStyle> _textStyleCache = <Fonts, pw.TextStyle>{};

  /// Cache for the loaded TTF assets, keyed by file name.
  static final Map<String, pw.Font> _fontCache = <String, pw.Font>{};

  /// Memoized result of [resolveFontsDirectory].
  static String? _fontsDirectory;

  /// Directory holding the bundled `.ttf` assets.
  ///
  /// The fonts ship with the package, so they must not be resolved against the
  /// current working directory: the tool is meant to be installed globally
  /// (`dart pub global activate`) and run from wherever the invoice lives.
  /// Candidates are probed in order and the first one that really contains the
  /// fonts wins.
  static Future<String> resolveFontsDirectory() async => _fontsDirectory ??= await _probeFontsDirectory();

  static Future<String> _probeFontsDirectory() async {
    const probe = 'OpenSans-Regular.ttf';
    bool holdsFonts(String directory) => io.FileSystemEntity.isFileSync(p.join(directory, probe));

    // 1. Explicit override, for unusual deployments.
    if (io.Platform.environment['INVOICES_FONTS'] case String value when value.isNotEmpty) {
      if (holdsFonts(value)) return value;
    }

    // 2. Relative to this library, resolved through the package config. This is
    //    the only candidate that holds for a globally activated package, whose
    //    entry point is a snapshot under `.dart_tool`.
    try {
      final library = await Isolate.resolvePackageUri(Uri.parse('package:invoices/invoices.dart'));
      if (library != null && library.scheme == 'file') {
        // `<package>/lib/invoices.dart` -> `<package>/fonts`
        final directory = p.join(p.dirname(p.dirname(library.toFilePath())), 'fonts');
        if (holdsFonts(directory)) return directory;
      }
    } on Object {
      // No package config available; fall through to the remaining candidates.
    }

    // 3. The current directory, so a checkout keeps working and a caller can
    //    deliberately shadow the bundled fonts.
    final current = p.join(io.Directory.current.path, 'fonts');
    if (holdsFonts(current)) return current;

    // 4. Alongside the entry point, walking up a few levels. Covers an AOT
    //    compiled binary shipped next to a `fonts/` directory.
    if (_scriptDirectory case String script when script.isNotEmpty) {
      var directory = script;
      for (var depth = 0; depth < 5; depth++) {
        final candidate = p.join(directory, 'fonts');
        if (holdsFonts(candidate)) return candidate;
        final parent = p.dirname(directory);
        if (parent == directory) break;
        directory = parent;
      }
    }

    // Nothing found: keep a relative path so the error raised by [loadPDFFont]
    // names a sensible location.
    return 'fonts';
  }

  /// Directory containing the executed script, or `null` when it cannot be determined.
  static String? get _scriptDirectory {
    try {
      final script = io.Platform.script;
      if (!script.hasScheme || script.scheme != 'file') return null;
      return p.dirname(script.toFilePath());
    } on Object {
      return null;
    }
  }

  /// Load a PDF font bundled with this package, by file name.
  static Future<pw.Font> loadPDFFont(String name) async {
    if (_fontCache[name] case pw.Font cached) return cached;
    final directory = await resolveFontsDirectory();
    final file = io.File(p.join(directory, name));
    if (!file.existsSync()) {
      throw io.FileSystemException(
        'Bundled font not found. Set the INVOICES_FONTS environment variable to '
        'the directory containing the package fonts.',
        file.path,
      );
    }
    final data = file.readAsBytesSync();
    return _fontCache[name] = pw.Font.ttf(ByteData.view(data.buffer, data.offsetInBytes, data.lengthInBytes));
  }

  /// Load the icons font used as a fallback for emojis.
  static Future<pw.Font> loadIconsFont() => loadPDFFont('NotoEmoji.ttf');

  /// Get the theme data from the font
  static Future<pw.TextStyle> getTextStyle(Object? font) async {
    final selected = switch (font) {
      Fonts value => value,
      String name => Fonts.fromName(name),
      _ => Fonts.openSans,
    };
    if (_textStyleCache[selected] case pw.TextStyle cached) return cached;

    final icons = await loadIconsFont();
    final pw.TextStyle style;
    switch (selected) {
      case Fonts.times:
        final regular = pw.Font.times();
        style = pw.TextStyle.defaultStyle().copyWith(
          font: regular,
          fontNormal: regular,
          fontBold: pw.Font.timesBold(),
          fontItalic: pw.Font.timesItalic(),
          fontBoldItalic: pw.Font.timesBoldItalic(),
          fontFallback: <pw.Font>[icons],
        );
      case Fonts.helvetica:
        final regular = pw.Font.helvetica();
        style = pw.TextStyle.defaultStyle().copyWith(
          font: regular,
          fontNormal: regular,
          fontBold: pw.Font.helveticaBold(),
          fontItalic: pw.Font.helveticaOblique(),
          fontBoldItalic: pw.Font.helveticaBoldOblique(),
          fontFallback: <pw.Font>[icons],
        );
      case Fonts.courier:
        final regular = pw.Font.courier();
        style = pw.TextStyle.defaultStyle().copyWith(
          font: regular,
          fontNormal: regular,
          fontBold: pw.Font.courierBold(),
          fontItalic: pw.Font.courierOblique(),
          fontBoldItalic: pw.Font.courierBoldOblique(),
          fontFallback: <pw.Font>[icons],
        );
      case Fonts.openSans:
        final regular = await loadPDFFont('OpenSans-Regular.ttf');
        style = pw.TextStyle.defaultStyle().copyWith(
          font: regular,
          fontNormal: regular,
          fontBold: await loadPDFFont('OpenSans-Bold.ttf'),
          fontItalic: await loadPDFFont('OpenSans-Italic.ttf'),
          fontBoldItalic: await loadPDFFont('OpenSans-BoldItalic.ttf'),
          fontFallback: <pw.Font>[icons],
        );
    }
    return _textStyleCache[selected] = style;
  }
}
