{-# LANGUAGE TypeOperators, DataKinds, PolyKinds, TypeFamilies,
             RankNTypes, FlexibleContexts, TemplateHaskell,
             UndecidableInstances, GADTs, DefaultSignatures #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Singletons.Prelude.Eq
-- Copyright   :  (C) 2013 Richard Eisenberg
-- License     :  BSD-style (see LICENSE)
-- Maintainer  :  Richard Eisenberg (eir@cis.upenn.edu)
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Defines the SEq singleton version of the Eq type class.
--
-----------------------------------------------------------------------------

module Data.Singletons.Prelude.Eq (
  PEq(..), SEq(..),
  (:==$), (:==$$), (:==$$$), (:/=$), (:/=$$), (:/=$$$)
  ) where

import Data.Singletons.Prelude.Bool
import Data.Singletons
import Data.Singletons.Single
import Data.Singletons.Prelude.Instances
import Data.Singletons.Util
import Data.Singletons.Promote
import Data.Type.Equality

import Language.Haskell.TH
import Language.Haskell.TH.Desugar
import Data.Singletons.Names

-- | The promoted analogue of 'Eq'. If you supply no definition for '(:==)',
-- then it defaults to a use of '(==)', from @Data.Type.Equality@.
class kproxy ~ 'KProxy => PEq (kproxy :: KProxy a) where
  type (:==) (x :: a) (y :: a) :: Bool
  type (:/=) (x :: a) (y :: a) :: Bool

  type (x :: a) :== (y :: a) = x == y
  type (x :: a) :/= (y :: a) = Not (x :== y)

-- need to spit out class and method annotations!
$( do a <- newName "a"
      classAnnot <- [| [a] |]
      methAnnot  <- [| ([DVarK a, DVarK a], DConK boolName []) |]
      return [ PragmaD $ AnnP (TypeAnnotation ''PEq)   classAnnot
             , PragmaD $ AnnP (TypeAnnotation ''(:==)) methAnnot
             , PragmaD $ AnnP (TypeAnnotation ''(:/=)) methAnnot ])
               
$(genDefunSymbols [''(:==), ''(:/=)])

-- | The singleton analogue of 'Eq'. Unlike the definition for 'Eq', it is required
-- that instances define a body for '(%:==)'. You may also supply a body for '(%:/=)'.
class (kparam ~ 'KProxy) => SEq (kparam :: KProxy k) where
  -- | Boolean equality on singletons
  (%:==) :: forall (a :: k) (b :: k). Sing a -> Sing b -> Sing (a :== b)

  -- | Boolean disequality on singletons
  (%:/=) :: forall (a :: k) (b :: k). Sing a -> Sing b -> Sing (a :/= b)
  default (%:/=) :: forall (a :: k) (b :: k).
                    ((a :/= b) ~ Not (a :== b))
                 => Sing a -> Sing b -> Sing (a :/= b)
  a %:/= b = sNot (a %:== b)

$(singEqInstances basicTypes)
