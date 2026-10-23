{-# LANGUAGE OverloadedStrings #-}
module Distribution.CabalSourceRepoUpdate
( Location
, Tag
, SRP (..)
, extract
, update
, prettyPatches
, applyPatches
) where

import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.ByteString.Char8 qualified as BS
import Data.List.Extra (firstJust)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Distribution.Fields qualified as C
import Distribution.Parsec.Position qualified as C
import Distribution.Utils.Generic (fromUTF8BS)
import System.Exit (die)
import System.IO (stderr)
import System.Process.Typed (readProcessStdout_, proc)


type Location = ByteString

type Tag = ByteString

-- | The @source-repository-package@ info we need
data SRP = SRP
  { location :: Location
  , tag :: Tag
  , tagPos :: C.Position
  , tagPattern :: Maybe ByteString
  }
  deriving Show

-- | A 'SRP' where the 'Tag' has to be replaced with the provided one
data Patch = Patch SRP Tag
  deriving Show

-- Extract SRPs from cabal.project
extract :: [C.Field C.Position] -> [SRP]
extract = mapMaybe fieldToSRP

fieldToSRP :: C.Field C.Position -> Maybe SRP
fieldToSRP (C.Section (C.Name _ "source-repository-package") _ fields)
  | fmap fieldLinesValue (findField "x-update" fields) == Just "true"
  = stanzaToSRP fields
fieldToSRP _ = Nothing

fieldLinesPos :: [C.FieldLine C.Position] -> C.Position
fieldLinesPos [C.FieldLine pos _] = pos
fieldLinesPos _ = error "multiline fields are not supported yet"

fieldLineValue :: C.FieldLine ann -> ByteString
fieldLineValue (C.FieldLine _ bs) = bs

fieldLinesValue :: [C.FieldLine ann] -> ByteString
fieldLinesValue = BS.intercalate "\n" . fmap fieldLineValue

stanzaToSRP :: [C.Field C.Position] -> Maybe SRP
stanzaToSRP fs = SRP
  <$> fmap fieldLinesValue locField
  <*> fmap fieldLinesValue tagField
  <*> fmap fieldLinesPos tagField
  <*> pure (fmap fieldLinesValue tagPatternField)
  where
    locField = findField "location" fs
    tagField = findField "tag" fs
    tagPatternField = findField "x-tag-pattern" fs

findField :: C.FieldName -> [C.Field ann] -> Maybe [C.FieldLine ann]
findField fn = firstJust f
  where
    f (C.Field (C.Name _ fn') fieldLines) | fn == fn' = Just fieldLines
    f _ = Nothing

-- | Query repo for latest tag
update :: SRP -> IO (Maybe Patch)
update srp@SRP {location, tagPattern} = do
  BS.hPutStrLn stderr $ "ℹ️ Checking " <> location
  newTag <- fetchHeadHash location tagPattern
  pure $ if newTag == tag srp then Nothing else Just $ Patch srp newTag

fetchHeadHash :: Location -> Maybe ByteString -> IO Tag
fetchHeadHash loc pattern = do
  let args = ["ls-remote", "--sort=-v:refname", "--end-of-options", fromUTF8BS loc]
        ++ maybe ["HEAD"] ((:[]) . fromUTF8BS) pattern
  output <- readProcessStdout_ $ proc "git" args
  case BS.words $ BS.toStrict output of
    hash:_ -> pure hash
    [] -> die $ "Failed to parse output of git " <> unwords args

-- | Pretty prints SRP changes, with output like:
--     The following packages will be updated
--       <location1: <old_tag> -> <new_tag>
--       <location2>: <old_tag> -> <new_tag>
prettyPatches :: [Patch] -> ByteString
prettyPatches srps = "The following packages will be updated:\n"
  <> foldMap prettyChange srps
  where
    prettyChange (Patch SRP { location, tag } newTag) =
      "  " <> location <> " " <> tag <> " -> " <> newTag <> "\n"

-- Replace SRP tags with new tags in raw cabal.project
applyPatches :: [Patch] -> ByteString -> ByteString
applyPatches srps = BS.unlines . fmap f . zip [1..] . BS.lines
  where
    f (lineNum, line) = case Map.lookup lineNum newTags of
      Nothing -> line
      Just (col, newTag) -> BS.take (pred col) line <> newTag
    newTags = newTagsByLine srps

newTagsByLine :: [Patch] -> Map Int (Int, Tag)
newTagsByLine = foldl' addTag Map.empty
  where
    addTag m (Patch SRP { tagPos = C.Position line col } newTag) =
      Map.insert line (col, newTag) m
