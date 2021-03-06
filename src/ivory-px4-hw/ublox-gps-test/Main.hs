{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}

module Main where

import Data.Char (ord)

import Ivory.Language
import Ivory.Stdlib

import Ivory.Tower
import Ivory.Tower.StateMachine
import Ivory.Tower.Frontend

import Ivory.BSP.STM32F4.RCC (BoardHSE)
import qualified Ivory.HW.SearchDir          as HW
import qualified Ivory.BSP.STM32F4.SearchDir as BSP

import Ivory.BSP.STM32F4.UART

import SMACCMPilot.Hardware.GPS.Types.Position as P
import SMACCMPilot.Hardware.GPS.Types.GPSFix
import SMACCMPilot.Hardware.GPS.UBlox
import Platform

main :: IO ()
main = compilePlatforms conf (gpsPlatforms app)
  where
  conf = searchPathConf [ HW.searchDir, BSP.searchDir ]

app :: forall p . (GPSUart p, BoardHSE p) => Tower p ()
app = do
  (shelli :: ChannelSink 128 (Stored Uint8)
   ,shello :: ChannelSource 128 (Stored Uint8)) <- uartTower
                                                    (consoleUart (Proxy :: Proxy p))
                                                    115200
  (gpsi :: ChannelSink 128 (Stored Uint8)
   ,_gpso :: ChannelSource 128 (Stored Uint8)) <- uartTower
                                                  (gpsUart (Proxy :: Proxy p))
                                                  38400
  position <- channel
  shell "gps test shell, console." shello shelli (snk position)
  ubloxGPSTower gpsi (src position)

forward :: (SingI n, SingI m, IvoryArea a, IvoryZero a)
        => ChannelSource n a
        -> ChannelSink   m a
        -> Tower p ()
forward osrc isnk = task "forward" $ do
  o <- withChannelEmitter  osrc "ostream"
  i <- withChannelEvent    isnk "istream"
  onEvent i (emit_ o)


shell :: (SingI n, SingI m, SingI o)
      => String
      -> ChannelSource n (Stored Uint8)
      -> ChannelSink   m (Stored Uint8)
      -> ChannelSink   o (Struct "position")
      -> Tower p ()
shell greet ostream istream ipos = task "shell" $ do
  out <- withChannelEmitter  ostream "ostream"
  inp <- withChannelEvent    istream "istream"
  posin <- withChannelEvent  ipos    "positionin"
  withStackSize 1024
  let puts str = mapM_ (\c -> putc (fromIntegral (ord c))) str
      putc c = emitV_ out c

  sm <- stateMachine "motor_shell" $ mdo
    init <- stateNamed "init" $ entry $ do
      liftIvory_ $ puts (greet ++ "\n")
      goto prompt

    prompt <- stateNamed "prompt" $ do
      entry $ liftIvory_ $ puts "> "
      on inp $ \inref -> liftIvory $ do
        i <- deref inref
        putc i -- Echo
        return $ do
          branch (i `isChar` '?')   help
          branch (i `isChar` 'f')   showfix
          branch (i `isChar` 's')   showsats
          branch (i `isChar` '\n')  prompt
          goto unknown

    showsats <- stateNamed "sats" $ do
      entry $ liftIvory_ $
        puts "\nshowing number of gps satellites, any key to exit\n"
      on inp $ \_ -> goto prompt
      on posin $ \p -> liftIvory_ $ do
        numsv <- deref (p ~> P.num_sv)
        puts "# "
        ifte_ (numsv <? 10)
              (putc (itoa numsv))
              (puts "9+")
        puts "\n"

    showfix <- stateNamed "fix" $ do
      entry $ liftIvory_ $
        puts "\nshowing gps fix, any key to exit\n"
      on inp $ \_ -> goto prompt
      on posin $ \p -> liftIvory_ $ do
        f <- deref (p ~> P.fix)
        cond_ [ f ==? fix_none ==> puts "no fix\n"
              , f ==? fix_2d   ==> puts "2d fix\n"
              , f ==? fix_3d   ==> puts "3d fix\n"
              ]

    unknown <- stateNamed "unknown" $ do
      entry $ do
        liftIvory_ $ puts "\n\nunknown command"
        goto help

    help <- stateNamed "help" $ do
      entry $ do
        liftIvory_ $ puts helpmsg
        goto prompt

    return init

  taskInit $ begin sm

helpmsg :: String
helpmsg = unlines $
  [ ""
  , "Help:"
  , "f: show gps fix status"
  , "s: show number of satellites visible"
  , "? for help"
  ]

isChar :: Uint8 -> Char -> IBool
isChar b c = b ==? (fromIntegral (ord c))

-- Hacky and unsafe...
itoa :: Uint8 -> Uint8
itoa i = i + (fromIntegral (ord '0'))
atoi :: Uint8 -> Uint8
atoi a = a - (fromIntegral (ord '0'))

