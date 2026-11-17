{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Typst.Parser
Description : Megaparsec-based parser for translating Typst markup into a custom AST.
License     : GPL-3.0-or-later

Provides the Phase 1 parser that converts raw Typst source documents into a
structured 'TypstDoc' abstract syntax tree. It separates translatable content
(headings, paragraphs, inline formatting, and custom macro arguments) from
non-translatable layout directives and preserves explicit Typst labels for
lossless roundtrip reconstruction.
-}
module Typst.Parser
  ( parseTypst,
  )
where

import Data.Maybe (catMaybes, isJust)
import qualified Data.Text as T
import Data.Void
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L
import Typst.AST (BookNode (..), TypstArg (..), TypstDoc (..), TypstInline (..), extractLabel)

type Parser = Parsec Void T.Text

-- | Parses a raw Typst source text into a structured 'TypstDoc' AST.
--
-- Takes a source file name (used in Megaparsec error diagnostics) and the
-- UTF-8 document text. Returns either a detailed 'ParseErrorBundle' on syntax
-- failure or the parsed 'TypstDoc' on success.
parseTypst :: String -> T.Text -> Either (ParseErrorBundle T.Text Void) TypstDoc
parseTypst filename input = parse typstDocParser filename input

-- Das Dokument besteht aus Zeilen-basierten oder Block-basierten Einheiten
typstDocParser :: Parser TypstDoc
typstDocParser = do
  space
  nodes <- many nodeParser
  eof
  return $ TypstDoc (catMaybes nodes)

lexeme :: Parser a -> Parser a
lexeme = L.lexeme hspace

nodeParser :: Parser (Maybe BookNode)
nodeParser = do
  notFollowedBy eof
  choice
    [ try multilineImportParser, -- <-- NEU: Fängt #import (...) ganz oben ab!
      try outlineFilterParser,
      try ignoreCommandsParser,
      try headingParser,
      try functionParser,
      paragraphParser
    ]
    <* space

multilineImportParser :: Parser (Maybe BookNode)
multilineImportParser = do
  (rawText, _) <- match $ do
    _ <- hspace
    _ <- string "#import"
    -- Liest bis zur öffnenden Klammer '(' auf derselben Zeile
    _ <- takeWhileP Nothing (\c -> c /= '(' && c /= '\n')
    _ <- char '('
    -- Liest alles über beliebig viele Zeilen hinweg bis zur schliessenden Klammer ')'
    _ <- manyTill anySingle (char ')')
    _ <- optional (manyTill anySingle eol)
    return ()
  return $ Just (MalformedFunction (T.stripEnd rawText))

ignoreCommandsParser :: Parser (Maybe BookNode)
ignoreCommandsParser = do
  (rawText, _) <- match $ do
    _ <- hspace
    choice
      [ -- 1. Inline-Abstände: Stoppen exakt nach ')', damit Text dahinter (z. B. А 80) erhalten bleibt
        try (string "#v(" >> manyTill anySingle (char ')') >> return ()),
        try (string "#h(" >> manyTill anySingle (char ')') >> return ()),
        -- 2. Zeilen-Befehle & mehrzeilige Imports: Lesen bis zum Zeilenende
        do
          _ <-
            choice
              [ try $ do
                  _ <- string "#import"
                  _ <- takeWhileP Nothing (\c -> c /= '(' && c /= '\n')
                  _ <- char '('
                  _ <- manyTill anySingle (char ')')
                  return (),
                string "#import" >> return (),
                string "#include" >> return (),
                string "#show" >> return (),
                string "#set" >> return (),
                string "#cover-page" >> return (),
                string "#pagebreak" >> return (),
                string "#counter" >> return (),
                string "//" >> return ()
              ]
          _ <- optional (manyTill anySingle eol)
          return ()
      ]
  return $ Just (MalformedFunction (T.stripEnd rawText))

headingParser :: Parser (Maybe BookNode)
headingParser = do
  equals <- takeWhile1P (Just "Heading Level") (== '=')
  _ <- hspace
  contentLine <- manyTill anySingle eol
  let (cleanText, mLabel) = extractLabel (T.pack contentLine)
      cleanId = fmap cleanLabelForKey mLabel
  return $ Just (Heading (T.length equals) cleanText cleanId)

functionParser :: Parser (Maybe BookNode)
functionParser = do
  _ <- char '#'
  name <- takeWhile1P (Just "Funktionsname") (\c -> c `elem` ['a' .. 'z'] ++ ['0' .. '9'] ++ ['A' .. 'Z'] ++ ['-', '_'])
  args <- argumentsParser

  -- Überspringt optionalen Whitespace/Zeilenumbruch vor dem Label
  _ <- space

  -- Holt das Label direkt an Ort und Stelle ab
  mLabel <- optional $ do
    _ <- char '<'
    lbl <- takeWhile1P (Just "Function Label") (\c -> c /= '>')
    _ <- char '>'
    return (cleanLabelForKey lbl)

  return $ Just (CustomFunction name args mLabel)

