
// docs/lib/elements.typ
// Basic text and paragraph formatting, as well as chapter introductions

#import "constants.typ": (
  color-primary,
  font-cursive,
  font-serif,
  text-base-size,
)

/// Applies the global typography and paragraph rules to the document.
#let apply-base-styles(lang: "de", body) = {
  set text(
    font: font-serif,
    lang: lang,
    size: text-base-size,
    fill: color-primary,
  )

  set par(
    first-line-indent: 1.5em,
    justify: true,
  )

  body
}

/// Formats a calligraphic introductory text for the beginning of a chapter
/// flush with the 20-mm grid.
#let intro-cursive(body) = {
  block(
    width: 100%,
    inset: (
      top: 10pt,
      bottom: 12pt,
      left: 20mm,
      right: 15pt,
    ),
  )[
    #set text(
      font: font-cursive,
      size: 1.15em,
    )
    #set par(leading: 0.85em, justify: false)
    #body
  ]
}
