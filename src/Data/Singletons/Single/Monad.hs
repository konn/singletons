{- Data/Singletons/Single/Monad.hs

(c) Richard Eisenberg 2014
eir@cis.upenn.edu

This file defines the SgM monad and its operations, for use during singling.

The SgM monad allows reading from a SgEnv environment and is wrapped around a Q.
-}

{-# LANGUAGE GeneralizedNewtypeDeriving, ParallelListComp,
             TemplateHaskell #-}

module Data.Singletons.Single.Monad (
  SgM, bindLets, bindTyVars, bindTyVarsClause, lookupVarE, lookupConE,
  wrapSingFun, wrapUnSingFun,
  singM, singDecsM,
  emitDecs, emitDecsM
  ) where

import Prelude hiding ( exp )
import Data.Map ( Map )
import qualified Data.Map as Map
import Data.Singletons.Promote.Monad ( emitDecs, emitDecsM, VarPromotions )
import Data.Singletons.Names
import Data.Singletons.Util
import Data.Singletons
import Language.Haskell.TH.Syntax hiding ( lift )
import Language.Haskell.TH.Desugar
import Control.Applicative
import Control.Monad.Reader
import Control.Monad.Writer

-- environment during singling
data SgEnv =
  SgEnv { sg_let_binds :: Map Name DExp   -- from the *original* name
        }

emptySgEnv :: SgEnv
emptySgEnv = SgEnv { sg_let_binds = Map.empty
                   }

-- the singling monad
newtype SgM a = SgM (ReaderT SgEnv (WriterT [DDec] Q) a)
  deriving ( Functor, Applicative, Monad, Quasi
           , MonadReader SgEnv, MonadWriter [DDec] )

bindLets :: [(Name, DExp)] -> SgM a -> SgM a
bindLets lets1 =
  local (\env@(SgEnv { sg_let_binds = lets2 }) ->
               env { sg_let_binds = (Map.fromList lets1) `Map.union` lets2 })

-- bindTyVarsClause
-- ~~~~~~~~~~~~~~~~
--
-- This function does some dirty business.
--
-- The problem is that, whenever we bind a term variable, we would also like
-- to bind a type variable, for use in promotions of any nested lambdas,
-- cases, and lets. The natural idea, something like `(\(foo :: Sing ty_foo)
-- (bar :: Sing ty_bar) -> ...)` doesn't work, because ScopedTypeVariables is
-- stupid (in RAE's opinon). The ScopedTypeVariables extension says that any
-- scoped type variable is a rigid skolem. This means that the types ty_foo
-- and ty_bar must be distinct! That's actually not the problem. The problem
-- is that the implicit kind variables used in ty_foo's and ty_bar's kinds are
-- also skolems, and this breaks the idea.
--
-- The solution? Use scoped type variables from a function signature, where
-- the bound variables' kinds are *inferred*, not skolem. This means that,
-- whenever we lambda-bind variables (that is, in lambdas, let-bound
-- functions, and case matches), we must then pass the variables immediately
-- to a function with an explicit type signature. Thus, something like
--
--   (\foo bar -> ...)
--
-- becomes
--
--   (\foo bar ->
--     let lambda :: forall ty_foo ty_bar. Sing ty_foo -> Sing ty_bar -> Sing ...
--         lambda foo' bar' = ... (with foo |-> foo' and bar |-> bar')
--     in lambda foo bar)
--
-- Getting the ... right in the type above is a major nuisance, and it
-- explains a bunch of the types stored in the ADExp AST. (See LetDecEnv.)
--
-- A further, unsolved problem with all of this is that the type signature
-- generated never has any constraints. Thus, if the body requires a
-- constraint somewhere, the code will fail to compile; we're not quite clever
-- enough to get everything to line up.
--
-- As a stop-gap measure to fix this, in the function clause case, we tie the
-- scoped type variables in this "lambda" to the outer scoped type variables.
-- This has the effect of making sure that the kinds of ty_foo and ty_bar
-- match that of the surrounding scope and makes sure that any constraint is
-- available from within the "lambda".
--
-- This means, though, that using constraints with case statements and lambdas
-- will likely not work. Ugh.

bindTyVarsClause :: VarPromotions   -- the bindings we wish to effect
                 -> DType           -- the type of the thing_inside
                 -> [(DType, DType)]  -- and asserting these equalities
                 -> SgM DExp -> SgM DExp
bindTyVarsClause var_proms prom_fun equalities thing_inside = do
  lambda <- qNewName "lambda"
  let (term_names, tyvar_names) = unzip var_proms
      eq_ct  = [ DConPr equalityName `DAppPr` t1 `DAppPr` t2
               | (t1, t2) <- equalities ]
      ty_sig = DSigD lambda $
               DForallT (map DPlainTV tyvar_names) eq_ct $
                        ravel (map (\tv_name -> singFamily `DAppT` DVarT tv_name)
                                    tyvar_names ++ [singFamily `DAppT` prom_fun])
  arg_names <- mapM (qNewName . nameBase) term_names
  body <- bindLets [ (term_name, DVarE arg_name)
                   | term_name <- term_names
                   | arg_name <- arg_names ] $ thing_inside
  let fundef   = DFunD lambda [DClause (map DVarPa arg_names) body]
      let_body = foldExp (DVarE lambda) (map (DVarE . singValName) term_names)
  return $ DLetE [ty_sig, fundef] let_body

bindTyVars :: VarPromotions -> DType -> SgM DExp -> SgM DExp
bindTyVars var_proms prom_fun = bindTyVarsClause var_proms prom_fun []

lookupVarE :: Name -> SgM DExp
lookupVarE = lookup_var_con singValName (DVarE . singValName)

lookupConE :: Name -> SgM DExp
lookupConE = lookup_var_con singDataConName (DConE . singDataConName)

lookup_var_con :: (Name -> Name) -> (Name -> DExp) -> Name -> SgM DExp
lookup_var_con mk_sing_name mk_exp name = do
  letExpansions <- asks sg_let_binds
  sName <- mkDataName (nameBase (mk_sing_name name)) -- we want *term* names!
  case Map.lookup name letExpansions of
    Nothing -> do
      -- try to get it from the global context
      m_dinfo <- qReifyMaybe sName
      case m_dinfo of
        Just (DVarI _ ty _ _) ->
          let num_args = countArgs ty in
          return $ wrapSingFun num_args (promoteValRhs name) (mk_exp name)
        _ -> return $ mk_exp name   -- lambda-bound
    Just exp -> return exp

wrapSingFun :: Int -> DType -> DExp -> DExp
wrapSingFun 0 _  = id
wrapSingFun n ty =
  let wrap_fun = DVarE $ case n of
                           1 -> 'singFun1
                           2 -> 'singFun2
                           3 -> 'singFun3
                           4 -> 'singFun4
                           5 -> 'singFun5
                           6 -> 'singFun6
                           7 -> 'singFun7
                           _ -> error "No support for functions of arity > 7."
  in
  (wrap_fun `DAppE` proxyFor ty `DAppE`)

wrapUnSingFun :: Int -> DType -> DExp -> DExp
wrapUnSingFun 0 _  = id
wrapUnSingFun n ty =
  let unwrap_fun = DVarE $ case n of
                             1 -> 'unSingFun1
                             2 -> 'unSingFun2
                             3 -> 'unSingFun3
                             4 -> 'unSingFun4
                             5 -> 'unSingFun5
                             6 -> 'unSingFun6
                             7 -> 'unSingFun7
                             _ -> error "No support for functions of arity > 7."
  in
  (unwrap_fun `DAppE` proxyFor ty `DAppE`)

singM :: Quasi q => SgM a -> q (a, [DDec])
singM (SgM rdr) =
  let wr = runReaderT rdr emptySgEnv
      q  = runWriterT wr
  in
  runQ q

singDecsM :: Quasi q => SgM [DDec] -> q [DDec]
singDecsM thing = do
  (decs1, decs2) <- singM thing
  return $ decs1 ++ decs2
