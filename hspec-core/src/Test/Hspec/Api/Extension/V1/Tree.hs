module Test.Hspec.Api.Extension.V1.Tree (
  SpecTree
, mapItems
, filterItems
) where

import           Prelude ()
import           Test.Hspec.Core.Compat

import           Test.Hspec.Core.Spec

mapItems :: (Item () -> Item ()) -> [SpecTree ()] -> [SpecTree ()]
mapItems = bimapForest id

filterItems :: (Item () -> Bool) -> [SpecTree ()] -> [SpecTree ()]
filterItems = filterForest
