{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Typst.Printer
Description : Exports a parsed 'TypstDoc' AST into Java .properties files for CAT tools.
License     : GPL-3.0-or-later

Serializes headings, paragraphs, and translatable macro arguments into
key-value pairs compatible with OmegaT and other CAT tools, while filtering
out non-translatable layout macros configured via @hide_functions@.
-}
module Typst.Printer
  ( generateOmegaT,
    extractFunctionsReport,
  )
where

import Control.Monad.State
import Data.Maybe (catMaybes, listToMaybe)
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T
import Typst.AST (BookNode (..), TypstArg (..), TypstDoc (..), TypstInline (..), extractLabel)

type PrintEnv = (Int, S.Set T.Text)

type PrintState = State PrintEnv

-- | Serializes a 'TypstDoc' AST into Java @.properties@ format for CAT tool translation.
--
-- Takes a set of named arguments to ignore (@ignoreArgsSet@) and the parsed
-- 'TypstDoc', returning the UTF-8 @.properties@ content with deterministic,
-- label-based keys.
generateOmegaT :: S.Set T.Text -> TypstDoc -> T.Text
generateOmegaT ignoreArgsSet (TypstDoc nodes) =
  let linesOfFile = evalState (mapM (nodeToProperty ignoreArgsSet) nodes) (1, S.empty)
   in T.unlines $ filter (not . T.null) linesOfFile

-- | Collects all unique custom Typst macro names encountered in a 'TypstDoc'.
--
-- Runs the property traversal over all AST nodes and returns a 'S.Set' of
-- discovered macro names, used to generate diagnostic export reports.
extractFunctionsReport :: TypstDoc -> S.Set T.Text
extractFunctionsReport (TypstDoc nodes) =
  let (_, finalEnv) = runState (mapM (nodeToProperty S.empty) nodes) (1, S.empty)
   in snd finalEnv

nodeToProperty :: S.Set T.Text -> BookNode -> State (Int, S.Set T.Text) T.Text
nodeToProperty ignoreArgsSet node = case node of
  Paragraph inlines mLabel -> do
    idBase <- case mLabel of
      Just lbl -> return $ cleanLabelForKey lbl
      Nothing -> do
        currentId <- getNextId
        return $ "p_id_" <> T.pack (show currentId)

    -- Fügt die Inlines zu einem sauberen Text zusammen
    let fullText = normalizeKeepParagraphs (T.unwords (map printInline inlines))
    return $ T.concat ["text_", idBase, "=", fullText]

    return $ T.concat ["text_", idBase, "=", T.strip fullText]
  Heading lvl txt mLabel -> do
    idBase <- case mLabel of
      Just lbl -> return $ cleanLabelForKey lbl
      Nothing -> do
        currentId <- getNextId
        return $ "h_id_" <> T.pack (show currentId)
    return $ "heading_lvl_" <> T.pack (show lvl) <> "_" <> idBase <> "=" <> txt
  CustomFunction name args mLabel -> do
    rememberFunction name

    let (mTextArg, embeddedTag) = findContentAndTag args
        finalLabel = case mLabel of
          Just l -> Just l
          Nothing -> embeddedTag

    idBase <- case finalLabel of
      Just lbl -> return $ cleanLabelForKey lbl
      Nothing -> do
        currentId <- getNextId
        return $ T.pack (show currentId)

    -- 1. Alle übersetzbaren Named Arguments dynamisch einsammeln
    let translatableNamedArgs =
          [ let cleanVal = T.strip (T.drop 1 (T.dropEnd 1 (T.strip v)))
             in T.concat ["func_", name, "_", idBase, "_arg_", k, "=", cleanVal]
          | NamedArg k v <- args
          , isTranslatableNamedArg ignoreArgsSet (k, v) -- <-- ignoreArgsSet hier übergeben
          ]

    -- 2. Hauptinhalt ([...]) wie bisher
    let propArg = case mTextArg of
          Just txt -> [T.concat ["func_", name, "_", idBase, "_arg=", normalizeKeepParagraphs txt]]
          Nothing -> []

    -- Alle existierenden Zeilen sauber getrennt zurückgeben
    return $ T.intercalate "\n" (translatableNamedArgs ++ propArg)
  MalformedFunction _ ->
    return T.empty

printCleanArg :: T.Text -> T.Text -> TypstArg -> PrintState T.Text
printCleanArg funcName idBase arg = case arg of
  ContentArg txt -> do
    let (cleanText, _) = extractLabel txt
    if T.null (T.strip cleanText)
      then return ""
      else return $ "func_" <> funcName <> "_" <> idBase <> "_arg=" <> cleanText
  NamedArg key val -> do
    let technicalKeys = ["gutter", "label", "width", "height", "layer", "radius"]
    if key `elem` technicalKeys
      then return ""
      else do
        let (cleanVal, _) = extractLabel val
        return $ "func_" <> funcName <> "_" <> idBase <> "_" <> key <> "=" <> cleanVal

