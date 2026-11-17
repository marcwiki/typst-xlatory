{-# LANGUAGE OverloadedStrings #-}

{- |
Module      : Typst.Reconstructor
Description : Reconstructs valid Typst source files from original ASTs and translated entries.
License     : GPL-3.0-or-later

Merges the structural layout and non-translatable directives of the original
t'TypstDoc' with translated text segments from CAT tools to generate ready-to-compile
target language @.typ@ files.
-}
module Typst.Reconstructor
  ( startImportPipeline,
  )
where

import Data.Foldable (traverse_)
import qualified Data.Map.Strict as M
import Data.Maybe (isJust)
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.List (find, isPrefixOf)
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory)
import System.FilePath (replaceExtension, takeBaseName, takeExtension, (</>))
import Text.Megaparsec (errorBundlePretty, parse)
-- Imports aus deinen Modulen
import Typst.AST (BookNode (..), TypstArg (..), TypstDoc (..), TypstInline (..))
-- Dein Haupt-Parser für Typst-Dateien
import Typst.ImporterParser (TranslatedProperty (..), parsePropertiesFile)
import Typst.Parser (parseTypst)

-- | Startet den Re-Import und reicht die Sets weiter
startImportPipeline :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> S.Set T.Text -> IO ()
startImportPipeline sourceDir omegaTargetDir deDir hideSet ignoreArgsSet = do
  createDirectoryIfMissing True deDir
  allFiles <- listDirectory sourceDir
  let typstFiles = filter (\f -> takeExtension f == ".typ") allFiles
  traverse_ (importSingleFile sourceDir omegaTargetDir deDir hideSet ignoreArgsSet) typstFiles
  putStrLn "[SUCCESS] Import erfolgreich abgeschlossen! Typst-Dateien wurden generiert."

importSingleFile :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> S.Set T.Text -> FilePath -> IO ()
importSingleFile sourceDir transDir targetDir hideSet ignoreArgsSet file = do
  let origPath = sourceDir </> file
      baseName = takeBaseName file
      destPath = targetDir </> file

  transFiles <- listDirectory transDir
  let mMatchedProp =
        find
          ( \f ->
              takeExtension f == ".properties"
                && ( f == replaceExtension file ".properties"
                       || (baseName ++ "_") `isPrefixOf` f
                       || (file ++ "_") `isPrefixOf` f
                   )
          )
          transFiles

  case mMatchedProp of
    Just propFile -> proceedWithImport origPath (transDir </> propFile) destPath hideSet ignoreArgsSet
    Nothing -> putStrLn $ "[WARN] Keine Übersetzung gefunden für: " ++ file


proceedWithImport :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> S.Set T.Text -> IO ()
proceedWithImport origPath propPath destPath hideSet ignoreArgsSet = do
  origContent <- TIO.readFile origPath
  propContent <- TIO.readFile propPath

  -- 1. Original-Datei sauber über deine parseTypst-Funktion einlesen
  let originalAST = case parseTypst origPath origContent of
        Left err -> error $ "Parsing Fehler Quelle:\n" ++ errorBundlePretty err
        Right (TypstDoc ast) -> ast

      -- 2. Übersetzungen strukturiert als Inline-AST einlesen
      translationMap = case parse parsePropertiesFile propPath propContent of
        Left err -> error $ "Parsing Fehler Properties:\n" ++ errorBundlePretty err
        Right props -> M.fromList [(propKey p, propValue p) | p <- props]

  -- 3. Rekonstruktion ausführen
  let (reconstructedNodes, _) = runReconstruction originalAST translationMap hideSet ignoreArgsSet 1

  -- 4. Speichern
  TIO.writeFile destPath (T.intercalate "\n\n" reconstructedNodes)

runReconstruction :: [BookNode] -> M.Map T.Text [TypstInline] -> S.Set T.Text -> S.Set T.Text -> Int -> ([T.Text], Int)
runReconstruction [] _ _ _ currentId = ([], currentId)
runReconstruction (node : rest) transMap hideSet ignoreArgsSet currentId =
  let (txt, nextId) = reconstructSingleNode node transMap hideSet ignoreArgsSet currentId
      (restTxts, finalId) = runReconstruction rest transMap hideSet ignoreArgsSet nextId
   in (txt : restTxts, finalId)

