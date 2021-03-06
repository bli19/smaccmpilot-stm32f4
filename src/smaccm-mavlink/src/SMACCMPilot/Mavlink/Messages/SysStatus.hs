{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.SysStatus where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

sysStatusMsgId :: Uint8
sysStatusMsgId = 1

sysStatusCrcExtra :: Uint8
sysStatusCrcExtra = 124

sysStatusModule :: Module
sysStatusModule = package "mavlink_sys_status_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkSysStatusSender
  incl sysStatusUnpack
  defStruct (Proxy :: Proxy "sys_status_msg")

[ivory|
struct sys_status_msg
  { onboard_control_sensors_present :: Stored Uint32
  ; onboard_control_sensors_enabled :: Stored Uint32
  ; onboard_control_sensors_health :: Stored Uint32
  ; load :: Stored Uint16
  ; voltage_battery :: Stored Uint16
  ; current_battery :: Stored Sint16
  ; drop_rate_comm :: Stored Uint16
  ; errors_comm :: Stored Uint16
  ; errors_count1 :: Stored Uint16
  ; errors_count2 :: Stored Uint16
  ; errors_count3 :: Stored Uint16
  ; errors_count4 :: Stored Uint16
  ; battery_remaining :: Stored Sint8
  }
|]

mkSysStatusSender ::
  Def ('[ ConstRef s0 (Struct "sys_status_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 (Struct "mavlinkPacket") -- tx buffer/length
        ] :-> ())
mkSysStatusSender =
  proc "mavlink_sys_status_msg_send"
  $ \msg seqNum sendStruct -> body
  $ do
  arr <- local (iarray [] :: Init (Array 31 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> onboard_control_sensors_present)
  call_ pack buf 4 =<< deref (msg ~> onboard_control_sensors_enabled)
  call_ pack buf 8 =<< deref (msg ~> onboard_control_sensors_health)
  call_ pack buf 12 =<< deref (msg ~> load)
  call_ pack buf 14 =<< deref (msg ~> voltage_battery)
  call_ pack buf 16 =<< deref (msg ~> current_battery)
  call_ pack buf 18 =<< deref (msg ~> drop_rate_comm)
  call_ pack buf 20 =<< deref (msg ~> errors_comm)
  call_ pack buf 22 =<< deref (msg ~> errors_count1)
  call_ pack buf 24 =<< deref (msg ~> errors_count2)
  call_ pack buf 26 =<< deref (msg ~> errors_count3)
  call_ pack buf 28 =<< deref (msg ~> errors_count4)
  call_ pack buf 30 =<< deref (msg ~> battery_remaining)
  -- 6: header len, 2: CRC len
  let usedLen    = 6 + 31 + 2 :: Integer
  let sendArr    = sendStruct ~> mav_array
  let sendArrLen = arrayLen sendArr
  if sendArrLen < usedLen
    then error "sysStatus payload of length 31 is too large!"
    else do -- Copy, leaving room for the payload
            arrayCopy sendArr arr 6 (arrayLen arr)
            call_ mavlinkSendWithWriter
                    sysStatusMsgId
                    sysStatusCrcExtra
                    31
                    seqNum
                    sendStruct

instance MavlinkUnpackableMsg "sys_status_msg" where
    unpackMsg = ( sysStatusUnpack , sysStatusMsgId )

sysStatusUnpack :: Def ('[ Ref s1 (Struct "sys_status_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
sysStatusUnpack = proc "mavlink_sys_status_unpack" $ \ msg buf -> body $ do
  store (msg ~> onboard_control_sensors_present) =<< call unpack buf 0
  store (msg ~> onboard_control_sensors_enabled) =<< call unpack buf 4
  store (msg ~> onboard_control_sensors_health) =<< call unpack buf 8
  store (msg ~> load) =<< call unpack buf 12
  store (msg ~> voltage_battery) =<< call unpack buf 14
  store (msg ~> current_battery) =<< call unpack buf 16
  store (msg ~> drop_rate_comm) =<< call unpack buf 18
  store (msg ~> errors_comm) =<< call unpack buf 20
  store (msg ~> errors_count1) =<< call unpack buf 22
  store (msg ~> errors_count2) =<< call unpack buf 24
  store (msg ~> errors_count3) =<< call unpack buf 26
  store (msg ~> errors_count4) =<< call unpack buf 28
  store (msg ~> battery_remaining) =<< call unpack buf 30

