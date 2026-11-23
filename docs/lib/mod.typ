
// docs/lib/mod.typ
// Central entry point to the template library for multilingual book projects

#import "constants.typ": *
#import "utils.typ": *
#import "theme.typ": *
#import "page-setup.typ": (
  layout-cover,
  layout-frontmatter,
  layout-title-page,
  layout-mainmatter,
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
    header: context { make-header() },
    footer: context {
      let page-num = counter(page).get().first()
      set text(size: 8.5pt, fill: rgb("#444444"))
      if calc.odd(page-num) {
        align(right)[#page-num]
      } else {
        align(left)[#page-num]
      }
    },
  )

  body
}
