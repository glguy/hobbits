{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE PatternGuards #-}

-- |
-- Module      : Data.Binding.Hobbits.NameSet
-- Copyright   : (c) 2020 Edwin Westbrook
--
-- License     : BSD3
--
-- Maintainer  : westbrook@galois.com
-- Stability   : experimental
-- Portability : GHC
--
-- Implements sets of 'Name's using 'Data.IntSet.Strict'. Note that these
-- mappings are strict.

module Data.Binding.Hobbits.NameSet (
  NameSet(), SomeName(..)
  , empty, singleton, fromList, toList
  , insert, delete, member, null, size
  , union, unions, difference, (\\), intersection
  , map, foldr, foldl
  , liftNameSet
  ) where

import Prelude hiding (lookup, null, map, foldr, foldl)
import qualified Prelude as Prelude (map)
import Data.Maybe
import Data.IntSet (IntSet)
import qualified Data.IntSet as IntSet
import Data.Kind
import qualified Data.Foldable as Foldable

import Data.Binding.Hobbits.Internal.Name
import Data.Binding.Hobbits.Mb
import Data.Binding.Hobbits.NuMatching
import Data.Binding.Hobbits.QQ
import Data.Binding.Hobbits.Liftable

-- | A set of 'Name's whose types all have kind @k@
newtype NameSet k = NameSet { unNameSet :: IntSet }

-- | A 'Name' of some unknown type of kind @k@
data SomeName k = forall (a :: k). SomeName (Name a)

$(mkNuMatching [t| forall k. SomeName k |])

-- | The empty 'NameSet'
empty :: NameSet k
empty = NameSet $ IntSet.empty

-- | The singleton 'NameSet'
singleton :: Name (a::k) -> NameSet k
singleton (MkName i) = NameSet $ IntSet.singleton $ i

-- | Convert a list of names to a 'NameSet'
fromList :: [SomeName k] -> NameSet k
fromList =
  NameSet . IntSet.fromList . Prelude.map (\(SomeName (MkName i)) -> i)

-- | Convert a 'NameSet' to a list
toList :: NameSet k -> [SomeName k]
toList (NameSet s) = Prelude.map (SomeName . MkName) (IntSet.toList s)

-- | Insert a name into a 'NameSet'
insert :: Name (a::k) -> NameSet k -> NameSet k
insert (MkName i) (NameSet s) = NameSet $ IntSet.insert i s

-- | Delete a name from a 'NameSet'
delete :: Name (a::k) -> NameSet k -> NameSet k
delete (MkName i) (NameSet s) = NameSet $ IntSet.delete i s

-- | Test if a name is in a 'NameSet'
member :: Name (a::k) -> NameSet k -> Bool
member (MkName i) (NameSet s) = IntSet.member i s

-- | Test if a 'NameSet' is empty
null :: NameSet k -> Bool
null (NameSet s) = IntSet.null s

-- | Compute the cardinality of a 'NameSet'
size :: NameSet k -> Int
size (NameSet s) = IntSet.size s

-- | Take the union of two 'NameSet's
union :: NameSet k -> NameSet k -> NameSet k
union (NameSet s1) (NameSet s2) = NameSet $ IntSet.union s1 s2

-- | Take the union of a list of 'NameSet's
unions :: Foldable f => f (NameSet k) -> NameSet k
unions = Foldable.foldl' union empty

-- | Take the set of all elements of the first 'NameSet' not in the second
difference :: NameSet k -> NameSet k -> NameSet k
difference (NameSet s1) (NameSet s2) = NameSet $ IntSet.difference s1 s2

-- | Another name for 'difference'
(\\) :: NameSet k -> NameSet k -> NameSet k
(\\) = difference

-- | Take the intersection of two 'NameSet's
intersection :: NameSet k -> NameSet k -> NameSet k
intersection (NameSet s1) (NameSet s2) = NameSet $ IntSet.intersection s1 s2

-- | Map a function across all elements of a 'NameSet'
map :: (forall (a::k). Name a -> Name a) -> NameSet k -> NameSet k
map f (NameSet s) =
  NameSet $ IntSet.map (\i -> let (MkName j) = f (MkName i) in j) s

-- | Perform a right fold of a function across all elements of a 'NameSet'
foldr :: (forall (a::k). Name a -> r -> r) -> r -> NameSet k -> r
foldr f r (NameSet s) = IntSet.foldr (f . MkName) r s

-- | Perform a left fold of a function across all elements of a 'NameSet'
foldl :: (forall (a::k). r -> Name a -> r) -> r -> NameSet k -> r
foldl f r (NameSet s) = IntSet.foldl (\r -> f r . MkName) r s

-- | Lift a 'NameSet' out of a name-binding by lifting all names not bound by
-- the name-binding and then forming a 'NameSet' from those lifted names
liftNameSet :: Mb ctx (NameSet (k :: Type)) -> NameSet k
liftNameSet mb_s = fromList $ mapMaybe helper $ mbList $ fmap toList mb_s
  where
    helper :: forall ctx' k'. Mb ctx' (SomeName k') -> Maybe (SomeName k')
    helper [nuP| SomeName mb_n |]
      | Right n <- mbNameBoundP mb_n = Just (SomeName n)
    helper _ = Nothing
