## Basic Information

Use HUnit for unit testing.

This project uses the GHC2024 language edition.

## List Formatting

When writing multi-line lists, place `,` and `[` like this (only when the list is long):

```
list = 
    [ a1
    , a2
    , a3
    ]
```

If the list is short, write it inline: `lst = [1,2,3]`

## Nix

This project uses `flake.nix`. Run `nix develop --command cabal test` when you want to run tests.

## Haskell Language Extensions

UndecidableInstances, TypeFamilies, and AllowAmbiguousTypes are enabled by default.

DataKinds, GADTs, and TypeApplications are already included in GHC2024, so you do not need to enable them manually.

## Typeclass

Do **not** use OVERLAPPABLE or OVERLAPPING. In such cases, use closed type family dispatch.

Because AllowAmbiguousTypes is enabled, you do not need to add an extra special parameter for dispatch. Just use type application directly.

Here is an example:

```haskell
type family TypeDispatch a where
    XXX = 'True
    YYY = 'False

class ToBeDispatchedImpl (dispatch :: Bool) a where
    myFuncImpl :: a -> x -> y

instance ToBeDispatchedImpl 'True a where
    myFuncImpl = ...

instance ToBeDispatchedImpl 'False a where
    myFuncImpl = ...

class ToBeDispatched a where
    myFunc :: a -> x -> y

instance (ToBeDispatchedImpl (TypeDispatch a) a) => ToBeDispatched a where
    myFunc = myFuncImpl @(TypeDispatch a)
```