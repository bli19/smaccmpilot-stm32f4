{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.SystemTime where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

systemTimeMsgId :: Uint8
systemTimeMsgId = 2

systemTimeCrcExtra :: Uint8
systemTimeCrcExtra = 137

systemTimeModule :: Module
systemTimeModule = package "mavlink_system_time_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkSystemTimeSender
  incl systemTimeUnpack
  defStruct (Proxy :: Proxy "system_time_msg")

[ivory|
struct system_time_msg
  { time_unix_usec :: Stored Uint64
  ; time_boot_ms :: Stored Uint32
  }
|]

mkSystemTimeSender ::
  Def ('[ ConstRef s0 (Struct "system_time_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 (Struct "mavlinkPacket") -- tx buffer/length
        ] :-> ())
mkSystemTimeSender =
  proc "mavlink_system_time_msg_send"
  $ \msg seqNum sendStruct -> body
  $ do
  arr <- local (iarray [] :: Init (Array 12 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> time_unix_usec)
  call_ pack buf 8 =<< deref (msg ~> time_boot_ms)
  -- 6: header len, 2: CRC len
  let usedLen    = 6 + 12 + 2 :: Integer
  let sendArr    = sendStruct ~> mav_array
  let sendArrLen = arrayLen sendArr
  if sendArrLen < usedLen
    then error "systemTime payload of length 12 is too large!"
    else do -- Copy, leaving room for the payload
            arrayCopy sendArr arr 6 (arrayLen arr)
            call_ mavlinkSendWithWriter
                    systemTimeMsgId
                    systemTimeCrcExtra
                    12
                    seqNum
                    sendStruct

instance MavlinkUnpackableMsg "system_time_msg" where
    unpackMsg = ( systemTimeUnpack , systemTimeMsgId )

systemTimeUnpack :: Def ('[ Ref s1 (Struct "system_time_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
systemTimeUnpack = proc "mavlink_system_time_unpack" $ \ msg buf -> body $ do
  store (msg ~> time_unix_usec) =<< call unpack buf 0
  store (msg ~> time_boot_ms) =<< call unpack buf 8

