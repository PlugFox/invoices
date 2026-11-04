import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:invoices/invoices.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

final $log = io.stdout.writeln; // Log to stdout
final $err = io.stderr.writeln; // Log to stderr

/// The main entry point of the application.
/// This function runs the application in a guarded zone to handle errors gracefully.
void main([List<String>? $arguments]) => runZonedGuarded<void>(
  () async {
    // Get command line arguments
    // If no arguments are provided, use the default values
    final parser = buildArgumentsParser();
    final args = parser.parse($arguments ?? []);
    if (args['help'] == true) {
      io.stdout
        ..writeln(_help.trim())
        ..writeln()
        ..writeln(parser.usage);
      io.exit(0);
    }

    // Validate input and output file paths from command line arguments
    final String input, output;
    {
      // Strip a matching pair of surrounding quotes, as shells on Windows
      // routinely pass them through.
      String unquote(String? value, String fallback) {
        var path = value?.trim() ?? '';
        while (path.length > 1 &&
            ((path.startsWith('"') && path.endsWith('"')) || (path.startsWith("'") && path.endsWith("'")))) {
          path = path.substring(1, path.length - 1).trim();
        }
        return path.isEmpty ? fallback : path;
      }

      input = unquote(args.option('input'), 'config.yaml');
      output = unquote(args.option('output'), 'output.pdf');

      if (input.isEmpty || output.isEmpty) {
        $err('Input and output paths cannot be empty.');
        io.exit(1);
      } else if (!input.endsWith('.yaml') && !input.endsWith('.yml')) {
        $err('Input file must be a YAML file (ending with .yaml or .yml): $input');
        io.exit(1);
      } else if (!output.endsWith('.pdf')) {
        $err('Output file must be a PDF file (ending with .pdf): $output');
        io.exit(1);
      } else if (!io.FileSystemEntity.isFileSync(input)) {
        $err('Input file does not exist: $input');
        io.exit(1);
      } else if (io.FileSystemEntity.isDirectorySync(output)) {
        $err('Existing output path is a directory, not a file: $output');
        io.exit(1);
      }
    }

    // Load the invoice from the YAML file
    final Invoice invoice;
    {
      final inputFile = io.File(input);
      if (!inputFile.existsSync()) {
        $err('Input file does not exist: $input');
        io.exit(1);
      }

      final text = inputFile.readAsStringSync();
      if (text.isEmpty) {
        $err('Input file is empty: $input');
        io.exit(1);
      }

      final content = yaml.loadYamlDocument(text, sourceUrl: inputFile.uri);
      if (content case yaml.YamlDocument(contents: yaml.YamlMap data)) {
        String normalizeKey(Object? key) => switch (key) {
          String key => key,
          Object key => key.toString(),
          null => '_',
        };

        Object? normalizeValue(Object? value) => switch (value) {
          String value => value,
          num value => value,
          bool value => value,
          yaml.YamlScalar scalar => scalar.value,
          yaml.YamlList list => list.map(normalizeValue).toList(growable: false),
          yaml.YamlMap map => <String, Object?>{
            for (final MapEntry<Object?, Object?>(:key, :value) in map.entries)
              normalizeKey(key): normalizeValue(value),
          },
          yaml.YamlNode node => normalizeValue(node.value),
          List<Object?> list => list.map(normalizeValue).toList(growable: false),
          Map<String, Object?> map => map.map((k, v) => MapEntry(k.toString(), normalizeValue(v))),
          _ => value?.toString() ?? '',
        };

        invoice = Invoice.fromMap(<String, Object?>{
          for (final MapEntry<Object?, Object?>(:key, :value) in data.entries) normalizeKey(key): normalizeValue(value),
        });
      } else {
        $err('Input file does not contain valid YAML data: $input');
        io.exit(1);
      }
    }

    // Resolution order for options that exist both as a flag and as a YAML key:
    // an explicitly passed flag wins, then the YAML file, then the flag default.
    // Comparing against the flag default is not enough, since the user may pass
    // that same value deliberately.
    String? selected(String option) {
      if (args.wasParsed(option)) return args.option(option);
      if (invoice.extra[option] case String value when value.trim().isNotEmpty) return value.trim();
      return args.option(option);
    }

    // Initialize locale and date formatting
    String locale;
    {
      locale = switch (selected('locale')) {
        String locale when locale.isNotEmpty => locale,
        _ => io.Platform.localeName,
      }.replaceAll('-', '_');
      await initializeDateFormatting(locale);
    }

    final font = Fonts.fromName(selected('font'));

    // Document level options (title, subject, author, keywords, color, format,
    // logo, ...) are read from the top level of the YAML file.
    final context = <String, Object?>{
      ...invoice.extra,
      'locale': locale,
      'font': font,
      if (_resolveLogo(invoice.extra['logo'], input) case Uint8List bytes) 'logo': bytes,
    };

    final template = Templates.fromName(selected('template'));
    final bytes = await template.build(invoice, context);
    io.File(output).writeAsBytesSync(bytes);
    $log('Invoice generated successfully: $output');

    io.exit(0);
  },
  (error, stackTrace) {
    $err(switch (error) {
      String() => error,
      ArgumentError() => 'Invalid argument: ${error.message}',
      FormatException() => 'Format error: ${error.message}',
      io.FileSystemException() => <String>[
        'File system error: ${error.message}',
        if (error.path case String path when path.isNotEmpty) 'path: $path',
        if (error.osError case io.OSError osError) 'cause: ${osError.message}',
      ].join(' '),
      Exception() => 'An error occurred: ${error.toString()}',
      _ => 'Unexpected error: ${error.toString()}',
    });
    io.exit(1);
  },
  zoneSpecification: ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, Object? message) {
      $log(switch (message) {
        String() => message,
        Object() => message.toString(),
        null => '',
      });
    },
  ),
);

