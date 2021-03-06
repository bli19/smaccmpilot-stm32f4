{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- Autogenerated Mavlink v1.0 implementation: see smavgen_ivory.py

module SMACCMPilot.Mavlink.Messages.VisionSpeedEstimate where

import SMACCMPilot.Mavlink.Pack
import SMACCMPilot.Mavlink.Unpack
import SMACCMPilot.Mavlink.Send

import Ivory.Language
import Ivory.Stdlib

visionSpeedEstimateMsgId :: Uint8
visionSpeedEstimateMsgId = 103

visionSpeedEstimateCrcExtra :: Uint8
visionSpeedEstimateCrcExtra = 208

visionSpeedEstimateModule :: Module
visionSpeedEstimateModule = package "mavlink_vision_speed_estimate_msg" $ do
  depend packModule
  depend mavlinkSendModule
  incl mkVisionSpeedEstimateSender
  incl visionSpeedEstimateUnpack
  defStruct (Proxy :: Proxy "vision_speed_estimate_msg")

[ivory|
struct vision_speed_estimate_msg
  { usec :: Stored Uint64
  ; x :: Stored IFloat
  ; y :: Stored IFloat
  ; z :: Stored IFloat
  }
|]

mkVisionSpeedEstimateSender ::
  Def ('[ ConstRef s0 (Struct "vision_speed_estimate_msg")
        , Ref s1 (Stored Uint8) -- seqNum
        , Ref s1 (Struct "mavlinkPacket") -- tx buffer/length
        ] :-> ())
mkVisionSpeedEstimateSender =
  proc "mavlink_vision_speed_estimate_msg_send"
  $ \msg seqNum sendStruct -> body
  $ do
  arr <- local (iarray [] :: Init (Array 20 (Stored Uint8)))
  let buf = toCArray arr
  call_ pack buf 0 =<< deref (msg ~> usec)
  call_ pack buf 8 =<< deref (msg ~> x)
  call_ pack buf 12 =<< deref (msg ~> y)
  call_ pack buf 16 =<< deref (msg ~> z)
  -- 6: header len, 2: CRC len
  let usedLen    = 6 + 20 + 2 :: Integer
  let sendArr    = sendStruct ~> mav_array
  let sendArrLen = arrayLen sendArr
  if sendArrLen < usedLen
    then error "visionSpeedEstimate payload of length 20 is too large!"
    else do -- Copy, leaving room for the payload
            arrayCopy sendArr arr 6 (arrayLen arr)
            call_ mavlinkSendWithWriter
                    visionSpeedEstimateMsgId
                    visionSpeedEstimateCrcExtra
                    20
                    seqNum
                    sendStruct

instance MavlinkUnpackableMsg "vision_speed_estimate_msg" where
    unpackMsg = ( visionSpeedEstimateUnpack , visionSpeedEstimateMsgId )

visionSpeedEstimateUnpack :: Def ('[ Ref s1 (Struct "vision_speed_estimate_msg")
                             , ConstRef s2 (CArray (Stored Uint8))
                             ] :-> () )
visionSpeedEstimateUnpack = proc "mavlink_vision_speed_estimate_unpack" $ \ msg buf -> body $ do
  store (msg ~> usec) =<< call unpack buf 0
  store (msg ~> x) =<< call unpack buf 8
  store (msg ~> y) =<< call unpack buf 12
  store (msg ~> z) =<< call unpack buf 16

