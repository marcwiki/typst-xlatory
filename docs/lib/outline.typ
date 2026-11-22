
// docs/lib/outline.typ
// Tables of contents with embedded chapter teasers and section overviews

#import "constants.typ": font-cursive
#import "headings.typ": cl-chapter-counter
#import "utils.typ": *

// Optionaler Override für den Teaser-Einzug in speziellen Sub-TOCs
#let _override-teaser-left-inset = state("override-teaser-left-inset", none)

/// Renders the main table of contents (up to `before`) with Level 1 entries
/// in cursive script (font-cursive) without page numbers, followed by the
/// suffix defined via `meta-set(key: "outline-h1")`.
#let layout-main-toc(before: none) = {
  let target-selector = if before != none {
    heading.where(level: 1).or(heading.where(level: 2)).before(before)
  } else {
    heading.where(level: 1).or(heading.where(level: 2))
  }

  [
    #show outline.entry.where(level: 1): it => {
      context {
        let suffix = meta-str("outline-h1")

        block(
          width: 100%,
          above: 1.2em,
          below: 0.4em,
          inset: (left: 0.5em, right: 0.5em, bottom: 0.3em),
          stroke: (bottom: 0.4pt + gray.lighten(55%)),
          link(
            it.element.location(),
            {
              set par(first-line-indent: 0mm, leading: 0.35em, justify: false)
              grid(
                columns: (1.8em, 1fr),
                column-gutter: 0.4em,
                align(left)[#text(weight: "bold", size: 1.05em)[#it.prefix()]],
                align(left)[
                  #text(
                    font: font-cursive,
                    size: 1.25em,
                    weight: "bold",
                  )[#it.body()]
                  #if suffix != none and suffix != "" [
                    #h(0.4em)
                    #text(size: 0.9em, style: "italic")[#suffix]
                  ]
                ],
              )
            },
          ),
        )
      }
    }

    #outline(
      title: none,
      target: target-selector,
    )
  ]
}

/// Renders the commentary table of contents starting after `after`.
#let layout-commentary-toc(after, teaser-inset: 8mm) = {
  _override-teaser-left-inset.update(teaser-inset)
  outline(
    title: none,
    target: heading.where(level: 2).after(after, inclusive: false),
  )
  _override-teaser-left-inset.update(none)
}


