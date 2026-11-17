
// docs/lib/theme.typ
// OmegaT-freundliche Layout- und Typografie-Komponenten für Buchprojekte

#import "constants.typ" as std

// =====================================================================
// HILFSFUNKTIONEN
// =====================================================================

/// Wandelt Typst-Content rekursiv in einen reinen String um (z. B. für Initialen).
#let to-string(content) = {
  if type(content) == "string" {
    content
  } else if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(to-string).join("")
  } else if content.has("body") {
    to-string(content.body)
  } else {
    repr(content)
  }
}

/// Hebt den ersten Buchstaben eines Wortes als kalligrafische Initiale hervor.
/// Nutzt Unicode-Cluster, damit auch kyrillische Zeichen sauber getrennt werden.
#let initial(wort) = {
  let wort-str = to-string(wort)
  let buchstaben = wort-str.clusters()

  if buchstaben.len() > 0 {
    let erster = buchstaben.at(0)
    let rest = buchstaben.slice(1).join("")

    text(
      font: std.font-cursive,
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

// =====================================================================
// 1. TITELEI & METADATEN
// =====================================================================

/// Formatiert den Autorennamen auf der Titelseite.
#let title-author(body) = {
  v(30mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formatiert den Haupttitel auf der Titelseite.
#let title-main(body) = {
  v(15mm)
  text(size: 20pt)[#body]
}

/// Formatiert den Untertitel auf der Titelseite.
#let title-sub(body) = {
  v(15mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formatiert die Verlags- oder Versionsangabe unten auf der Titelseite.
#let title-publisher(body) = {
  v(30mm)
  text(size: 11pt)[#body]
}

/// Formatiert eine eingerückte Titel-Zusatzzeile auf der ersten Seite.
#let title-note(body) = {
  h(20mm)
  text(
    style: "normal",
    font: std.font-serif,
    size: 1.4em,
  )[#body]
}

// =====================================================================
// 2. LAYOUT-UMSCHALTER & SPEZIAL-BOXEN (für hide_functions)
// =====================================================================

/// Aktiviert den regulären Buch-Blocksatz mit 3 mm Erstzeileneinzug.
#let layout-body-text(body) = {
  show par: set par(first-line-indent: 3mm, justify: true)
  body
}

/// Kapselt den OmegaT-Tag-Regex als unveränderlichen Codeblock.
#let layout-regex-box(dummy: true) = {
  raw(
    block: true,
    lang: "regex",
    "(?:`[^`]+`|</?[a-zA-Z0-9]+>|#link\\(<[^>]+>\\)\\s*\\[[^\\]]*\\]|#meta-teaser\\[|#initial\\[|<p_id_[^>]+>\\]|\\])",
  )
}

// =====================================================================
// 3. ECHTE ÜBERSCHRIFTEN (h1-* bis h5-*)
// =====================================================================

/// Erzeugt eine kalligrafische Kapitelüberschrift (Level 1 ohne Nummerierung).
#let h1-cursive(body) = {
  set text(font: std.font-cursive, size: 0.8em, weight: "bold")
  heading(level: 1, numbering: none, body)
}

/// Große Serif-Überschrift (Level 1) für Kommentar- oder Referenzabschnitte.
#let h1-serif(body) = {
  show heading.where(level: 1): it => {
    block(
      sticky: true,
      breakable: false,
      inset: (top: 10mm, bottom: 15mm, left: 20mm, right: 8pt),
      width: 100%,
    )[
      #set text(font: std.font-serif, size: 2.5em, weight: "bold")
      #it.body
    ]
  }
  heading(level: 1, body)
}

/// Überschrift Ebene 3 in Schreibschrift.
#let h3-cursive(body) = {
  show heading.where(level: 3): it => {
    block(
      sticky: true,
      breakable: false,
      inset: (top: 8pt, bottom: 8pt, left: 20mm, right: 8pt),
      width: 100%,
    )[
      #set align(left)
      #set par(justify: false, leading: 0.3em)
      #set text(font: std.font-cursive, size: 1.5em, weight: "bold")
      #it.body
    ]
  }
  heading(level: 3, body)
}

/// Überschrift Ebene 3 in Serif-Versalien.
#let h3-caps(body) = {
  block(
    inset: (top: 8pt, bottom: 0pt, left: 20mm, right: 8pt),
    width: 100%,
    {
      set text(size: 0.85em, weight: "regular")
      heading(level: 3, upper(body))
    },
  )
}

