
module Ivory.BSP.HWF4
  ( hwf4Modules
  ) where

import Ivory.Language

import Ivory.BSP.HWF4.EEPROM
import Ivory.BSP.HWF4.I2C
import Ivory.BSP.HWF4.GPIO
import Ivory.BSP.HWF4.USART

hwf4Modules :: [Module]
hwf4Modules =
  [ eepromModule
  , i2cModule
  , gpioModule
  , usartModule
  ]

