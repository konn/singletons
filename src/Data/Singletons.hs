{-# LANGUAGE MagicHash, RankNTypes, PolyKinds, GADTs, DataKinds,
             FlexibleContexts, TypeFamilies, TypeOperators,
             UndecidableInstances #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Singletons
-- Copyright   :  (C) 2013 Richard Eisenberg
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  Richard Eisenberg (eir@cis.upenn.edu)
-- Stability   :  experimental
-- Portability :  non-portable
--
-- This module exports the basic definitions to use singletons. For routine
-- use, consider importing 'Data.Singletons.Prelude', which exports constructors
-- for singletons based on types in the @Prelude@.
--
-- You may also want to read
-- <http://www.cis.upenn.edu/~eir/packages/singletons/README.html> and the
-- original paper presenting this library, available at
-- <http://www.cis.upenn.edu/~eir/papers/2012/singletons/paper.pdf>.
--
----------------------------------------------------------------------------

module Data.Singletons (
  -- * Main singleton definitions

  Sing(SLambda, applySing),
  -- | See also 'Data.Singletons.Prelude.Sing' for exported constructors

  SingI(..), SingKind(..),

  -- * Working with singletons
  KindOf, Demote,
  SingInstance(..), SomeSing(..),
  singInstance, withSingI, withSomeSing, singByProxy,

  singByProxy#,
  withSing, singThat,

  -- ** Defunctionalization
  TyFun, TyCon1, TyCon2, TyCon3, TyCon4, TyCon5, TyCon6, TyCon7,
  Apply, type (@@),

  -- ** Defunctionalized singletons
  -- | When calling a higher-order singleton function, you need to use a
  -- @singFun...@ function to wrap it. See 'singFun1'.
  singFun1, singFun2, singFun3, singFun4, singFun5, singFun6, singFun7,
  unSingFun1, unSingFun2, unSingFun3, unSingFun4, unSingFun5,
  unSingFun6, unSingFun7,

-- | These type synonyms are exported only to improve error messages; users
  -- should not have to mention them.
  SingFunction1, SingFunction2, SingFunction3, SingFunction4, SingFunction5,
  SingFunction6, SingFunction7,

  -- * Auxiliary functions
  bugInGHC,
  KProxy(..)
  ) where

import Unsafe.Coerce
import Data.Proxy ( Proxy(..), KProxy(..) )
import GHC.Exts ( Proxy# )

-- | Convenient synonym to refer to the kind of a type variable:
-- @type KindOf (a :: k) = ('KProxy :: KProxy k)@
type KindOf (a :: k) = ('KProxy :: KProxy k)

----------------------------------------------------------------------
---- Sing & friends --------------------------------------------------
----------------------------------------------------------------------

-- | The singleton kind-indexed data family.
data family Sing (a :: k)

-- | A 'SingI' constraint is essentially an implicitly-passed singleton.
-- If you need to satisfy this constraint with an explicit singleton, please
-- see 'withSingI'.
class SingI (a :: k) where
  -- | Produce the singleton explicitly. You will likely need the @ScopedTypeVariables@
  -- extension to use this method the way you want.
  sing :: Sing a

-- | The 'SingKind' class is essentially a /kind/ class. It classifies all kinds
-- for which singletons are defined. The class supports converting between a singleton
-- type and the base (unrefined) type which it is built from.
class (kparam ~ 'KProxy) => SingKind (kparam :: KProxy k) where
  -- | Get a base type from a proxy for the promoted kind. For example,
  -- @DemoteRep ('KProxy :: KProxy Bool)@ will be the type @Bool@.
  type DemoteRep kparam :: *

  -- | Convert a singleton to its unrefined version.
  fromSing :: Sing (a :: k) -> DemoteRep kparam

  -- | Convert an unrefined type to an existentially-quantified singleton type.
  toSing   :: DemoteRep kparam -> SomeSing kparam

-- | Convenient abbreviation for 'DemoteRep':
-- @type Demote (a :: k) = DemoteRep ('KProxy :: KProxy k)@
type Demote (a :: k) = DemoteRep ('KProxy :: KProxy k)

-- | An /existentially-quantified/ singleton. This type is useful when you want a
-- singleton type, but there is no way of knowing, at compile-time, what the type
-- index will be. To make use of this type, you will generally have to use a
-- pattern-match:
--
-- > foo :: Bool -> ...
-- > foo b = case toSing b of
-- >           SomeSing sb -> {- fancy dependently-typed code with sb -}
--
-- An example like the one above may be easier to write using 'withSomeSing'.
data SomeSing (kproxy :: KProxy k) where
  SomeSing :: Sing (a :: k) -> SomeSing ('KProxy :: KProxy k)

----------------------------------------------------------------------
---- SingInstance ----------------------------------------------------
----------------------------------------------------------------------

-- | A 'SingInstance' wraps up a 'SingI' instance for explicit handling.
data SingInstance (a :: k) where
  SingInstance :: SingI a => SingInstance a

-- dirty implementation of explicit-to-implicit conversion
newtype DI a = Don'tInstantiate (SingI a => SingInstance a)

-- | Get an implicit singleton (a 'SingI' instance) from an explicit one.
singInstance :: forall (a :: k). Sing a -> SingInstance a
singInstance s = with_sing_i SingInstance
  where
    with_sing_i :: (SingI a => SingInstance a) -> SingInstance a
    with_sing_i si = unsafeCoerce (Don'tInstantiate si) s

----------------------------------------------------------------------
---- Defunctionalization ---------------------------------------------
----------------------------------------------------------------------

-- | Representation of the kind of a type-level function. The difference
-- between term-level arrows and this type-level arrow is that at the term
-- level applications can be unsaturated, whereas at the type level all
-- applications have to be fully saturated.
data TyFun :: * -> * -> *

-- | Wrapper for converting the normal type-level arrow into a 'TyFun'.
-- For example, given:
--
-- > data Nat = Zero | Succ Nat
-- > type family Map (a :: TyFun a b -> *) (a :: [a]) :: [b]
-- >   Map f '[] = '[]
-- >   Map f (x ': xs) = Apply f x ': Map f xs
--
-- We can write:
--
-- > Map (TyCon1 Succ) [Zero, Succ Zero]
data TyCon1 :: (k1 -> k2) -> (TyFun k1 k2) -> *

-- | Similar to 'TyCon1', but for two-parameter type constructors.
data TyCon2 :: (k1 -> k2 -> k3) -> TyFun k1 (TyFun k2 k3 -> *) -> *
data TyCon3 :: (k1 -> k2 -> k3 -> k4) -> TyFun k1 (TyFun k2 (TyFun k3 k4 -> *) -> *) -> *
data TyCon4 :: (k1 -> k2 -> k3 -> k4 -> k5) -> TyFun k1 (TyFun k2 (TyFun k3 (TyFun k4 k5 -> *) -> *) -> *) -> *
data TyCon5 :: (k1 -> k2 -> k3 -> k4 -> k5 -> k6) -> TyFun k1 (TyFun k2 (TyFun k3 (TyFun k4 (TyFun k5 k6 -> *) -> *) -> *) -> *) -> *
data TyCon6 :: (k1 -> k2 -> k3 -> k4 -> k5 -> k6 -> k7) -> TyFun k1 (TyFun k2 (TyFun k3 (TyFun k4 (TyFun k5 (TyFun k6 k7 -> *) -> *) -> *) -> *) -> *) -> *
data TyCon7 :: (k1 -> k2 -> k3 -> k4 -> k5 -> k6 -> k7 -> k8) -> TyFun k1 (TyFun k2 (TyFun k3 (TyFun k4 (TyFun k5 (TyFun k6 (TyFun k7 k8 -> *) -> *) -> *) -> *) -> *) -> *) -> *

-- | Type level function application
type family Apply (f :: TyFun k1 k2 -> *) (x :: k1) :: k2
type instance Apply (TyCon1 f) x = f x
type instance Apply (TyCon2 f) x = TyCon1 (f x)
type instance Apply (TyCon3 f) x = TyCon2 (f x)
type instance Apply (TyCon4 f) x = TyCon3 (f x)
type instance Apply (TyCon5 f) x = TyCon4 (f x)
type instance Apply (TyCon6 f) x = TyCon5 (f x)
type instance Apply (TyCon7 f) x = TyCon6 (f x)

-- | An infix synonym for `Apply`
type a @@ b = Apply a b
infixl 9 @@

----------------------------------------------------------------------
---- Defunctionalized Sing instance and utilities --------------------
----------------------------------------------------------------------

newtype instance Sing (f :: TyFun k1 k2 -> *) =
  SLambda { applySing :: forall t. Sing t -> Sing (f @@ t) }

instance (SingKind ('KProxy :: KProxy k1), SingKind ('KProxy :: KProxy k2))
         => SingKind ('KProxy :: KProxy (TyFun k1 k2 -> *)) where
  type DemoteRep ('KProxy :: KProxy (TyFun k1 k2 -> *)) =
    DemoteRep ('KProxy :: KProxy k1) -> DemoteRep ('KProxy :: KProxy k2)
  fromSing sFun x = withSomeSing x (fromSing . applySing sFun)
  toSing _ = error "Cannot create existentially-quantified singleton functions."

type SingFunction1 f = forall t. Sing t -> Sing (f @@ t)

-- | Use this function when passing a function on singletons as
-- a higher-order function. You will often need an explicit type
-- annotation to get this to work. For example:
--
-- > falses = sMap (singFun1 sNot :: Sing NotSym0)
-- >               (STrue `SCons` STrue `SCons` SNil)
--
-- There are a family of @singFun...@ functions, keyed by the number
-- of parameters of the function.
singFun1 :: Proxy f -> SingFunction1 f -> Sing f
singFun1 _ f = SLambda f

type SingFunction2 f = forall t. Sing t -> SingFunction1 (f @@ t)
singFun2 :: Proxy f -> SingFunction2 f -> Sing f
singFun2 _ f = SLambda (\x -> singFun1 Proxy (f x))

type SingFunction3 f = forall t. Sing t -> SingFunction2 (f @@ t)
singFun3 :: Proxy f -> SingFunction3 f -> Sing f
singFun3 _ f = SLambda (\x -> singFun2 Proxy (f x))

type SingFunction4 f = forall t. Sing t -> SingFunction3 (f @@ t)
singFun4 :: Proxy f -> SingFunction4 f -> Sing f
singFun4 _ f = SLambda (\x -> singFun3 Proxy (f x))

type SingFunction5 f = forall t. Sing t -> SingFunction4 (f @@ t)
singFun5 :: Proxy f -> SingFunction5 f -> Sing f
singFun5 _ f = SLambda (\x -> singFun4 Proxy (f x))

type SingFunction6 f = forall t. Sing t -> SingFunction5 (f @@ t)
singFun6 :: Proxy f -> SingFunction6 f -> Sing f
singFun6 _ f = SLambda (\x -> singFun5 Proxy (f x))

type SingFunction7 f = forall t. Sing t -> SingFunction6 (f @@ t)
singFun7 :: Proxy f -> SingFunction7 f -> Sing f
singFun7 _ f = SLambda (\x -> singFun6 Proxy (f x))

-- | This is the inverse of 'singFun1', and likewise for the other
-- @unSingFun...@ functions.
unSingFun1 :: Proxy f -> Sing f -> SingFunction1 f
unSingFun1 _ sf = applySing sf

unSingFun2 :: Proxy f -> Sing f -> SingFunction2 f
unSingFun2 _ sf x = unSingFun1 Proxy (sf `applySing` x)

unSingFun3 :: Proxy f -> Sing f -> SingFunction3 f
unSingFun3 _ sf x = unSingFun2 Proxy (sf `applySing` x)

unSingFun4 :: Proxy f -> Sing f -> SingFunction4 f
unSingFun4 _ sf x = unSingFun3 Proxy (sf `applySing` x)

unSingFun5 :: Proxy f -> Sing f -> SingFunction5 f
unSingFun5 _ sf x = unSingFun4 Proxy (sf `applySing` x)

unSingFun6 :: Proxy f -> Sing f -> SingFunction6 f
unSingFun6 _ sf x = unSingFun5 Proxy (sf `applySing` x)

unSingFun7 :: Proxy f -> Sing f -> SingFunction7 f
unSingFun7 _ sf x = unSingFun6 Proxy (sf `applySing` x)

----------------------------------------------------------------------
---- Convenience -----------------------------------------------------
----------------------------------------------------------------------

-- | Convenience function for creating a context with an implicit singleton
-- available.
withSingI :: Sing n -> (SingI n => r) -> r
withSingI sn r =
  case singInstance sn of
    SingInstance -> r

-- | Convert a normal datatype (like 'Bool') to a singleton for that datatype,
-- passing it into a continuation.
withSomeSing :: SingKind ('KProxy :: KProxy k)
             => DemoteRep ('KProxy :: KProxy k)   -- ^ The original datatype
             -> (forall (a :: k). Sing a -> r)    -- ^ Function expecting a singleton
             -> r
withSomeSing x f =
  case toSing x of
    SomeSing x' -> f x'

-- | A convenience function useful when we need to name a singleton value
-- multiple times. Without this function, each use of 'sing' could potentially
-- refer to a different singleton, and one has to use type signatures (often
-- with @ScopedTypeVariables@) to ensure that they are the same.
withSing :: SingI a => (Sing a -> b) -> b
withSing f = f sing

-- | A convenience function that names a singleton satisfying a certain
-- property.  If the singleton does not satisfy the property, then the function
-- returns 'Nothing'. The property is expressed in terms of the underlying
-- representation of the singleton.
singThat :: forall (a :: k). (SingKind ('KProxy :: KProxy k), SingI a)
         => (Demote a -> Bool) -> Maybe (Sing a)
singThat p = withSing $ \x -> if p (fromSing x) then Just x else Nothing

-- | Allows creation of a singleton when a proxy is at hand.
singByProxy :: SingI a => proxy a -> Sing a
singByProxy _ = sing

-- | Allows creation of a singleton when a @proxy#@ is at hand.
singByProxy# :: SingI a => Proxy# a -> Sing a
singByProxy# _ = sing

-- | GHC 7.8 sometimes warns about incomplete pattern matches when no such
-- patterns are possible, due to GADT constraints.
-- See the bug report at <https://ghc.haskell.org/trac/ghc/ticket/3927>.
-- In such cases, it's useful to have a catch-all pattern that then has
-- 'bugInGHC' as its right-hand side.
bugInGHC :: forall a. a
bugInGHC = error "Bug encountered in GHC -- this should never happen"
