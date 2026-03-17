{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module TypedRpc
    ( ApiCmd
    , Apis
    , Service(..)
    , service
    , api
    , handleRequest
    ) where

import Data.Aeson (FromJSON, ToJSON, decode, encode)
import Data.ByteString.Lazy (ByteString)
import Data.Kind (Type)
import Data.Proxy (Proxy(..))
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Network.Wai qualified as Wai

data ApiCmd (name :: Symbol) ain aout

data Apis (cmds :: [Type])

data Service apis where
    SrvNil :: Service (Apis '[])
    SrvCons ::
        (FromJSON ain, ToJSON aout) =>
        (Wai.Request -> ain -> IO (Either (Int, String) aout)) ->
        Service (Apis cmds) ->
        Service (Apis (ApiCmd name ain aout ': cmds))

service :: (Service (Apis '[]) -> Service apis) -> Service apis
service build = build SrvNil

api ::
    forall name ain aout cmds.
    (FromJSON ain, ToJSON aout) =>
    (Wai.Request -> ain -> IO (Either (Int, String) aout)) ->
    Service (Apis cmds) ->
    Service (Apis (ApiCmd name ain aout ': cmds))
api handler rest = SrvCons handler rest

-- | Main entry point: dispatch by runtime comparison
handleRequest ::
    forall apis.
    HandleRequestImpl apis =>
    Service (Apis apis)
    -> String
    -> Wai.Request
    -> ByteString
    -> IO (Either (Int, String) ByteString)
handleRequest srv methodName req body =
    handleRequestImpl @apis methodName srv req body

-- | Try each element in order
class HandleRequestImpl (apis :: [Type]) where
    handleRequestImpl ::
        String
        -> Service (Apis apis)
        -> Wai.Request
        -> ByteString
        -> IO (Either (Int, String) ByteString)

instance HandleRequestImpl '[] where
    handleRequestImpl methodName _ _ _ =
        pure $ Left (400, "Method not found: " ++ methodName)

instance
    ( FromJSON ain
    , ToJSON aout
    , KnownSymbol name
    , HandleRequestImpl rest
    ) => HandleRequestImpl (ApiCmd name ain aout ': rest) where
    handleRequestImpl methodName (SrvCons handler rest) req body =
        if methodName == symbolVal (Proxy @name)
        then case decode body of
            Nothing -> pure $ Left (400, "Invalid JSON input")
            Just input -> do
                result <- handler req input
                pure $ case result of
                    Left err -> Left err
                    Right out -> Right (encode out)
        else handleRequestImpl @rest methodName rest req body

