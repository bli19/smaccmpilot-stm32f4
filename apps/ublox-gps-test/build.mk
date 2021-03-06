# -*- Mode: makefile-gmake; indent-tabs-mode: t; tab-width: 2 -*-
#
# build.mk
#
# Copyright (C) 2012, Galois, Inc.
# All Rights Reserved.
#
# This software is released under the "BSD3" license.  Read the file
# "LICENSE" for more information.
#
# Written by Pat Hickey <pat@galois.com>, January 08, 2013
#

APP_UBLOX_GPS_TEST_PLATFORMS := px4fmu17_bare_freertos px4fmu17_ioar_freertos open407vc px4fmu17_ioar_echronos

$(eval $(call when_platforms, $(APP_UBLOX_GPS_TEST_PLATFORMS) \
				,tower_pkg,IVORY_PKG_UBLOX_GPS_TEST,ublox-gps-test-gen))

APP_UBLOX_GPS_TEST_IMG          := ublox-gps-test

ifneq ($($(CONFIG_PLATFORM)_TOWER_OS),echronos)
APP_UBLOX_GPS_TEST_OBJECTS      := freertos/main.o
APP_UBLOX_GPS_TEST_LIBRARIES    += libFreeRTOS.a
APP_UBLOX_GPS_TEST_INCLUDES     += $(FREERTOS_CFLAGS)
else
APP_UBLOX_GPS_TEST_ECHRONOS_PRX := echronos/ublox-gps-test.prx
APP_UBLOX_GPS_TEST_OBJECTS      := echronos/main.o
APP_UBLOX_GPS_TEST_OBJECTS      += echronos/irq_wrappers.o
endif

APP_UBLOX_GPS_TEST_REAL_OBJECTS += $(IVORY_PKG_UBLOX_GPS_TEST_OBJECTS)
APP_UBLOX_GPS_TEST_LIBS         += -lm

APP_UBLOX_GPS_TEST_INCLUDES     += -I$(TOP)/src/bsp/include
APP_UBLOX_GPS_TEST_INCLUDES     += $(IVORY_PKG_UBLOX_GPS_TEST_CFLAGS)

APP_UBLOX_GPS_TEST_CFLAGS       += -O2 $(APP_UBLOX_GPS_TEST_INCLUDES)

$(eval $(call when_platforms,$(APP_UBLOX_GPS_TEST_PLATFORMS) \
				,cbmc_pkg,APP_UBLOX_GPS_TEST,IVORY_PKG_UBLOX_GPS_TEST))

$(eval $(call when_os,echronos,echronos_gen,APP_UBLOX_GPS_TEST))
$(eval $(call when_platforms,$(APP_UBLOX_GPS_TEST_PLATFORMS) \
				,image,APP_UBLOX_GPS_TEST))

# vim: set ft=make noet ts=2:
