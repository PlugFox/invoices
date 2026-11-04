# Invoices Generator

A simple command line tool to generate PDF invoices from YAML files.
This tool reads a YAML file containing invoice data and generates a PDF invoice based on the provided template.
It is designed to be used in a Dart environment and can be run from the command line.

## Features

- 📝 Generate professional PDF invoices from YAML configuration files
- 🎨 Multiple templates available
- 🔤 Support for multiple fonts
- 🌍 Internationalization support with locale formatting
- 🔧 Cross-platform support (Windows, macOS, Linux)
- ⚡ Fast and lightweight command-line interface

## Installation

### Prerequisites

- Dart SDK 3.7.0 or higher

The repository pins its toolchain with [mise](https://mise.jdx.dev), so the SDK
can be provisioned for you instead of installed by hand:

```bash
mise trust && mise install
```

`mise trust` is needed once per clone because `mise.toml` defines environment
variables and tasks. Run `mise tasks` to see the available tasks.

### Install from source

```bash
git clone https://github.com/plugfox/invoices.git
cd invoices
dart pub get
```

### Global installation

```bash
dart pub global activate --source path .
```

## Usage

### Basic usage

```bash
dart run bin/main.dart -i config.yaml -o invoice.pdf
```

### Command line options

```bash
dart run bin/main.dart [options]
```

#### Options

| Option       | Short | Description                                               | Default       |
| ------------ | ----- | --------------------------------------------------------- | ------------- |
| `--help`     | `-h`  | Print usage information                                   | -             |
| `--input`    | `-i`  | Input YAML file containing invoice data                   | `config.yaml` |
| `--output`   | `-o`  | Output PDF file where the generated invoice will be saved | `output.pdf`  |
| `--template` | `-t`  | Template to use for generating the invoice                | `simple`      |
| `--font`     | `-f`  | Font to use for the invoice text                          | `openSans`    |
| `--locale`   | `-l`  | Locale to use for formatting the invoice                  | system locale |

Allowed `--template` values: `simple`.
Allowed `--font` values: `openSans` (bundled TTF), `times`, `helvetica`, `courier` (built-in PDF fonts).

> The bundled fonts in `fonts/` are resolved relative to the installed package,
> so the tool works from any directory once it is activated globally. Set
> `INVOICES_FONTS` to override the directory they are loaded from.

## YAML Configuration

The input YAML file should contain all the necessary information to generate the invoice, such as organization details, counterparty information, services, and totals.

### Example configuration

```yaml
issuedAt: 2023-10-01T12:00:00Z

currency: "USD"

organization:
  name: "My Organization"
  address: "123 Main St, City, Country"
  taxId: "123456789"
  description: "A brief description of the organization."

counterparty:
  name: "Client Name"
  address: "456 Client St, City, Country"
  taxId: "987654321"
  description: |
    Sample Client Company
    789 Client Ave, City, Country

description: |
  Frontend software development services according to _INDEPENDENT CONTRACTOR AGREEMENT
  dated XXth day of Month, 2023_

  #### Bank details for USD transfer
  **Beneficiary's Bank:** Bank name, City, Country
  **Beneficiary SWIFT:** BANKSWIFT
  **Ben's IBAN:** US12BANK12345678901234
  **Name of Beneficiary:** P/E Name Surname

services:
  - name: "Service 1"
    amount: 123.45
  - name: "Service 2"
    amount: 67.89
```

### Configuration fields

All fields in the YAML configuration are optional.

- **issuedAt** - Invoice issue date in ISO 8601 format
- **currency** - Currency code (e.g., "USD", "EUR", "RUB")
- **organization** - Your organization details
  - **name** - Organization name
  - **address** - Organization address
  - **taxId** - Tax identification number
  - **description** - Additional organization description
- **counterparty** - Client/customer details
  - **name** - Client name
  - **address** - Client address
  - **taxId** - Client tax identification number
  - **description** - Additional client description
- **description** - Invoice description (supports Markdown formatting)
- **services** - List of services/items
  - **name** - Service or item name
  - **amount** - Service or item amount

### Document options

These optional top-level keys control the generated document itself:

| Key        | Description                                                                 | Default                       |
| ---------- | --------------------------------------------------------------------------- | ----------------------------- |
| `color`    | Accent color of the header banner and total badge                           | `blueGrey800`                 |
| `format`   | Page format: `a4`, `letter` or `legal`                                      | `a4`                          |
| `logo`     | Path to a logo image, resolved relative to the YAML file                    | none                          |
| `title`    | PDF document title                                                          | `<organization> - <date> invoice` |
| `subject`  | PDF document subject                                                        | title plus the invoice number |
| `author`   | PDF document author                                                         | organization name             |
| `creator`  | PDF document creator                                                        | organization name             |
| `producer` | PDF document producer                                                       | organization name             |
| `keywords` | PDF document keywords                                                       | `invoice, <organization>, <number>` |

`color` accepts a hex value (`"#B00020"`) or a named Material color
(`red`, `blue`, `teal`, `blueGrey`, `deepOrangeAccent`, ...). An unrecognized
value falls back to the template default rather than failing.

```yaml
color: "#B00020"
format: letter
logo: assets/logo.png
title: "Invoice for October"
```

## Examples

### Generate invoice with custom template and font

```bash
dart run bin/main.dart -i my-invoice.yaml -o invoice-2023.pdf -t simple -f times
```

### Generate invoice with specific locale

```bash
dart run bin/main.dart -i config.yaml -o output.pdf -l en_US
```

### Using aliases for shorter commands

```bash
dart run bin/main.dart -i config.yaml -o invoice.pdf -t simple -f openSans -l ru_RU
```

## Development

### Running tests

```bash
dart test
```

### Formatting code

```bash
dart format bin lib test
```

### Analyzing code

```bash
dart analyze --fatal-infos --fatal-warnings bin lib test
```

### Getting dependencies

```bash
dart pub get
```

### Running every check CI runs

```bash
mise run check
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please [open an issue](https://github.com/plugfox/invoices/issues) on GitHub.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.
