
// docs/lib/theme.typ
// OmegaT-compatible layout and typography components for book projects

#import "constants.typ" as std
#import "utils.typ": *

// =====================================================================
// 1. TITLE & METADATA
// =====================================================================

/// Formats the author's name on the title page.
#let title-author(body) = {
  v(30mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formats the main title on the title page.
#let title-main(body) = {
  v(15mm)
  text(size: 20pt)[#body]
}

/// Formats the subtitle on the title page.
#let title-sub(body) = {
  v(15mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formats the publisher or version information at the bottom of the title page.
#let title-publisher(body) = {
  v(30mm)
  text(size: 11pt)[#body]
}

/// Formats an additional title line on the first page.
#let title-note(body) = {
  h(20mm)
  text(
    style: "normal",
    font: std.font-serif,
    size: 1.4em,
  )[#body]
}

// =====================================================================
// 2. LAYOUT SWITCHES & SPECIAL BOXES (for hide_functions)
// =====================================================================

/// Aktiviert den regulären Buch-Blocksatz mit 3 mm Erstzeileneinzug.
#let layout-body-text(body) = {
  show par: set par(first-line-indent: 3mm, justify: true)
  body
}

/// Encapsulates the OmegaT tag regex as an immutable code block.
#let layout-regex-box(dummy: true) = {
  raw(
    block: true,
    lang: "regex",
    "(?:`[^`]+`|</?[a-zA-Z0-9]+>|#link\\(<[^>]+>\\)\\s*\\[[^\\]]*\\]|#meta-teaser\\[|#initial\\[|<p_id_[^>]+>\\]|\\])",
  )
}

// =====================================================================
// 4. PARAGRAPH & TEXT MACROS
// =====================================================================

/// Visual subheading below H1 in all caps (not a separate heading).
#let par-h1-subcaps(body) = {
  set text(size: 1.6em, font: std.font-serif, weight: "bold")
  set par(justify: false, leading: 0.45em)
  pad(left: 20mm, align(left, upper(body)))
}

/// Visual subtitle directly below `h1-serif` (no separate heading).
#let par-h1-subtitle(body) = {
  v(-5mm)
  h(20mm)
  text(weight: "bold", style: "normal", size: 1.4em, body)
}

/// Bold introductory paragraph under H1 (no separate heading).
#let par-h1-lead(body) = {
  text(font: std.font-serif, style: "normal", size: 1.3em, weight: "bold", body)
  v(3em)
}

/// Introductory informational paragraph in large cursive font (no separate heading).
#let par-h2-lead(body) = [
  #block(
    width: 100%,
    breakable: false,
    sticky: true,
    above: 1.5em,
    below: 1.5em,
    inset: (left: 20mm, bottom: 5mm),
  )[
    #set align(left)
    #set par(first-line-indent: 0mm, leading: 0.3em, justify: false)
    #set text(style: "normal", font: std.font-cursive, size: 1.5em)
    #body
  ]
]

/// Formats an introductory guiding question
#let question-cursive(body) = {
  block(
    breakable: false,
    sticky: true,
    width: 100%,
    inset: (left: 20mm),
  )[
    #set text(font: std.font-cursive)
    #body
  ]
}

/// Starts a paragraph with a 20-mm indent and a decorative initial on the first word.
#let dropcap-par(body) = {
  v(-2mm)
  h(20mm)
  show regex("^\p{Letter}+"): it => initial(it)
  body
}

/// A variant of `dropcap-par` with a slightly reduced indent (15 mm).
#let dropcap-par-compact(body) = {
  h(-5mm)
  dropcap-par(body)
}

/// Displays a highlighted “Conclusion” or “Key Points” block with a title column on the left.
#let summary-box(title: "", body) = {
  v(-3mm)
  block(width: 100%, breakable: false, above: 1.5em, below: 1.5em)[
    #grid(
      columns: (18mm, 1fr),
      gutter: 2mm,
      align(left)[
        #set text(weight: "bold", size: 0.85em)
        #title
      ],
      align(left)[
        #set text(size: 0.85em)
        #set par(justify: true, leading: 0.65em)
        #body
      ],
    )
  ]
}

