## 0.0.2

- **FIXED**: `--font` was read from the `--template` option, so the flag had no
  effect and every invoice was rendered with Open Sans.
- **FIXED**: Bundled fonts were resolved against the current working directory,
  which made the globally activated tool fail outside the package root. They are
  now resolved relative to the package, overridable via `INVOICES_FONTS`.
- **FIXED**: Document metadata fallbacks were dead code — the generic of the
  internal `extract` helper was inferred as nullable, so a missing key returned
  `null` instead of the fallback and the PDF carried no title, author or
  producer at all.
- **FIXED**: The PDF `creator` field was populated from the `author` key.
- **FIXED**: Top-level YAML options (`color`, `format`, `title`, `subject`,
  `author`, `creator`, `producer`, `keywords`, `logo`) were never passed to the
  template and were silently ignored.
- **FIXED**: `Invoice.numberToDateTime` threw a `RangeError` on invoice numbers
  containing characters outside its dictionary; it now returns `null`.
- **FIXED**: Quoted input and output paths kept a trailing quote.
- **FIXED**: File system errors no longer hide the path that failed.
- **FIXED**: Malformed hex colors no longer abort generation.
- **ADDED**: `logo:` support — a path in the YAML file is loaded and rendered in
  the invoice header.
- **ADDED**: Markdown links now accept `http`, `mailto` and `tel` in addition to
  `https`; unsupported schemes render as plain text.
- **CHANGED**: CI now actually runs the test suite and a CLI smoke test, and the
  format check no longer uses a malformed `find | xargs` invocation.
- **CHANGED**: Editor configuration for VS Code reworked, and configuration for
  Zed and `.editorconfig` added.

## 0.0.1

- **ADDED**: Initial commit with basic project structure.
