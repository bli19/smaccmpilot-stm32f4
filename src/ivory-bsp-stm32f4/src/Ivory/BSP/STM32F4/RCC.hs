--
-- RCC.hs --- RCC (Reset and Clock Control) peripheral driver.
--
-- Copyright (C) 2013, Galois, Inc.
-- All Rights Reserved.
--

module Ivory.BSP.STM32F4.RCC (
    RCCDevice(..), rccEnable, rccDisable
  , module Ivory.BSP.STM32F4.RCC.Regs

  -- * system clock frequency
  , PClk(..)
  , BoardHSE(..)
  , getFreqSysClk
  , getFreqHClk
  , getFreqPClk1
  , getFreqPClk2
  , getFreqPClk
) where

import Ivory.BSP.STM32F4.RCC.Class
import Ivory.BSP.STM32F4.RCC.Regs
import Ivory.BSP.STM32F4.RCC.GetFreq
