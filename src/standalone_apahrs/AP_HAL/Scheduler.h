
#ifndef __AP_HAL_SCHEDULER_H__
#define __AP_HAL_SCHEDULER_H__

#include "AP_HAL_Namespace.h"

#include <stdint.h>
#include <AP_Progmem/AP_Progmem.h>

class AP_HAL::Scheduler {
public:
    Scheduler() {}
    virtual void     init(void* implspecific) = 0;
    virtual void     delay(uint16_t ms) = 0;
    virtual uint32_t millis() = 0;
    virtual uint32_t micros() = 0;

    // register a high priority timer task
    virtual void     register_timer_process(AP_HAL::TimedProc) = 0;

    // register a low priority IO task
    virtual void     register_io_process(AP_HAL::TimedProc) = 0;

    // suspend and resume both timer and IO processes
    virtual void     suspend_timer_procs() = 0;
    virtual void     resume_timer_procs() = 0;

    virtual bool     in_timerprocess() = 0;

    virtual void     register_timer_failsafe(AP_HAL::TimedProc,
                        uint32_t period_us) = 0;

    virtual bool     system_initializing() = 0;
    virtual void     system_initialized() = 0;

    virtual void     panic(const prog_char_t *errormsg) = 0;
    virtual void     reboot() = 0;
};

#endif // __AP_HAL_SCHEDULER_H__

