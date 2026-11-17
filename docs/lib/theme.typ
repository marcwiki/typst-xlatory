
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
#let author-name(body) = {
  v(30mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formatiert den Haupttitel auf der Titelseite.
#let book-title(body) = {
  v(15mm)
  text(size: 20pt)[#body]
}

/// Formatiert den Untertitel auf der Titelseite.
#let book-subtitle(body) = {
  v(15mm)
  text(font: std.font-cursive, size: 18pt)[#body]
}

/// Formatiert die Verlags- oder Versionsangabe unten auf der Titelseite.
#let book-publisher(body) = {
  v(30mm)
  text(size: 11pt)[#body]
}

/// Formatiert eine eingerückte Titel-Zusatzzeile auf der ersten Seite.
#let title-info(body) = {
  h(20mm)
  text(
    style: "normal",
    font: std.font-serif,
    size: 1.4em,
  )[#body]
}

// =====================================================================
// 2. KAPITEL-EINSTIEG & FLIESSTEXT-STEUERUNG
// =====================================================================

/// Aktiviert den regulären Buch-Blocksatz mit 3 mm Erstzeileneinzug.
#let start-normal-text(body) = {
  show par: set par(first-line-indent: 3mm, justify: true)
  body
}

/// Erzeugt eine kalligrafische Kapitelüberschrift (Level 1 ohne Nummerierung).
#let h1-title(body) = {
  set text(font: std.font-cursive, size: 0.8em, weight: "bold")
  heading(level: 1, numbering: none, body)
}

/// Erzeugt den rechtsbündig zum 20-mm-Raster gesetzten Kapitel-Untertitel in Versalien.
#let h1-title-info(body) = {
  v(-8mm)
  set text(size: 1.6em, font: std.font-serif, weight: "bold")
  set par(justify: false, leading: 0.45em)
  pad(left: 20mm, align(left, upper(body)))
}

/// Startet einen Absatz mit 20-mm-Einzug und verzierter Initiale am ersten Wort.
#let first-par(body) = {
  v(-2mm)
  h(20mm)
  show regex("^\p{Letter}+"): it => initial(it)
  body
}

/// Variante von `first-par` mit leicht reduziertem Einzug (15 mm).
#let big-indent-initial(body) = {
  h(-5mm)
  first-par(body)
}

/// Formatiert eine einleitende Leitfrage in Schreibschrift am Kapitelbeginn.
#let intro-question(body) = {
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

// =====================================================================
// 3. AUSZÜGE, METADATEN-TEASER & FAZIT
// =====================================================================

/// Speichert einen Kapitel-Teaser als Metadatum für das Inhaltsverzeichnis
/// und zeigt ihn gleichzeitig eingerückt in Schreibschrift im Text an.
#let chapter-extract(extract-text) = [
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

/// Wie `chapter-extract`, ergänzt um ein fett hervorgehobenes Label (z. B. Stichwort).
#let chapter-extract-and-meta(label: none, body) = [
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
#let chapter-extract-meta-only(extract-text) = [
  #metadata((extract: extract-text))<meta-chapter>
]

/// Zeigt einen hervorgehobenen Fazit- oder Merksatz-Block mit linker Titelspalte.
///
/// - title (str): Überschrift in der linken Spalte (wird als `_arg_title` exportiert).
/// - body (content): Inhalt in der rechten Spalte (wird als `_arg` exportiert).
#let conclusion(title: "", body) = {
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

// =====================================================================
// 4. SPEZIELLE ÜBERSCHRIFTEN- & KOMMENTAR-HIERARCHIEN
// =====================================================================

/// Große Serif-Überschrift (Level 1) für Kommentar- oder Referenzabschnitte.
#let comment-h1-title(body) = {
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

/// Untertitel direkt unterhalb eines `comment-h1-title`.
#let comment-h1-sub-title(body) = {
  v(-10mm)
  h(20mm)
  text(weight: "bold", style: "normal", size: 1.4em, body)
}

/// Fett gesetzter Info-Titel im Kommentarbereich.
#let comment-h1-title-info(body) = {
  text(font: std.font-serif, style: "normal", size: 1.3em, weight: "bold", body)
  v(3em)
}

/// Zweizeilige oder einführende Info-Überschrift in Schreibschrift (Ebene 2).
#let comment-cursive-h2-info(body) = [
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

/// Überschrift Ebene 3 in Schreibschrift.
#let comment-cursive-h3(body) = {
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

/// Überschrift Ebene 4 in Schreibschrift.
#let comment-cursive-h4(body) = {
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

/// Info-Extrakt in Schreibschrift (Ebene 5) inkl. Metadatum für das Inhaltsverzeichnis.
#let comment-cursive-h5-info-extract(extract-text) = [
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

/// Überschrift Ebene 3 in Serif-Versalien.
#let comment-serif-h3(body) = {
  block(
    inset: (top: 8pt, bottom: 0pt, left: 20mm, right: 8pt),
    width: 100%,
    {
      set text(size: 0.85em, weight: "regular")
      heading(level: 3, upper(body))
    },
  )
}

/// Info-Extrakt in Serif-Versalien (Ebene 3) inkl. Metadatum für das Inhaltsverzeichnis.
#let comment-serif-h3-info-extract(extract-text) = [
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
#let comment-serif-h4-info-extract(extract-text) = [
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

/// Überschrift Ebene 5 in fett gesetzter Serif-Schrift.
#let comment-serif-h5(body) = {
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
// 5. DIALOG- & LAYOUT-HELFER
// =====================================================================

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
#let row(label: none, gutter: -2mm, body) = {
  grid(
    columns: (10mm, 1fr),
    if label != none [#label] else [], [#body],
  )
  v(gutter)
}

/// Richtet den Inhalt rechtsbündig aus (z. B. für Ort und Datum).
#let right-text(body) = {
  align(right)[#body]
}

/// Setzt Kleingedrucktes (8 pt) ohne Erstzeileneinzug.
#let small-text(body) = {
  show par: set par(first-line-indent: 0mm)
  text(size: 8pt)[#body]
}

// =====================================================================
// 6. HANDBUCH-SPEZIFISCHE CODE-BOXEN
// =====================================================================

/// Kapselt den OmegaT-Tag-Regex als unveränderlichen Codeblock.
#let omegat-regex-box(dummy: true) = {
  raw(
    block: true,
    lang: "regex",
    "(?:`[^`]+`|</?[a-zA-Z0-9]+>|#link\\(<[^>]+>\\)\\s*\\[[^\\]]*\\]|#chapter-extract\\[|#initial\\[|<p_id_[^>]+>\\]|\\])",
  )
}
