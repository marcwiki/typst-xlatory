{-# LANGUAGE OverloadedStrings #-}

module Typst.ImporterParser
  ( TranslatedProperty (..),
    parsePropertiesFile,
    parseOmegaTInline,
  )
where

import qualified Data.Text as T
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char
import Typst.AST (TypstInline (..))

type Parser = Parsec Void T.Text

-- | Repräsentiert einen gelesenen Eintrag aus der OmegaT-Datei
data TranslatedProperty = TranslatedProperty
  { propKey :: T.Text,
    propValue :: [TypstInline]
  }
  deriving (Show, Eq)

-- | Haupt-Einstiegspunkt für den Import: Parsed die gesamte .properties Datei
parsePropertiesFile :: Parser [TranslatedProperty]
parsePropertiesFile = do
  _ <- space
  many (try propertyLineParser <* space)

-- | Parsed eine einzelne (auch mehrzeilige) Property-Definition: key=value
propertyLineParser :: Parser TranslatedProperty
propertyLineParser = do
  -- Kommentare überspringen (aber keine #link-Zeilen)
  _ <- skipMany (try (char '#' >> notFollowedBy (string "link") >> takeWhileP Nothing (/= '\n') >> eol >> space))

  key <- takeWhile1P (Just "Property Key") (\c -> c `notElem` ['=', '\n', '\r'])
  _ <- char '='
  firstLine <- takeWhileP (Just "Property Value") (\c -> c /= '\n' && c /= '\r')
  _ <- optional eol

  -- Liest alle Folgezeilen (inkl. Leerzeilen in Blöcken wie #chapter-extract) bis zum nächsten key=
  contLines <- many $ try $ do
    notFollowedBy eof
    notFollowedBy (try (char '#' >> notFollowedBy (string "link")))
    notFollowedBy nextPropertyKey
    line <- takeWhileP (Just "Continuation Line") (\c -> c /= '\n' && c /= '\r')
    _ <- optional eol
    return (T.strip (T.dropWhileEnd (== '\\') (T.stripEnd line)))

  let cleanFirst = T.strip (T.dropWhileEnd (== '\\') (T.stripEnd firstLine))
      rawValue = T.intercalate "\n" (filter (not . T.null) (cleanFirst : contLines))

  let inlineAST = case parse parseOmegaTInline "" rawValue of
        Left _ -> [PlainText rawValue]
        Right ast -> ast

  return $ TranslatedProperty (T.strip key) inlineAST
  where
    -- Erkennt sicher, ob auf der aktuellen Zeile ein neuer OmegaT-Key startet
    nextPropertyKey = do
      _ <- choice [string "text_", string "func_", string "heading_"]
      _ <- takeWhile1P Nothing (\c -> c `notElem` ['=', '\n', '\r', ' '])
      _ <- char '='
      return ()

-- | Der spezifische Parser für den Inhalt eines OmegaT-Werts
-- | Der spezifische Parser für den Inhalt eines OmegaT-Werts
parseOmegaTInline :: Parser [TypstInline]
parseOmegaTInline =
  many
    ( choice
        [ try omegatInlineCodeParser, -- 1. Höchste Priorität: Alles in `...` unverändert übernehmen
          try omegatLinkParser,       -- 2. Echte Links: #link(<target>)[text]
          try omegatBoldParser,       -- 3. Bold-Tags: <b>inhalt</b>
          omegatTextParser            -- 4. Normaler Text (inkl. sicherem Fallback)
        ]
    )
  where
    -- 0. Schützt Inline-Code in Backticks komplett vor Link-/Tag-Parsing
    omegatInlineCodeParser = do
      _ <- char '`'
      code <- takeWhile1P (Just "Inline Code") (\c -> c /= '`' && c /= '\n')
      _ <- char '`'
      return $ PlainText ("`" <> code <> "`")

    -- 1. Erkennt Links: #link(<target>)[text] mit flexiblen Spaces
    omegatLinkParser = try $ do
      _ <- string "#link"
      _ <- hspace
      _ <- char '('
      _ <- hspace
      target <- takeWhile1P (Just "Link Target") (\c -> c /= ')')
      _ <- char ')'
      _ <- hspace
      _ <- char '['
      _ <- hspace
      linkText <- takeWhile1P (Just "Link Text") (\c -> c /= ']')
      _ <- char ']'
      return $ InlineLink (T.strip target) (T.strip linkText)

    -- 2. Erkennt Bold-Tags: <b>inhalt</b>
    omegatBoldParser = try $ do
      _ <- string "<b>"
      content <-
        many
          ( notFollowedBy (string "</b>")
              >> choice [try omegatInlineCodeParser, try omegatLinkParser, try omegatBoldParser, omegatTextParser]
          )
      _ <- string "</b>"
      return $ InlineBold content

    -- 3. Liest normalen Text, stoppt nur vor schliessendem </b>
    omegatTextParser = do
      notFollowedBy (string "</b>")
      c <- anySingle
      rest <- takeWhileP (Just "Plain Text") (\ch -> ch `notElem` ['<', '#', '`'])
      return $ PlainText (T.cons c rest)
