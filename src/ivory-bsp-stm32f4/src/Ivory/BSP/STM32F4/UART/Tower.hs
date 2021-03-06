{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Ivory.BSP.STM32F4.UART.Tower where

import GHC.TypeLits

import Ivory.Language
import Ivory.Stdlib
import Ivory.Tower
import Ivory.HW
import Ivory.HW.Module
import Ivory.BitData

import Ivory.BSP.STM32F4.Interrupt
import Ivory.BSP.STM32F4.UART.Regs
import Ivory.BSP.STM32F4.UART.Peripheral
import Ivory.BSP.STM32F4.RCC

uartTower :: forall n m p
           . (SingI n, SingI m, BoardHSE p)
          => UART
          -> Integer
          -> Tower p ( ChannelSink   n (Stored Uint8)
                     , ChannelSource m (Stored Uint8))
uartTower uart baud = do
  -- XXX MAGIC NUMBER: freertos syscalls must be lower (numerically greater than) level 11
  let max_syscall_priority = (12::Uint8)

  (src_ostream, snk_ostream) <- channelWithSize
  (src_istream, snk_istream) <- channelWithSize

  let user_src_ostream = channelSourceCallback
                            (const (setTXEIE uart true))
                             hw_moduledef
                             src_ostream
  -- Signal:
  -- runs the UART Interrupt Service Routine
  signal (uartName uart ++ "ISR") $ do
    signalInit $ do
      uartInit    uart (Proxy :: Proxy p) (fromIntegral baud)
      uartInitISR uart max_syscall_priority
    o <- withChannelReceiver snk_ostream "ostream"
    i <- withChannelEmitter  src_istream "istream"
    signalName (handlerName (uartInterrupt uart))
    signalModuleDef $ hw_moduledef
    signalBody $ do
      sr <- getReg (uartRegSR uart)
      cond_
       [ bitToBool (sr #. uart_sr_rxne) ==> do
           byte <- readDR uart
           bref <- local (ival byte)
           emit_ i (constRef bref)
       , bitToBool (sr #. uart_sr_txe)  ==> do
           byte <- local (ival 0)
           rv   <- receive o byte
           ifte_ rv
             (setDR uart =<< deref byte)
             (setTXEIE uart false)
       ]

  return (snk_istream, user_src_ostream)
