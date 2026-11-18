{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Typst.Parser
-- Description : Megaparsec-based parser for translating Typst markup into a custom AST.
-- License     : GPL-3.0-or-later
--
-- Provides the Phase 1 parser that converts raw Typst source documents into a
-- structured t'TypstDoc' abstract syntax tree. It separates translatable content
-- (headings, paragraphs, inline formatting, and custom macro arguments) from
-- non-translatable layout directives and preserves explicit Typst labels for
-- lossless roundtrip reconstruction.
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

-- | Parses a raw Typst source text into a structured t'TypstDoc' AST.
--
-- Takes a source file name (used in Megaparsec error diagnostics) and the
-- UTF-8 document text. Returns either a detailed '@ParseErrorBundle@' on syntax
-- failure or the parsed t'TypstDoc' on success.
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
    -- Reads up to the opening parenthesis ‘(’ on the same line
    _ <- takeWhileP Nothing (\c -> c /= '(' && c /= '\n')
    _ <- char '('
    -- Reads everything across any number of lines up to the closing parenthesis ‘)’
    _ <- manyTill anySingle (char ')')
    _ <- optional (manyTill anySingle eol)
    return ()
  return $ Just (MalformedFunction (T.stripEnd rawText))

ignoreCommandsParser :: Parser (Maybe BookNode)
ignoreCommandsParser = do
  (rawText, _) <- match $ do
    _ <- hspace
    choice
      [ -- 1. Inline spacing: Stop exactly after ‘)’, so that the text that follows (e.g., А 80) is preserved
        try (string "#v(" >> manyTill anySingle (char ')') >> return ()),
        try (string "#h(" >> manyTill anySingle (char ')') >> return ()),
        -- 2. Line Commands & Multi-Line Imports: Reading Until the End of the Line
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

  -- Skips optional whitespace/line break before the label
  _ <- space

  -- Pick up the label right there on the spot
  mLabel <- optional $ do
    _ <- char '<'
    lbl <- takeWhile1P (Just "Function Label") (\c -> c /= '>')
    _ <- char '>'
    return (cleanLabelForKey lbl)

  return $ Just (CustomFunction name args mLabel)

paragraphParser :: Parser (Maybe BookNode)
paragraphParser = do
  notFollowedBy (choice [string "#import", string "#show", string "#set", string "#row", string "#outline", string "=", string "//", string "(", string " )"])

  -- 1. We read the entire paragraph, including line breaks.
  --    We don't stop until we encounter an empty line (\n\n) or a block command.
  rawParagraphText <- manyTill anySingle (lookAhead endOfParagraph)
  let rawText = T.pack rawParagraphText

  -- 2. Use the original `extractLabel` throughout the entire paragraph string!
  let (cleanText, mLabel) = extractLabel rawText
      cleanId = fmap cleanLabelForKey mLabel

  -- 3. Parse inline elements from text that is completely free of labels
  let inlineAST = case runParser (many inlineParser <* eof) "inside-paragraph" (T.strip cleanText) of
        Left _ -> [PlainText (T.strip cleanText)]
        Right ast -> ast

  if null inlineAST
    then return Nothing
    else return $ Just (Paragraph inlineAST cleanId)
  where
    -- Defines when a paragraph in a book physically ends
    endOfParagraph =
      choice
        [ eof,
          try (eol >> eol >> return ()), -- Double blank line -> returns ()
          try $ do
            _ <- eol
            -- Each element in the choice list is converted to () using ‘void’ or ‘>> return ()’
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
  -- Parses all arguments (valid and invalid) and filters out the “Nothings”
  args <- anyArgParser `sepBy` (L.lexeme space (char ','))
  return (catMaybes args)

anyArgParser :: Parser (Maybe TypstArg)
anyArgParser =
  choice
    [ try (Just <$> namedStringArgParser), -- If the key is “String,” it retains “...”
      try (Just <$> namedRawArgParser), -- Detects key: 0mm / true -> without “...”
      try positionalStringArgParser, -- “String with (parentheses), commas, and \”quotes\“”
      positionalArgParser -- Recognizes <label>, 1em, true, etc. -> retains them as PositionalArg
    ]
  where
    identParser = takeWhile1P (Just "Arg Key") (\c -> c `elem` (['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++ ['-', '_']))

    -- Reads a string—including escaped characters (\“) and parentheses—correctly up to the closing ”
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
  -- Processes the unwanted argument up to the separator without affecting the AST
  _ <- takeWhileP (Just "Ignored Argument") (\c -> c `notElem` [',', ')'])
  return Nothing

bracketArgsParser :: Parser [TypstArg]
bracketArgsParser = do
  _ <- char '['
  content <- balancedContent 1 T.empty
  return [ContentArg (T.strip content)]

-- Make sure that ‘eof’ is imported from Text.Megaparsec

balancedContent :: Int -> T.Text -> Parser T.Text
balancedContent 0 acc = return acc
balancedContent depth acc = do
  -- EMERGENCY STOP: We first check on the fly to see if the file has ended.
  -- If so, we'll return the accumulated buffer and prevent the freeze!
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

-- Fully recognizes flat and packaged outlines and passes them through 1:1
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
    -- Case 1: #outline(...) embedded directly in the source
    skipFlatOutline = do
      _ <- optional (char '#')
      _ <- string "outline"
      _ <- space
      _ <- char '('
      _ <- balancedParens 1
      return ()

    -- Case 2: #pad(...) [ #outline(...) ]
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

-- Auxiliary parser: Counts open and closed parentheses
balancedParens :: Int -> Parser ()
balancedParens 0 = return ()
balancedParens depth = do
  choice
    [ char '(' >> balancedParens (depth + 1),
      char ')' >> balancedParens (depth - 1),
      anySingle >> balancedParens depth
    ]

-- | Parses exactly one #link(<target>)[text] and allows optional spaces anywhere
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

-- | Parses text between two asterisks *bold*
boldParser :: Parser TypstInline
boldParser = try $ do
  _ <- char '*'
  -- Parses the content inside the asterisks recursively using inlineParser
  -- We stop as soon as the closing ‘*’ appears
  content <- many (notFollowedBy (char '*') >> inlineParser)
  _ <- char '*'
  return $ InlineBold content

-- =====================================================================
-- INLINE PARSER (In src/Typst/Parser.hs)
-- =====================================================================
inlineParser :: Parser TypstInline
inlineParser =
  choice
    [ try inlineCodeParser, -- 1. Top Priority: Protect everything inside `...` as plain text
      try linkParser, -- 2. Use ‘try’ so that a broken link doesn't break up the paragraph
      try boldParser, -- 3. Also use ‘try’ to handle exceptions
      try singleNewlineParser,
      plainTextParser
    ]
  where
    -- Liest `...` entirely as unalterable plain text
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
