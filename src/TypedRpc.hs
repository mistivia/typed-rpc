module TypedRpc
    ( ApiCmd
    , Api
    , Service(..)
    , service
    , api
    ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Kind (Type)
import GHC.TypeLits (Symbol)
import Network.Wai qualified as Wai

data ApiCmd (name :: Symbol) ain aout

data Api (cmds :: [Type])

data Service api where
    SrvNil :: Service (Api '[])
    SrvCons ::
        (FromJSON ain, ToJSON aout) =>
        (Wai.Request -> ain -> IO (Either (Int, String) aout)) ->
        Service (Api cmds) ->
        Service (Api (ApiCmd name ain aout ': cmds))

service :: (Service (Api '[]) -> Service api) -> Service api
service build = build SrvNil

api ::
    forall name ain aout cmds.
    (FromJSON ain, ToJSON aout) =>
    (Wai.Request -> ain -> IO (Either (Int, String) aout)) ->
    Service (Api cmds) ->
    Service (Api (ApiCmd name ain aout ': cmds))
api handler rest = SrvCons handler rest
