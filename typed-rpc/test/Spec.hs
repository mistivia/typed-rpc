module Main where

import Data.TypedRpc (greet)
import Test.HUnit
    ( Counts (errors, failures)
    , Test (TestCase, TestLabel, TestList)
    , assertEqual
    , runTestTT
    )

tests :: Test
tests =
    TestList
        [ TestLabel "greet returns expected message" $
            TestCase $
                assertEqual "greet message" "Hello from typed-rpc!" greet
        ]

main :: IO ()
main = do
    counts <- runTestTT tests
    if errors counts + failures counts == 0
        then pure ()
        else fail "Tests failed."