/// Creates a local subdirectory for levels 3 through 5
/// between two defined labels in the document.
#let layout-sub-toc(after-label, before-label) = {
  pad(left: 20mm - 1em, right: 0mm, top: 0mm)[
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

/// Identifies a subsequent `<meta-chapter>` teaser for a heading.
#let find-associated-teaser(heading-position) = {
  let nachfolgende-teasers = query(
    selector(<meta-chapter>).after(heading-position),
  )
  let nachfolgende-headings = query(
    selector(heading).after(heading-position, inclusive: false),
  )

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

/// Formats entries in the table of contents and displays the corresponding teasers.
#let apply-outline-styles(body) = {
  show outline.entry: set block(above: 0.35em, below: 0.35em)
  show outline.entry: it => {
    show linebreak: [ ]
    if sys.inputs.at("format", default: "paged") == "html" {
      it
    } else {
      let level = it.element.level
      let dynamic-left-inset = 0.5em

      // Synchronisation mit cl-numbered aus headings.typ
      let label-text = if it.element.has("label") {
        str(it.element.label)
      } else { "" }
      let is-numbered = "cl-numbered" in label-text

      context {
        let heading-position = it.element.location()
        let teaser-data = find-associated-teaser(heading-position)

        // Check whether the next heading in the document is a sub-heading (level 1 to 5)
        let next-headings = query(
          selector(heading).after(heading-position, inclusive: false),
        )
        let has-sub-heading = (
          next-headings.len() > 0 and next-headings.first().level > it.level
        )

        // Check whether we are at or after the comment-start label from metadata
        let comment-label-name = meta-str("comment-start")
        let is-in-comment = if comment-label-name != "" {
          let comment-lbl = label(comment-label-name)
          let comment-markers = query(
            selector(comment-lbl).before(heading-position),
          )
          (
            comment-markers.len() > 0
              or (it.element.has("label") and it.element.label == comment-lbl)
          )
        } else {
          false
        }

        // Define teaser left inset (mit optionalem Override für Sub-TOCs)
        let custom-inset = _override-teaser-left-inset.get()
        let teaser-left-inset = if custom-inset != none {
          custom-inset
        } else if is-in-comment {
          0.5em
        } else {
          8mm
        }

        // Read the exact chapter number at the position of the heading (+1, since `step()` follows it)
        let chapter-number = if is-numbered {
          let count = cl-chapter-counter.at(heading-position).first()
          str(count + 1) + "."
        } else {
          none
        }

        // Optional suffix from the teaser data (if provided there)
        let suffix = if teaser-data != none {
          teaser-data.at("suffix", default: none)
        } else {
          none
        }

        block(
          width: 100%,
          breakable: false,
          {
            // 1. Formatting the Entries in the Table of Contents
            if it.level == 1 {
              block(
                width: 100%,
                above: 1.2em,
                below: 0.4em,
                inset: (left: 0.5em, right: 0.5em, bottom: 0.3em),
                stroke: (bottom: 0.4pt + gray.lighten(55%)),
                link(
                  heading-position,
                  {
                    set text(weight: "bold", size: 1.05em)
                    set par(
                      first-line-indent: 0mm,
                      leading: 0.35em,
                      justify: false,
                    )
                    grid(
                      columns: (1.8em, 1fr, auto),
                      column-gutter: 0.4em,
                      align(left)[#chapter-number],
                      align(left)[#it.body()],
                      align(right + bottom)[#if not has-sub-heading {
                          it.page()
                        }],
                    )
                  },
                ),
              )
            } else if it.level == 2 {
              block(
                width: 100%,
                above: 0.35em,
                below: 0.35em,
                inset: (left: 0.5em, right: 0.5em),
                link(
                  heading-position,
                  {
                    set par(
                      first-line-indent: 0mm,
                      leading: 0.35em,
                      justify: false,
                    )
                    grid(
                      columns: (1.8em, 1fr, auto),
                      column-gutter: 0.4em,
                      align(left)[
                        #text(weight: "bold", size: 1.05em)[#chapter-number]
                      ],
                      align(left)[
                        #text(
                          font: font-cursive,
                          size: 1.25em,
                          weight: "bold",
                        )[#it.body()]
                        #if suffix != none and suffix != "" [
                          #h(0.4em)
                          #text(size: 0.9em, style: "italic")[#suffix]
                        ]
                        #if not has-sub-heading {
                          box(width: 1fr, repeat[#text(fill: gray)[.]])
                        }
                      ],
                      align(right + bottom)[#if not has-sub-heading {
                          it.page()
                        }],
                    )
                  },
                ),
              )
            } else {
              let sub-size = if it.level == 3 {
                1.12em
              } else if it.level == 4 {
                1.02em
              } else {
                0.95em
              }

              block(
                width: 100%,
                above: 0.2em,
                below: 0.1em,
                inset: (left: dynamic-left-inset + 0.5em, right: 0.5em),
                {
                  set text(weight: "bold", size: sub-size)
                  link(
                    heading-position,
                    if has-sub-heading {
                      it.element.body
                    } else {
                      it.element.body + box(width: 1fr, it.fill) + it.page()
                    },
                  )
                },
              )
            }


            // 2. Show optional chapter teasers
            if teaser-data != none {
              let teaser-label = teaser-data.at("label", default: none)
              let teaser-extract = teaser-data.at("extract", default: none)

              if teaser-label != none or teaser-extract != none {
                block(
                  width: 100%,
                  inset: (left: dynamic-left-inset, right: 1em),
                  above: 0.35em,
                  below: 0.2em,
                  breakable: false,
                  pad(left: teaser-left-inset)[
                    #set text(size: 1em, style: "italic")
                    #set par(
                      leading: 0.42em,
                      spacing: 0.35em,
                      first-line-indent: 0mm,
                    )
                    #if teaser-label != none {
                      initial(teaser-label)
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
