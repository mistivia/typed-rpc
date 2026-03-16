module Main where

import Data.TypedRpc (greet)

main :: IO ()
main = putStrLn ("typed-rpc-demo: " <> greet)