/// Read the optional `logo:` image referenced by the invoice file.
///
/// The path is resolved relative to the invoice file itself, so a config can be
/// generated from any working directory. Returns `null` when no usable image is
/// configured; a broken path is reported but does not abort the generation.
Uint8List? _resolveLogo(Object? value, String invoicePath) {
  if (value is! String || value.trim().isEmpty) return null;
  final raw = value.trim();
  final candidate = p.isAbsolute(raw) ? raw : p.join(p.dirname(p.absolute(invoicePath)), raw);
  final file = io.File(candidate);
  if (!file.existsSync()) {
    $err('Warning: logo file not found, continuing without it: $candidate');
    return null;
  }
  try {
    return file.readAsBytesSync();
  } on Object catch (error) {
    $err('Warning: could not read the logo file, continuing without it: $error');
    return null;
  }
}

/// Parse arguments
ArgParser buildArgumentsParser() =>
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        aliases: const <String>['readme', 'usage', 'info', 'howto'],
        negatable: false,
        defaultsTo: false,
        help: 'Print this usage information',
      )
      ..addOption(
        'input',
        abbr: 'i',
        aliases: const <String>['config', 'yaml', 'in', 'input-file', 'configuration', 'in-file'],
        mandatory: false,
        defaultsTo: 'config.yaml',
        valueHelp: 'path/to/input.yaml',
        help:
            'Input YAML file containing invoice data.\n'
            'This file should contain all the necessary\n'
            'information to generate the invoice,\n'
            'such as customer details, items, and totals.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        aliases: const <String>['document', 'pdf', 'out', 'output-file', 'generated', 'out-file'],
        mandatory: false,
        defaultsTo: 'output.pdf',
        valueHelp: 'path/to/output.pdf',
        help:
            'Output PDF file where the generated invoice will be saved.\n'
            'This file will contain the formatted invoice based\n'
            'on the input YAML data and the template used.',
      )
      ..addOption(
        'template',
        abbr: 't',
        aliases: const <String>['layout', 'style', 'format', 'template-file'],
        mandatory: false,
        defaultsTo: Templates.values.first.name,
        allowed: Templates.values.map((e) => e.name).toList(growable: false),
        allowedHelp: {for (final template in Templates.values) template.name: template.description},
        help: 'Template to use for generating the invoice.',
      )
      ..addOption(
        'font',
        abbr: 'f',
        aliases: const <String>['fonts', 'typeface', 'ttf', 'font-file'],
        mandatory: false,
        defaultsTo: Fonts.openSans.name,
        allowed: Fonts.values.map((e) => e.name).toList(growable: false),
        allowedHelp: {for (final font in Fonts.values) font.name: font.description},
        help:
            'Font to use for the invoice text.\n'
            'This can be a built-in PDF font or a custom TTF font file',
      )
      ..addOption(
        'locale',
        abbr: 'l',
        aliases: const <String>['language', 'lang', 'i18n', 'internationalization', 'localization'],
        mandatory: false,
        defaultsTo: io.Platform.localeName,
        valueHelp: 'en_US',
        help: 'Locale to use for formatting the invoice.',
      );

/// Help message for the command line arguments
const String _help = '''
Invoices Generator

A simple command line tool to generate pdf invoices from the yaml file.
This tool reads a YAML file containing invoice data and
generates a PDF invoice based on the provided template.
It is designed to be used in a Dart environment
and can be run from the command line.

Usage: dart run bin/main.dart [options]
''';
