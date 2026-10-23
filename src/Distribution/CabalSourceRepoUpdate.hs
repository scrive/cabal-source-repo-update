{-# LANGUAGE OverloadedStrings #-}
module Distribution.CabalSourceRepoUpdate
( Location
, Tag
, SRP (..)
, extract
, update
, prettyChanges
, replace
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
import System.Process.Typed (readProcessStdout_, proc)


type Location = ByteString

type Tag = ByteString

-- | source-repository-package with optional update
data SRP = SRP
  { location :: Location
  , tag :: Tag
  , tagPos :: C.Position
  , newTag :: Maybe Tag
  }
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
update srp = do
  BS.putStrLn $ "Checking " <> location srp
  newTag <- fetchHeadHash $ location srp
  pure $ srp { newTag = Just newTag }

fetchHeadHash :: Location -> IO Tag
fetchHeadHash loc = do
  let args = ["ls-remote", fromUTF8BS loc, "HEAD"]
  output <- readProcessStdout_ $ proc "git" args
  case BS.words $ BS.toStrict output of
    hash:_ -> pure hash
    [] -> die $ "Failed to parse output of git " <> unwords args

-- | Pretty prints SRP changes, with output like:
--     The following packages will be updated
--       <location1: <old_tag> -> <new_tag>
--       <location2>: <old_tag> -> <new_tag>
prettyChanges :: [SRP] -> ByteString
prettyChanges srps = "The following packages will be updated:\n"
  <> foldMap prettyChange srps
  where
    prettyChange SRP { location, tag, newTag = Just newTag } =
      "  " <> location <> " " <> tag <> " -> " <> newTag <> "\n"
    prettyChange _ = ""

-- Replace SRP tags with new tags in raw cabal.project
replace :: [SRP] -> ByteString -> ByteString
replace srps = BS.unlines . fmap f . zip [1..] . BS.lines
  where
    f (lineNum, line) = case Map.lookup lineNum newTags of
      Nothing -> line
      Just (col, newTag) -> BS.take (pred col) line <> newTag
    newTags = newTagsByLine srps

newTagsByLine :: [SRP] -> Map Int (Int, Tag)
newTagsByLine = foldl' addTag Map.empty
  where
    addTag m SRP { tagPos = C.Position line col, newTag = Just newTag } = Map.insert line (col, newTag) m
    addTag m _ = m
