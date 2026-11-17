
// docs/lib/mod.typ
// Zentraler Einstiegspunkt der Template-Library für mehrsprachige Buchprojekte

#import "constants.typ": *
#import "theme.typ": *
#import "page-setup.typ": (
  layout-cover,
  layout-frontmatter,
  layout-title-page,
  make-footer,
  make-header,
)
#import "elements.typ": apply-base-styles, intro-cursive
#import "headings.typ": apply-heading-styles
#import "outline.typ": apply-outline-styles, layout-sub-toc

/// Wendet das komplette Buch-Layout auf ein Dokument an.
#let book-template(
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
