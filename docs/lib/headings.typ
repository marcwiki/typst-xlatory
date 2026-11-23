
// docs/lib/headings.typ
#import "constants.typ": color-accent, font-cursive, font-serif

// Central layout axis for all headings
#let _axis-left = 20mm

// =====================================================================
// 1. GLOBAL BASIC RULES (including label control: cl-numbered / cl-comment)
// =====================================================================

/// Controls the default appearance of all headings (Levels 1 through 5).
/// All levels are uniformly aligned with the 20-mm axis.
/// Recognizes specific Typst labels:
/// - `cl-numbered`: Enables chapter numbering at Level 2.
/// - `cl-comment`: Switches to the calligraphic comment font.

// Define your own independent counter (starts internally at 0; the first `step()` sets it to 1)
#let cl-chapter-counter = counter("cl-chapter-counter")

#let apply-heading-styles(body) = {
  set heading(
    numbering: (..args) => {
      if args.pos().len() >= 2 {
        cl-chapter-counter.display("1.")
      }
    },
  )

  show heading: it => {
    set block(sticky: true, breakable: false)

    let label-text = if it.has("label") { str(it.label) } else { "" }
    let is-numbered = "cl-numbered" in label-text
    let is-comment = "cl-comment" in label-text
    let active-font = if is-comment { font-cursive } else { font-serif }

    if it.level == 1 {
      // Optional: If you want the numbering to start at 1 again for each Level 1 section:
      // cl-chapter-counter.update(0)

      block(above: 40mm, below: 3em, inset: (left: _axis-left), width: 100%)[
        #set text(font: active-font, size: 1.4em, style: "italic")
        #it.body
      ]
    } else if it.level == 2 {
      if is-numbered {
        [
          #context {
            let aktuelle-nummer = cl-chapter-counter.get().first() + 1
            block(above: 3.5em, below: 1em, width: 100%)[
              #grid(
                columns: (17mm, 3mm, 1fr),
                align(right)[
                  #text(
                    font: active-font,
                    size: 1.4em,
                    weight: "bold",
                  )[#(str(aktuelle-nummer) + ".")]
                ],
                none,
                align(left)[
                  #set par(leading: 0.2em, justify: false)
                  #text(
                    font: active-font,
                    size: 1.4em,
                    weight: "bold",
                  )[#it.body]
                ],
              )
            ]
          }
          #cl-chapter-counter.step()
        ]
      } else {
        // An unnumbered Level 2 heading leaves the counter unchanged
        block(above: 1.5em, below: 1em, inset: (left: _axis-left), width: 100%)[
          #set par(leading: 0.5em, justify: false)
          #align(left)[
            #text(font: active-font, size: 1.2em, weight: "bold")[#it.body]
          ]
        ]
      }
    } else if it.level == 3 {
      block(above: 1.2em, below: 0.8em, inset: (left: _axis-left), width: 100%)[
        #set par(justify: false)
        #text(font: active-font, size: 1.2em, weight: "bold")[#it.body]
      ]
    } else if it.level == 4 {
      block(above: 1em, below: 0.6em, inset: (left: _axis-left), width: 100%)[
        #set par(justify: false)
        #text(font: active-font, size: 1.1em, weight: "medium")[#it.body]
      ]
    } else if it.level == 5 {
      block(above: 1em, below: 0.6em, inset: (left: _axis-left), width: 100%)[
        #set par(justify: false)
        #text(font: active-font, size: 1.0em, style: "normal")[#it.body]
      ]
    } else {
      it
    }
  }

  body
}

// =====================================================================
// 2. INTERNAL HELPER FOR EXPLICIT SPECIAL HEADINGS
// =====================================================================

#let _custom-heading(
  level: 1,
  numbered: false,
  inset: (top: 8pt, bottom: 8pt, left: _axis-left, right: 8pt),
  text-style: (:),
  transform: it => it,
  body,
  ..args,
) = {
  show heading: it => {
    let label-text = if it.has("label") { str(it.label) } else { "" }
    let is-numbered = numbered or ("cl-numbered" in label-text)

    if level == 2 and is-numbered {
      [
        #context {
          let aktuelle-nummer = cl-chapter-counter.get().first() + 1
          block(
            sticky: true,
            breakable: false,
            above: 3.5em,
            below: 1em,
            width: 100%,
          )[
            #grid(
              columns: (17mm, 3mm, 1fr),
              align(right)[
                #text(..text-style)[#(str(aktuelle-nummer) + ".")]
              ],
              none,
              align(left)[
                #set par(justify: false, leading: 0.3em)
                #text(..text-style)[#transform(it.body)]
              ],
            )
          ]
        }
        #cl-chapter-counter.step()
      ]
    } else {
      block(
        sticky: true,
        breakable: false,
        inset: inset,
        width: 100%,
      )[
        #set align(left)
        #set par(justify: false, leading: 0.3em)
        #text(..text-style)[#transform(it.body)]
      ]
    }
  }
  heading(level: level, ..args, body)
}


// =====================================================================
// 3. EXPLICIT HEADING MACROS (h1-* through h5-*)
// =====================================================================

/// Calligraphic Level 1 heading (without numbering).
#let h1-cursive(body, ..args) = _custom-heading(
  level: 1,
  numbering: none,
  text-style: (font: font-cursive, size: 1em, weight: "bold"),
  body,
  ..args,
)

/// Serif heading (Level 1)
#let h1-serif(body, ..args) = _custom-heading(
  level: 1,
  inset: (top: 10mm, bottom: 15mm, left: _axis-left, right: 8pt),
  text-style: (font: font-serif, size: 1.4em, weight: "bold"),
  body,
  ..args,
)

/// Large serif heading (Level 1) for comments or reference sections.
#let h1-serif-large(body, ..args) = _custom-heading(
  level: 1,
  inset: (top: 10mm, bottom: 15mm, left: _axis-left, right: 8pt),
  text-style: (font: font-serif, size: 2.5em, weight: "bold"),
  body,
  ..args,
)

/// Level 3 heading in cursive.
#let h3-cursive(body, ..args) = _custom-heading(
  level: 3,
  text-style: (font: font-cursive, size: 1.5em, weight: "bold"),
  body,
  ..args,
)

/// Level 3 heading in all caps (remains in normal text in the table of contents).
#let h3-caps(body, ..args) = _custom-heading(
  level: 3,
  inset: (top: 8pt, bottom: 0pt, left: _axis-left, right: 8pt),
  text-style: (size: 0.85em, weight: "regular"),
  transform: upper,
  body,
  ..args,
)

/// Level 4 heading in cursive.
#let h4-cursive(body, ..args) = _custom-heading(
  level: 4,
  text-style: (font: font-cursive, size: 1.3em, weight: "bold"),
  body,
  ..args,
)

/// Level 5 heading in serif font on the 20-mm axis.
#let h5-serif(body, ..args) = _custom-heading(
  level: 5,
  inset: (top: 1em, bottom: 0.6em, left: _axis-left, right: 8pt),
  text-style: (font: font-serif, size: 1.0em, style: "normal"),
  body,
  ..args,
)
