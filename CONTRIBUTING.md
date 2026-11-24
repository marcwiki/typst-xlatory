# Contributing to `typst-xlatory`

Thank you for your interest in contributing to `typst-xlatory`!

We especially welcome contributions focused on the project's documentation and localization:
1. **Adding new languages** for the manual.
2. **Improving the Russian manual**, which is currently largely machine-translated.

---

## Pull Request Workflow

All Pull Requests are currently reviewed and verified manually. To keep reviews focused and manageable, please follow these steps:

### 1. Keep Pull Requests Focused
* Submit **one new language** or **one coherent set of Russian corrections** per Pull Request (PR).
* Keep unrelated code refactors or formatting changes out of translation PRs.

### 2. Choose Your Contribution Path

#### Path A: Adding a New Language
1. Register the new target language and output directory (e.g., `docs/out_<lang>/`) in `docs/docs.yaml`.
2. Export the Typst source files to `.properties`:
   ```bash
   typst-xlatory --config docs/docs.yaml
   ```
3. Translate the exported `.properties` files from `docs/i18n/source/` using your CAT tool (or editor) and save them into the configured target directory under `docs/i18n/`.
4. Reconstruct all target languages:
   ```bash
   typst-xlatory --config docs/docs.yaml --import
   ```
5. Compile the reconstructed manual into a PDF using [Typst](https://typst.app):
   ```bash
   mkdir -p pdf
   typst compile --root docs docs/out_<lang>/manual.typ pdf/manual_<lang>.pdf
   ```
6. **Include the regenerated `docs/out_<lang>/` files** in your PR so the generated Typst markup can be inspected directly. *(Please do not commit the `pdf/` directory or `.pdf` files).*

#### Path B: Correcting the Russian Manual
1. Edit `docs/i18n/target_ru/manual_ru_RU.properties` to fix machine-translated phrasing, terminology, or grammar.
2. Reconstruct all target languages:
   ```bash
   typst-xlatory --config docs/docs.yaml --import
   ```
3. Compile the reconstructed Russian manual to PDF:
   ```bash
   mkdir -p pdf
   typst compile --root docs docs/out_ru/manual.typ pdf/manual_ru.pdf
   ```
4. Include the updated `docs/out_ru/` files in your PR. *(Please do not commit the `pdf/` directory or `.pdf` files).*

### 3. Manual Validation & Visual Check
Instead of automated test suites, `typst-xlatory` relies on round-trip integrity and visual inspection:
* Visually inspect the generated PDF in `pdf/` to ensure layout, line breaks, and special characters render properly.
* Fill out the Pull Request template checklist and note any layout adjustments or open questions.

### 4. Review & Merge
A maintainer will check out your branch locally, run `typst-xlatory --config docs/docs.yaml --import` to verify that the generated output matches the `.properties` source, compile the PDF, and review the changes before merging.
