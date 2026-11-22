
// docs/lib/page-setup.typ
// Page layouts for the title page, foreword, and running column headings

#import "utils.typ": meta-str
#import "constants.typ": font-cursive
#import "headings.typ": cl-chapter-counter


/// Displays a full-page cover image on the first page with no margins.
#let layout-cover(image-path: "/images/cover.jpeg") = {
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
  )[]
}

/// Layout for cover pages or legal notice pages without header and footer.
#let layout-frontmatter(body) = {
  set page(
    paper: "a5",
    margin: (inside: 18mm, outside: 11mm, top: 12mm, bottom: 14mm),
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

/// Layout for the main title page with a wide white space on the right.
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

/// Generates dynamic column headings in the header (suppressed on chapter title pages).
#let make-header() = {
  let current-page = here().page()

  let headings-on-page = query(
    heading.where(level: 1).or(heading.where(level: 2)),
  ).filter(it => it.location().page() == current-page)

  if headings-on-page.len() > 0 {
    return none
  }

  let book-title = meta-str("book-title")
  let page-num = counter(page).at(here()).first()
  let is-even = calc.even(page-num)

  if is-even {
    let elements = query(heading.where(level: 1).before(here()))
    if elements.len() > 0 {
      text(
        9pt,
        font: font-cursive,
        fill: rgb("#003366"),
        elements.last().body,
      )
    }
    text(9pt, fill: rgb("#444444"), "  " + book-title)
  } else {
    let elements = query(heading.where(level: 2).before(here()))
    if elements.len() > 0 {
      let last-heading = elements.last()
      let label-text = if last-heading.has("label") {
        str(last-heading.label)
      } else { "" }
      let is-numbered = "cl-numbered" in label-text
      let num-string = if is-numbered {
        let stand = cl-chapter-counter.at(last-heading.location()).first()
        str(stand + 1) + ". "
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

/*
/// Displays the centered page number in the footer (suppressed on page 1).
#let make-footer() = {
  let page-num = counter(page).at(here()).first()
  if page-num == 1 { return none }
  align(center, text(10pt, str(page-num)))
}
*/

/// Standard layout for the main body of the book (A5, 360 pages, adhesive binding).
#let layout-mainmatter(body) = {
  set page(
    paper: "a5",
    margin: (inside: 20mm, outside: 14mm, top: 18mm, bottom: 18mm),
    header: context make-header(),
    footer: context {
      let page-num = counter(page).get().first()
      set text(size: 8.5pt, fill: rgb("#444444"))
      if calc.odd(page-num) {
        align(right)[#page-num]
      } else {
        align(left)[#page-num]
      }
    },
  )
  body
}
