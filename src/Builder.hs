{-# LANGUAGE DeriveGeneric, FlexibleInstances, LambdaCase #-}
module Builder (
    CcMode (..), GhcMode (..), GhcPkgMode (..), Builder (..), isOptional, builder
    ) where

import GHC.Generics
import Hadrian.Expression

import Base
import Context
import Stage

-- | C compiler can be used in two different modes:
-- * Compile or preprocess a source file.
-- * Extract source dependencies by passing @-MM@ command line argument.
data CcMode = CompileC | FindCDependencies deriving (Eq, Generic, Show)

instance Binary   CcMode
instance Hashable CcMode
instance NFData   CcMode

-- | GHC can be used in four different modes:
-- * Compile a Haskell source file.
-- * Compile a C source file.
-- * Extract source dependencies by passing @-M@ command line argument.
-- * Link object files & static libraries into an executable.
data GhcMode = CompileHs | CompileCWithGhc | FindHsDependencies | LinkHs
    deriving (Eq, Generic, Show)

instance Binary   GhcMode
instance Hashable GhcMode
instance NFData   GhcMode

-- | GhcPkg can initialise a package database and register packages in it.
data GhcPkgMode = Init | Update deriving (Eq, Generic, Show)

instance Binary   GhcPkgMode
instance Hashable GhcPkgMode
instance NFData   GhcPkgMode

-- | A 'Builder' is an external command invoked in a separate process via 'cmd'.
-- @Ghc Stage0@ is the bootstrapping compiler.
-- @Ghc StageN@, N > 0, is the one built in stage (N - 1).
-- @GhcPkg Stage0@ is the bootstrapping @GhcPkg@.
-- @GhcPkg Stage1@ is the one built in Stage0.
data Builder = Alex
             | Ar Stage
             | DeriveConstants
             | Cc CcMode Stage
             | Configure FilePath
             | GenApply
             | GenPrimopCode
             | Ghc GhcMode Stage
             | GhcCabal
             | GhcCabalHsColour -- synonym for 'GhcCabal hscolour'
             | GhcPkg GhcPkgMode Stage
             | Haddock
             | Happy
             | Hpc
             | HsColour
             | HsCpp
             | Hsc2Hs
             | Ld
             | Make FilePath
             | Nm
             | Objdump
             | Patch
             | Perl
             | Ranlib
             | Tar
             | Unlit
             deriving (Eq, Generic, Show)

instance Binary   Builder
instance Hashable Builder
instance NFData   Builder

-- TODO: Some builders are required only on certain platforms. For example,
-- Objdump is only required on OpenBSD and AIX, as mentioned in #211. Add
-- support for platform-specific optional builders as soon as we can reliably
-- test this feature.
isOptional :: Builder -> Bool
isOptional = \case
    HsColour -> True
    Objdump  -> True
    _        -> False

-- | This type class allows the user to construct both precise builder
-- predicates, such as @builder (Ghc CompileHs Stage1)@, as well as predicates
-- covering a set of similar builders. For example, @builder (Ghc CompileHs)@
-- matches any stage, and @builder Ghc@ matches any stage and any GHC mode.
class BuilderPredicate a where
    -- | Is a particular builder being used?
    builder :: a -> Predicate Context Builder

instance BuilderPredicate Builder where
    builder b = (b ==) <$> getBuilder

instance BuilderPredicate a => BuilderPredicate (Stage -> a) where
    builder f = builder . f =<< getStage

instance BuilderPredicate a => BuilderPredicate (CcMode -> a) where
    builder f = do
        b <- getBuilder
        case b of
            Cc  c _ -> builder (f c)
            _       -> return False

instance BuilderPredicate a => BuilderPredicate (GhcMode -> a) where
    builder f = do
        b <- getBuilder
        case b of
            Ghc c _ -> builder (f c)
            _       -> return False

instance BuilderPredicate a => BuilderPredicate (FilePath -> a) where
    builder f = do
        b <- getBuilder
        case b of
            Configure path -> builder (f path)
            _              -> return False
