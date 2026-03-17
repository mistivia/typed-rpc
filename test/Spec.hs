module Main where

import Data.Aeson (toJSON)
import Network.Wai qualified as Wai
import Test.HUnit
    ( Counts (errors, failures)
    , Test (TestCase, TestLabel, TestList)
    , assertBool
    , assertEqual
    , runTestTT
    )
import TypedRpc
    ( Apis
    , ApiCmd
    , Service (SrvCons, SrvNil)
    , api
    , handleRequest
    , service
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
        ]

main :: IO ()
main = do
    counts <- runTestTT tests
    if errors counts + failures counts == 0
        then pure ()
        else fail "Tests failed."