paragraphParser :: Parser (Maybe BookNode)
paragraphParser = do
  notFollowedBy (choice [string "#import", string "#show", string "#set", string "#row", string "#outline", string "=", string "//", string "(", string " )"])

  -- 1. Wir lesen den gesamten Absatz inklusive Zeilenumbrüchen ein.
  --    Wir stoppen erst, wenn eine leere Zeile (\n\n) oder ein Blockbefehl droht.
  rawParagraphText <- manyTill anySingle (lookAhead endOfParagraph)
  let rawText = T.pack rawParagraphText

  -- 2. Nutzt dein originales extractLabel auf dem gesamten Absatz-String!
  let (cleanText, mLabel) = extractLabel rawText
      cleanId = fmap cleanLabelForKey mLabel

  -- 3. Inlines aus dem absolut label-freien Text herausparsen
  let inlineAST = case runParser (many inlineParser <* eof) "inside-paragraph" (T.strip cleanText) of
        Left _ -> [PlainText (T.strip cleanText)]
        Right ast -> ast

  if null inlineAST
    then return Nothing
    else return $ Just (Paragraph inlineAST cleanId)
  where
    -- Definiert, wann ein Absatz im Buch physisch zu Ende ist
    endOfParagraph =
      choice
        [ eof,
          try (eol >> eol >> return ()), -- Doppelte Leerzeile -> gibt () zurück
          try $ do
            _ <- eol
            -- Jedes Element in der choice-Liste wird durch 'void' oder '>> return ()' zu ()
            _ <-
              choice
                [ string "#import",
                  string "#show",
                  string "#set",
                  string "#row",
                  string "#outline",
                  string "=",
                  string "//"
                ]
            return ()
        ]

labelParser :: Parser T.Text
labelParser = do
  _ <- char '<'
  content <- takeWhile1P (Just "Label Inhalt") (/= '>')
  _ <- char '>'
  return $ "<" <> content <> ">"

argumentsParser :: Parser [TypstArg]
argumentsParser = do
  argBlocks <- many (choice [try parenArgsParser, bracketArgsParser])
  return (concat argBlocks)

parenArgsParser :: Parser [TypstArg]
parenArgsParser = between (char '(') (char ')') $ do
  _ <- space
  -- Parsed alle Argumente (valide & invalide) und filtert die Nothings heraus
  args <- anyArgParser `sepBy` (L.lexeme space (char ','))
  return (catMaybes args)

