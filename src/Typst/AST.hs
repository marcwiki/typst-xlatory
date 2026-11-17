{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Typst.AST where

import qualified Data.Text as T
import GHC.Generics

data TypstArg
  = NamedArg T.Text T.Text
  | PositionalArg T.Text
  | ContentArg T.Text
  deriving (Show, Eq, Generic)

data TypstInline
  = PlainText T.Text
  | InlineLink T.Text T.Text
  | InlineBold [TypstInline] -- NEU: Hält fettgedruckte Inline-Elemente
  deriving (Show, Eq, Generic)

data BookNode
  = Paragraph [TypstInline] (Maybe T.Text) -- Jetzt mit Inlines statt reinem Text
  | Heading Int T.Text (Maybe T.Text)
  | CustomFunction T.Text [TypstArg] (Maybe T.Text)
  | MalformedFunction T.Text
  deriving (Show, Eq, Generic)

data TypstDoc = TypstDoc [BookNode]
  deriving (Show, Eq)

-- | Geteilte Utility-Funktion für Parser und Printer
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

