{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Typst.AST
-- Description : Core Abstract Syntax Tree (AST) data types and label utilities.
-- License     : GPL-3.0-or-later
--
-- Defines the intermediate representation (t'TypstDoc') used across the entire
-- extraction and reconstruction pipeline, along with helper functions for
-- extracting and normalizing explicit Typst labels.
module Typst.AST
  ( TypstArg (..),
    TypstInline (..),
    BookNode (..),
    TypstDoc (..),
    extractLabel,
  )
where

import qualified Data.Text as T
import GHC.Generics

-- | Represents an argument passed to a custom Typst macro or function call.
data TypstArg
  = -- | A named parameter such as @title: "Summary"@.
    NamedArg T.Text T.Text
  | -- | An unnamed positional parameter such as @1em@ or @true@.
    PositionalArg T.Text
  | -- | A translatable content block enclosed in brackets @[...]@.
    ContentArg T.Text
  deriving (Show, Eq, Generic)

-- | Represents inline formatting and text elements inside paragraphs or headings.
data TypstInline
  = -- | Unformatted text or protected inline code in backticks.
    PlainText T.Text
  | -- | Internal or external link @#link(<target>)[text]@.
    InlineLink T.Text T.Text
  | -- | Bold text wrapped in asterisks @*...*@.
    InlineBold [TypstInline]
  deriving (Show, Eq, Generic)

-- | Represents a top-level structural node within a parsed Typst document.
data BookNode
  = -- | Translatable body paragraph with inline elements and optional label ID.
    Paragraph [TypstInline] (Maybe T.Text)
  | -- | Section heading with level, clean text, and optional label ID.
    Heading Int T.Text (Maybe T.Text)
  | -- | Custom Typst macro call with function name, arguments, and optional label ID.
    CustomFunction T.Text [TypstArg] (Maybe T.Text)
  | -- | Pass-through raw Typst directive (e.g., @#import@, @#set@, @#show@).
    MalformedFunction T.Text
  deriving (Show, Eq, Generic)

-- | Root container representing a parsed Typst source file.
data TypstDoc = TypstDoc [BookNode]
  deriving (Show, Eq)

-- | Extracts a trailing Typst label (e.g., @<p:intro-1>@) from the end of a
-- text block while preserving angle brackets enclosed in inline backticks.
extractLabel :: T.Text -> (T.Text, Maybe T.Text)
extractLabel s =
  let trimmed = T.strip s
      (beforeGreater, afterGreater) = T.breakOnEnd ">" trimmed
   in -- Ein echtes Typst-Label steht IMMER ganz am Ende (nach '>' darf nichts mehr folgen!)
      if T.null beforeGreater || not (T.null (T.strip afterGreater))
        then (s, Nothing)
        else
          let targetPart = T.dropEnd 1 beforeGreater
              (leftover, labelContent) = T.breakOnEnd "<" targetPart
           in if T.null leftover && not ("<" `T.isPrefixOf` targetPart)
                then (s, Nothing)
                else
                  let prefix = T.stripEnd (T.dropEnd 1 leftover)
                      backtickCount = T.count "`" prefix
                      validLabelChars =
                        not (T.null labelContent)
                          && T.all (\c -> c `notElem` [' ', '\n', '\t', '<', '>', '`']) labelContent
                   in if even backtickCount && validLabelChars
                        then (prefix, Just ("<" <> labelContent <> ">"))
                        else (s, Nothing)
