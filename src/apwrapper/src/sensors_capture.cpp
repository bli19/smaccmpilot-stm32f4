
#include "apwrapper/sensors_capture.h"

#ifdef ECHRONOS
#include <eChronos.h>
#else
#include <FreeRTOS.h>
#include <task.h>
#include <semphr.h>
#endif

#include <hwf4/led.h>

#include <AP_AHRS/AP_AHRS.h>
#include <AP_AHRS/AP_AHRS_DCM.h>
#include <AP_Baro/AP_Baro.h>
#include <AP_GPS/AP_GPS.h>
#include <AP_Compass/AP_Compass_HMC5843.h>
#include <AP_InertialSensor/AP_InertialSensor_MPU6000.h>
#include <AP_Param/AP_Param.h>
#include <AP_HAL/AP_HAL.h>
extern const AP_HAL::HAL& hal;

static void flash_leds(bool on);

// The rate we run the inertial sensor at.
static const AP_InertialSensor::Sample_rate INS_SAMPLE_RATE =
    AP_InertialSensor::RATE_200HZ;

static AP_InertialSensor_MPU6000 g_ins;
static AP_Compass_HMC5843 g_compass;
static AP_Baro_MS5611 g_baro(&AP_Baro_MS5611::i2c);
static GPS_Shim gps_shim;
static GPS *g_gps = &gps_shim;
static AP_AHRS_DCM g_ahrs(&g_ins, g_gps);

// Timestamp of the last sensor data updates.
static portTickType g_ahrs_time;
static portTickType g_baro_time;

void sensors_begin(bool flipped) {

    hal.console->printf("init AP_InertialSensor: ");
    if (flipped) {
        g_ahrs.set_orientation(ROTATION_ROLL_180);
    }
    g_ins.init(AP_InertialSensor::COLD_START, INS_SAMPLE_RATE, flash_leds);
    g_ins.init_accel(flash_leds);
    hal.console->println();
    led_set(0, false);
    hal.console->printf("done\r\n");

    hal.console->printf("init AP_Compass: ");
    g_compass.init();
    g_compass.set_orientation(AP_COMPASS_COMPONENTS_DOWN_PINS_BACK);
    g_compass.set_offsets(0,0,0);
    g_compass.set_declination(0);
    hal.console->printf("done\r\n");

    hal.console->printf("init AP_Baro: ");
    g_baro.init();
    g_baro.calibrate();
    hal.console->printf("done\r\n");

    hal.console->printf("init AP_AHRS: ");
    g_ahrs.init();
    g_ahrs.set_compass(&g_compass);
    hal.console->printf("sensors init done\r\n");

}

void sensors_update() {
    static portTickType last_compass = 0;

    portTickType now = xTaskGetTickCount();

    if (last_compass == 0 || now - last_compass > 100) {
        last_compass = now;
        g_compass.read();
        g_baro.read();
        g_baro_time = now;
    }

    g_ahrs.update();
    g_compass.null_offsets();
    g_ahrs_time = now;
}

/* Write roll, pitch, yaw into an array of 3 floats
 * [ roll, pitch, yaw ]
 * units: radians
 */
void sensors_get_rpy(float *capt, uint32_t *time) {
    capt[0] = g_ahrs.roll;
    capt[1] = g_ahrs.pitch;
    capt[2] = g_ahrs.yaw;
    *time   = g_ahrs_time;
}

/* Write omega (angular rate) into an array of 3 floats
 * [ omega_x, omega_y, omega_z ]
 * units: radians/sec
 */
void sensors_get_omega(float *capt) {
    /* ahrs.get_gyro gives a smoothed (gyro, drift & offset compensated)
     * omega (body frame rate) output */
    const Vector3f omega = g_ahrs.get_gyro();
    capt[0] = omega.x;
    capt[1] = omega.y;
    capt[2] = omega.z;
}

/* Write accel values to an array of 3 floats.
 * [ accel_x, accel_y, accel_z ]
 * units: mg
 */
void sensors_get_accel(float *capt) {
    const Vector3f accel = g_ahrs.get_ins()->get_accel();
    capt[0] = accel.x / 9.81f * 1000.0f;
    capt[1] = accel.y / 9.81f * 1000.0f;
    capt[2] = accel.z / 9.81f * 1000.0f;
}

/* Get barometric altitude estimate
 * unit: meters
 */
float sensors_get_baro_alt(uint32_t *time) {
    /* altitude is only filtered by AP_Baro, no inertial compensation */
    *time = g_baro_time;
    return g_baro.get_altitude();
}


void sensors_set_gps_velocity(int32_t v_north, int32_t v_east, int32_t v_down,
        uint32_t speed_ground, float heading)
{
    gps_shim.set_velocity(v_north,v_east,v_down);
    float heading_cd = heading * 100.0f;
    gps_shim.set_ground_speed_course(speed_ground, (int32_t) heading_cd);
}

void sensors_set_gps_position(int32_t lat, int32_t lon) {
    gps_shim.set_lat_lon(lat,lon);
}

void sensors_set_gps_position_for_compass(int32_t lat, int32_t lon) {
    g_compass.set_initial_location(lat,lon);
}

void sensors_set_gps_fix(bool fix2d, bool fix3d, uint8_t num_sats) {
    gps_shim.set_fix(fix2d, fix3d, num_sats);
}

/* This is dead code, used in the past for debugging. */
#pragma GCC diagnostic ignored "-Wunused-function"
static void sensors_debug() {
    static int divider = 0;
    if (divider++ == 20) {
        divider = 0;
        float heading = g_compass.calculate_heading(g_ahrs.get_dcm_matrix());

        hal.console->printf("ahrs: roll %4.1f pitch %4.1f "
                            "yaw %4.1f hdg %.1f\r\n",
                            ToDeg(g_ahrs.roll), ToDeg(g_ahrs.pitch),
                            ToDeg(g_ahrs.yaw),
                            g_compass.use_for_yaw() ? ToDeg(heading):0.0f);

        Vector3f accel(g_ins.get_accel());
        Vector3f gyro(g_ins.get_gyro());
        hal.console->printf("mpu6000: accel %.2f %.2f %.2f "
                            "gyro %.2f %.2f %.2f\r\n",
                            accel.x, accel.y, accel.z,
                            gyro.x, gyro.y, gyro.z);

        hal.console->printf("compass: heading %.2f deg\r\n",
                            ToDeg(g_compass.calculate_heading(0, 0)));
    }
}

static void flash_leds(bool on) {
  led_set(0, on);
}