-- | Übersetzt und rekonstruiert eine einzelne Node
reconstructSingleNode :: BookNode -> M.Map T.Text [TypstInline] -> S.Set T.Text -> S.Set T.Text -> Int -> (T.Text, Int)
reconstructSingleNode node transMap hideSet ignoreArgsSet currentId = case node of

  Paragraph _ mLabel ->
    let idBase = case mLabel of
          Just lbl -> labelToPropKey lbl
          Nothing -> "p_id_" <> T.pack (show currentId)
        nextId = if isJust mLabel then currentId else currentId + 1

        translatedInlines = M.findWithDefault [PlainText "DE_TRANSLATION_MISSING"] ("text_" <> idBase) transMap

        -- FIX: Spitze Klammern <...> wieder um das Label setzen
        suffix = case mLabel of
          Just l -> " <" <> cleanLabelForKey l <> ">"
          Nothing -> ""
     in (printInlines translatedInlines <> suffix, nextId)
  Heading level _ mLabel ->
    let idBase = case mLabel of
          Just lbl -> labelToPropKey lbl
          Nothing -> "h_id_" <> T.pack (show currentId)
        nextId = if isJust mLabel then currentId else currentId + 1

        translatedInlines = M.findWithDefault [PlainText "DE_HEADING_MISSING"] ("heading_lvl_" <> T.pack (show level) <> "_" <> idBase) transMap
        prefix = T.replicate level "=" <> " "
        suffix = case mLabel of
          Just l -> " <" <> cleanLabelForKey l <> ">"
          Nothing -> ""
     in (prefix <> printInlines translatedInlines <> suffix, nextId)
  CustomFunction name args mLabel ->
    let -- 1. Sucht am ENDE des ContentArg nach einem eingebetteten <tag> (z. B. <p_id_53> statt <p_id_52>)
        embeddedTag = case [txt | ContentArg txt <- args] of
          (t : _) ->
            let stripped = T.stripEnd t
             in if ">" `T.isSuffixOf` stripped
                  then
                    let beforeClose = T.dropEnd 1 stripped
                        (prefix, tagWithOpen) = T.breakOnEnd "<" beforeClose
                     in if T.null prefix then Nothing else Just tagWithOpen
                  else Nothing
          [] -> Nothing

        effectiveLabel = case mLabel of
          Just l -> Just l
          Nothing -> embeddedTag

        -- Nutzt labelToPropKey (':' -> '_') für den Map-Lookup; bei Nothing nackte Zahl wie in Printer.hs
        idBase = case effectiveLabel of
          Just lbl -> labelToPropKey lbl
          Nothing -> T.pack (show currentId)

        hasContentArg = not (null [() | ContentArg _ <- args])
        isOptional = (name `S.member` hideSet) || not hasContentArg
        nextId = if isJust effectiveLabel || isOptional then currentId else currentId + 1
     in if isOptional
          then
            (printOriginalFunction name args effectiveLabel, nextId)
          else
            let lookupKey = "func_" <> name <> "_" <> idBase <> "_arg"
                mTextArg = M.lookup lookupKey transMap

                -- NEU: Dynamisches Ersetzen für alle benannten String-Argumente
                updatedNamedArgs =
                  map
                    ( \(k, v) ->
                        if k `S.member` ignoreArgsSet
                          then (k, v)
                          else
                            let newKey = "func_" <> name <> "_" <> idBase <> "_arg_" <> k
                                legacyKey = "func_" <> name <> "_" <> idBase <> "_" <> k
                                mTrans = case M.lookup newKey transMap of
                                  Just res -> Just res
                                  Nothing -> M.lookup legacyKey transMap
                             in case mTrans of
                                  Just trInlines ->
                                    let cleanTranslated = T.dropAround (== '"') (printInlines trInlines)
                                     in (k, "\"" <> cleanTranslated <> "\"")
                                  Nothing -> (k, v)
                    )
                    [(k, v) | NamedArg k v <- args]

                formatNamedArg (k, v) = k <> ": " <> v
                namedArgsString = T.intercalate ", " (map formatNamedArg updatedNamedArgs)

                parensContent =
                  if T.null namedArgsString
                    then if name `elem` ["cover-page", "pagebreak"] then "()" else ""
                    else "(" <> namedArgsString <> ")"

                finalContentText = case mTextArg of
                  Just translatedInlines -> printInlines translatedInlines
                  Nothing -> "DE_FUNCTION_TRANSLATION_MISSING"

                -- Behält Doppelpunkte für das Ziel-Dokument bei
                suffix = case effectiveLabel of
                  Just l -> " <" <> cleanLabelForKey l <> ">"
                  Nothing -> ""
             in ("#" <> name <> parensContent <> "[" <> finalContentText <> "]" <> suffix, nextId)
  MalformedFunction txt -> (txt, currentId)

-- | Hilfsfunktion: Wandelt den Inline-AST wieder in natives Typst um
printInlines :: [TypstInline] -> T.Text
printInlines inlines = T.unwords (map printInline inlines)
  where
    printInline (PlainText txt) = txt
    printInline (InlineLink target label) = T.concat ["#link(", target, ")[", label, "]"]
    printInline (InlineBold content) = T.concat ["*", printInlines content, "*"]

-- Hilfsfunktion für Key-Bereinigung, falls sie nicht aus der AST kommt
cleanLabelForKey :: T.Text -> T.Text
cleanLabelForKey lbl = T.replace "<" "" (T.replace ">" "" lbl)

-- Ersetzt zusätzlich ':' durch '_' für den Lookup in transMap (z. B. "h2-id-1_cl-numbered")
labelToPropKey :: T.Text -> T.Text
labelToPropKey lbl = T.replace ":" "_" (cleanLabelForKey lbl)

-- | Rekonstruiert eine versteckte Funktion exakt im russischen Originalzustand.
printOriginalFunction :: T.Text -> [TypstArg] -> Maybe T.Text -> T.Text
printOriginalFunction name args mLabel =
  let parenArgs =
        [ case arg of
            NamedArg k v -> k <> ": " <> v
            PositionalArg v -> v
            ContentArg _ -> ""
        | arg <- args
        , case arg of ContentArg _ -> False; _ -> True
        ]
      contentArgs = [txt | ContentArg txt <- args]
      parensContent =
        if null parenArgs
          then if null contentArgs then "()" else ""
          else "(" <> T.intercalate ", " parenArgs <> ")"

      bracketsContent = T.concat ["[" <> txt <> "]" | txt <- contentArgs]
      suffix = case mLabel of
        Just lbl -> " <" <> cleanLabelForKey lbl <> ">"
        Nothing -> ""
   in "#" <> name <> parensContent <> bracketsContent <> suffix