/// Highlights a character's line in dialogue (optionally with a 20-mm indent and an initial).
#let speaker(big-indent: false, body) = {
  let current-indent = if big-indent { 20mm } else { 3mm }

  block(breakable: false, sticky: true, width: 100%)[
    #pad(left: current-indent)[
      #set text(font: std.font-cursive)
      #if big-indent {
        show regex("^\p{Letter}+"): it => initial(it)
        body
      } else {
        body
      }
    ]
  ]
}

/// Sets a two-column entry with a 10-mm left label column.
#let two-column-row(label: none, gutter: -2mm, body) = {
  grid(
    columns: (10mm, 1fr),
    if label != none [#label] else [], [#body],
  )
  v(gutter)
}

/// Aligns the content to the right (e.g., for the location and date).
#let align-right(body) = {
  align(right)[#body]
}

/// Sets the small print (8 pt) without a first-line indent.
#let small-note(body) = {
  show par: set par(first-line-indent: 0mm, leading: 0.3em)
  text(size: 8pt)[#body]
}

// =====================================================================
// 5. METADATA TEASERS FOR THE TABLE OF CONTENTS (meta-*)
// =====================================================================

/// Saves a chapter teaser as metadata for the table of contents
/// and displays it in the text at the same time, indented and in cursive.
#let meta-teaser(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
  #block(width: 100%, breakable: false, sticky: true)[
    #show par: set par(first-line-indent: 0mm)
    #pad(left: 20mm)[
      #block(width: 100%, above: 1.5em, below: 1.5em)[
        #text(style: "italic", font: std.font-cursive)[#extract-text]
      ]
    ]
  ]
]

/// Same as `meta-teaser`, but with a label highlighted in bold (e.g., keyword).
#let meta-teaser-labeled(label: none, body) = [
  #metadata((label: label, extract: body))<meta-chapter>

  #if label != none [
    #block(width: 100%, breakable: false, sticky: true)[
      #show par: set par(first-line-indent: 0mm)
      #pad(left: 20mm)[
        #initial[#label]
      ]
    ]
  ]

  #block(width: 100%, breakable: false, sticky: true)[
    #show par: set par(first-line-indent: 0mm)
    #pad(left: 20mm)[
      #block(width: 100%, above: 1.5em, below: 1.5em)[
        #text(style: "italic", font: std.font-cursive)[#body]
      ]
    ]
  ]
]

/// Inserts an invisible teaser text intended solely for the table of contents.
#let meta-teaser-hidden(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
]

/// Information summary in serif uppercase (Layer 3), including metadata for the table of contents.
#let meta-teaser-h3-caps(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
  #block(width: 100%, breakable: false, sticky: true)[
    #pad(left: 20mm, top: -3mm)[
      #block(width: 100%, above: 1.5em, below: 1.5em)[
        #set par(first-line-indent: 0mm, justify: false, leading: 0.4em)
        #align(left)[
          #text(
            style: "normal",
            font: std.font-serif,
            size: 1.3em,
          )[#upper(extract-text)]
        ]
      ]
    ]
  ]
]

/// Info excerpt in serif uppercase (Layer 4), including metadata for the table of contents.
#let meta-teaser-h4-caps(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
  #block(
    width: 100%,
    breakable: false,
    sticky: true,
    above: 1.5em,
    below: 1.5em,
    inset: (left: 20mm),
  )[
    #v(-6mm)
    #set align(left)
    #set text(
      style: "normal",
      font: std.font-serif,
      size: 1.2em,
      top-edge: "cap-height",
      bottom-edge: "baseline",
    )
    #set par(first-line-indent: 0mm, leading: 0.35em, justify: false)
    #upper(extract-text)
  ]
]

/// Information summary in cursive (Level 5), including metadata for the table of contents.
#let meta-teaser-h5-cursive(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
  #block(width: 100%, breakable: false, sticky: true)[
    #v(-5mm)
    #show par: set par(first-line-indent: 0mm, leading: 0.25em)
    #pad(left: 20mm)[
      #block(width: 100%, above: 1.5em, below: 1.5em)[
        #text(
          style: "normal",
          font: std.font-cursive,
          size: 1.05em,
        )[#extract-text]
      ]
    ]
  ]
]