/// Überschrift Ebene 4 in Schreibschrift.
#let h4-cursive(body) = {
  show heading.where(level: 4): it => {
    block(
      sticky: true,
      breakable: false,
      inset: (top: 8pt, bottom: 8pt, left: 20mm, right: 8pt),
      width: 100%,
    )[
      #set text(font: std.font-cursive, size: 1.3em, weight: "bold")
      #it.body
    ]
  }
  heading(level: 4, body)
}

/// Überschrift Ebene 5 in fett gesetzter Serif-Schrift.
#let h5-serif(body) = {
  show heading.where(level: 5): it => {
    block(
      sticky: true,
      breakable: false,
      inset: (top: 8pt, bottom: 8pt, left: 20mm, right: 8pt),
      width: 100%,
    )[
      #set text(font: std.font-serif, weight: "bold")
      #it.body
    ]
  }
  heading(level: 5, body)
}

// =====================================================================
// 4. ABSATZ- & TEXT-MAKROS
// =====================================================================

/// Visuelle Unterzeile unter H1 in Versalien (kein eigenes Heading).
#let par-h1-subcaps(body) = {
  v(-8mm)
  set text(size: 1.6em, font: std.font-serif, weight: "bold")
  set par(justify: false, leading: 0.45em)
  pad(left: 20mm, align(left, upper(body)))
}

/// Visueller Untertitel direkt unterhalb von `h1-serif` (kein eigenes Heading).
#let par-h1-subtitle(body) = {
  v(-10mm)
  h(20mm)
  text(weight: "bold", style: "normal", size: 1.4em, body)
}

/// Fett gesetzter Einleitungsabsatz unter H1 (kein eigenes Heading).
#let par-h1-lead(body) = {
  text(font: std.font-serif, style: "normal", size: 1.3em, weight: "bold", body)
  v(3em)
}

/// Einleitender Info-Absatz in großer Schreibschrift (kein eigenes Heading).
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

/// Formatiert eine einleitende Leitfrage in Schreibschrift am Kapitelbeginn.
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

/// Startet einen Absatz mit 20-mm-Einzug und verzierter Initiale am ersten Wort.
#let dropcap-par(body) = {
  v(-2mm)
  h(20mm)
  show regex("^\p{Letter}+"): it => initial(it)
  body
}

/// Variante von `dropcap-par` mit leicht reduziertem Einzug (15 mm).
#let dropcap-par-compact(body) = {
  h(-5mm)
  dropcap-par(body)
}

/// Zeigt einen hervorgehobenen Fazit- oder Merksatz-Block mit linker Titelspalte.
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

/// Markiert eine Sprecher-Zeile in Dialogen (optional mit 20-mm-Einzug und Initiale).
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

/// Setzt einen zweispaltigen Eintrag mit 10 mm linker Labelspalte.
#let two-column-row(label: none, gutter: -2mm, body) = {
  grid(
    columns: (10mm, 1fr),
    if label != none [#label] else [], [#body],
  )
  v(gutter)
}

/// Richtet den Inhalt rechtsbündig aus (z. B. für Ort und Datum).
#let align-right(body) = {
  align(right)[#body]
}

/// Setzt Kleingedrucktes (8 pt) ohne Erstzeileneinzug.
#let small-note(body) = {
  show par: set par(first-line-indent: 0mm)
  text(size: 8pt)[#body]
}

// =====================================================================
// 5. METADATEN-TEASER FÜR DAS INHALTSVERZEICHNIS (meta-*)
// =====================================================================

/// Speichert einen Kapitel-Teaser als Metadatum für das Inhaltsverzeichnis
/// und zeigt ihn gleichzeitig eingerückt in Schreibschrift im Text an.
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

/// Wie `meta-teaser`, ergänzt um ein fett hervorgehobenes Label (z. B. Stichwort).
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

/// Hinterlegt einen unsichtbaren Teaser-Text ausschliesslich für das Inhaltsverzeichnis.
#let meta-teaser-hidden(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
]

/// Info-Extrakt in Serif-Versalien (Ebene 3) inkl. Metadatum für das Inhaltsverzeichnis.
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

/// Info-Extrakt in Serif-Versalien (Ebene 4) inkl. Metadatum für das Inhaltsverzeichnis.
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

/// Info-Extrakt in Schreibschrift (Ebene 5) inkl. Metadatum für das Inhaltsverzeichnis.
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
