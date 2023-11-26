{-# LANGUAGE CPP #-}
module Test.Hspec.Core.Config (
  Config (..)
, ColorMode(..)
, UnicodeMode(..)
, defaultConfig
, readConfig
, configAddFilter

, readFailureReportOnRerun
, applyFailureReport
#ifdef TEST
, readConfigFiles
#endif
) where

import           Prelude ()
import           Test.Hspec.Core.Compat

import           GHC.IO.Exception (IOErrorType(UnsupportedOperation))
import           System.IO
import           System.IO.Error
import           System.Exit
import           System.FilePath
import           System.Directory
import           System.Environment (getProgName, getEnvironment)

import           Test.Hspec.Core.Util
import           Test.Hspec.Core.Config.Options
import           Test.Hspec.Core.Config.Definition (Config(..), ColorMode(..), UnicodeMode(..), mkDefaultConfig, filterOr)
import           Test.Hspec.Core.FailureReport
import qualified Test.Hspec.Core.Formatters.V2 as V2
import           Test.Hspec.Core.Example.Options
import           Test.Hspec.Core.Example

defaultConfig :: Config
defaultConfig = mkDefaultConfig $ map (fmap V2.formatterToFormat) [
    ("checks", V2.checks)
  , ("specdoc", V2.specdoc)
  , ("progress", V2.progress)
  , ("failed-examples", V2.failed_examples)
  , ("silent", V2.silent)
  ]

-- | Add a filter predicate to config.  If there is already a filter predicate,
-- then combine them with `||`.
configAddFilter :: (Path -> Bool) -> Config -> Config
configAddFilter p1 c = c {
    configFilterPredicate = Just p1 `filterOr` configFilterPredicate c
  }

applyFailureReport :: Maybe FailureReport -> Config -> Config
applyFailureReport mFailureReport opts = opts {
    configFilterPredicate = matchFilter `filterOr` rerunFilter
  , configValues = setOptions foo options__
  }
  where
    options__ = configValues opts
    qopts :: QuickCheckOptions
    qopts = getOptions options__

    foo = qopts {
      qMaxSuccess = mMaxSuccess
    , qMaxSize = mMaxSize
    , qMaxDiscardRatio = mMaxDiscardRatio
    , qSeed = mSeed
    }

    mSeed = qSeed qopts <|> (failureReportSeed <$> mFailureReport)
    mMaxSuccess = qMaxSuccess qopts <|> (failureReportMaxSuccess <$> mFailureReport)
    mMaxSize = qMaxSize qopts <|> (failureReportMaxSize <$> mFailureReport)
    mMaxDiscardRatio = qMaxDiscardRatio qopts <|> (failureReportMaxDiscardRatio <$> mFailureReport)

    matchFilter = configFilterPredicate opts

    rerunFilter = case failureReportPaths <$> mFailureReport of
      Just [] -> Nothing
      Just xs -> Just (`elem` xs)
      Nothing -> Nothing

-- |
-- `readConfig` parses config options from several sources and constructs a
-- `Config` value.  It takes options from:
--
-- 1. @~/.hspec@ (a config file in the user's home directory)
-- 1. @.hspec@ (a config file in the current working directory)
-- 1. [environment variables starting with @HSPEC_@](https://hspec.github.io/options.html#specifying-options-through-environment-variables)
-- 1. the provided list of command-line options (the second argument to @readConfig@)
--
-- (precedence from low to high)
--
-- When parsing fails then @readConfig@ writes an error message to `stderr` and
-- exits with `exitFailure`.
--
-- When @--help@ is provided as a command-line option then @readConfig@ writes
-- a help message to `stdout` and exits with `exitSuccess`.
--
-- A common way to use @readConfig@ is:
--
-- @
-- `System.Environment.getArgs` >>= readConfig `defaultConfig`
-- @
readConfig :: Config -> [String] -> IO Config
readConfig opts_ args = do
  prog <- getProgName
  configFiles <- do
    ignore <- ignoreConfigFile opts_ args
    case ignore of
      True -> return []
      False -> readConfigFiles
  env <- getEnvironment
  let envVar = words <$> lookup envVarName env
  case parseOptions opts_ prog configFiles envVar env args of
    Left (err, msg) -> exitWithMessage err msg
    Right (warnings, opts) -> do
      mapM_ (hPutStrLn stderr) warnings
      return opts

readFailureReportOnRerun :: Config -> IO (Maybe FailureReport)
readFailureReportOnRerun config
  | configRerun config = readFailureReport config
  | otherwise = return Nothing

readConfigFiles :: IO [ConfigFile]
readConfigFiles = do
  global <- readGlobalConfigFile
  local <- readLocalConfigFile
  return $ catMaybes [global, local]

readGlobalConfigFile :: IO (Maybe ConfigFile)
readGlobalConfigFile = do
  mHome <- tryJust (guard . isPotentialHomeDirError) getHomeDirectory
  case mHome of
    Left _ -> return Nothing
    Right home -> readConfigFile (home </> ".hspec")
  where
    isPotentialHomeDirError e =
      isDoesNotExistError e || ioeGetErrorType e == UnsupportedOperation

readLocalConfigFile :: IO (Maybe ConfigFile)
readLocalConfigFile = do
  mName <- tryJust (guard . isDoesNotExistError) (canonicalizePath ".hspec")
  case mName of
    Left _ -> return Nothing
    Right name -> readConfigFile name

readConfigFile :: FilePath -> IO (Maybe ConfigFile)
readConfigFile name = do
  exists <- doesFileExist name
  if exists then Just . (,) name . unescapeArgs <$> readFile name else return Nothing

exitWithMessage :: ExitCode -> String -> IO a
exitWithMessage err msg = do
  hPutStr h msg
  exitWith err
  where
    h = case err of
      ExitSuccess -> stdout
      _           -> stderr
