{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeFamilies #-}

module SMACCMPilot.Flight.Control.Yaw
  ( YawControl(..)
  , taskYawControl
  ) where

import Ivory.Language
import Ivory.Tower

import SMACCMPilot.Param
import SMACCMPilot.Flight.Param

import qualified SMACCMPilot.Flight.Types.Sensors         ()
import qualified SMACCMPilot.Flight.Types.ControlOutput   as CO
import qualified SMACCMPilot.Flight.Types.AttControlDebug ()

import           SMACCMPilot.Flight.Control.Attitude.YawRate
import           SMACCMPilot.Flight.Control.Attitude.HeadingControl

data YawControl =
  YawControl
    { yaw_init   :: forall eff . Ivory eff ()
    , yaw_rate   :: forall eff s1
                  . Ref s1 (Struct "sensors_result")
                 -> IFloat -- rate in radians per second
                 -> IFloat -- dt
                 -> Ivory eff ()
    , yaw_heading :: forall eff s1
                  .  Ref s1 (Struct "sensors_result")
                  -> IFloat -- Heading in radians
                  -> IFloat -- Heading rate in radians/sec
                  -> IFloat -- dt
                  -> Ivory eff ()
    , yaw_reset  :: forall eff . Ivory eff ()
    , yaw_output :: forall eff s . Ref s (Struct "controloutput") -> Ivory eff ()
    }

taskYawControl :: FlightParams ParamReader
               -> Task p YawControl
taskYawControl param_reader = do
  f <- fresh
  yaw_ctl        <- taskYawRateControl (stabRate     (flightYaw param_reader))
  hctl           <- taskHeadingControl (stabPosition (flightYaw param_reader))


  let named n = "yaw_ctl_" ++ n ++ "_" ++ show f

      init_proc :: Def ('[]:->())
      init_proc = proc (named "init") $ body $ do
        yc_init   yaw_ctl
        hctl_init hctl

      rate_proc :: Def ('[ Ref s1 (Struct "sensors_result")
                           , IFloat
                           , IFloat
                           ]:->())
      rate_proc = proc (named "rate") $ \sens yaw_rate_setpt _dt -> body $ do
         yc_run yaw_ctl yaw_rate_setpt (constRef sens)

      heading_proc :: Def ('[ Ref s1 (Struct "sensors_result")
                           , IFloat
                           , IFloat
                           , IFloat
                           ]:->())
      heading_proc = proc (named "heading") $ \sens heading heading_rate dt -> body $ do
         hctl_update   hctl heading heading_rate sens dt
         yaw_rate_setpt <- hctl_setpoint hctl
         yc_run yaw_ctl yaw_rate_setpt (constRef sens)

      reset_proc  :: Def ('[]:->())
      reset_proc = proc (named "reset") $ body $ do
        hctl_reset hctl
        yc_reset  yaw_ctl

-- XXX FIX DEBUGGING
--      debug_proc :: Def ('[]:->())
--      debug_proc = proc (named "debug") $ body $ do
--        dbg <- local izero
--        hctl_write_debug hctl dbg

      output_proc :: Def ('[Ref s (Struct "controloutput")]:->())
      output_proc = proc (named "output") $ \ctl-> body $ do
        y <- yc_state yaw_ctl
        store (ctl ~> CO.yaw) y

  taskModuleDef $ do
    incl init_proc
    incl rate_proc
    incl heading_proc
    incl reset_proc
    incl output_proc
  return YawControl
    { yaw_init = call_ init_proc
    , yaw_rate  = call_ rate_proc
    , yaw_heading = call_ heading_proc
    , yaw_reset = call_ reset_proc
    , yaw_output = call_ output_proc
    }

