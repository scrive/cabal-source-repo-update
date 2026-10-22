{-# LANGUAGE OverloadedStrings #-}
module Distribution.CabalSourceRepoUpdate where

import Distribution.Fields qualified as C
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS
import Data.ByteString (ByteString)
import qualified Distribution.Parsec.Position as C
import Data.List.Extra (firstJust)
import Data.Maybe (mapMaybe)


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
extract = mapMaybe fieldToSRP

fieldToSRP :: C.Field C.Position -> Maybe SRP
fieldToSRP (C.Section (C.Name _ "source-repository-package") _ fields) =
  stanzaToSRP fields
fieldToSRP _ = Nothing

fieldLinesPos :: [C.FieldLine C.Position] -> TagPos
fieldLinesPos [C.FieldLine (C.Position lineNumber _) _] = lineNumber
fieldLinesPos _ = error "multiline fields are not supported yet"

fieldLineValue :: C.FieldLine ann -> ByteString
fieldLineValue (C.FieldLine _ bs) = bs

fieldLinesValue :: [C.FieldLine ann] -> ByteString
fieldLinesValue = BS.unlines . fmap fieldLineValue

stanzaToSRP :: [C.Field C.Position] -> Maybe SRP
stanzaToSRP fs = SRP
  <$> fmap fieldLinesValue locField
  <*> fmap fieldLinesValue tagField
  <*> fmap fieldLinesPos tagField
  <*> pure Nothing
  where
    locField = findField "location" fs
    tagField = findField "tag" fs

findField :: C.FieldName -> [C.Field ann] -> Maybe [C.FieldLine ann]
findField fn = firstJust f
  where
    f (C.Field (C.Name _ fn') fieldLines) | fn == fn' = Just fieldLines
    f _ = Nothing

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
