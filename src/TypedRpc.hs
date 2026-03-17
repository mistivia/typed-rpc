{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module TypedRpc
    ( ApiCmd
    , Apis
    , Service(..)
    , service
    , api
    , handleRequest
    , makeApplication
    , JsonRpcRequest(..)
    , JsonRpcResponse(..)
    ) where

import Data.Aeson
    ( FromJSON(..) , ToJSON(..)
    , Value(..) , Result(..)
    , fromJSON, withObject, eitherDecode, encode
    , object
    , (.=), (.:), (.:?)
    )
import Data.Text qualified as T
import Data.Text.Encoding qualified as T
import Data.Kind (Constraint, Type)
import Data.Proxy (Proxy(..))
import Data.Text (Text)
import GHC.TypeError (TypeError, ErrorMessage(..))
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Network.Wai qualified as Wai
import Network.HTTP.Types.Status qualified as Status
import Data.ByteString.Lazy.Char8 qualified as BLC

data JsonRpcRequest = JsonRpcRequest
    { jrJsonrpc :: !Text
    , jrMethod :: !Text
    , jrParams :: !Value
    , jrId :: !(Maybe Integer)
    } deriving (Show, Eq)

instance FromJSON JsonRpcRequest where
    parseJSON = withObject "JsonRpcRequest" $ \v ->
        JsonRpcRequest
            <$> v .: "jsonrpc"
            <*> v .: "method"
            <*> v .: "params"
            <*> v .:? "id"

data JsonRpcResponse = JsonRpcResponse
    { jrpJsonrpc :: !Text
    , jrpResult :: !Value
    , jrpId :: !(Maybe Integer)
    } deriving (Show, Eq)

instance ToJSON JsonRpcResponse where
    toJSON resp = object
        [ "jsonrpc" .= jrpJsonrpc resp
        , "result" .= jrpResult resp
        , "id" .= maybe Null (Number . fromInteger) (jrpId resp)
        ]

-- | Type family to check if a name already exists in the list of ApiCmds
type family NameInApiCmds (name :: Symbol) (cmds :: [Type]) :: Bool where
    NameInApiCmds _ '[] = 'False
    NameInApiCmds name (ApiCmd name _ _ ': _) = 'True
    NameInApiCmds name (_ ': rest) = NameInApiCmds name rest

-- | Constraint that fails with a type error if name is already in cmds
type family NameNotInApiCmds (name :: Symbol) (cmds :: [Type]) :: Constraint where
    NameNotInApiCmds name cmds = NameNotInApiCmdsImpl (NameInApiCmds name cmds) name

type family NameNotInApiCmdsImpl (found :: Bool) (name :: Symbol) :: Constraint where
    NameNotInApiCmdsImpl 'False _ = ()
    NameNotInApiCmdsImpl 'True name =
        TypeError ('Text "Duplicate API name: " ':<>: 'ShowType name)

data ApiCmd (name :: Symbol) ain aout

data Apis (cmds :: [Type])

data Service apis where
    SrvNil :: Service (Apis '[])
    SrvCons ::
        (FromJSON ain, ToJSON aout) =>
        (Wai.Request -> ain -> IO (Either (Int, Text) aout)) ->
        Service (Apis cmds) ->
        Service (Apis (ApiCmd name ain aout ': cmds))

service :: (Service (Apis '[]) -> Service apis) -> Service apis
service build = build SrvNil

api ::
    forall name ain aout cmds.
    (FromJSON ain, ToJSON aout, NameNotInApiCmds name cmds) =>
    (Wai.Request -> ain -> IO (Either (Int, Text) aout)) ->
    Service (Apis cmds) ->
    Service (Apis (ApiCmd name ain aout ': cmds))
api handler rest = SrvCons handler rest

-- | Main entry point: dispatch by runtime comparison
handleRequest ::
    forall apis.
    HandleRequestImpl apis =>
    Service (Apis apis)
    -> Text
    -> Wai.Request
    -> Value
    -> IO (Either (Int, Text) Value)
handleRequest srv methodName req body =
    handleRequestImpl @apis methodName srv req body

-- | Try each element in order
class HandleRequestImpl (apis :: [Type]) where
    handleRequestImpl ::
        Text
        -> Service (Apis apis)
        -> Wai.Request
        -> Value
        -> IO (Either (Int, Text) Value)

instance HandleRequestImpl '[] where
    handleRequestImpl methodName _ _ _ =
        pure $ Left (404, "Method not found: " <> methodName)

instance
    ( FromJSON ain
    , ToJSON aout
    , KnownSymbol name
    , HandleRequestImpl rest
    ) => HandleRequestImpl (ApiCmd name ain aout ': rest) where
    handleRequestImpl methodName (SrvCons handler rest) req body =
        if methodName == T.pack (symbolVal (Proxy @name))
        then case fromJSON @ain body of
            Error err -> pure $ Left (400, "Invalid JSON input: " <> T.pack err)
            Success input -> do
                result <- handler req input
                pure $ case result of
                    Left err -> Left err
                    Right out -> Right (toJSON out)
        else handleRequestImpl @rest methodName rest req body

-- | Create a WAI Application from a Service
makeApplication :: forall apis.
    HandleRequestImpl apis =>
    Service (Apis apis)
    -> Wai.Application
makeApplication service' request respond = do
    body <- Wai.strictRequestBody request
    case eitherDecode @JsonRpcRequest body of
        Left err -> respond $ Wai.responseLBS
            Status.status400
            []
            (BLC.pack $ "Invalid JSON: " ++ err)
        Right jrRequest -> do
            result <- handleRequest @apis service' (jrMethod jrRequest) request (jrParams jrRequest)
            case result of
                Left (code, errMsg) ->
                    let httpStatus = if code >= 400 && code < 600
                            then Status.mkStatus code (T.encodeUtf8 errMsg)
                            else Status.status500
                    in respond $ Wai.responseLBS
                        httpStatus
                        []
                        (BLC.pack $ T.unpack errMsg)
                Right val -> do
                    let response = JsonRpcResponse
                            { jrpJsonrpc = "2.0"
                            , jrpResult = val
                            , jrpId = jrId jrRequest
                            }
                    respond $ Wai.responseLBS
                        Status.status200
                        [("Content-Type", "application/json")]
                        (encode response)

