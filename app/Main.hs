{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (foldM, forM_)
import Data.Foldable (traverse_)
import Data.Maybe (fromMaybe)
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Yaml (FromJSON (..), decodeFileEither, withObject, (.:), (.:?))
import GHC.Generics
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.FilePath (replaceExtension, takeExtension, (</>))
import Text.Megaparsec (errorBundlePretty)
import Typst.Parser (parseTypst)
import Typst.Printer (extractFunctionsReport, generateOmegaT)
import qualified Typst.Reconstructor as Reconstructor

-- =====================================================================
-- CONFIGURATION DATATYPES
-- =====================================================================

data TargetConfig = TargetConfig
  { targetLang :: T.Text,
    targetOutputDir :: FilePath,
    targetPropertiesDir :: Maybe FilePath
  }
  deriving (Show, Generic)

instance FromJSON TargetConfig where
  parseJSON = withObject "TargetConfig" $ \v ->
    TargetConfig
      <$> v .: "lang"
      <*> v .: "output_dir"
      <*> v .:? "i18n_target_dir"

data RulesConfig = RulesConfig
  { cfgSourceDir :: FilePath,
    cfgI18nSourceDir :: FilePath,
    cfgDefaultI18nTargetDir :: FilePath,
    cfgTargets :: [TargetConfig],
    cfgHideFunctions :: [T.Text],
    cfgIgnoreNamedArgs :: [T.Text]
  }
  deriving (Show, Generic)

instance FromJSON RulesConfig where
  parseJSON = withObject "RulesConfig" $ \v -> do
    hideFuncs <- fromMaybe [] <$> (v .:? "hide_functions")
    ignoreArgs <- fromMaybe ["font", "style", "weight", "lang", "region", "fill", "stroke", "align"] <$> (v .:? "ignore_named_args")
    mProject <- v .:? "project"
    case mProject of
      Just proj -> do
        srcDir <- proj .: "source_dir"
        i18nSrc <- proj .: "i18n_source_dir"
        i18nTgt <- fromMaybe "" <$> (proj .:? "i18n_target_dir")
        tgts <- v .: "targets"
        return $ RulesConfig srcDir i18nSrc i18nTgt tgts hideFuncs ignoreArgs
      Nothing -> do
        dirs <- v .: "directories"
        ruDir <- dirs .: "ru_dir"
        deDir <- dirs .: "de_dir"
        oSrc <- dirs .: "omega_source_dir"
        oTgt <- dirs .: "omega_target_dir"
        let legacyTarget = TargetConfig "de" deDir (Just oTgt)
        return $ RulesConfig ruDir oSrc oTgt [legacyTarget] hideFuncs ignoreArgs

-- | Loads the paths and rules from the specified YAML file
loadRules :: FilePath -> IO RulesConfig
loadRules path = do
  res <- decodeFileEither path
  case res of
    Left err -> error $ "Error loading the configuration (" ++ path ++ "): " ++ show err
    Right cfg -> return cfg

-- | Extracts the optional configuration path and any remaining flags from the CLI arguments
parseCliArgs :: [String] -> (FilePath, [String])
parseCliArgs ("--config" : path : rest) = (path, rest)
parseCliArgs ("-c" : path : rest) = (path, rest)
parseCliArgs (x : rest) =
  let (cfg, remaining) = parseCliArgs rest
   in (cfg, x : remaining)
parseCliArgs [] = ("rules.yaml", [])

-- =====================================================================
-- MAIN PIPELINE ENTRYPOINT
-- =====================================================================

main :: IO ()
main = do
  rawArgs <- getArgs
  let (configPath, args) = parseCliArgs rawArgs

  putStrLn $ "[INFO] Use Configuration: " ++ configPath
  configExists <- doesFileExist configPath
  cfg <-
    if configExists
      then loadRules configPath
      else error $ "The configuration file could not be found: " ++ configPath

  let hideSet = S.fromList (cfgHideFunctions cfg)
      ignoreArgsSet = S.fromList (cfgIgnoreNamedArgs cfg)
      srcDir = cfgSourceDir cfg
      i18nSrcDir = cfgI18nSourceDir cfg

  case args of
    ["--import"] -> do
      putStrLn "[INFO] Start the import from the Properties back into the Typst sources..."
      forM_ (cfgTargets cfg) $ \tgt -> do
        let propsDir = fromMaybe (cfgDefaultI18nTargetDir cfg) (targetPropertiesDir tgt)
            outDir = targetOutputDir tgt
        putStrLn $ "\n[TARGET: " ++ T.unpack (targetLang tgt) ++ "] " ++ propsDir ++ " -> " ++ outDir
        createDirectoryIfMissing True outDir
        Reconstructor.startImportPipeline
          srcDir
          propsDir
          outDir
          hideSet
          ignoreArgsSet
      putStrLn "\n[SUCCESS] Import completed for all target languages!"
    [] -> do
      putStrLn $ "[INFO] Scanne Verzeichnis für Typst-Dateien: " ++ srcDir
      createDirectoryIfMissing True i18nSrcDir
      allFiles <- listDirectory srcDir
      let typstFiles = filter (\f -> takeExtension f == ".typ") allFiles

      putStrLn $ "[INFO] Total number of files found in the folder:: " ++ show (length allFiles)
      putStrLn $ "[INFO] Of these, valid Typst files: " ++ show (length typstFiles)
      putStrLn "[INFO] Starte Export in die Properties..."

      finalFunctions <- foldM (processFile ignoreArgsSet srcDir i18nSrcDir) S.empty typstFiles

      putStrLn "[SUCCESS] Export completed successfully!"
      putStrLn ""
      putStrLn "[REPORT] The following Typst functions were automatically detected for translation:"
      traverse_ (\f -> putStrLn $ "  - " ++ T.unpack f) (S.toList finalFunctions)
    _ -> do
      putStrLn "Usage:"
      putStrLn "  typst-json-printer [--config <datei.yaml>]           (Export: Typst -> Properties)"
      putStrLn "  typst-json-printer [--config <datei.yaml>] --import  (Import: Properties -> Typst)"

-- =====================================================================
-- EXPORTER HELPER
-- =====================================================================

processFile :: S.Set T.Text -> FilePath -> FilePath -> S.Set T.Text -> FilePath -> IO (S.Set T.Text)
processFile ignoreArgsSet srcDir targetDir accumulatedFunctions file = do
  let inputPath = srcDir </> file
      outputPath = targetDir </> replaceExtension file ".properties"

  inputContent <- TIO.readFile inputPath
  putStrLn $ "\n[SCAN] Process File: " ++ file

  case parseTypst inputPath inputContent of
    Left errorBundle -> do
      putStrLn $ "[ERROR] Parsing failed in file: " ++ file
      putStrLn (errorBundlePretty errorBundle)
      return accumulatedFunctions
    Right astBaum -> do
      let omegaTOutput = generateOmegaT ignoreArgsSet astBaum
      TIO.writeFile outputPath omegaTOutput
      let fileFunctions = extractFunctionsReport astBaum
      return (S.union accumulatedFunctions fileFunctions)
