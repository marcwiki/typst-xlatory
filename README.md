# typst-xlatory

**A lossless round-trip transpiler connecting [Typst](https://typst.app) documents with CAT tools (like [OmegaT](https://omegat.org), Weblate, or Crowdin) via standard Java `.properties` files.**

Write your book or documentation once in Typst, translate the extracted text segments using professional translation memories, and reconstruct clean, ready-to-compile Typst source files for any number of target languages—without ever duplicating or breaking your layout code.

---

## Why `typst-xlatory`?

Translating large Typst projects by copying `.typ` files per language quickly turns into a maintenance nightmare. Every layout tweak, macro update, or spacing adjustment has to be repeated across every language file, while translators are exposed to fragile markup.

`typst-xlatory` solves this by strictly separating **content** from **presentation**:

1. **Extract (`Typst -> .properties`)**: Parses your Typst AST and exports headings, paragraphs, list items, and translatable function arguments into standard `.properties` files while preserving labels and inline markup.
2. **Translate (CAT Tool)**: Translators work in their preferred CAT tool (e.g., OmegaT) with full access to Translation Memories (TM), glossaries, and fuzzy matching—completely shielded from complex Typst layout definitions.
3. **Reconstruct (`.properties -> Typst`)**: Injects translated strings back into the exact original Typst structure across multiple target languages in a single run.

---

## Key Features

- **Loose Coupling via `.properties`**: Works out of the box with OmegaT, Poedit, Weblate, Crowdin, or any localization workflow supporting Java `.properties`.
- **Label-Anchored Segments**: Uses Typst labels (`<p:intro-1>`, `<h1:chapter-1>`) as stable segment keys so inserting or reordering paragraphs never breaks existing translations.
- **Dynamic Custom Function Support**: Automatically exports bracketed content (`#callout[Text]`) and quoted named arguments (`title: "Summary:"`) without hardcoded function lists.
- **Multi-Target YAML Configuration**: Configure source directories, ignored layout functions (`hide_functions`), technical parameters (`ignore_named_args`), and any number of target languages in a single YAML file.
- **Shared Layout Libraries**: All reconstructed language outputs point to the same `lib/` templates—update your design once, recompile all languages immediately.

---

## Quick Start

### 1. Project Structure

```text
my-book/
├── docs/
│   ├── docs.yaml         # Pipeline configuration
│   ├── lib/              # Shared Typst templates and layout macros
│   ├── src_de/           # Source Typst files
│   ├── i18n/
│   │   ├── source/       # Exported .properties (input for CAT tool)
│   │   ├── target_en/    # Translated .properties (English)
│   │   └── target_ru/    # Translated .properties (Russian)
│   ├── out_en/           # Reconstructed Typst files (English)
│   └── out_ru/           # Reconstructed Typst files (Russian)
└── pdf/                  # Compiled PDF outputs
```

### 2. Configuration (`docs.yaml`)

```yaml
project:
  source_dir: "src_de"
  i18n_source_dir: "i18n/source"

targets:
  - lang: "en"
    i18n_target_dir: "i18n/target_en"
    output_dir: "out_en"
  - lang: "ru"
    i18n_target_dir: "i18n/target_ru"
    output_dir: "out_ru"

hide_functions:
  - outline
  - pagebreak
  - include
  - raw
  - v
  - h
  - link

ignore_named_args:
  - font
  - style
  - weight
  - lang
  - region
  - fill
  - stroke
  - align
```

### Supported Typst Subset

`typst-xlatory` intentionally targets a clean, flat document subset (`Typst.AST`) to guarantee lossless round-trip reconstruction:

* **Top-Level Structure (`BookNode`):**
  * **Headings:** Standard ATX-style headings (`=`, `==`, `===`, ...) with optional trailing labels (`<h1:intro>`).
  * **Paragraphs & Lists:** Standard body paragraphs and list items separated by blank lines, with optional trailing labels (`<p:intro-1>`).
  * **Custom Macro Calls:** Top-level function calls (`#callout(title: "Note")[Text] <box:1>`). Bracketed content (`ContentArg`) and double-quoted named arguments (`NamedArg`) are extracted; positional arguments and parameters listed in `ignore_named_args` are preserved verbatim.
  * **Layout Directives:** Rules such as `#import`, `#set`, `#show`, and functions listed in `hide_functions` pass through untouched.
* **Inline Markup (`TypstInline`):**
  * Plain text and inline code in backticks (`` `...` ``, protected from label parsing).
  * Bold emphasis wrapped in asterisks (`*...*`).
  * Internal and external links (`#link(<target>)[text]`).
* **Authoring Constraints:**
  * **Flat Top-Level Hierarchy:** Do not wrap chapters or multiple paragraphs in outer content blocks (`[...]`); use `#show:` rules to switch layouts instead.
  * **Trailing Labels:** Labels (`<key>`) must appear at the very end of a block without spaces or angle brackets inside the identifier.


### 3. Run the Pipeline

```bash
# Step 1: Export Typst source files to .properties
typst-xlatory --config docs/docs.yaml

# Step 2: Translate the files in docs/i18n/source/ using your CAT tool

# Step 3: Reconstruct all target languages
typst-xlatory --config docs/docs.yaml --import

# Step 4: Compile PDFs with Typst
mkdir -p pdf
typst compile --root docs docs/src_de/manual.typ pdf/manual_de.pdf
typst compile --root docs docs/out_en/manual.typ pdf/manual_en.pdf
typst compile --root docs docs/out_ru/manual.typ pdf/manual_ru.pdf
```


---

## Building from Source

This project is written in Haskell and built with [Stack](https://haskellstack.org):

```bash
git clone https://github.com/marcwiki/typst-xlatory.git
cd typst-xlatory
stack build
```

Run directly via Stack:

```bash
stack run -- --config docs/docs.yaml
stack run -- --config docs/docs.yaml --import
```

---

## Documentation & Live Example

Pre-compiled PDF manuals (`manual_de.pdf`, `manual_en.pdf`, `manual_ru.pdf`) as well as pre-built binaries for Linux, Windows, and macOS are available on the [Releases](https://github.com/marcwiki/typst-xlatory/releases) page.

The `docs/` directory contains the full user manual—written in German (`docs/src_de/manual.typ`) and translated using this exact pipeline into English and Russian:

* **Source & Templates:** `docs/src_de/` and `docs/lib/`
* **Configuration:** `docs/docs.yaml`
* **Reconstructed Outputs:** `docs/out_en/` and `docs/out_ru/`
* **Compiled Manuals:** `pdf/manual_de.pdf`, `pdf/manual_en.pdf`, and `pdf/manual_ru.pdf`

---

## Contributing

[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen)](CONTRIBUTING.md)

Contributions to `typst-xlatory` are very welcome! We are especially looking for help with:
* **Translating the manual** into new languages (please ensure your PR also updates the PDF compile list in `.github/workflows/release.yml` and the manual list in this README so new languages are included in release PDFs).
* **Refining the Russian manual** (`docs/i18n/target_ru/manual_ru_RU.properties`), which is currently largely machine-translated.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the step-by-step workflow and validation checklist before opening a Pull Request.

---

## License

Version 3 of the GNU General Public License