findEmbeddedLabel :: [TypstArg] -> Maybe T.Text
findEmbeddedLabel [] = Nothing
findEmbeddedLabel (ContentArg txt : xs) =
  if "<" `T.isInfixOf` txt then snd (extractLabel txt) else findEmbeddedLabel xs
findEmbeddedLabel (NamedArg _ val : xs) =
  if "<" `T.isInfixOf` val then snd (extractLabel val) else findEmbeddedLabel xs

cleanLabelForKey :: T.Text -> T.Text
cleanLabelForKey lbl =
  T.replace ":" "_" $ T.replace "<" "" (T.replace ">" "" lbl)

getNextId :: PrintState Int
getNextId = do
  (currentId, funcs) <- get
  put (currentId + 1, funcs)
  return currentId

rememberFunction :: T.Text -> PrintState ()
rememberFunction name = do
  (currentId, funcs) <- get
  put (currentId, S.insert ("#" <> name) funcs)

-- Sucht nach dem Wert eines bestimmten benannten Arguments (z.B. "label")
findNamedArgValue :: T.Text -> [TypstArg] -> Maybe T.Text
findNamedArgValue targetKey args =
  let matches = [T.dropAround (== '"') val | NamedArg key val <- args, key == targetKey]
   in listToMaybe matches

-- Verarbeitet die ContentArgs: Trennt den reinen Text dynamisch vom Tag via extractLabel
findContentAndTag :: [TypstArg] -> (Maybe T.Text, Maybe T.Text)
findContentAndTag args =
  let contents = [txt | ContentArg txt <- args]
   in if null contents
        then (Nothing, Nothing)
        else
          let fullText = T.intercalate " " contents
              (cleanText, mTag) = extractLabel fullText
           in case mTag of
                Just tagVal ->
                  -- KORRIGIERTER SAFETY-CHECK:
                  -- Ein echtes Funktions-Label steht IMMER am absoluten Ende des Textes.
                  -- Wenn der Text mit ']' oder einem anderen Zeichen endet, das nicht zum Label gehört,
                  -- handelt es sich um ein eingebettetes Link-Ziel. Das lassen wir komplett unangetastet!
                  if "]" `T.isSuffixOf` T.strip fullText
                    then (Just fullText, Nothing) -- Link bleibt zu 100% intakt!
                    else (Just cleanText, Just tagVal) -- Echtes ID-Label extrahieren
                Nothing -> (Just fullText, Nothing)

-- In src/Typst/Printer.hs anpassen:
printInline :: TypstInline -> T.Text
printInline (PlainText txt) = txt
printInline (InlineLink target label) = T.concat ["#link(", target, ")[", label, "]"]
-- FIX: Der fehlende Zweig für den Fettdruck hinzugefügt!
printInline (InlineBold inlines) =
  -- Übersetzt den fettgedruckten Inhalt rekursiv und verpackt ihn in HTML-Tags für OmegaT
  T.concat ["<b>", T.unwords (map printInline inlines), "</b>"]

-- Glättet einzelne Zeilenumbrüche innerhalb eines Absatzes zu Leerzeichen,
-- bewahrt aber doppelte Zeilenumbrüche (\n\n) als echte Absatztrennung.
normalizeKeepParagraphs :: T.Text -> T.Text
normalizeKeepParagraphs txt =
  let -- Vereinheitlicht Windows-Zeilenumbrüche (\r\n) zu \n
      unixTxt = T.replace "\r\n" "\n" txt
      -- Trennt an doppelten Zeilenumbrüchen (auch wenn Leerzeichen dazwischen sind)
      blocks = T.splitOn "\n\n" unixTxt
      -- Glättet jeden Block für sich zu einer sauberen Fließtext-Zeile
      cleanBlocks = map (T.unwords . T.words) blocks
   in T.intercalate "\n\n" (filter (not . T.null) cleanBlocks)

-- Standard-Fallback, falls in der YAML-Datei kein ignore_named_args definiert ist
defaultIgnoredNamedArgs :: S.Set T.Text
defaultIgnoredNamedArgs =
  S.fromList ["font", "style", "weight", "lang", "region", "fill", "stroke", "align"]

-- Prüft anhand des übergebenen Sets, ob ein NamedArg übersetzbar ist
isTranslatableNamedArg :: S.Set T.Text -> (T.Text, T.Text) -> Bool
isTranslatableNamedArg ignoredKeys (k, v) =
  let stripped = T.strip v
      isQuoted = "\"" `T.isPrefixOf` stripped && "\"" `T.isSuffixOf` stripped && T.length stripped >= 2
      inner = T.drop 1 (T.dropEnd 1 stripped)
      isHexColor = "#" `T.isPrefixOf` inner
   in (k `S.notMember` ignoredKeys) && isQuoted && not isHexColor && not (T.null (T.strip inner))