anyArgParser :: Parser (Maybe TypstArg)
anyArgParser =
  choice
    [ try (Just <$> namedStringArgParser), -- Erkennt Key: "String" -> behält "..."
      try (Just <$> namedRawArgParser), -- Erkennt Key: 0mm / true -> ohne "..."
      try positionalStringArgParser, -- NEU: "String mit (Klammern), Kommas und \"Quotes\""
      positionalArgParser -- Erkennt <label>, 1em, true usw. -> behält sie als PositionalArg
    ]
  where
    identParser = takeWhile1P (Just "Arg Key") (\c -> c `elem` (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ ['-', '_']))

    -- Liest einen String inklusive escaped Zeichen (\") und innerer Klammern sauber bis zum schliessenden "
    quotedStringLiteral = do
      _ <- char '"'
      chunks <- many (try escapedChar <|> (T.singleton <$> noneOf ['"']))
      _ <- char '"'
      return $ "\"" <> T.concat chunks <> "\""
      where
        escapedChar = do
          _ <- char '\\'
          c <- anySingle
          return $ T.pack ['\\', c]

    namedStringArgParser = do
      key <- identParser
      _ <- hspace >> char ':' >> hspace
      _ <- char '"'
      val <- takeWhileP (Just "String Content") (/= '"')
      _ <- char '"'
      return $ NamedArg key ("\"" <> val <> "\"")

    namedRawArgParser = do
      key <- identParser
      _ <- hspace >> char ':' >> hspace
      val <- takeWhile1P (Just "Raw Value") (`notElem` [',', ')'])
      return $ NamedArg key (T.strip val)

    positionalStringArgParser = do
      val <- quotedStringLiteral
      return $ Just (PositionalArg val)

    positionalArgParser = do
      val <- takeWhileP (Just "Positional Argument") (`notElem` [',', ')'])
      let stripped = T.strip val
      return $
        if T.null stripped
          then Nothing
          else Just (PositionalArg stripped)

namedStringArgParser :: Parser TypstArg
namedStringArgParser = do
  key <- takeWhile1P (Just "Argument Key") (\c -> c `elem` ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['_', '-'])
  _ <- space
  _ <- char ':'
  _ <- space
  val <- between (char '"') (char '"') (takeWhileP (Just "Quoted Value") (/= '"'))
  return $ NamedArg (T.strip key) (T.strip val)

skipArg :: Parser (Maybe TypstArg)
skipArg = do
  -- Konsumiert das ungewollte Argument bis zum Trennzeichen, ohne den AST zu belasten
  _ <- takeWhileP (Just "Ignored Argument") (\c -> c `notElem` [',', ')'])
  return Nothing

bracketArgsParser :: Parser [TypstArg]
bracketArgsParser = do
  _ <- char '['
  content <- balancedContent 1 T.empty
  return [ContentArg (T.strip content)]

-- Stelle sicher, dass 'eof' aus Text.Megaparsec importiert ist

balancedContent :: Int -> T.Text -> Parser T.Text
balancedContent 0 acc = return acc
balancedContent depth acc = do
  -- NOTBREMSE: Wir prüfen zuerst fliegend, ob die Datei zu Ende ist.
  -- Wenn ja, geben wir den gesammelten Puffer zurück und verhindern den Freeze!
  isEOF <- choice [eof >> return True, return False]
  if isEOF
    then return acc
    else
      choice
        [ do
            _ <- char ']'
            if depth == 1
              then return acc
              else balancedContent (depth - 1) (T.snoc acc ']'),
          do
            _ <- char '['
            balancedContent (depth + 1) (T.snoc acc '['),
          do
            x <- anySingle
            balancedContent depth (T.snoc acc x)
        ]

-- Weiter unten die veränderte Funktion einsetzen:
cleanInlineSpacing :: T.Text -> T.Text
cleanInlineSpacing input
  | "#h(" `T.isInfixOf` input =
      case T.splitOn "#h(" input of
        [] -> input
        (before : afterParts) ->
          let after = T.concat afterParts
              trueText = T.strip $ T.drop 1 (T.dropWhile (/= ')') after)
           in T.strip (before <> trueText)
  | otherwise = input

-- Erkennt flache und verpackte Outlines vollständig und reicht sie 1:1 durch
outlineFilterParser :: Parser (Maybe BookNode)
outlineFilterParser = do
  (rawText, _) <-
    match $
      choice
        [ try skipPadWithOutline,
          try skipFlatOutline
        ]
  return $ Just (MalformedFunction (T.stripEnd rawText))
  where
    -- Fall 1: #outline(...) flach in der Source
    skipFlatOutline = do
      _ <- optional (char '#')
      _ <- string "outline"
      _ <- space
      _ <- char '('
      _ <- balancedParens 1
      return ()

    -- Fall 2: #pad(...) [ #outline(...) ]
    skipPadWithOutline = do
      _ <- optional (char '#')
      _ <- string "pad"
      _ <- char '('
      _ <- balancedParens 1
      _ <- space
      _ <- char '['
      _ <- space
      _ <- skipFlatOutline
      _ <- space
      _ <- char ']'
      return ()

-- Hilfsparser: Zählt geöffnete und geschlossene runde Klammern
balancedParens :: Int -> Parser ()
balancedParens 0 = return ()
balancedParens depth = do
  choice
    [ char '(' >> balancedParens (depth + 1),
      char ')' >> balancedParens (depth - 1),
      anySingle >> balancedParens depth
    ]

-- | Parsed exakt ein #link(<target>)[text] und erlaubt optionale Leerzeichen überall
linkParser :: Parser TypstInline
linkParser = try $ do
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

-- | Parsed Text zwischen zwei Sternen *fett*
boldParser :: Parser TypstInline
boldParser = try $ do
  _ <- char '*'
  -- Parsed den Inhalt innerhalb der Sterne rekursiv via inlineParser
  -- Wir stoppen, sobald das schließende '*' kommt
  content <- many (notFollowedBy (char '*') >> inlineParser)
  _ <- char '*'
  return $ InlineBold content

-- =====================================================================
-- KORRIGIERTER & VEREINFACHTER INLINE PARSER (In src/Typst/Parser.hs)
-- =====================================================================
inlineParser :: Parser TypstInline
inlineParser =
  choice
    [ try inlineCodeParser, -- 1. Höchste Priorität: Alles in `...` als PlainText schützen
      try linkParser,       -- 2. Mit 'try', damit ein fehlgeschlagener Link den Absatz nicht abbricht
      try boldParser,       -- 3. Ebenfalls mit 'try' absichern
      try singleNewlineParser,
      plainTextParser
    ]
  where
    -- Liest `...` komplett als unveränderlichen PlainText ein
    inlineCodeParser = do
      _ <- char '`'
      code <- takeWhile1P (Just "Inline Code") (\c -> c /= '`' && c /= '\n')
      _ <- char '`'
      return $ PlainText ("`" <> code <> "`")

    plainTextParser = do
      -- Falls ein einzelnes '#' oder '*' kein gültiger Link/Bold war, wird es hier als normales Zeichen gelesen
      firstChar <- oneOf ['#', '*'] <|> satisfy (\c -> c `notElem` ['\n', '#', '*', '`'])
      rest <- takeWhileP (Just "Plain Text") (\c -> c `notElem` ['\n', '#', '*', '`'])
      return $ PlainText (T.cons firstChar rest)

    singleNewlineParser = do
      _ <- eol
      notFollowedBy eol
      notFollowedBy
        ( choice
            [ string "#import",
              string "#show",
              string "#set",
              string "#row",
              string "#outline",
              string "#pad",
              string "=",
              string "//"
            ]
        )
      return $ PlainText " "


cleanLabelForKey :: T.Text -> T.Text
cleanLabelForKey lbl = T.replace "<" "" (T.replace ">" "" lbl)
