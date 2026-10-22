module Distribution.CabalSourceRepoUpdate where

import Distribution.Fields qualified as C
import qualified Data.ByteString as BS
import Data.ByteString (ByteString)
import qualified Distribution.Parsec.Position as C


type Location = ByteString

type Tag = ByteString

-- | Line number
type TagPos = Int

-- | source-repository-package with optional update
data SRP = SRP
  { location :: Location
  , tag :: Tag
  , tagPos :: TagPos
  , newTag :: Maybe Tag
  }

-- Extract SRPs from cabal.project
extract :: [C.Field C.Position] -> [SRP]
extract = undefined

-- | Query repo for latest tag
update :: SRP -> IO SRP
update = undefined

-- | Pretty prints SRP changes, with output like:
--     The following packages will be updated
--       <location1: <old_tag> -> <new_tag>
--       <location2>: <old_tag> -> <new_tag>
prettyChanges :: [SRP] -> String
prettyChanges = undefined

-- Replace SRP tags with new tags in raw cabal.project
replace :: ByteString -> [SRP] -> ByteString
replace = undefined

main :: IO ()
main = do
  contents <- BS.readFile "cabal.project"
  let Right fields = C.readFields contents
  let srps = extract fields
  srps' <- traverse update srps
  putStrLn $ prettyChanges srps'
  BS.writeFile "cabal.project" $ replace contents srps'
