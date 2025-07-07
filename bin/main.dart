import 'dart:async';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:invoices/src/invoice.dart';
import 'package:invoices/src/templates.dart';
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
        ..writeln(_help)
        ..writeln()
        ..writeln(parser.usage);
      io.exit(0);
    }

    // Validate input and output file paths from command line arguments
    final String input, output;
    {
      final pathRegExp = RegExp('^["\']?(?<path>[^"]+)["\']?\$');
      input = pathRegExp.firstMatch(args.option('input') ?? '')?.namedGroup('path') ?? 'config.yaml';
      output = pathRegExp.firstMatch(args.option('output') ?? '')?.namedGroup('path') ?? 'output.pdf';

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

    final template = Templates.fromName(args.option('template'));
    final _ = await template.build(invoice, {});

    io.exit(0);
  },
  (error, stackTrace) {
    $err(switch (error) {
      String() => error,
      ArgumentError() => 'Invalid argument: ${error.message}',
      FormatException() => 'Format error: ${error.message}',
      io.FileSystemException() => 'File system error: ${error.message}',
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
            'Input YAML file containing invoice data. '
            'This file should contain all the necessary information to generate the invoice, '
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
            'Output PDF file where the generated invoice will be saved. '
            'This file will contain the formatted invoice based on the input YAML data and the template used.',
      )
      ..addOption(
        'template',
        abbr: 't',
        aliases: const <String>['layout', 'style', 'format', 'template-file'],
        mandatory: false,
        defaultsTo: Templates.values.first.name,
        valueHelp: Templates.values.map((e) => e.name).join('|'),
        help: 'Template to use for generating the invoice.',
      );

/// Help message for the command line arguments
const String _help = '''
Invoices Generator

A simple command line tool to generate pdf invoices from the yaml file.
This tool reads a YAML file containing invoice data and generates a PDF invoice based on the provided template.
It is designed to be used in a Dart environment and can be run from the command line.

Usage: dart run bin/main.dart [options]
''';
