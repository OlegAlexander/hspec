module Test.Hspec.Runners where

-- | This module contains the runners that take a set of specs, evaluate their examples, and
-- report to a given handle.
--
import Test.Hspec.Core
import Test.Hspec.Formatters
import System.IO
import System.CPUTime (getCPUTime)
import Control.Monad (when)


-- | Evaluate and print the result of checking the spec examples.
runFormatter :: Formatter -> Handle -> String -> [String] -> [IO Spec] -> IO [Spec]
runFormatter formatter h _     errors []     = do
  errorsFormatter formatter h (reverse errors)
  return []
runFormatter formatter h group errors (iospec:ioss) = do
  spec <- iospec
  when (group /= name spec) (exampleGroupStarted formatter h spec)
  case result spec of
    (Success  ) -> examplePassed formatter h spec errors
    (Fail _   ) -> exampleFailed formatter h spec errors
    (Pending _) -> examplePending formatter h spec errors
  let errors' = if isFailure (result spec)
                then errorDetails spec (length errors) : errors
                else errors
  specs <- runFormatter formatter h (name spec) errors' ioss
  return $ specs ++ [spec]

errorDetails :: Spec -> Int -> String
errorDetails spec i = case result spec of
  (Fail s   ) -> concat [ show (i + 1), ") ", name spec, " ",  requirement spec, " FAILED", if null s then "" else "\n" ++ s ]
  _           -> ""


-- | Create a document of the given specs and write it to stdout.
hspec :: IO [IO Spec] -> IO [Spec]
hspec ss = hHspec stdout ss

-- | Create a document of the given specs and write it to the given handle.
--
-- > writeReport filename specs = withFile filename WriteMode (\ h -> hHspec h specs)
--
hHspec :: Handle     -- ^ A handle for the stream you want to write to.
       -> IO [IO Spec]  -- ^ The specs you are interested in.
       -> IO [Spec]
hHspec h = hHspecWithFormat (specdoc $ h == stdout) h

-- | Create a document of the given specs and write it to the given handle.
-- THIS IS LIKELY TO CHANGE
hHspecWithFormat :: Formatter
                 -> Handle     -- ^ A handle for the stream you want to write to.
                 -> IO [IO Spec]  -- ^ The specs you are interested in.
                 -> IO [Spec]
hHspecWithFormat formatter h ss = do
  t0 <- getCPUTime
  ioSpecList <- ss
  specList <- (runFormatter formatter) h "" [] ioSpecList
  t1 <- getCPUTime
  let runTime = ((fromIntegral $ t1 - t0) / (10.0^(12::Integer)) :: Double)
  (footerFormatter formatter) h specList runTime
  return specList

