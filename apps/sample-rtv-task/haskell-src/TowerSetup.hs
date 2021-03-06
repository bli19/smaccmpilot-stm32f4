
-- Put all includes, etc. in Tower () and out of tasks
-- Make use of queues easier by external tasks
-- unused vars in, e.g., taskbody_verify_updates_2 in tower.c

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import System.Environment (getArgs)

import Types
import CheckerTask
import Checker

import Ivory.Language
import Ivory.Tower
import Ivory.Tower.Frontend


--------------------------------------------------------------------------------
-- Record Assigment
--------------------------------------------------------------------------------

legacyHdr :: String
legacyHdr = "legacy.h"

--------------------------------------------------------------------------------
-- Legacy tasks: wrappers for the tasks.
--------------------------------------------------------------------------------

-- Types
type Clk = Stored Sint32
type ClkEmitterType s = '[ConstRef s Clk] :-> ()

-- Externs
clkEmitter :: (SingI n) => ChannelEmitter n Clk -> Def (ClkEmitterType s)
clkEmitter ch = proc "clkEmitter" $ \r -> body $ emit_ ch r

read_clock_block :: Def ('[ProcPtr (ClkEmitterType s)] :-> ())
read_clock_block = importProc "read_clock_block" legacyHdr

update_time_init :: Def ('[ProcPtr ('[AssignRef s] :-> ())] :-> ())
update_time_init = importProc "update_time_init" legacyHdr

update_time_block :: Def ('[Sint32] :-> ())
update_time_block = importProc "update_time_block" legacyHdr

-- Task wrapper: task reads a logical clock and passes the result to
-- updateTimeTask.
readClockTask :: (SingI n) => ChannelSource n Clk -> Task p ()
readClockTask clkSrc = do
  clk <- withChannelEmitter clkSrc "clkSrc"

  let clkEmitterProc = clkEmitter clk
  taskModuleDef (incl clkEmitterProc)

  onPeriod 1000 $ \_now -> -- once per sec
    call_ read_clock_block $ procPtr clkEmitterProc

-- Task wrapper: task reads the channel and updates its local state with the
-- time.
updateTimeTask :: (SingI n, SingI m)
               => ChannelSink n Clk -> ChannelSource m AssignStruct -> Task p ()
updateTimeTask clk chk = do
  newVal <- withChannelEmitter chk "newVal"

  let recordEmitProc = recordEmit newVal
  taskModuleDef (incl recordEmitProc)

  taskInit (call_ update_time_init $ procPtr recordEmitProc)
  onChannelV clk "timeRx" $ \time -> do
    call_ update_time_block time

--------------------------------------------------------------------------------

assignModule :: Module
assignModule = package "assignment" $ defStruct (Proxy :: Proxy "assignment")

tasks :: Tower p ()
tasks = do
  (chkSrc, chkSink) <- channel
  (clkSrc, clkSink) <- channel
  task "verify_updates" $ checkerTask chkSink
  task "readClockTask"  $ readClockTask clkSrc
  task "updateTimeTask" $ updateTimeTask clkSink chkSrc

  -- Create assignments definition
  addModule assignModule
  -- Include it everywhere
  addDepends assignModule

--------------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  compile defaultBuildConf (tasks >> addModule checksMod)
  checker (verbose args)
  where
  verbose args = "--verbose" `elem` args
              || "-v" `elem` args

--------------------------------------------------------------------------------
