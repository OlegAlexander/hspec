module Test.Hspec.Api.Extension.V1.Item (
  Item
, isFocused
, pending
, pendingWith
, getAnnotation
, setAnnotation
) where

import           Prelude ()
import           Test.Hspec.Core.Compat

import           Test.Hspec.Core.Spec hiding (pending, pendingWith)
import           Test.Hspec.Core.Tree hiding (filterForest)

isFocused :: Item a -> Bool
isFocused = itemIsFocused

pending :: Item a -> Item a
pending item = item { itemExample = \ _params _hook _progress -> result }
  where
    result :: IO Result
    result = return $ Result "" (Pending Nothing Nothing)

pendingWith :: String -> Item a -> Item a
pendingWith reason item = item { itemExample = \ _params _hook _progress -> result }
  where
    result :: IO Result
    result = return $ Result "" (Pending Nothing (Just reason))

getAnnotation :: Typeable value => Item a -> Maybe value
getAnnotation = getItemAnnotation

setAnnotation :: Typeable value => value -> Item a -> Item a
setAnnotation = setItemAnnotation
