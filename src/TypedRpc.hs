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
    , TypedRpcResp
    ) where

import Data.Aeson
    ( FromJSON(..) , ToJSON(..)
    , Value(..) , Result(..)
    , fromJSON, withObject, eitherDecode, encode
    , object
    , (.=), (.:), (.:?)
    )
import Data.Text qualified as T
import Data.Kind (Constraint, Type)
import Data.Proxy (Proxy(..))
import Data.Text (Text)
import GHC.TypeError (TypeError, ErrorMessage(..))
import GHC.TypeLits (KnownSymbol, Symbol, symbolVal)
import Network.Wai qualified as Wai
import Network.HTTP.Types qualified

contentTypeJson :: Network.HTTP.Types.Header
contentTypeJson = ("Content-Type", "application/json")

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

data JsonRpcErrorResp = JsonRpcErrorResp
    { jreJsonrpc :: !Text
    , jreError :: !JsonRpcError
    , jreId :: !(Maybe Integer)
    } deriving (Show, Eq)

data JsonRpcError = JsonRpcError
    { jreCode :: !Int
    , jreMessage :: !Text
    } deriving (Show, Eq)

instance ToJSON JsonRpcError where
    toJSON err = object
        [ "code" .= jreCode err
        , "message" .= jreMessage err
        ]

instance ToJSON JsonRpcErrorResp where
    toJSON resp = object
        [ "jsonrpc" .= jreJsonrpc resp
        , "error" .= jreError resp
        , "id" .= maybe Null (Number . fromInteger) (jreId resp)
        ]

mkErrorResp :: Int -> Text -> Maybe Integer -> JsonRpcErrorResp
mkErrorResp code errMsg reqId = JsonRpcErrorResp
    { jreJsonrpc = "2.0"
    , jreError = JsonRpcError
        { jreCode = code
        , jreMessage = errMsg
        }
    , jreId = reqId
    }

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
    SrvCons :: (FromJSON ain, ToJSON aout, NameNotInApiCmds name cmds) =>
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
        pure $ Left (-32601, "Method not found: " <> methodName)

instance
    ( FromJSON ain
    , ToJSON aout
    , KnownSymbol name
    , HandleRequestImpl rest
    ) => HandleRequestImpl (ApiCmd name ain aout ': rest) where
    handleRequestImpl methodName (SrvCons handler rest) req body =
        if methodName == T.pack (symbolVal (Proxy @name))
        then case fromJSON @ain body of
            Error err -> pure $ Left (-32602, "Invalid params: " <> T.pack err)
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
            Network.HTTP.Types.status200
            [contentTypeJson]
            (encode $ mkErrorResp (-32700) (T.pack $ "Parse error: " ++ err) Nothing)
        Right jrRequest -> do
            result <- handleRequest @apis service' (jrMethod jrRequest) request (jrParams jrRequest)
            case result of
                Left (code, errMsg) ->
                    respond $ Wai.responseLBS
                        Network.HTTP.Types.status200
                        [contentTypeJson]
                        (encode $ mkErrorResp code errMsg (jrId jrRequest))
                Right val -> do
                    let response = JsonRpcResponse
                            { jrpJsonrpc = "2.0"
                            , jrpResult = val
                            , jrpId = jrId jrRequest
                            }
                    respond $ Wai.responseLBS
                        Network.HTTP.Types.status200
                        [contentTypeJson]
                        (encode response)

type TypedRpcResp a = IO (Either (Int, Text) a)