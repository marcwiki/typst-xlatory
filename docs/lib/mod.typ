
// docs/lib/mod.typ
// Zentraler Einstiegspunkt der Template-Library für mehrsprachige Buchprojekte

#import "constants.typ": *
#import "theme.typ": *
#import "page-setup.typ": (
  apply-first-page-layout,
  apply-title-page-layout,
  cover-page,
  make-footer,
  make-header,
)
#import "elements.typ": apply-base-styles, chapter-intro
#import "headings.typ": apply-heading-styles
#import "outline.typ": apply-outline-styles, comment-sub-outline

/// Wendet das komplette Buch-Layout auf ein Dokument an.
///
/// - lang (str): Sprachcode für Silbentrennung und Anführungszeichen (z. B. "de", "en", "ru").
/// - book-title (str): Buchtitel für die lebenden Kolumnentitel auf geraden Seiten.
/// - body (content): Der gesamte Dokumentinhalt.
#let book-style(
  lang: "de",
  book-title: "typst-xlatory",
  body,
) = {
  show: apply-outline-styles
  show: apply-heading-styles
  show: apply-base-styles.with(lang: lang)

  set page(
    paper: page-size,
    margin: (
      inside: margin-inside,
      outside: margin-outside,
      top: margin-y,
      bottom: margin-y,
    ),
    header: context { make-header(book-title) },
    footer: context { make-footer() },
  )

  body
}
