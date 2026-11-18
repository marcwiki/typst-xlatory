{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Typst.ImporterParser
-- Description : Parses translated Java .properties files back into structured AST nodes.
-- License     : GPL-3.0-or-later
--
-- Reads key-value entries exported from CAT tools (such as OmegaT), reconstructs
-- inline formatting (bold HTML tags, Typst links, and protected backtick code),
-- and maps them back to their original structural identifiers.
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

-- | Represents an entry read from the OmegaT file
data TranslatedProperty = TranslatedProperty
  { propKey :: T.Text,
    propValue :: [TypstInline]
  }
  deriving (Show, Eq)

-- | Main entry point for importing: Parses the entire .properties file
parsePropertiesFile :: Parser [TranslatedProperty]
parsePropertiesFile = do
  _ <- space
  many (try propertyLineParser <* space)

-- | Parses a single (or multi-line) property definition: key=value
propertyLineParser :: Parser TranslatedProperty
propertyLineParser = do
  -- Kommentare überspringen (aber keine #link-Zeilen)
  _ <- skipMany (try (char '#' >> notFollowedBy (string "link") >> takeWhileP Nothing (/= '\n') >> eol >> space))

  key <- takeWhile1P (Just "Property Key") (\c -> c `notElem` ['=', '\n', '\r'])
  _ <- char '='
  firstLine <- takeWhileP (Just "Property Value") (\c -> c /= '\n' && c /= '\r')
  _ <- optional eol

  -- Reads all subsequent lines (including blank lines in blocks such as #chapter-extract) up to the next key=
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
    -- Reliably detects whether a new OmegaT key begins on the current line
    nextPropertyKey = do
      _ <- choice [string "text_", string "func_", string "heading_"]
      _ <- takeWhile1P Nothing (\c -> c `notElem` ['=', '\n', '\r', ' '])
      _ <- char '='
      return ()

-- | Der spezifische Parser für den Inhalt eines OmegaT-Werts
parseOmegaTInline :: Parser [TypstInline]
parseOmegaTInline =
  many
    ( choice
        [ try omegatInlineCodeParser, -- 1. Top priority: Keep everything inside `...` unchanged
          try omegatLinkParser, -- 2. Real links: #link(<target>)[text]
          try omegatBoldParser, -- 3. Bold tags: <b>content</b>
          omegatTextParser -- 4. Normal text (including a safe fallback)
        ]
    )
  where
    -- 0. Completely protects inline code enclosed in backticks from link/tag parsing
    omegatInlineCodeParser = do
      _ <- char '`'
      code <- takeWhile1P (Just "Inline Code") (\c -> c /= '`' && c /= '\n')
      _ <- char '`'
      return $ PlainText ("`" <> code <> "`")

    -- 1. Recognizes links: #link(<target>)[text] with flexible spaces
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

    -- 2. Recognizes bold tags: <b>content</b>
    omegatBoldParser = try $ do
      _ <- string "<b>"
      content <-
        many
          ( notFollowedBy (string "</b>")
              >> choice [try omegatInlineCodeParser, try omegatLinkParser, try omegatBoldParser, omegatTextParser]
          )
      _ <- string "</b>"
      return $ InlineBold content

    -- 3. Reads normal text, stopping only before a closing </b> tag
    omegatTextParser = do
      notFollowedBy (string "</b>")
      c <- anySingle
      rest <- takeWhileP (Just "Plain Text") (\ch -> ch `notElem` ['<', '#', '`'])
      return $ PlainText (T.cons c rest)
