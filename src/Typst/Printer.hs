{-# LANGUAGE OverloadedStrings #-}

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

generateOmegaT :: TypstDoc -> T.Text
generateOmegaT (TypstDoc nodes) =
  let linesOfFile = evalState (mapM nodeToProperty nodes) (1, S.empty)
   in T.unlines $ filter (not . T.null) linesOfFile

extractFunctionsReport :: TypstDoc -> S.Set T.Text
extractFunctionsReport (TypstDoc nodes) =
  let (_, finalEnv) = runState (mapM nodeToProperty nodes) (1, S.empty)
   in snd finalEnv

nodeToProperty :: BookNode -> PrintState T.Text
nodeToProperty node = case node of
  Paragraph inlines mLabel -> do
    idBase <- case mLabel of
      Just lbl -> return $ cleanLabelForKey lbl
      Nothing -> do
        currentId <- getNextId
        return $ "p_id_" <> T.pack (show currentId)

    -- Fügt die Inlines zu einem sauberen Text zusammen
    let fullText = T.unwords (map printInline inlines)

    return $ T.concat ["text_", idBase, "=", T.strip fullText]
  Heading lvl txt _ -> do
    currentId <- getNextId
    return $ "heading_lvl_" <> T.pack (show lvl) <> "_" <> T.pack (show currentId) <> "=" <> txt
  CustomFunction name args mLabel -> do
    rememberFunction name

    -- 1. Extrahiere den reinen Text und ein eventuell im Text eingebettetes Tag
    let (mTextArg, embeddedTag) = findContentAndTag args
        mLabelArg = findNamedArgValue "label" args
        -- FIX: Wir fischen hier das benannte title-Argument heraus!
        mTitleArg = findNamedArgValue "title" args

        -- Priorität für die ID: 1. Explizites mLabel, 2. Im Text gefundenes Tag
        finalLabel = case mLabel of
          Just l -> Just l
          Nothing -> embeddedTag

    idBase <- case finalLabel of
      Just lbl -> return $ cleanLabelForKey lbl
      Nothing -> do
        currentId <- getNextId
        return $ T.pack (show currentId)

    -- 2. Generiere die drei OmegaT-Zeilen (inklusive title)
    let propArg = case mTextArg of
          Just txt -> T.concat ["func_", name, "_", idBase, "_arg=", txt]
          Nothing -> T.empty

        propLabel = case mLabelArg of
          Just lblVal -> T.concat ["func_", name, "_", idBase, "_label=", lblVal]
          Nothing -> T.empty

        -- FIX: Wenn ein Titel da ist, säubern wir ihn von Anführungszeichen für OmegaT
        propTitle = case mTitleArg of
          Just titleVal ->
            let cleanTitle = T.replace "\"" "" titleVal
             in T.concat ["func_", name, "_", idBase, "_title=", T.strip cleanTitle]
          Nothing -> T.empty

    -- Gibt alle existierenden Zeilen sauber getrennt zurück
    return $ T.intercalate "\n" (filter (not . T.null) [propTitle, propLabel, propArg])
  MalformedFunction orig ->
    return $ "#MALFORMED=" <> orig

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
cleanLabelForKey lbl = T.replace "<" "" (T.replace ">" "" lbl)

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
