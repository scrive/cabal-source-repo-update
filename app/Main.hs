module Main (main) where

import Control.Monad (when)
import Control.Monad.Extra (mapMaybeM)
import Data.ByteString qualified as BS
import Distribution.CabalSourceRepoUpdate
import Distribution.Fields qualified as C
import System.Environment (getArgs)
import System.IO (stderr, hPutStrLn)
import System.Exit (exitFailure)

main :: IO ()
main = do
  args <- getArgs
  projectFile <- case args of
    [fileName] -> pure fileName
    [] -> pure "cabal.project"
    _ -> do
      hPutStrLn stderr "usage: cabal-source-repo-update [<project file>]"
      exitFailure
  contents <- BS.readFile projectFile
  let Right fields = C.readFields contents
  let srps = extract fields
  when (null srps) $
    hPutStrLn stderr "⚠️ Warning: no top-level source-repository-packages marked with `x-update: true` found."
  patches <- mapMaybeM update srps
  BS.hPutStr stderr $ prettyPatches patches
  BS.writeFile projectFile $ applyPatches patches contents
