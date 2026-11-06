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
    propValue :: [TypstInline] -- Der fix und fertig geparste Inline-AST
  }
  deriving (Show, Eq)

-- | Haupt-Einstiegspunkt für den Import: Parsed die gesamte .properties Datei
parsePropertiesFile :: Parser [TranslatedProperty]
parsePropertiesFile = many (try propertyLineParser <* space)

-- | Parsed eine einzelne Zeile: key=value
-- | Parsed eine einzelne Zeile: key=value
propertyLineParser :: Parser TranslatedProperty
propertyLineParser = do
  -- Kommentare und führende Leerzeilen sauber überspringen
  _ <- space
  _ <- skipMany (char '#' >> takeWhileP Nothing (/= '\n') >> eol >> space)

  key <- takeWhile1P (Just "Property Key") (\c -> c /= '=')
  _ <- char '='
  rawValue <- takeWhileP (Just "Property Value") (\c -> c /= '\n')
  -- FIX: Wir konsumieren das Zeilenende (eol) jetzt zwingend physisch,
  -- damit der Parser sauber zur nächsten Zeile vorrückt!
  _ <- optional eol

  let inlineAST = case parse parseOmegaTInline "" rawValue of
        Left _ -> [PlainText rawValue]
        Right ast -> ast

  return $ TranslatedProperty (T.strip key) inlineAST

-- | Der spezifische Parser für den Inhalt eines OmegaT-Werts
parseOmegaTInline :: Parser [TypstInline]
parseOmegaTInline = many (choice [try omegatLinkParser, try omegatBoldParser, omegatTextParser])
  where
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

    omegatBoldParser = try $ do
      _ <- string "<b>"
      -- FIX: try omegatBoldParser in die innere Auswahlliste aufgenommen für volle Rekursion!
      content <- many (notFollowedBy (string "</b>") >> choice [try omegatLinkParser, try omegatBoldParser, omegatTextParser])
      _ <- string "</b>"
      return $ InlineBold content

    omegatTextParser = do
      txt <- takeWhile1P (Just "Plain Text") (\c -> c `notElem` ['<', '#'])
      return $ PlainText txt
