{-# LANGUAGE OverloadedStrings #-}

module Test.JsonCodec
    ( jsonCodecTests
    ) where

import Data.Aeson (toJSON, decode', Value(..), object, (.=))
import Data.Aeson.Key (fromString)
import Data.ByteString.Lazy.Char8 (pack)
import Data.Maybe (fromJust)
import Data.Text (Text)
import Test.HUnit
    ( Test (TestCase, TestLabel, TestList)
    , assertBool
    , assertEqual
    )
import TypedRpc
    ( JsonRpcRequest(..)
    , JsonRpcResponse(..)
    )

jsonCodecTests :: Test
jsonCodecTests =
    TestList
        [ TestLabel "FromJSON JsonRpcRequest parses valid request" $
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
