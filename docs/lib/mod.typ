
// docs/lib/mod.typ
// Central entry point to the template library for multilingual book projects

#import "constants.typ": *
#import "utils.typ": *
#import "theme.typ": *
#import "page-setup.typ": (
  layout-cover,
  layout-frontmatter,
  layout-title-page,
  make-footer,
  make-header,
)
#import "elements.typ": apply-base-styles, intro-cursive
#import "headings.typ": *
#import "outline.typ": (
  apply-outline-styles,
  layout-sub-toc,
  layout-main-toc,
  layout-commentary-toc,
)

/// Applies the entire book layout to a document.
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
