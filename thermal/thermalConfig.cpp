// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#include "thermalConfig.h"

namespace android::hardware::thermal::V2_0::implementation {
ThermalConfig::ThermalConfig() {
    // Names verified on PLE4.19, never use pseudo ADC alarm/current zones.
    // SEVERE mirrors existing kernel cooling (CPU85/GPU95C) and case trip65C.
    // Zero leaves undocumented shutdown/VR/battery thresholds as NAN. Health
    // and kernel charger/JEITA/TSENS protections remain authoritative.
    thermalConfig = {
        {TemperatureType::CPU, {"apc1-cpu0-usr", "apc1-cpu1-usr",
            "apc1-cpu2-usr", "apc1-cpu3-usr", "cpuss0-usr"}, "", 85000, 0, 0, true},
        {TemperatureType::GPU, {"gpu-usr"}, "GPU", 95000, 0, 0, true},
        {TemperatureType::SKIN, {"case-therm-adc"}, "skin", 65000, 0, 0, true},
        {TemperatureType::BATTERY, {"battery"}, "battery", 0, 0, 0, true},
    };
}
}
