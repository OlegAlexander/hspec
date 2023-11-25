module Test.Hspec.Api.Extension.V1.Spec (
  mapItems
) where

import           Prelude ()

import           Test.Hspec.Core.Spec

mapItems :: (Item a -> Item b) -> SpecWith a -> SpecWith b
mapItems = mapSpecItem_
