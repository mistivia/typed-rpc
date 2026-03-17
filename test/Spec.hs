{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson (toJSON, decode', Value(..), object, (.=))
import Data.ByteString.Lazy.Char8 (pack)
import Data.Text (Text)
import Network.Wai qualified as Wai
import Data.Maybe (fromJust)
import Test.HUnit
    ( Counts (errors, failures)
    , Test (TestCase, TestLabel, TestList)
    , assertBool
    , assertEqual
    , runTestTT
    )
import Data.Aeson.Key (fromString)
import TypedRpc
    ( Apis
    , ApiCmd
    , Service (SrvCons, SrvNil)
    , api
    , handleRequest
    , service
    , JsonRpcRequest(..)
    , JsonRpcResponse(..)
    )

emptyService :: Service (Apis '[])
emptyService = service id

echoHandler :: Wai.Request -> Int -> IO (Either (Int, String) Int)
echoHandler _ n = pure (Right n)

incHandler :: Wai.Request -> Int -> IO (Either (Int, String) Int)
incHandler _ n = pure (Right (n + 1))

errorHandler :: Wai.Request -> () -> IO (Either (Int, String) String)
errorHandler _ _ = pure $ Left (500, "Internal error")

singleService :: Service (Apis '[ApiCmd "echo" Int Int])
singleService = service (api @"echo" echoHandler)

type DoubleApis = Apis
    [ ApiCmd "inc" Int Int
    , ApiCmd "echo" Int Int
    ]

doubleService :: Service DoubleApis
doubleService = service 
    $ api @"inc" incHandler
    . api @"echo" echoHandler

errorService :: Service (Apis '[ApiCmd "fail" () String])
errorService = service (api @"fail" errorHandler)

dummyRequest :: Wai.Request
dummyRequest = Wai.defaultRequest

tests :: Test
tests =
    TestList
        [ TestLabel "service id builds SrvNil" $
            TestCase $
                assertBool "expected SrvNil" $
                    case emptyService of
                        SrvNil -> True
        , TestLabel "api builds single command" $
            TestCase $
                assertBool "expected SrvCons _ SrvNil" $
                    case singleService of
                        SrvCons _ SrvNil -> True
        , TestLabel "composed api builds two commands" $
            TestCase $
                assertBool "expected SrvCons _ (SrvCons _ SrvNil)" $
                    case doubleService of
                        SrvCons _ (SrvCons _ SrvNil) -> True
        , TestLabel "handleRequest empty service returns method not found" $
            TestCase $ do
                result <- handleRequest emptyService "echo" dummyRequest (toJSON (42 :: Int))
                assertEqual "expected method not found error" (Left (400, "Method not found: echo")) result
        , TestLabel "handleRequest finds method in single service" $
            TestCase $ do
                result <- handleRequest singleService "echo" dummyRequest (toJSON (42 :: Int))
                assertEqual "expected echo result" (Right (toJSON (42 :: Int))) result
        , TestLabel "handleRequest finds first method in double service" $
            TestCase $ do
                result <- handleRequest doubleService "inc" dummyRequest (toJSON (5 :: Int))
                assertEqual "expected inc result" (Right (toJSON (6 :: Int))) result
        , TestLabel "handleRequest finds second method in double service" $
            TestCase $ do
                result <- handleRequest doubleService "echo" dummyRequest (toJSON (99 :: Int))
                assertEqual "expected echo result" (Right (toJSON (99 :: Int))) result
        , TestLabel "handleRequest returns method not found for non-existent method" $
            TestCase $ do
                result <- handleRequest doubleService "nonexistent" dummyRequest (toJSON (1 :: Int))
                assertEqual "expected method not found error" (Left (400, "Method not found: nonexistent")) result
        , TestLabel "handleRequest propagates handler error" $
            TestCase $ do
                result <- handleRequest errorService "fail" dummyRequest (toJSON ())
                assertEqual "expected handler error" (Left (500, "Internal error")) result
        , TestLabel "FromJSON JsonRpcRequest parses valid request" $
            TestCase $
                let input = pack "{\"jsonrpc\":\"2.0\",\"method\":\"echo\",\"params\":42,\"id\":1}"
                    expected = JsonRpcRequest "2.0" "echo" (Number 42) (Just 1)
                in assertEqual "expected parsed request" expected (fromJust (decode' input))
        , TestLabel "FromJSON JsonRpcRequest handles null id" $
            TestCase $
                let input = pack "{\"jsonrpc\":\"2.0\",\"method\":\"echo\",\"params\":{\"x\":1},\"id\":null}"
                    expectedId = Nothing
                in case decode' input of
                    Just req -> assertEqual "expected parsed request id" expectedId (jrId req)
                    Nothing -> assertBool "expected successful parse" False
        , TestLabel "FromJSON JsonRpcRequest handles missing id" $
            TestCase $
                let input = pack "{\"jsonrpc\":\"2.0\",\"method\":\"echo\",\"params\":[]}"
                    expected = JsonRpcRequest "2.0" "echo" (Array mempty) Nothing
                in assertEqual "expected parsed request" expected (fromJust (decode' input))
        , TestLabel "ToJSON JsonRpcResponse encodes correctly" $
            TestCase $
                let resp = JsonRpcResponse { jrpJsonrpc = "2.0", jrpResult = Number 42, jrpId = Just 1 }
                    expected = object [fromString "jsonrpc" .= ("2.0" :: Text), fromString "result" .= Number 42, fromString "id" .= Number 1]
                in assertEqual "expected encoded response" expected (toJSON resp)
        , TestLabel "ToJSON JsonRpcResponse encodes with null id" $
            TestCase $
                let resp = JsonRpcResponse { jrpJsonrpc = "2.0", jrpResult = String "hello", jrpId = Nothing }
                    expected = object [fromString "jsonrpc" .= ("2.0" :: Text), fromString "result" .= String "hello", fromString "id" .= Null]
                in assertEqual "expected encoded response" expected (toJSON resp)
        ]

main :: IO ()
main = do
    counts <- runTestTT tests
    if errors counts + failures counts == 0
        then pure ()
        else fail "Tests failed."
