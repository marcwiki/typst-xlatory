#let omegat-regex-box() = {
  raw(
    block: true,
    lang: "regex",
    "(?:`[^`]+`|</?[a-zA-Z0-9]+>|#link\\(<[^>]+>\\)\\s*\\[[^\\]]*\\]|#chapter-extract\\[|#initial\\[|<p_id_[^>]+>\\]|\\])",
  )
}
