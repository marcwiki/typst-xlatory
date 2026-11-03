{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

module Main (main) where

import Control.Monad (when)
import Data.Char (chr)
import Data.Foldable (traverse_)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import qualified Data.Set as S
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.IO.Utf8 as TIOUtf8
import Data.Yaml (FromJSON, decodeFileEither, parseJSON)
import qualified Data.Yaml as Y
import GHC.Generics
import Numeric (readHex)
import System.Directory (createDirectoryIfMissing, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.FilePath (replaceExtension, takeBaseName, takeExtension, (</>))
import System.IO (IOMode (ReadMode, WriteMode), hSetEncoding, openFile, stdout, utf8, withFile)

-- | Die Strategien als sauberer Datentyp
data TranslationStrategy = XlateAll | XlateWithoutTag | XlateBoth
  deriving (Show, Eq)

instance FromJSON TranslationStrategy where
  parseJSON = Y.withText "TranslationStrategy" $ \v ->
    case v of
      "xlate-without-tag" -> return XlateWithoutTag
      "xlate-both" -> return XlateBoth
      _ -> return XlateAll

-- | Eine einzelne Regel aus der YAML-Datei
data RuleConfig = RuleConfig
  { funcName :: T.Text,
    strategy :: TranslationStrategy
  }
  deriving (Show, Generic)

instance FromJSON RuleConfig

-- | Die Gesamtstruktur der YAML-Datei
data ConfigFile = ConfigFile
  { hide_functions :: [T.Text],
    translation_rules :: [RuleConfig]
  }
  deriving (Show, Generic)

instance FromJSON ConfigFile

-- | Unser globaler Laufzeit-Zustand, generiert aus der YAML-Datei
data AppRules = AppRules
  { shouldHide :: S.Set T.Text,
    strategies :: M.Map T.Text TranslationStrategy
  }
  deriving (Show)

-- | Lädt die YAML-Datei und baut den schnellen Lookup-State auf
loadRules :: FilePath -> IO AppRules
loadRules path = do
  res <- decodeFileEither path
  case res of
    Left err -> error $ "Fehler beim Laden der rules.yaml: " ++ show err
    Right cfg ->
      let hideSet = S.fromList (hide_functions cfg)
          stratMap = M.fromList [(funcName r, strategy r) | r <- translation_rules cfg]
       in return $ AppRules hideSet stratMap

-- | Unser erweiterter semantischer Dokumenten-Knoten (jetzt hält PlainText auch ein Label)
data BookNode
  = CustomFunction T.Text [T.Text] (Maybe T.Text)
  | Heading Int T.Text (Maybe T.Text)
  | PlainText T.Text (Maybe T.Text)
  deriving (Show)

-- | Extrahiert alle ID-Labels der Form <p_id_...> oder <h2-id-...> aus einem Text
extractAllIds :: T.Text -> S.Set T.Text
extractAllIds txt = go txt S.empty
  where
    go t acc
      | T.null t = acc
      | otherwise =
          let (_, restAfterOpen) = T.breakOn "<" t
           in if T.null restAfterOpen
                then acc
                else
                  let (potentialLabel, next) = T.breakOn ">" restAfterOpen
                      fullLabel = potentialLabel <> ">"
                   in if ">" `T.isPrefixOf` next && isIdLabel fullLabel
                        then go (T.drop 1 next) (S.insert fullLabel acc)
                        else go (T.drop 1 restAfterOpen) acc

    -- Prüft, ob das gefundene Tag ein echtes ID-Label ist
    isIdLabel l = "id_" `T.isInfixOf` l || "p_" `T.isPrefixOf` l || "h" `T.isInfixOf` l

-- | Repräsentiert einen Validierungsfehler in einer bestimmten Zeile
data ValidationError = ValidationError
  { lineNumber :: Int,
    missingIds :: S.Set T.Text,
    originalLine :: T.Text,
    generatedLine :: T.Text
  }
  deriving (Show)

-- | Validiert die generierten Zeilen gegen die Originalzeilen
validateDocIds :: AppRules -> M.Map T.Text T.Text -> [T.Text] -> Either [ValidationError] ()
validateDocIds rules transMap origLines =
  let -- 1. Rekonstruiere alle Zeilen paarweise mit ihrer Zeilennummer
      evaluated =
        zipWith
          ( \idx orig ->
              let gen = reconstructTypstLine rules transMap idx orig
               in (idx, orig, gen)
          )
          [1 ..]
          origLines

      -- 2. Prüfe jede Zeile auf verlorene IDs
      errors = foldr checkLine [] evaluated
   in if null errors then Right () else Left errors
  where
    checkLine (idx, orig, gen) acc =
      let origIds = extractAllIds orig
          genIds = extractAllIds gen
          lostIds = S.difference origIds genIds
       in if S.null lostIds
            then acc
            else ValidationError idx lostIds orig gen : acc

-- | Führt die Validierung aus und gibt Feedback auf der Konsole
runIdValidation :: AppRules -> M.Map T.Text T.Text -> [T.Text] -> IO Bool
runIdValidation rules transMap origLines =
  case validateDocIds rules transMap origLines of
    Right () -> do
      putStrLn "✅ Validierung erfolgreich: Alle ID-Labels sind vollständig!"
      return True
    Left errors -> do
      putStrLn "❌ VALIDIERUNGSFEHLER: ID-Labels wurden beschädigt oder gelöscht!\n"
      traverse_ printError errors
      return False
  where
    printError err = do
      putStrLn $ "--- Fehler in Zeile " ++ show (lineNumber err) ++ " ---"
      putStrLn $ "❌ Fehlende ID(s): " ++ show (S.toList (missingIds err))
      putStrLn $ "  Original:  " ++ T.unpack (originalLine err)
      putStrLn $ "  Generiert: " ++ T.unpack (generatedLine err)
      putStrLn ""

compileDocument :: AppRules -> M.Map T.Text T.Text -> [T.Text] -> FilePath -> IO ()
compileDocument rules transMap origLines outPath = do
  isValid <- runIdValidation rules transMap origLines
  if isValid
    then do
      let finalContent = T.unlines $ zipWith (\idx orig -> reconstructTypstLine rules transMap idx orig) [1 ..] origLines
      TIO.writeFile outPath finalContent
      putStrLn "💾 Typst-Datei erfolgreich geschrieben."
    else do
      putStrLn "🚫 Schreiben abgebrochen. Bitte korrigiere die Übersetzungen in OmegaT."

-- | Fügt mehrzeilige Absätze zusammen, ignoriert Imports und hält Funktionsblöcke zusammen
joinMultilines :: [T.Text] -> [T.Text]
joinMultilines [] = []
joinMultilines (x : xs)
  | T.null (T.strip x) = "" : joinMultilines xs
  -- Mehrzeilige Imports ignorieren
  | "#import" `T.isPrefixOf` T.strip x && not (")" `T.isSuffixOf` T.strip x) =
      let (_, rest) = break (\l -> ")" `T.isSuffixOf` T.strip l) xs
       in joinMultilines (drop 1 rest)
  | "#import" `T.isPrefixOf` T.strip x = joinMultilines xs
  -- Äußere Container strippen
  | "#" `T.isPrefixOf` T.strip x && "[" `T.isSuffixOf` T.strip x = joinMultilines xs
  | T.strip x == "]" = joinMultilines xs
  -- Wenn eine Zeile eine Funktion startet (z.B. #conclusion-block)

  | "#" `T.isPrefixOf` T.strip x && ("(" `T.isInfixOf` x || "[" `T.isInfixOf` x) =
      let -- Wir ermitteln die Start-Klammerwerte der ersten Zeile
          (initR, initS) = countBrackets 0 0 (T.unpack x)
          (blockLines, rest) = collectBalancedFunction initR initS [x] xs
          combined = T.unwords (map T.strip blockLines)
       in combined : joinMultilines rest
  -- Normale Absätze zusammenfügen
  | otherwise =
      let (block, rest) = collectParagraph [x] xs
          combined = T.unwords (map T.strip block)
          cleaned =
            if "]" `T.isSuffixOf` combined && not ("[" `T.isInfixOf` combined)
              then T.stripEnd (T.dropEnd 1 combined)
              else combined
       in cleaned : joinMultilines rest
  where
    -- Hilfsfunktion zum Zählen von Klammern in einem String
    countBrackets r s [] = (r, s)
    countBrackets r s (c : cs) =
      case c of
        '(' -> countBrackets (r + 1) s cs
        ')' -> countBrackets (max 0 (r - 1)) s cs
        '[' -> countBrackets r (s + 1) cs
        ']' -> countBrackets r (max 0 (s - 1)) cs
        _ -> countBrackets r s cs

    -- Sammelt Zeilen, bis alle geöffneten Klammern wieder geschlossen sind
    collectBalancedFunction :: Int -> Int -> [T.Text] -> [T.Text] -> ([T.Text], [T.Text])
    collectBalancedFunction _ _ acc [] = (reverse acc, [])
    collectBalancedFunction r s acc (y : ys) =
      let (newR, newS) = countBrackets r s (T.unpack y)
       in if newR == 0 && newS == 0
            then (reverse (y : acc), ys) -- Komplett balanciert!
            else collectBalancedFunction newR newS (y : acc) ys

    collectParagraph acc [] = (reverse acc, [])
    collectParagraph acc (y : ys)
      | T.null (T.strip y) = (reverse acc, y : ys)
      | "=" `T.isPrefixOf` T.strip y = (reverse acc, y : ys)
      | "#" `T.isPrefixOf` T.strip y = (reverse acc, y : ys)
      | T.strip y == "]" = (reverse acc, y : ys)
      | otherwise = collectParagraph (y : acc) ys

-- | Extrahiert echten Text und isoliert das finale ID-Label sauber.
-- Wirft allen Syntax-Ballast (wie runde Klammern, gutter, labels) kompromisslos weg.
extractArgsAndLabel :: T.Text -> ([T.Text], Maybe T.Text)
extractArgsAndLabel t =
  let trimmed = T.strip t

      -- 1. Wir isolieren das echte ID-Label am Ende der Zeile
      (textWithoutLabel, mLabel) = extractLabel trimmed

      -- 2. Wir suchen den Text *innerhalb* der eckigen Klammern [...]
      --    T.breakOn "[" trennt das Ganze am ersten Vorkommen
      (_, afterOpenBracket) = T.breakOn "[" textWithoutLabel

      cleanContent =
        if T.null afterOpenBracket
          then textWithoutLabel -- Fallback, falls keine eckige Klammer existiert
          else
            -- Wir droppen das '[' und lesen alles bis zum letzten ']'
            let rawInner = T.drop 1 afterOpenBracket
                -- Wir schneiden das schließende ] am Ende ab, falls vorhanden
                withoutClose =
                  if "]" `T.isSuffixOf` T.stripEnd rawInner
                    then T.dropEnd 1 (T.stripEnd rawInner)
                    else rawInner
             in T.strip withoutClose

      -- 3. Wir säubern den Text komplett für den Übersetzer
      --    (Entfernt eventuelle äußere Anführungszeichen)
      finalText =
        let s = T.strip cleanContent
         in if "\"" `T.isPrefixOf` s && "\"" `T.isSuffixOf` s
              then T.dropEnd 1 (T.drop 1 s)
              else s

      -- 4. Wir packen den reinen Text als einziges Argument in die Liste
      args = if T.null finalText then [] else [finalText]
   in (args, mLabel)

-- | Sucht nach dem exakt finalen ID-Label einer Zeile, ohne vordere Links/Labels zu beschädigen
extractLabel :: T.Text -> (T.Text, Maybe T.Text)
extractLabel s =
  let trimmed = T.strip s
      -- Wir suchen nach dem letzten Vorkommen von '>'
      (beforeGreater, afterGreater) = T.breakOnEnd ">" trimmed
   in if T.null beforeGreater
        then (s, Nothing) -- Kein '>' gefunden
        else
          -- Wir suchen das passende '<' vor diesem '>' im hinteren Abschnitt
          let targetPart = T.dropEnd 1 beforeGreater -- entfernt das '>'
              (leftover, labelContent) = T.breakOnEnd "<" targetPart
           in if T.null leftover && not ("<" `T.isPrefixOf` targetPart)
                then (s, Nothing) -- Kein passendes '<' gefunden
                else
                  let cleanLabel = "<" <> labelContent <> ">"
                      -- Der Text vor dem Label und der Text nach dem Label (z.B. Klammern)
                      prefix = T.stripEnd (T.dropEnd 1 leftover)
                      suffix = T.strip afterGreater
                      -- Wir fügen den Text zusammen, lassen die Klammern aber ganz hinten stehen!
                      combinedText = T.stripEnd (prefix <> suffix)
                   in if "id_" `T.isInfixOf` labelContent || "h2-" `T.isPrefixOf` labelContent || "h3-" `T.isPrefixOf` labelContent || "h4-" `T.isPrefixOf` labelContent || "p_" `T.isPrefixOf` labelContent
                        then (combinedText, Just cleanLabel)
                        else (s, Nothing) -- Es war ein normaler Link/Verweis, kein ID-Label

-- | Die bereinigte parseTypstLine (ohne fehleranfälliges Zwiebel-Schälen)
parseTypstLine :: AppRules -> T.Text -> Maybe BookNode
parseTypstLine rules line
  | "import" `T.isPrefixOf` trimLine = Nothing
  | "apply-title-page" `T.isPrefixOf` trimLine = Nothing
  | "pagebreak" `T.isPrefixOf` trimLine = Nothing

    -- HIER NEU: #show und #set Befehle komplett überspringen!
  | "#show" `T.isPrefixOf` trimLine = Nothing
  | "#set" `T.isPrefixOf` trimLine = Nothing

  -- HIER KORRIGIERT: Fängt Inline-Abstände ab und rettet den dahinterstehenden Text!
  | "#h(" `T.isPrefixOf` trimLine || "#v(" `T.isPrefixOf` trimLine =
      let -- Schneidet alles bis zur schließenden Klammer des Abstands-Befehls weg (z.B. "#h(3mm)" entfernen)
          restText = T.strip (T.drop 1 (T.dropWhile (/= ')') trimLine))
       in if T.null restText
            then Nothing -- War ein reiner Abstand ohne Text -> Ignorieren
            else
              -- Der verbleibende Text (z.B. "А 80 <p_id_3>") wird als PlainText eingestuft
              let (lineWithoutLabel, globalLabel) = extractLabel restText
               in Just (PlainText lineWithoutLabel globalLabel)
  | ")" `T.isPrefixOf` trimLine = Nothing
  | "," `T.isSuffixOf` trimLine = Nothing
  | "." `T.isPrefixOf` trimLine = Nothing
  | T.null trimLine = Nothing
  | "//" `T.isPrefixOf` trimLine = Nothing
  | "=" `T.isPrefixOf` trimLine =
      let (lineWithoutLabel, globalLabel) = extractLabel trimLine
          lvl = T.length (T.takeWhile (== '=') lineWithoutLabel)
          cleanContent = T.dropWhile (== ' ') (T.drop lvl lineWithoutLabel)
       in Just (Heading lvl cleanContent globalLabel)
  | "#" `T.isPrefixOf` trimLine =
      let name = T.takeWhile (\c -> c /= '[' && c /= '(') (T.drop 1 trimLine)
          argsPart = T.dropWhile (\c -> c /= '[' && c /= '(') trimLine
          (args, funcLabel) = extractArgsAndLabel trimLine
       in if T.null name
            then Nothing
            else
              if S.member name (shouldHide rules)
                then
                  -- HIER DIE KORREKTUR: Wenn die Funktion versteckt werden soll,
                  -- prüfen wir, ob danach noch verwertbarer Text steht!
                  let remainingText = T.strip (T.dropWhile (\c -> c /= ']' && c /= ')') argsPart)
                      -- Wir schneiden die schließende Klammer der Funktion noch weg
                      cleanRemainder = T.strip (T.drop 1 remainingText)
                   in if T.null cleanRemainder
                        then Nothing -- Die Zeile enthielt NUR die Funktion -> Sicher verstecken
                        else -- Es steht noch Text dahinter -> Als PlainText retten!
                          let (lineWithoutLabel, globalLabel) = extractLabel cleanRemainder
                           in Just (PlainText lineWithoutLabel globalLabel)
                else Just (CustomFunction name args funcLabel)
  | otherwise =
      if T.null trimLine
        then Nothing -- Verhindert, dass leere Zeilen Objekte erzeugen
        else
          -- Falls hier fälschlicherweise noch ein Funktionsfragment drinsteckt,
          -- verhindern wir, dass es als reiner Text interpretiert wird.
          let (lineWithoutLabel, globalLabel) = extractLabel trimLine
           in Just (PlainText lineWithoutLabel globalLabel)
  where
    trimLine = T.strip line

-- | Hilfsfunktion: Schneidet alles ab, was nach dem Schließen aller geöffneten
-- Klammern (runde und eckige zusammen) im Stream folgt.
isolateBalancedBlock :: T.Text -> T.Text
isolateBalancedBlock input = go 0 input T.empty
  where
    go depth t acc
      | T.null t = acc
      -- Wenn wir bei Tiefe 0 sind und ein neues Zeichen sehen (außerhalb der Funktion)
      | depth == 0 && not (T.null acc) && not (T.isPrefixOf "[" (T.stripStart t)) && not (T.isPrefixOf "(" (T.stripStart t)) = acc
      | otherwise =
          case T.uncons t of
            Just (x, xs) ->
              let newDepth = case x of
                    '[' -> depth + 1
                    '(' -> depth + 1
                    ']' -> depth - 1
                    ')' -> depth - 1
                    _ -> depth
               in if newDepth < 0
                    then T.snoc acc x -- Fängt strukturelle Risse ab
                    else go newDepth xs (T.snoc acc x)
            Nothing -> acc

-- | Bereinigt ein Label für die Verwendung im Property-Key (entfernt <, > und Doppelpunkte)
cleanLabelForKey :: T.Text -> T.Text
cleanLabelForKey lbl = T.filter (`notElem` ['<', '>', ':']) lbl

-- | Generiert stabile Keys basierend auf den Dokument-Labels
getNodeKey :: Int -> BookNode -> T.Text
getNodeKey idx (CustomFunction fname _ lbl) =
  case lbl of
    Just l -> "func_" <> fname <> "_" <> cleanLabelForKey l
    Nothing -> "func_" <> fname <> "_" <> T.pack (show idx)
getNodeKey idx (Heading lvl _ lbl) =
  case lbl of
    Just l -> "heading_l" <> T.pack (show lvl) <> "_" <> cleanLabelForKey l
    Nothing -> "heading_l" <> T.pack (show lvl) <> "_" <> T.pack (show idx)
getNodeKey idx (PlainText _ lbl) =
  case lbl of
    Just l -> "text_" <> cleanLabelForKey l
    Nothing -> "text_" <> T.pack (show idx)

-- | Verarbeitet die Argumente basierend auf der geladenen Strategie und fängt Einzeltexte ab
toOmegaT :: AppRules -> Int -> BookNode -> T.Text
toOmegaT rules idx node@(CustomFunction fname args _) =
  let baseKey = getNodeKey idx node
   in case args of
        [einzelnerText] -> baseKey <> "=" <> einzelnerText <> "\n"
        _ -> T.unlines [baseKey <> "_arg" <> T.pack (show i) <> "=" <> arg | (i, arg) <- zip [1 :: Int ..] args]
toOmegaT _ idx node@(Heading _ content _) =
  let key = getNodeKey idx node
   in key <> "=" <> content <> "\n"
toOmegaT _ idx node@(PlainText content _) =
  let key = getNodeKey idx node
   in key <> "=" <> content <> "\n"

-- | Liest die Translation-Map ein und dekodiert Java-Unicode-Escapes (\uXXXX) automatisch
parseTranslationMap :: T.Text -> M.Map T.Text T.Text
parseTranslationMap txt =
  let zeilen = T.lines txt
      paare = map splitLine zeilen
   in M.fromList [(k, decodeUnicodeEscapes v) | Just (k, v) <- paare]
  where
    splitLine l
      | "=" `T.isInfixOf` l = Just (T.strip (T.takeWhile (/= '=') l), T.drop 1 (T.dropWhile (/= '=') l))
      | otherwise = Nothing

-- | Konvertiert alle vorkommenden \uXXXX Sequenzen in echte UTF-8 Zeichen
decodeUnicodeEscapes :: T.Text -> T.Text
decodeUnicodeEscapes t
  | T.null t = ""
  | "\\u" `T.isPrefixOf` t && T.length t >= 6 =
      let hexStr = T.unpack (T.take 4 (T.drop 2 t))
          rest = T.drop 6 t
       in case readHex hexStr of
            [(code, "")] -> T.singleton (chr code) <> decodeUnicodeEscapes rest
            _ -> "\\u" <> decodeUnicodeEscapes (T.drop 2 t)
  | otherwise =
      let (normal, escaped) = T.breakOn "\\u" t
       in normal <> decodeUnicodeEscapes escaped

-- | Baut die Typst-Zeile aus den Übersetzungen fehlerfrei und ohne Verdoppelungen wieder zusammen
reconstructTypstLine :: AppRules -> M.Map T.Text T.Text -> Int -> T.Text -> T.Text
reconstructTypstLine rules transMap idx originalLine =
  case parseTypstLine rules originalLine of
    Nothing -> originalLine
    Just node ->
      let baseKey = getNodeKey idx node
       in case M.lookup baseKey transMap of
            -- Fall 1: Der direkte Basis-Key wurde gefunden (PlainText, Headings, Single-Arg-Functions)
            Just übersetzterText ->
              let cleanText = T.strip übersetzterText
               in case node of
                    PlainText _ labelPart ->
                      let lbl = fromMaybe "" labelPart
                       in cleanText <> (if T.null lbl then "" else " " <> lbl)
                    Heading lvl _ labelPart ->
                      let lbl = fromMaybe "" labelPart
                       in T.replicate lvl "=" <> " " <> cleanText <> (if T.null lbl then "" else " " <> lbl)
                    -- So setzt du die gereinigten Texte beim Import wieder in das Originalgerüst ein:
                    CustomFunction fname _ labelPart ->
                      let lbl = fromMaybe "" labelPart
                          -- Wir holen uns das exakte Gerüst der Optionen aus der Originalzeile vorn weg
                          -- z.B. "#row(label: "A80")" oder "#row(gutter: 0mm)"
                          originalPrefix = T.takeWhile (/= '[') originalLine
                       in originalPrefix <> "[" <> cleanText <> "]" <> (if T.null lbl then "" else " " <> lbl)
            -- Fall 2: Der Basis-Key wurde nicht direkt gefunden -> Multi-Argument-Funktion
            Nothing ->
              case node of
                CustomFunction fname args labelPart ->
                  let extractLinks t = [m | m <- T.words t, "#link" `T.isPrefixOf` m]

                      collectArgs _ [] = []
                      collectArgs i (orig : origRest) =
                        let argKey = baseKey <> "_arg" <> T.pack (show i)
                            -- Falls nicht im transMap (weil kein String/Content), nimm das Original
                            translated = fromMaybe orig (M.lookup argKey transMap)

                            origLinks = extractLinks orig
                            transLinks = extractLinks translated

                            securedText =
                              if not (null origLinks) && null transLinks
                                then T.strip translated <> " " <> T.intercalate " " origLinks
                                else T.strip translated
                         in (orig, T.strip securedText) : collectArgs (i + 1) origRest

                      pairArgs = collectArgs 1 args
                      lbl = fromMaybe "" labelPart
                   in if map snd pairArgs == map T.strip args
                        then originalLine
                        else
                          let renderArg (orig, trans)
                                -- Fall A: Es war ein benanntes Argument (z.B. label: "A80")
                                | ":" `T.isInfixOf` orig =
                                    -- Falls der Übersetzer aus Versehen das "label:" mitkopiert hat, fangen wir es ab
                                    if ":" `T.isInfixOf` trans
                                      then trans
                                      else
                                        let keyPrefix = T.takeWhile (/= ':') orig
                                         in T.strip keyPrefix <> ": \"" <> trans <> "\""
                                -- Fall B: Es war ein normaler eckiger Inhaltsblock [Text]
                                | "[" `T.isPrefixOf` orig =
                                    if "[" `T.isPrefixOf` trans then trans else "[" <> trans <> "]"
                                -- Fall C: Es war ein isolierter String in Anführungszeichen "Text"
                                | "\"" `T.isPrefixOf` orig =
                                    if "\"" `T.isPrefixOf` trans then trans else "\"" <> trans <> "\""
                                -- Fallback für Zahlen, Längen (0mm) etc.
                                | otherwise = trans

                              -- Trennung in Optionen (runde Klammern) und Content (eckige Klammern)
                              (namedArgs, contentBlocks) =
                                let formatted = map renderArg pairArgs
                                    named = filter (\a -> ":" `T.isInfixOf` a) formatted
                                    content = filter (\a -> not (":" `T.isInfixOf` a)) formatted
                                 in (named, content)

                              argsRound =
                                if null namedArgs
                                  then ""
                                  else "(" <> T.intercalate ", " namedArgs <> ")"

                              argsSquare = T.concat contentBlocks
                           in "#" <> fname <> argsRound <> argsSquare <> (if T.null lbl then "" else " " <> lbl)
                _ -> originalLine

-- | Verarbeitet eine einzelne Datei
processFile :: AppRules -> String -> FilePath -> FilePath -> FilePath -> FilePath -> FilePath -> IO ()
processFile rules mode ruDir omegaTSourceDir omegaTTargetDir deDir fileName = do
  createDirectoryIfMissing True omegaTSourceDir
  createDirectoryIfMissing True omegaTTargetDir
  createDirectoryIfMissing True deDir

  let ruFile = ruDir </> fileName
  let propExportFile = omegaTSourceDir </> replaceExtension fileName "properties"
  -- HIER DAS OMEGAT-SUFFIX ANHÄNGEN:
  let omegaTFileName = takeBaseName fileName <> "_de_DE.properties"
  let propImportFile = omegaTTargetDir </> omegaTFileName
  let deFile = deDir </> fileName

  readHandle <- openFile ruFile ReadMode
  hSetEncoding readHandle utf8
  ruInhalt <- TIO.hGetContents readHandle
  let roheZeilen = T.lines (fromMaybe ruInhalt (T.stripPrefix "\xFEFF" ruInhalt))
      ruZeilen = joinMultilines roheZeilen
  let knoten = [k | Just k <- map (parseTypstLine rules) ruZeilen]

  if mode == "--export"
    then do
      let omegaTInhalt = T.concat [toOmegaT rules idx k | (idx, k) <- zip [1 :: Int ..] knoten]
      if T.null (T.strip omegaTInhalt)
        then return ()
        else TIOUtf8.writeFile propExportFile omegaTInhalt -- <-- Narrensicheres UTF-8-Schreiben!
    else do
      -- IMPORT MODUS
      transExists <- doesFileExist propImportFile
      if not transExists
        then TIOUtf8.writeFile deFile ruInhalt -- Fallback aufs Original
        else do
          transInhalt <- TIOUtf8.readFile propImportFile
          let transMap = parseTranslationMap transInhalt

          -- Wir lesen die Datei für den Import zeilenweise im Originalzustand (roheZeilen)
          -- Dadurch bleiben alle Imports, Leerzeilen und Container intakt!
          let importKnoten = [(idx, parseTypstLine rules z, z) | (idx, z) <- zip [1 :: Int ..] roheZeilen]
              neuZeilen = map (ersetzeZeile transMap) importKnoten

          TIOUtf8.writeFile deFile (T.unlines neuZeilen)
  where
    -- Ändere originalLine zu rawLine, um die Warnung zu eliminieren
    ersetzeZeile transMap (idx, Just node, rawLine) =
      let key = getNodeKey idx node
       in case M.lookup key transMap of
            Just übersetzterText ->
              let cleanText = T.strip übersetzterText
              in case node of
                PlainText _ labelPart -> 
                  let lbl = fromMaybe "" labelPart
                  in cleanText <> (if T.null lbl then "" else " " <> lbl)
                Heading lvl _ labelPart -> 
                  let lbl = fromMaybe "" labelPart
                  in T.replicate lvl "=" <> " " <> cleanText <> (if T.null lbl then "" else " " <> lbl)
                CustomFunction fname args labelPart ->
                  let lbl = fromMaybe "" labelPart
                      -- HIER AUCH ANPASSEN:
                      bracketOpen = if "(" `T.isInfixOf` rawLine then "(" else "["
                      bracketClose = if ")" `T.isInfixOf` rawLine then ")" else "]"
                      formattedArgs =
                        if bracketOpen == "(" && not ("\"" `T.isPrefixOf` cleanText)
                          then "\"" <> cleanText <> "\""
                          else cleanText
                   in "#" <> fname <> bracketOpen <> formattedArgs <> bracketClose <> (if T.null lbl then "" else " " <> lbl)
            Nothing -> rawLine
            
    ersetzeZeile _ (_, Nothing, rawLine) = rawLine


main :: IO ()
main = do
  args <- getArgs
  let ruVerzeichnis = "C:\\Users\\marcg\\Documents\\projects\\arepjev-buecher-typst\\buch_1_ru"
      omegaTSourceDir = "C:\\Users\\marcg\\Documents\\projects\\typst-omegat\\source"
      omegaTTargetDir = "C:\\Users\\marcg\\Documents\\projects\\typst-omegat\\target"
      deVerzeichnis = "C:\\Users\\marcg\\Documents\\projects\\arepjev-buecher-typst\\buch_1_de"

  rules <- loadRules "rules.yaml"
  allFiles <- listDirectory ruVerzeichnis
  let typFiles = filter (\f -> takeExtension f == ".typ") allFiles

  case args of
    ["--export"] -> do
      putStrLn "=== BATCH EXPORT FÜR OMEGAT (IN SOURCE) STARTEN ==="
      mapM_ (processFile rules "--export" ruVerzeichnis omegaTSourceDir omegaTTargetDir deVerzeichnis) typFiles
      putStrLn "=== BATCH EXPORT ABGESCHLOSSEN ==="
    ["--import"] -> do
      putStrLn "=== BATCH IMPORT AUS OMEGAT (AUS TARGET) STARTEN ==="
      mapM_ (processFile rules "--import" ruVerzeichnis omegaTSourceDir omegaTTargetDir deVerzeichnis) typFiles
      putStrLn "=== BATCH TRANSFORMATION ABGESCHLOSSEN ==="
    _ -> do
      putStrLn "Bitte Modus angeben:"
      putStrLn "  stack run -- --export"
      putStrLn "  stack run -- --import"
