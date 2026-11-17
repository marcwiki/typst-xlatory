
// docs/lib/headings.typ
// Überschriften-Hierarchie mit labelgesteuerter Nummerierung und Schriftwahl

#import "constants.typ": font-cursive

/// Steuert das Erscheinungsbild aller Überschriften-Ebenen (Level 1 bis 5).
/// Erkennt über Typst-Labels automatisch spezielle Formatierungs-Marker:
/// - `cl-numbered`: Aktiviert die Kapitelnummerierung auf Ebene 2.
/// - `cl-comment`: Wechselt auf die kalligrafische Kommentar-Schriftart.
#let apply-heading-styles(body) = {
  set heading(
    numbering: (..args) => {
      let nums = args.pos()
      if nums.len() >= 2 { str(nums.at(1)) + "." }
    },
  )

  show heading: it => {
    set block(sticky: true, breakable: false)

    let label-text = if it.has("label") { str(it.label) } else { "" }
    let is-numbered = "cl-numbered" in label-text
    let is-comment = "cl-comment" in label-text

    if it.level == 1 {
      block(above: 40mm, below: 3em, inset: (left: 20mm), width: 100%)[
        #set text(size: 1.4em, style: "italic")
        #it.body
      ]
    } else if it.level == 2 {
      if is-numbered {
        context {
          let heading-number = counter(heading).display(it.numbering)
          block(above: 3.5em, below: 1em, width: 100%)[
            #grid(
              columns: (17mm, 3mm, 1fr),
              align(right)[
                #if is-comment [
                  #set text(font: font-cursive)
                  #text(size: 1.4em, weight: "bold")[#heading-number]
                ] else [
                  #text(size: 1.4em, weight: "bold")[#heading-number]
                ]
              ],
              none,
              align(left)[
                #set par(leading: 0.2em, justify: false)
                #if is-comment [
                  #set text(font: font-cursive)
                  #text(size: 1.4em, weight: "bold")[#it.body]
                ] else [
                  #text(size: 1.4em, weight: "bold")[#it.body]
                ]
              ],
            )
          ]
        }
      } else {
        block(above: 1.5em, below: 1em, width: 100%)[
          #pad(left: 20mm)[
            #set par(leading: 0.5em, justify: false)
            #align(left)[
              #if is-comment [
                #set text(font: font-cursive)
                #text(size: 1.2em, weight: "bold")[#it.body]
              ] else [
                #text(size: 1.2em, weight: "bold")[#it.body]
              ]
            ]
          ]
        ]
      }
    } else if it.level == 3 {
      block(above: 1.2em, below: 0.8em)[#text(
          size: 1.2em,
          weight: "bold",
        )[#it.body]]
    } else if it.level == 4 {
      block(above: 1em, below: 0.6em)[#text(
          size: 1.1em,
          weight: "medium",
        )[#it.body]]
    } else if it.level == 5 {
      block(above: 1em, below: 0.6em)[#text(
          size: 1.0em,
          style: "normal",
        )[#it.body]]
    } else {
      it
    }
  }

  body
}
