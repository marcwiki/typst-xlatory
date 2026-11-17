
// docs/lib/elements.typ
// Grundlegende Text- und Absatzformatierungen sowie Kapitel-Einleitungen

#import "constants.typ": (
  color-primary,
  font-cursive,
  font-serif,
  text-base-size,
)

/// Wendet die globalen Typografie- und Absatzregeln auf das Dokument an.
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

/// Formatiert einen kalligrafischen Einleitungstext für Kapitelanfänge
/// bündig auf dem 20-mm-Raster.
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
