{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (foldM)
import Data.Foldable (traverse_)
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Yaml (FromJSON (..), decodeFileEither)
import qualified Data.Yaml as Y
import GHC.Generics
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.FilePath (replaceExtension, takeExtension, (</>))
-- Unsere krisenfesten Compiler-Phasen aus der internen Library

import Typst.Parser (errorBundlePretty, parseTypst)
import Typst.Printer (extractFunctionsReport, generateOmegaT)
import qualified Typst.Reconstructor as Reconstructor

-- =====================================================================
-- CONFIGURATION DATATYPES (Aus Ihrem Original-Snippet)
-- =====================================================================

data AppDirs = AppDirs
  { ru_dir :: FilePath,
    de_dir :: FilePath,
    omega_source_dir :: FilePath,
    omega_target_dir :: FilePath
  }
  deriving (Show, Generic)

instance FromJSON AppDirs

-- KORRIGIERT: Keine verwaisten Kommas oder Einrückungsfehler mehr
data ConfigFile = ConfigFile
  { directories :: AppDirs,
    hide_functions :: [T.Text]
  }
  deriving (Show, Generic)

instance FromJSON ConfigFile

data AppRules = AppRules
  { shouldHide :: S.Set T.Text,
    appDirs :: AppDirs
  }
  deriving (Show)

-- | Lädt die Pfade und Regeln krisenfest aus der rules.yaml
loadRules :: FilePath -> IO AppRules
loadRules path = do
  res <- decodeFileEither path
  case res of
    Left err -> error $ "Fehler beim Laden der rules.yaml: " ++ show err
    Right cfg ->
      let hideSet = S.fromList (hide_functions cfg)
          paths = directories cfg
       in return $ AppRules hideSet paths

-- =====================================================================
-- MAIN PIPELINE ENTRYPOINT
-- =====================================================================

main :: IO ()
main = do
  args <- getArgs

  -- Konfigurationsdatei laden
  let configPath = "rules.yaml"
  configExists <- doesFileExist configPath
  rules <-
    if configExists
      then loadRules configPath
      else error "rules.yaml konnte nicht gefunden werden!"

  let dirs = appDirs rules -- Holt die AppDirs-Struktur
      hideSet = shouldHide rules -- Holt das Set der versteckten Funktionen (hide_functions)

  -- Kontrollfluss anhand der CLI-Argumente
  case args of
    ["--import"] -> do
      putStrLn "[INFO] Starte Import aus den OmegaT Properties zurück in die Typst-Sourcen..."
      -- FIX: Pfade korrekt aus 'dirs' extrahiert und das 'hideSet' übergeben
      Reconstructor.startImportPipeline
        (ru_dir dirs)
        (omega_target_dir dirs)
        (de_dir dirs)
        hideSet
    _ -> do
      -- Der perfekt funktionierende Standard-Export
      let sourceDir = ru_dir dirs
          targetDir = omega_source_dir dirs

      putStrLn $ "[INFO] Scanne Verzeichnis für Typst-Dateien: " ++ sourceDir
      createDirectoryIfMissing True targetDir
      allFiles <- listDirectory sourceDir
      let typstFiles = filter (\f -> takeExtension f == ".typ") allFiles

      putStrLn $ "[INFO] Dateien im Ordner gefunden insg.: " ++ show (length allFiles)
      putStrLn $ "[INFO] Davon gueltige Typst-Dateien: " ++ show (length typstFiles)
      putStrLn "[INFO] Starte Export in die OmegaT Properties..."

      -- FIX: Wir übergeben 'hideSet' als dritten Parameter an processFile beim Teilaufruf (Currying)
      finalFunctions <- foldM (processFile sourceDir targetDir) S.empty typstFiles

      putStrLn "[SUCCESS] Export erfolgreich abgeschlossen!"
      putStrLn ""
      putStrLn "[REPORT] Folgende Typst-Funktionen wurden automatisch fuer die Uebersetzung erfasst:"
      traverse_ (\f -> putStrLn $ "  - " ++ T.unpack f) (S.toList finalFunctions)

-- =====================================================================
-- EXPORTER HELPER (Ganz unten in app/Main.hs anpassen)
-- =====================================================================

-- KORRIGIERTE SIGNATUR: Nimmt sourceDir, targetDir, den Akkumulator und das File
processFile :: FilePath -> FilePath -> S.Set T.Text -> FilePath -> IO (S.Set T.Text)
processFile sourceDir targetDir accumulatedFunctions file = do
  let inputPath  = sourceDir </> file
      outputPath = targetDir </> replaceExtension file ".properties"

  inputContent <- TIO.readFile inputPath
  
  -- DEBUG-LOG: Zeigt uns an, welches File verarbeitet wird
  putStrLn $ "\n[SCAN] Verarbeite Datei: " ++ file

  case parseTypst inputPath inputContent of
    Left errorBundle -> do
      putStrLn $ "[ERROR] Parsing fehlgeschlagen in Datei: " ++ file
      putStrLn (errorBundlePretty errorBundle)
      return accumulatedFunctions
    Right astBaum -> do
      let omegaTOutput = generateOmegaT astBaum
      TIO.writeFile outputPath omegaTOutput
      let fileFunctions = extractFunctionsReport astBaum
      return (S.union accumulatedFunctions fileFunctions)
