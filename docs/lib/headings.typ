
// docs/lib/headings.typ
// Überschriften-Hierarchie mit Nummerierung (1. / 1.1)
// und labelgesteuerter Nummerierung
// und labelgesteuertem Styling

#import "constants.typ": color-accent, font-cursive, font-serif

/// Steuert das Erscheinungsbild
/// und die Nummerierung aller Überschriften (Level 1 bis 5).
/// Erkennt über Typst-Labels automatisch spezielle Formatierungs-Marker:
/// - `cl-numbered`: Aktiviert die Kapitelnummerierung auf Ebene 2.
/// - `cl-comment`: Wechselt auf die kalligrafische Kommentar-Schriftart.
#let apply-heading-styles(body) = {
  // Nummerierungsschema: Ebene 1 -> "1.", Ebene 2 -> "1.1"
  set heading(
    numbering: (..args) => {
      let nums = args.pos()
      if nums.len() == 1 {
        str(nums.at(0)) + "."
      } else if nums.len() == 2 {
        str(nums.at(0)) + "." + str(nums.at(1))
      } else {
        none
      }
    },
  )

  show heading: it => {
    set block(sticky: true, breakable: false)

    let label-text = if it.has("label") { str(it.label) } else { "" }
    let is-comment = "cl-comment" in label-text

    if it.level == 1 {
      // Kapitelüberschrift Ebene 1 mit Nummer (z. B. "1. Einführung")
      block(above: 28mm, below: 2em, width: 100%)[
        #grid(
          columns: (17mm, 3mm, 1fr),
          align(right)[
            #if it.numbering != none [
              #text(
                size: 1.5em,
                weight: "bold",
                fill: color-accent,
              )[#counter(heading).display(it.numbering)]
            ]
          ],
          none,
          align(left)[
            #set par(leading: 0.25em, justify: false)
            #text(size: 1.5em, weight: "bold")[#it.body]
          ],
        )
      ]
    } else if it.level == 2 {
      // Unterkapitel Ebene 2 mit Nummer (z. B. "1.1 Die Lösung")
      block(above: 2.2em, below: 0.9em, width: 100%)[
        #grid(
          columns: (17mm, 3mm, 1fr),
          align(right)[
            #if it.numbering != none [
              #set text(
                font: if is-comment { font-cursive } else { font-serif },
              )
              #text(
                size: 1.2em,
                weight: "bold",
                fill: color-accent,
              )[#counter(heading).display(it.numbering)]
            ]
          ],
          none,
          align(left)[
            #set par(leading: 0.25em, justify: false)
            #set text(font: if is-comment { font-cursive } else { font-serif })
            #text(size: 1.2em, weight: "bold")[#it.body]
          ],
        )
      ]
    } else if it.level == 3 {
      block(above: 1.2em, below: 0.8em)[#text(
          size: 1.15em,
          weight: "bold",
        )[#it.body]]
    } else if it.level == 4 {
      block(above: 1em, below: 0.6em)[#text(
          size: 1.05em,
          weight: "medium",
        )[#it.body]]
    } else {
      it
    }
  }

  body
}
