
#include "apwrapper/userinput_capture.h"

#include <AP_HAL/AP_HAL.h>
#include <AP_HAL_SMACCM/AP_HAL_SMACCM.h>

#define NUM_CAPTURED_CHANNELS 8

extern const AP_HAL::HAL& hal;

uint8_t userinput_capture(uint16_t *chs) {
    if (hal.rcin->valid_channels()) {
        uint8_t count = hal.rcin->read(chs, NUM_CAPTURED_CHANNELS);
        return count;
    } else {
        return 0;
    }
}

