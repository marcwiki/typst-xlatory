
// docs/lib/outline.typ
// Inhaltsverzeichnisse mit eingebetteten Kapitel-Teasern und Teil-Übersichten

#import "constants.typ": font-cursive

/// Erzeugt ein lokales Unterverzeichnis für die Ebenen 3 bis 5
/// zwischen zwei definierten Labels im Dokument.
///
/// - after-label (label): Start-Label des Bereichs.
/// - before-label (label): End-Label des Bereichs.
#let comment-sub-outline(after-label, before-label) = {
  pad(left: 20mm - 1em, right: -15mm, top: 0mm)[
    #set par(leading: 0.3em)
    #show outline.entry: set block(above: 0.8em, below: 0.8em)

    #outline(
      title: none,
      target: heading
        .where(level: 3)
        .or(heading.where(level: 4))
        .or(heading.where(level: 5))
        .after(after-label)
        .before(before-label),
    )
  ]
}

/// Hebt den ersten Buchstaben eines Teaser-Labels im Inhaltsverzeichnis hervor.
#let outline-initial(wort) = {
  let wort-str = if type(wort) == str {
    wort
  } else if wort.has("text") {
    wort.text
  } else {
    ""
  }

  let buchstaben = wort-str.clusters()

  if buchstaben.len() > 0 {
    let erster = buchstaben.at(0)
    let rest = buchstaben.slice(1).join("")

    text(
      font: font-cursive,
      size: 1.4em,
      baseline: -0.03em,
      erster,
    )
    h(-0.3mm)
    rest
  } else {
    wort
  }
}

/// Ermittelt einen nachfolgenden `<meta-chapter>`-Teaser für eine Überschrift.
#let find-associated-teaser(ueberschrift-position) = {
  let alle-teasers = query(<meta-chapter>)
  let alle-headings = query(heading)

  let nachfolgende-teasers = alle-teasers.filter(el => (
    el.location().page() > ueberschrift-position.page()
      or (
        el.location().page() == ueberschrift-position.page()
          and el.location().position().y > ueberschrift-position.position().y
      )
  ))
  let nachfolgende-headings = alle-headings.filter(el => (
    el.location().page() > ueberschrift-position.page()
      or (
        el.location().page() == ueberschrift-position.page()
          and el.location().position().y > ueberschrift-position.position().y
      )
  ))

  let teaser-element = nachfolgende-teasers.at(0, default: none)
  let naechste-ueberschrift = nachfolgende-headings.at(0, default: none)

  let teaser-gehoert-hierher = (
    teaser-element != none
      and (
        naechste-ueberschrift == none
          or teaser-element.location().page()
            < naechste-ueberschrift.location().page()
          or (
            teaser-element.location().page()
              == naechste-ueberschrift.location().page()
              and teaser-element.location().position().y
                < naechste-ueberschrift.location().position().y
          )
      )
  )

  if teaser-gehoert-hierher {
    teaser-element.value
  } else {
    none
  }
}

/// Formatiert Einträge im Inhaltsverzeichnis und blendet zugehörige Teaser ein.
#let apply-outline-styles(body) = {
  show outline.entry: set block(above: 0.35em, below: 0.35em)

  show outline.entry: it => {
    show linebreak: [ ]
    if sys.inputs.at("format", default: "paged") == "html" {
      it
    } else {
      let level = it.element.level
      let dynamic-left-inset = if level == 2 { 1.1em } else if level > 2 {
        1.1em + (level - 3) * 1.5em
      } else { 0.5em }

      context {
        let ueberschrift-position = it.element.location()
        let teaser-daten = find-associated-teaser(ueberschrift-position)

        block(
          width: 100%,
          breakable: false,
          {
            if it.level == 1 {
              block(
                width: 100%,
                above: 1.4em,
                below: 0.8em,
                align(
                  left,
                  block(
                    width: 100%,
                    inset: (left: 1.1em, right: 3em),
                    it.body(),
                  ),
                ),
              )
            } else if it.level == 2 {
              it
            } else {
              block(
                width: 100%,
                inset: (left: dynamic-left-inset, right: 3em),
                link(
                  it.element.location(),
                  it.element.body + box(width: 1fr, it.fill) + it.page(),
                ),
              )
            }

            if teaser-daten != none {
              let teaser-label = teaser-daten.at("label", default: none)
              let teaser-extract = teaser-daten.at("extract", default: none)

              if teaser-label != none or teaser-extract != none {
                block(
                  width: 100%,
                  inset: (left: dynamic-left-inset, right: 3em),
                  above: 0.35em,
                  below: 0.2em,
                  breakable: false,
                  pad(left: 6mm)[
                    #set text(size: 0.82em, style: "italic")
                    #set par(
                      leading: 0.42em,
                      spacing: 0.35em,
                      first-line-indent: 0mm,
                    )

                    #if teaser-label != none {
                      outline-initial(teaser-label)
                      if teaser-extract != none {
                        parbreak()
                      }
                    }

                    #if teaser-extract != none {
                      teaser-extract
                    }
                  ],
                )
              }
            }
          },
        )
      }
    }
  }

  body
}
