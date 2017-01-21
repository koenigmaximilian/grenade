{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
module Grenade.Layers.Fuse (
    Fuse (..)
  ) where

import           Grenade.Core.Network
import           Grenade.Core.Shape

-- | Fuse two layers into one layer.
--   This can be used to simplify a network if a complicated repeated structure is used.
data Fuse :: * -> * -> Shape -> Shape -> Shape -> * where
    (:$$) :: (Layer x i h, Layer y h o)
          => !x
          -> !y
          -> Fuse x y i h o
infixr 5 :$$

instance (Show x, Show y) => Show (Fuse x y i h o) where
  show (x :$$ y) = "(" ++ show x ++ " :$$ " ++ show y ++ ")"

instance (Layer x i h, Layer y h o) => UpdateLayer (Fuse x y i h o) where
  type Gradient (Fuse x y i h o) = (Gradient x, Gradient y)
  runUpdate lr (x :$$ y) (x', y') =
    let newX = runUpdate lr x x'
        newY = runUpdate lr y y'
    in (newX :$$ newY)
  createRandom = (:$$) <$> createRandom <*> createRandom

instance (Layer x i h, Layer y h o) => Layer (Fuse x y i h o) i o where
  type Tape (Fuse x y i h o) i o = (Tape x i h, Tape y h o)
  runForwards (x :$$ y) input =
    let (xTape, yInput :: S h) = runForwards x input
        (yTape, output :: S o) = runForwards y yInput
    in  ((xTape, yTape), output)

  runBackwards (x :$$ y) (xTape, yTape) backGradient =
    let (y', yGrad :: S h) = runBackwards y yTape backGradient
        (x', xGrad)        = runBackwards x xTape yGrad
    in ((x', y'), xGrad)
