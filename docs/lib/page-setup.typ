
// docs/lib/page-setup.typ
// Seitenlayouts für Titelei, Vorwort sowie lebende Kolumnentitel

/// Zeigt ein vollflächiges Cover-Bild auf der ersten Seite ohne Ränder.
#let layout-cover(image-path: "../images/cover.jpeg") = {
  page(
    paper: "a5",
    margin: 0cm,
    header: none,
    footer: none,
    background: image(
      image-path,
      width: 100%,
      height: 100%,
      fit: "cover",
    ),
  )
}

/// Layout für Schmutztitel oder Impressumsseiten ohne Kopf-/Fußzeile.
#let layout-frontmatter(body) = {
  set page(
    paper: "a5",
    margin: (right: 20mm, left: 20mm, top: 15mm, bottom: 15mm),
    header: none,
    footer: none,
  )
  show par: set par(
    first-line-indent: 0mm,
    leading: 0.3em,
    spacing: 0.5em,
    justify: false,
  )
  body
}

/// Layout für die Haupttitelseite mit breitem rechtem Weißraum.
#let layout-title-page(body) = {
  set page(
    paper: "a5",
    margin: (right: 50mm),
    header: none,
    footer: none,
  )
  show par: set par(first-line-indent: 0pt, justify: false)
  body
}

/// Erzeugt dynamische Kolumnentitel in der Kopfzeile (unterdrückt auf Kapitelanfangsseiten).
///
/// - book-title (str | content): Der Titel des Buches für gerade Seiten.
#let make-header(book-title) = {
  let current-page = here().page()

  let headings-on-page = query(
    heading.where(level: 1).or(heading.where(level: 2)),
  ).filter(it => it.location().page() == current-page)

  if headings-on-page.len() > 0 {
    return none
  }

  let page-num = counter(page).at(here()).first()
  let is-even = calc.even(page-num)

  if is-even {
    let elements = query(heading.where(level: 1).before(here()))
    if elements.len() > 0 {
      text(9pt, fill: rgb("#003366"), elements.last().body)
    }
    text(9pt, fill: rgb("#444444"), "  " + book-title)
  } else {
    let elements = query(heading.where(level: 2).before(here()))
    if elements.len() > 0 {
      let last-heading = elements.last()
      let heading-counter = counter(heading).at(last-heading.location())
      let num-string = if last-heading.numbering != none {
        numbering(last-heading.numbering, ..heading-counter) + " "
      } else {
        ""
      }

      align(
        right,
        text(9pt, fill: rgb("#003366"))[
          #show linebreak: [ ]
          #show v: none
          #num-string#last-heading.body
        ],
      )
    } else {
      none
    }
  }
}

/// Erzeugt die zentrierte Seitenzahl in der Fußzeile (auf Seite 1 unterdrückt).
#let make-footer() = {
  let page-num = counter(page).at(here()).first()
  if page-num == 1 { return none }
  align(center, text(10pt, str(page-num)))
}
