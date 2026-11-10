// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
// Read-only Binder qualification utility. Not installed in product images.
#include <aidl/android/hardware/power/stats/IPowerStats.h>
#include <android/binder_manager.h>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <thread>
using namespace aidl::android::hardware::power::stats;
void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
int main() {
    auto service = IPowerStats::fromBinder(ndk::SpAIBinder(
        AServiceManager_checkService("android.hardware.power.stats.IPowerStats/default")));
    if (!service) return 2;
    try {
        std::vector<PowerEntity> entities;
        require(service->getPowerEntityInfo(&entities).isOk() && entities.size() == 8, "entities");
        for (size_t i = 0; i < entities.size(); ++i)
            require(entities[i].id == static_cast<int>(i) && entities[i].states.size() == 2, "entity schema");
        std::vector<StateResidencyResult> first, second, selected;
        require(service->getStateResidency({}, &first).isOk() && first.size() == 8, "first residency");
        std::this_thread::sleep_for(std::chrono::seconds(3));
        require(service->getStateResidency({}, &second).isOk() && second.size() == 8, "second residency");
        bool changed = false;
        for (size_t i = 0; i < first.size(); ++i) {
            require(first[i].stateResidencyData.size() == 2 && second[i].stateResidencyData.size() == 2, "states");
            for (size_t j = 0; j < 2; ++j) {
                auto a = first[i].stateResidencyData[j], b = second[i].stateResidencyData[j];
                require(a.id == static_cast<int>(j) && b.id == a.id, "state IDs");
                require(b.totalTimeInStateMs >= a.totalTimeInStateMs && b.totalStateEntryCount >= a.totalStateEntryCount, "monotonic counters");
                require(b.lastEntryTimestampMs == 0, "unsupported timestamp convention");
                changed |= b.totalTimeInStateMs > a.totalTimeInStateMs;
            }
        }
        require(changed, "no real CPU-idle counter advanced");
        require(service->getStateResidency({7, 0}, &selected).isOk() && selected.size() == 2 && selected[0].id == 7 && selected[1].id == 0, "selected IDs");
        require(service->getStateResidency({-1}, &selected).getExceptionCode() == EX_ILLEGAL_ARGUMENT, "negative ID");
        require(service->getStateResidency({8}, &selected).getExceptionCode() == EX_ILLEGAL_ARGUMENT, "out-of-range ID");
        std::vector<EnergyConsumer> consumers;
        std::vector<Channel> channels;
        std::vector<EnergyConsumerResult> consumed;
        std::vector<EnergyMeasurement> measured;
        require(service->getEnergyConsumerInfo(&consumers).isOk() && consumers.empty(), "no invented consumers");
        require(service->getEnergyMeterInfo(&channels).isOk() && channels.empty(), "no invented meters");
        require(service->getEnergyConsumed({}, &consumed).isOk() && consumed.empty(), "empty consumer query");
        require(service->readEnergyMeter({}, &measured).isOk() && measured.empty(), "empty meter query");
        require(service->readEnergyMeter({0}, &measured).getExceptionCode() == EX_ILLEGAL_ARGUMENT, "invalid meter");
        require(service->getEnergyConsumed({0}, &consumed).getExceptionCode() == EX_ILLEGAL_ARGUMENT, "invalid consumer");
        std::cout << "PASS actual Binder: 8CPU/16states, monotonic real samples, selected/invalid IDs, honest unsupported energy/timestamps\n";
    } catch (const std::exception& error) {
        std::cerr << "FAIL " << error.what() << '\n'; return 1;
    }
}
