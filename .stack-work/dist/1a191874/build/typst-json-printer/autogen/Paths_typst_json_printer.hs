{-# LANGUAGE CPP #-}
{-# LANGUAGE NoRebindableSyntax #-}
#if __GLASGOW_HASKELL__ >= 810
{-# OPTIONS_GHC -Wno-prepositive-qualified-module #-}
#endif
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module Paths_typst_json_printer (
    version,
    getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where


import qualified Control.Exception as Exception
import qualified Data.List as List
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude


#if defined(VERSION_base)

#if MIN_VERSION_base(4,0,0)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#else
catchIO :: IO a -> (Exception.Exception -> IO a) -> IO a
#endif

#else
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#endif
catchIO = Exception.catch

version :: Version
version = Version [0,1,0,0] []

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir `joinFileName` name)

getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath




bindir, libdir, dynlibdir, datadir, libexecdir, sysconfdir :: FilePath
bindir     = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\bin"
libdir     = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\lib\\x86_64-windows-ghc-9.10.3-b42a\\typst-json-printer-0.1.0.0-2O3eY3CNFHhCZoR2TVxYUm-typst-json-printer"
dynlibdir  = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\lib\\x86_64-windows-ghc-9.10.3-b42a"
datadir    = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\share\\x86_64-windows-ghc-9.10.3-b42a\\typst-json-printer-0.1.0.0"
libexecdir = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\libexec\\x86_64-windows-ghc-9.10.3-b42a\\typst-json-printer-0.1.0.0"
sysconfdir = "C:\\Users\\marcg\\Documents\\projects\\typst-json-printer\\.stack-work\\install\\37b31142\\etc"

getBinDir     = catchIO (getEnv "typst_json_printer_bindir")     (\_ -> return bindir)
getLibDir     = catchIO (getEnv "typst_json_printer_libdir")     (\_ -> return libdir)
getDynLibDir  = catchIO (getEnv "typst_json_printer_dynlibdir")  (\_ -> return dynlibdir)
getDataDir    = catchIO (getEnv "typst_json_printer_datadir")    (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "typst_json_printer_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "typst_json_printer_sysconfdir") (\_ -> return sysconfdir)



joinFileName :: String -> String -> FilePath
joinFileName ""  fname = fname
joinFileName "." fname = fname
joinFileName dir ""    = dir
joinFileName dir fname
  | isPathSeparator (List.last dir) = dir ++ fname
  | otherwise                       = dir ++ pathSeparator : fname

pathSeparator :: Char
pathSeparator = '\\'

isPathSeparator :: Char -> Bool
isPathSeparator c = c == '/' || c == '\\'
