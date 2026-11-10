// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#include "CpuIdleReader.h"
#include <aidl/android/hardware/power/stats/BnPowerStats.h>
#include <android-base/logging.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>
#include <cerrno>
#include <cstdio>

using namespace aidl::android::hardware::power::stats;
class PlePowerStats final : public BnPowerStats {
  public:
    ndk::ScopedAStatus getPowerEntityInfo(std::vector<PowerEntity>* out) override {
        out->clear();
        for (int32_t cpu = 0; cpu < 8; ++cpu) {
            PowerEntity info;
            info.id = cpu;
            info.name = "CPU" + std::to_string(cpu);
            for (int32_t id = 0; id < 2; ++id) {
                State state;
                state.id = id;
                state.name = "C" + std::to_string(id);
                info.states.push_back(std::move(state));
            }
            out->push_back(std::move(info));
        }
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getStateResidency(const std::vector<int32_t>& ids,
                                       std::vector<StateResidencyResult>* out) override {
        out->clear();
        try {
            auto values = reader_.read(ids);
            for (const auto& cpu : values) {
                StateResidencyResult item;
                item.id = cpu.id;
                for (const auto& value : cpu.states) {
                    StateResidency state;
                    state.id = value.id;
                    state.totalTimeInStateMs = value.timeMs;
                    state.totalStateEntryCount = value.entries;
                    // Kernel does not export last-entry timestamps. Like the
                    // maintained generic provider's unsupported field: zero,
                    // not a current timestamp or invented residency.
                    state.lastEntryTimestampMs = 0;
                    item.stateResidencyData.push_back(state);
                }
                out->push_back(std::move(item));
            }
        } catch (const std::invalid_argument& error) {
            return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_ARGUMENT, error.what());
        } catch (const std::exception& error) {
            return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(EIO, error.what());
        }
        return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getEnergyConsumerInfo(std::vector<EnergyConsumer>* out) override {
        out->clear(); return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getEnergyMeterInfo(std::vector<Channel>* out) override {
        out->clear(); return ndk::ScopedAStatus::ok();
    }
    ndk::ScopedAStatus getEnergyConsumed(const std::vector<int32_t>& ids,
                                      std::vector<EnergyConsumerResult>* out) override {
        out->clear(); return noEnergyIds(ids);
    }
    ndk::ScopedAStatus readEnergyMeter(const std::vector<int32_t>& ids,
                                     std::vector<EnergyMeasurement>* out) override {
        out->clear(); return noEnergyIds(ids);
    }
    binder_status_t dump(int fd, const char**, uint32_t) override {
        std::vector<StateResidencyResult> values;
        auto status = getStateResidency({}, &values);
        if (!status.isOk()) { dprintf(fd, "CPU-idle unavailable: %s\n", status.getDescription().c_str()); return STATUS_OK; }
        for (const auto& cpu : values) for (const auto& state : cpu.stateResidencyData)
            dprintf(fd, "CPU%d C%d entries=%lld total_ms=%lld last_entry=unsupported\n", cpu.id, state.id,
                    static_cast<long long>(state.totalStateEntryCount), static_cast<long long>(state.totalTimeInStateMs));
        dprintf(fd, "Energy consumers/meters: unsupported (none); not full-system suspend accounting\n");
        return STATUS_OK;
    }
  private:
    static ndk::ScopedAStatus noEnergyIds(const std::vector<int32_t>& ids) {
        return ids.empty() ? ndk::ScopedAStatus::ok() : ndk::ScopedAStatus::fromExceptionCode(EX_ILLEGAL_ARGUMENT);
    }
    const ple::CpuIdleReader reader_{"/sys/devices/system/cpu"};
};
int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(0);
    auto service = ndk::SharedRefBase::make<PlePowerStats>();
    CHECK_EQ(AServiceManager_addService(service->asBinder().get(),
        "android.hardware.power.stats.IPowerStats/default"), STATUS_OK);
    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;
}
