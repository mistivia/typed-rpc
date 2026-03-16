## Basic Information

Use HUnit for unit testing.

This project uses the GHC2024 language edition.

## List Formatting

When writing multi-line lists, place `,` and `[` like this (only when
the list is long):

```
list = 
    [ a1
    , a2
    , a3
    ]
```

If the list is short, write it inline: `lst = [1,2,3]`

## Nix

This project uses `flake.nix`. Run `nix develop --command cabal test`
when you want to run tests.

## Haskell Language Extensions

UndecidableInstances, TypeFamilies, and AllowAmbiguousTypes are
enabled by default.

DataKinds, GADTs, and TypeApplications are already included in
GHC2024, so you do not need to enable them manually.

## Typeclass

Do **not** use OVERLAPPABLE or OVERLAPPING. In such cases, use closed
type family dispatch.

Because AllowAmbiguousTypes is enabled, you do not need to add an
extra special parameter for dispatch. Just use type application
directly.

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

## flex-record

`Data.FlexRecord` is a lightweight Haskell Record library based on
type-level field lists. Its core capabilities include type-safe field
access via `frGet`, field updates via `frSet`, and seamless integration
with `accessor-hs` through `frAcc`, so you can continue using
`view` / `set` / `over` / `dot` / `facc` for compositional access.
It also provides `Data.FlexRecord.Json` to support `ToJSON` /
`FromJSON` instances. Repository:
<https://github.com/mistivia/flex-record>. See the README.md on the
master branch for documentation.

## accessor-hs

`Data.Accessor` provides a simpler "getter + setter" abstraction than
lens: build accessors with `accessor`, use `view` / `set` / `over` for
reading, writing, and transforming values, compose nested access with
`dot`, and process `Functor` containers (such as `Maybe` and lists)
with `facc`. It also includes practical list-index accessors (`listAt`
and `_0` to `_9`), making it well-suited for building data access
chains with low cognitive overhead. Repository:
<https://github.com/mistivia/accessor-hs>. See the README.md on the
master branch for documentation.

## Querying Function and Type Signatures in GHC/GHCi

In an interactive environment, the most commonly used GHCi commands
are: `:browse ModuleName` (list exported function/type/class
signatures from a module), `:browse! ModuleName` (show more complete
expanded information), `:type expr` (query the type of an expression),
and `:info Name` (query a function, type, typeclass, and its instances).

For example:

```bash
ghci << EOF
import Data.Accessor
:browse Data.Accessor
EOF
```

