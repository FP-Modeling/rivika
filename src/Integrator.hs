{-# LANGUAGE BangPatterns #-}
module Integrator where

import Data.IORef
import Control.Monad.Trans

import Prelude hiding (Real)
import Types
import Dynamics
import Solver
import Interpolation
import Memo
           
-- | The Integrator type represents an integral with caching.
data Integrator = Integrator { initial :: Dynamics Real,   -- ^ The initial value.
                               cache   :: IORef (Dynamics Real),
                               computation  :: IORef (Dynamics Real)
                             }

initialize :: Dynamics a -> Dynamics a
initialize (Dynamics m) =
  Dynamics $ \ps ->
  if iteration ps == 0 && getSolverStage (stage $ solver ps) == 0 then
    m ps
  else
    let iv = interval ps
        sl = solver ps
    in m $ ps { time = iterToTime iv sl 0 (SolverStage 0),
                iteration = 0,
                solver = sl { stage = SolverStage 0 }}

newInteg :: Dynamics Real -> Dynamics Integrator
newInteg i =
  Dynamics $ \ps ->
  do r1 <- newIORef $ initialize i 
     r2 <- newIORef $ initialize i 
     let integ = Integrator { initial = i, 
                              cache   = r1,
                              computation  = r2 }
         z = Dynamics $ \ps ->  (`apply` ps) =<< readIORef (computation integ)
     y <- memo interpolate z `apply` ps
     writeIORef (cache integ) y
     return integ

readInteg :: Integrator -> Dynamics Real
readInteg integ = 
  Dynamics $ \ps -> (`apply` ps) =<< readIORef (cache integ)

diffInteg :: Integrator -> Dynamics Real -> Dynamics ()
diffInteg integ diff = Dynamics $ const $ writeIORef (computation integ) z
  where i = initial integ
        z = Dynamics $ \ps ->
          let f = solverToFunction (method $ solver ps)
          in
          (\y -> f diff i y ps) =<< readIORef (cache integ)
     
solverToFunction Euler = integEuler
solverToFunction RungeKutta2 = integRK2
solverToFunction RungeKutta4 = integRK4

integEuler :: Dynamics Real
             -> Dynamics Real 
             -> Dynamics Real 
             -> Parameters -> IO Real
integEuler (Dynamics diff) (Dynamics i) (Dynamics y) ps =
  case iteration ps of
    0 -> 
      i ps
    n -> do 
      let iv  = interval ps
          sl  = solver ps
          ty  = iterToTime iv sl (n - 1) (SolverStage 0)
          psy = ps { time = ty, iteration = n - 1, solver = sl { stage = SolverStage 0} }
      a <- y psy
      b <- diff psy
      let !v = a + dt (solver ps) * b
      return v

integRK2 :: Dynamics Real
           -> Dynamics Real
           -> Dynamics Real
           -> Parameters -> IO Real
integRK2 (Dynamics f) (Dynamics i) (Dynamics y) ps =
  case stage (solver ps) of
    SolverStage 0 -> case iteration ps of
                       0 ->
                         i ps
                       n -> do
                         let iv = interval ps
                             sl = solver ps
                             ty = iterToTime iv sl (n - 1) (SolverStage 0)
                             t1 = ty
                             t2 = iterToTime iv sl (n - 1) (SolverStage 1)
                             psy = ps { time = ty, iteration = n - 1, solver = sl { stage = SolverStage 0 }}
                             ps1 = psy
                             ps2 = ps { time = t2, iteration = n - 1, solver = sl { stage = SolverStage 1 }}
                         vy <- y psy
                         k1 <- f ps1
                         k2 <- f ps2
                         let !v = vy + dt sl / 2.0 * (k1 + k2)
                         return v
    SolverStage 1 -> do
                  let iv = interval ps
                      sl = solver ps
                      n  = iteration ps
                      ty = iterToTime iv sl n (SolverStage 0)
                      t1 = ty
                      psy = ps { time = ty, iteration = n, solver = sl { stage = SolverStage 0 }}
                      ps1 = psy
                  vy <- y psy
                  k1 <- f ps1
                  let !v = vy + dt sl * k1
                  return v
    _ -> 
      error "Incorrect stage: integRK2"

integRK4 :: Dynamics Real
           -> Dynamics Real
           -> Dynamics Real
           -> Parameters -> IO Real
integRK4 (Dynamics f) (Dynamics i) (Dynamics y) ps =
  case stage (solver ps) of
    SolverStage 0 -> case iteration ps of
                       0 -> 
                         i ps
                       n -> do
                         let iv = interval ps
                             sl = solver ps
                             ty = iterToTime iv sl (n - 1) (SolverStage 0)
                             t1 = ty
                             t2 = iterToTime iv sl  (n - 1) (SolverStage 1)
                             t3 = iterToTime iv sl  (n - 1) (SolverStage 2)
                             t4 = iterToTime iv sl  (n - 1) (SolverStage 3)
                             psy = ps { time = ty, iteration = n - 1, solver = sl { stage = SolverStage 0 }}
                             ps1 = psy
                             ps2 = ps { time = t2, iteration = n - 1, solver = sl { stage = SolverStage 1 }}
                             ps3 = ps { time = t3, iteration = n - 1, solver = sl { stage = SolverStage 2 }}
                             ps4 = ps { time = t4, iteration = n - 1, solver = sl { stage = SolverStage 3 }}
                         vy <- y psy
                         k1 <- f ps1
                         k2 <- f ps2
                         k3 <- f ps3
                         k4 <- f ps4
                         let !v = vy + dt sl / 6.0 * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
                         return v
    SolverStage 1 -> do
                  let iv = interval ps
                      sl = solver ps
                      n  = iteration ps
                      ty = iterToTime iv sl n (SolverStage 0)
                      t1 = ty
                      psy = ps { time = ty, iteration = n, solver = sl { stage = SolverStage 0 }}
                      ps1 = psy
                  vy <- y psy
                  k1 <- f ps1
                  let !v = vy + dt sl / 2.0 * k1
                  return v
    SolverStage 2 -> do
                  let iv = interval ps
                      sl = solver ps
                      n  = iteration ps
                      ty = iterToTime iv sl n (SolverStage 0)
                      t2 = iterToTime iv sl n (SolverStage 1)
                      psy = ps { time = ty, iteration = n, solver = sl { stage = SolverStage 0 }}
                      ps2 = ps { time = t2, iteration = n, solver = sl { stage = SolverStage 1 }}
                  vy <- y psy
                  k2 <- f ps2
                  let !v = vy + dt sl / 2.0 * k2
                  return v
    SolverStage 3 -> do
                  let iv = interval ps
                      sl = solver ps
                      n  = iteration ps
                      ty = iterToTime iv sl n (SolverStage 0)
                      t3 = iterToTime iv sl n (SolverStage 2)
                      psy = ps { time = ty, iteration = n, solver = sl { stage = SolverStage 0 }}
                      ps3 = ps { time = t3, iteration = n, solver = sl { stage = SolverStage 2 }}
                  vy <- y psy
                  k3 <- f ps3
                  let !v = vy + dt sl * k3
                  return v
    _ -> 
      error "Incorrect stase: integRK4"


-- -- | The Integrator' type represents an integral without caching.
-- data Integrator' = Integrator' { initial'     :: Dynamics Real,
--                                  computation' :: IORef (Dynamics Real)
--                                }

-- newInteg' :: Dynamics Double -> Dynamics Integrator'
-- newInteg' i = 
--   do comp <- liftIO $ newIORef $ initialize i 
--      let integ = Integrator'{ initial'     = i, 
--                               computation' = comp }
--      return integ

-- readInteg' :: Integrator' -> Dynamics Real
-- readInteg' integ = 
--   Dynamics $ \ps ->
--   do (Dynamics m) <- readIORef (computation' integ)
--      m ps
     
-- diffInteg' :: Integrator' -> Dynamics Real -> Dynamics ()
-- diffInteg' integ diff =
--   do let z = Dynamics $ \ps ->
--            do y <- readIORef (computation' integ)
--               let i = initial' integ
--               case method (solver ps) of
--                 Euler -> integEuler diff i y ps
--                 RungeKutta2 -> integRK2 diff i y ps
--                 RungeKutta4 -> integRK4 diff i y ps
--      liftIO $ writeIORef (computation' integ) (interpolate z)
