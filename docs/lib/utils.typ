#import "constants.typ": font-cursive
/// Recursively converts Typst content into a string.
/// - sep: Trennzeichen für Zeilen- und Absatzumbrüche (Standard: "\n").
#let to-string(c, sep: "\n") = {
  if c == none {
    ""
  } else if type(c) == str {
    c
  } else if type(c) in (int, float, bool, decimal) {
    str(c)
  } else if type(c) == content {
    if c.has("text") {
      c.text
    } else if c.has("children") {
      c.children.map(child => to-string(child, sep: sep)).join("")
    } else if c.has("body") {
      to-string(c.body, sep: sep)
    } else if c == [ ] {
      " "
    } else if c == linebreak() or c == parbreak() {
      sep
    } else {
      ""
    }
  } else {
    repr(c)
  }
}

/// Highlight the first letter of a word as a calligraphic initial.
/// Uses Unicode clusters to ensure that Cyrillic characters
/// are also separated correctly.
#let initial(wort) = {
  let wort-str = to-string(wort)
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

// Central State is guaranteed to store only strings
// Safe comparisons. Since the Dictionary always contains actual strings,
// queries like `if meta-str(“status”) == ‘final’`
// or `upper(meta-str(“title”))` work within a context block
// without any type errors.
#let meta-state = state("book-meta", (:))

// Setter: Converts the input to a string immediately upon saving.
// One-time conversion. _to-str runs only once when meta-set is called,
// not every time data is read.
#let meta-set(key: "", body) = {
  let clean-val = to-string(body)
  meta-state.update(dict => {
    dict.insert(key, clean-val)
    dict
  })
}

// For Logic & Functions,
// returns the current value at the specified location in the document.
// Must be called within a context block!
#let meta-str(key, default: "") = {
  meta-state.get().at(key, default: default)
}

// Used by Logig and functions
// to retrieve a value that is defined later in the document.
// Must be called within a context block.
#let meta-str-final(key, default: "") = {
  meta-state.final().at(key, default: default)
}

// Retrieve the current status at this point in the document
//for direct output in the running text with its own context.
#let meta-get-current(key, default: none) = context {
  meta-str(key, default: default)
}

// Retrieve the final value (e.g., for the title page or header)
// using a custom context.
#let meta-get-final(key, default: none) = context {
  meta-str-final(key, default: default)
}

