# Adding a New Test Module

To add a new test module to the project, follow these steps:

1. **Create the test module file** in `test/Test/<ModuleName>.hs`:
   - The module should export a `Test` value (e.g., `myModuleTests`)
   - Import necessary dependencies including `Test.HUnit` and project modules
   - Define your test cases and group them using `TestList`

2. **Add the module to `test/Spec.hs`**:
   - Import the new test module: `import Test.ModuleName (myModuleTests)`
   - Add the test to the main `tests` TestList

3. **Register the module in `typed-rpc.cabal`**:
   - Add the module name to the `other-modules` field in the `test-suite test` 
     section, following the same format as existing modules:
     ```
     other-modules:
         Test.HandleRequest
         , Test.JsonCodec
         , Test.ServiceBuilding
         , Test.YourNewModule
     ```

4. **Run tests to verify**:
   ```bash
   nix develop --command cabal test
   ```

Example structure of a test module:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Test.MyNewModule
    ( myNewModuleTests
    ) where

import Test.HUnit
    ( Test (TestCase, TestLabel, TestList)
    , assertEqual
    )
-- Import your project modules here

myNewModuleTests :: Test
myNewModuleTests =
    TestList
        [ TestLabel "test description" $
            TestCase $ do
                -- test assertions
                assertEqual "expected value" expected actual
        ]
```
