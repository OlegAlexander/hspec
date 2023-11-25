module Test.Hspec.Api.Extension.V1 (
  Item
, SpecWith
, SpecTree

, runIO
, addTransformation

, Option
, flag
, option
, argument
, registerOption

, Config
, modifyConfig
, Config.getConfigAnnotation
, Config.setConfigAnnotation
) where

import           Prelude ()
import           Test.Hspec.Core.Compat

import qualified GetOpt.Declarative as Config
import           Test.Hspec.Core.Spec hiding (filterForest, mapSpecItem)
import           Test.Hspec.Core.Config.Definition (Config)
import qualified Test.Hspec.Core.Config.Definition as Config

type Option = Config.Option Config
type OptionSetter = Config.OptionSetter Config

flag :: String -> (Bool -> Config -> Config) -> String -> Option
flag name setter = Config.flag name setter

option :: String -> OptionSetter -> String -> Option
option = Config.option

argument :: String -> (String -> Maybe a) -> (a -> Config -> Config) -> OptionSetter
argument = Config.argument

registerOption :: String -> Option -> SpecWith a
registerOption section = modifyConfig . Config.addExtensionOptions section . return

addTransformation :: (Config -> [SpecTree ()] -> [SpecTree ()]) -> SpecWith a
addTransformation = modifyConfig . Config.addSpecTransformation
