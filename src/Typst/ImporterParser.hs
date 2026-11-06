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
parsePropertiesFile = do
  _ <- space
  props <- many (try propertyLineParser <* space)
  return props

-- | Parsed einen Eintrag (ein- oder mehrzeilig), bis der nächste key= oder eof kommt
propertyLineParser :: Parser TranslatedProperty
propertyLineParser = do
  -- Kommentare überspringen
  _ <- skipMany (char '#' >> takeWhileP Nothing (/= '\n') >> eol >> space)

  -- Key einlesen (darf kein Zeilenumbruch oder '=' enthalten)
  key <- takeWhile1P (Just "Property Key") (\c -> c `notElem` ['=', '\n', '\r'])
  _ <- char '='
  
  -- Erste Zeile einlesen
  firstLine <- takeWhileP (Just "Property Value") (\c -> c /= '\n' && c /= '\r')
  _ <- optional eol

  -- Liest ALLE Folgezeilen ein, solange sie KEIN neuer key= sind und nicht leer sind
  contLines <- many $ try $ do
    notFollowedBy eof
    notFollowedBy eol               -- Stoppt bei einer Leerzeile
    notFollowedBy (char '#')        -- Stoppt bei Kommentaren
    notFollowedBy nextPropertyKey   -- Stoppt, sobald eine neue Zeile mit 'irgendwas=' beginnt!
    line <- takeWhile1P (Just "Continuation Line") (\c -> c /= '\n' && c /= '\r')
    _ <- optional eol
    -- Entfernt eventuelle Java-Properties Backslashes '\' am Zeilenende und Leerzeichen
    return (T.strip (T.dropWhileEnd (== '\\') (T.stripEnd line)))

  let cleanFirst = T.strip (T.dropWhileEnd (== '\\') (T.stripEnd firstLine))
      rawValue   = T.intercalate " " (filter (not . T.null) (cleanFirst : contLines))

  let inlineAST = case parse parseOmegaTInline "" rawValue of
        Left _    -> [PlainText rawValue]
        Right ast -> ast

  return $ TranslatedProperty (T.strip key) inlineAST
  where
    -- Erkennt, ob auf der aktuellen Zeile ein neuer Property-Key (z. B. "func_...=") startet
    nextPropertyKey = do
      _ <- takeWhile1P Nothing (\c -> c `notElem` ['=', '\n', '\r', ' '])
      _ <- char '='
      return ()

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
