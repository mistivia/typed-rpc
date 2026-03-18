{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import TypedRpc (Service, service, api, makeApplication, ApiCmd, Apis, TypedRpcResp)
import Data.Text (Text)
import Network.Wai (Request)
import Network.Wai.Handler.Warp (run)
import Data.FlexRecord (FlexRecord, Field, frGet, flexRecord, field)
import Data.FlexRecord.Json ()

type HelloInput = FlexRecord 
    [ Field "name" Text
    , Field "email" (Maybe Text)
    ]
type HelloOutput = FlexRecord '[ Field "message" Text]

type EchoInput = FlexRecord '[Field "content" Text]
type EchoOutput = FlexRecord '[Field "echoed" Text]


mkHelloOutput :: Text -> HelloOutput
mkHelloOutput msg = flexRecord $ field @"message" msg

mkEchoOutput :: Text -> EchoOutput
mkEchoOutput echoed = flexRecord $ field @"echoed" echoed

helloHandler :: Request -> HelloInput -> TypedRpcResp HelloOutput
helloHandler _req input = do
    let name = frGet @"name" input
        mEmail = frGet @"email" input
        greeting = case mEmail of
            Just email -> "Hello, " <> name <> "! Your email is: " <> email
            Nothing -> "Hello, " <> name <> "!"
    pure $ Right (mkHelloOutput greeting)
 
-- Echo service handler
echoHandler :: Request -> EchoInput -> TypedRpcResp EchoOutput
echoHandler _req input = do
    let content = frGet @"content" input
    pure $ Right (mkEchoOutput content)

type MyServiceApi = Apis
    [ ApiCmd "hello" HelloInput HelloOutput
    , ApiCmd "echo" EchoInput EchoOutput
    ]

-- Build the API service with both hello and echo endpoints
myService :: Service MyServiceApi
myService = service 
    $ api @"hello" helloHandler
    . api @"echo" echoHandler

-- Application entry point
main :: IO ()
main = do
    putStrLn "typed-rpc-demo starting on http://localhost:18888"
    putStrLn "Available endpoints:"
    putStrLn "  POST http://localhost:18888 with JSON-RPC 2.0 format"
    putStrLn "  Methods: 'hello' (params: {name: string, email?: string})"
    putStrLn "           'echo' (params: {content: string})"
    run 18888 (makeApplication myService)
