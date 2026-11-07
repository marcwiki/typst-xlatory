{-# LANGUAGE OverloadedStrings #-}

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
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory)
import System.FilePath (replaceExtension, takeBaseName, takeExtension, (</>))
import Text.Megaparsec (errorBundlePretty, parse)
-- Imports aus deinen Modulen
import Typst.AST (BookNode (..), TypstArg (..), TypstDoc (..), TypstInline (..))
-- Dein Haupt-Parser für Typst-Dateien
import Typst.ImporterParser (TranslatedProperty (..), parsePropertiesFile)
import Typst.Parser (parseTypst)

-- | Startet den Re-Import und reicht das Set der versteckten Funktionen weiter
startImportPipeline :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> IO ()
startImportPipeline sourceDir omegaTargetDir deDir hideSet = do
  createDirectoryIfMissing True deDir
  allFiles <- listDirectory sourceDir
  let typstFiles = filter (\f -> takeExtension f == ".typ") allFiles

  -- FIX: 'hideSet' hier explizit mit in die Klammern für importSingleFile geben!
  traverse_ (importSingleFile sourceDir omegaTargetDir deDir hideSet) typstFiles
  putStrLn "[SUCCESS] Import erfolgreich abgeschlossen! Deutsche Typst-Dateien wurden generiert."

importSingleFile :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> FilePath -> IO ()
importSingleFile sourceDir transDir targetDir hideSet file = do
  let origPath = sourceDir </> file
      baseName = takeBaseName file
      propPath = transDir </> (baseName ++ "_de_DE.properties")
      destPath = targetDir </> file

  propExists <- doesFileExist propPath
  if not propExists
    then do
      let altPropPath1 = transDir </> (file ++ "_de_DE.properties")
          altPropPath2 = transDir </> replaceExtension file ".properties"
      c1 <- doesFileExist altPropPath1
      c2 <- doesFileExist altPropPath2
      if c1
        then proceedWithImport origPath altPropPath1 destPath hideSet
        else
          if c2
            then proceedWithImport origPath altPropPath2 destPath hideSet
            else putStrLn $ "[WARN] Keine Übersetzung gefunden für: " ++ file
    else proceedWithImport origPath propPath destPath hideSet

proceedWithImport :: FilePath -> FilePath -> FilePath -> S.Set T.Text -> IO ()
proceedWithImport origPath propPath destPath hideSet = do
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
  let (reconstructedNodes, _) = runReconstruction originalAST translationMap hideSet 1

  -- 4. Speichern
  TIO.writeFile destPath (T.intercalate "\n\n" reconstructedNodes)

runReconstruction :: [BookNode] -> M.Map T.Text [TypstInline] -> S.Set T.Text -> Int -> ([T.Text], Int)
runReconstruction [] _ _ currentId = ([], currentId)
runReconstruction (node : nodes) transMap hideSet currentId =
  let (printedNode, nextId) = reconstructSingleNode node transMap hideSet currentId
      (restLines, finalId) = runReconstruction nodes transMap hideSet nextId
   in (printedNode : restLines, finalId)

-- | Übersetzt und rekonstruiert eine einzelne Node
reconstructSingleNode :: BookNode -> M.Map T.Text [TypstInline] -> S.Set T.Text -> Int -> (T.Text, Int)
reconstructSingleNode node transMap hideSet currentId = case node of
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

        isOptional = name `S.member` hideSet
        nextId = if isJust effectiveLabel || isOptional then currentId else currentId + 1
     in if isOptional
          then
            (printOriginalFunction name args effectiveLabel, nextId)
          else
            let lookupKey = "func_" <> name <> "_" <> idBase <> "_arg"
                mTextArg = M.lookup lookupKey transMap

                mTranslatedLabel = M.lookup ("func_" <> name <> "_" <> idBase <> "_label") transMap
                mTranslatedTitle = M.lookup ("func_" <> name <> "_" <> idBase <> "_title") transMap

                updatedNamedArgs =
                  map
                    ( \(k, v) ->
                        case k of
                          "label" -> case mTranslatedLabel of
                            Just trInlines -> (k, "\"" <> T.dropAround (== '"') (printInlines trInlines) <> "\"")
                            Nothing -> (k, v)
                          "title" -> case mTranslatedTitle of
                            Just trInlines -> (k, "\"" <> T.dropAround (== '"') (printInlines trInlines) <> "\"")
                            Nothing -> (k, v)
                          _ -> (k, v)
                    )
                    [(k, v) | NamedArg k v <- args]

                formatNamedArg (k, v) = k <> ": " <> v
                namedArgsString = T.intercalate ", " (map formatNamedArg updatedNamedArgs)

                parensContent =
                  if T.null namedArgsString
                    then ""
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
  let namedArgs = [(k, v) | NamedArg k v <- args]
      contentArgs = [txt | ContentArg txt <- args]
      formatNamed (k, v) = if "\"" `T.isPrefixOf` v then k <> ": " <> v else k <> ": \"" <> v <> "\""
      parensContent =
        if null namedArgs
          then ""
          else "(" <> T.intercalate ", " (map formatNamed namedArgs) <> ")"
      bracketsContent = T.concat ["[" <> txt <> "]" | txt <- contentArgs]
      suffix = case mLabel of
        Just lbl -> " " <> lbl
        Nothing -> ""
   in "#" <> name <> parensContent <> bracketsContent <> suffix
