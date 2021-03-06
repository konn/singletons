Changelog for singletons project
================================

1.1
-----

* Instance promotion now works properly -- it was quite buggy in 1.0.

* We now have promoted and singletonized versions of `Enum`, as well as `Bounded`.

* Ditto for `Num`, which includes an instance for `Nat`, naturally.

* Promoting a literal number now uses overloaded literals at the type level,
using a type-level `FromInteger` in the type-level `Num` class.

1.0
---

This is a complete rewrite of the package.

* A much wider array of surface syntax is now accepted for promotion
and singletonization, including `let`, `case`, partially-applied functions,
and anonymous functions, `where`, sections, among others.

* Classes and instances can be promoted (but not singletonized).

* Derivation of promoted instances for `Ord` and `Bounded`.

This release can be seen as a "technology preview". More features are coming
soon.

This version drops GHC 7.6 support.

0.10.0
------

Template Haskell names are now more hygienic. In other words, `singletons`
won't try to gobble up something happened to be named `Sing` in your project.
(Note that the Template Haskell names are not *completely* hygienic; names
generated during singleton generation can still cause conflicts.)

If a function to be promoted or singletonized is missing a type signature,
that is now an *error*, not a warning.

Added a new external module Data.Singletons.TypeLits, which contain the
singletons for GHC.TypeLits. Some convenience functions are also provided.

The extension `EmptyCase` is no longer needed. This caused pain when trying
to support both GHC 7.6.3 and 7.8.

0.9.3
-----

Fix export list of Data.Singletons.TH, again again.

Add `SEq` instances for `Nat` and `Symbol`.

0.9.2
-----

Fix export list of Data.Singletons.TH, again.

0.9.1
-----

Fix export list of Data.Singletons.TH.

0.9.0
-----

Make compatible with GHC HEAD, but HEAD reports core lint errors sometimes.

Change module structure significantly. If you want to derive your own
singletons, you should import `Data.Singletons.TH`. The module
`Data.Singletons` now exports functions only for the *use* of singletons.

New modules `Data.Singletons.Bool`, `...Maybe`, `...Either`, and `...List`
are just like their equivalents from `Data.`, except for `List`, which is
quite lacking in features.

For singleton equality, use `Data.Singletons.Eq`.

For propositional singleton equality, use `Data.Singletons.Decide`.

New module `Data.Singletons.Prelude` is meant to mirror the Haskell Prelude,
but with singleton definitions.

Streamline representation of singletons, resulting in *exponential* speedup
at execution. (This has not been rigorously measured, but the data structures
are now *exponentially* smaller.)

Add internal support for TypeLits, because the TypeLits module no longer
exports singleton definitions.

Add support for existential singletons, through the `toSing` method of
`SingKind`.

Remove the `SingE` class, bundling its functionality into `SingKind`.
Thus, the `SingRep` synonym has also been removed.

Name change: `KindIs` becomes `KProxy`.

Add support for singletonizing calls to `error`.

Add support for singletonizing empty data definitions.

0.8.6
-----

Make compatible with GHC HEAD, but HEAD reports core lint errors sometimes.

0.8.5
-----

Bug fix to make singletons compatible with GHC 7.6.1.

Added git info to cabal file.

0.8.4
-----

Update to work with latest version of GHC (7.7.20130114).

Now use branched type family instances to allow for promotion of functions
with overlapping patterns.

Permit promotion of functions with constraints by omitting constraints.

0.8.3
-----

Update to work with latest version of GHC (7.7.20121031).

Removed use of Any to simulate kind classes; now using KindOf and OfKind
from GHC.TypeLits.

Made compatible with GHC.TypeLits.

0.8.2
-----

Added this changelog

Update to work with latest version of GHC (7.6.1). (There was a change to
Template Haskell).

Moved library into Data.Singletons.

0.8.1
-----

Update to work with latest version of GHC. (There was a change to
Template Haskell).

Updated dependencies in cabal to include the newer version of TH.

0.8
---

Initial public release
