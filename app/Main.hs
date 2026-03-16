module Main where

import TypedRpc (greet)

main :: IO ()
main = putStrLn ("typed-rpc-demo: " <> greet)
