{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.HUnit
    ( Counts (errors, failures)
    , Test (TestList)
    , runTestTT
    )
import Test.ServiceBuilding (serviceBuildingTests)
import Test.HandleRequest (handleRequestTests)
import Test.JsonCodec (jsonCodecTests)

tests :: Test
tests =
    TestList
        [ serviceBuildingTests
        , handleRequestTests
        , jsonCodecTests
        ]

main :: IO ()
main = do
    counts <- runTestTT tests
    if errors counts + failures counts == 0
        then pure ()
        else fail "Tests failed."
