{-# LANGUAGE OverloadedStrings #-}

module Test.ServiceBuilding
    ( serviceBuildingTests
    ) where

import Test.HUnit
    ( Test (TestCase, TestLabel, TestList)
    , assertBool
    )
import TypedRpc
    ( Apis
    , ApiCmd
    , Service (SrvCons, SrvNil)
    , api
    , service
    )
import qualified Network.Wai as Wai

emptyService :: Service (Apis '[])
emptyService = service id

echoHandler :: Wai.Request -> Int -> IO (Either (Int, String) Int)
echoHandler _ n = pure (Right n)

incHandler :: Wai.Request -> Int -> IO (Either (Int, String) Int)
incHandler _ n = pure (Right (n + 1))

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

serviceBuildingTests :: Test
serviceBuildingTests =
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
        ]
