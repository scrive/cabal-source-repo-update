module Main (main) where

import Distribution.CabalSourceRepoUpdate
import Distribution.Fields qualified as C
import Data.ByteString qualified as BS
import System.Exit (exitFailure)
import System.Environment (getArgs)

main :: IO ()
main = do
  args <- getArgs
  projectFile <- case args of
    [fileName] -> pure fileName
    [] -> pure "cabal.project"
    _ -> do
      putStrLn "usage: cabal-source-repo-update [<project file>]"
      exitFailure
  contents <- BS.readFile projectFile
  let Right fields = C.readFields contents
  let srps = extract fields
  srps' <- traverse update srps
  BS.putStr $ prettyChanges srps'
  BS.writeFile projectFile $ replace srps' contents
