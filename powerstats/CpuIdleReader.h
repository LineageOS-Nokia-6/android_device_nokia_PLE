// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <charconv>
#include <cstdint>
#include <fstream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace ple {
struct IdleState { int32_t id; int64_t timeMs; int64_t entries; };
struct CpuResidency { int32_t id; std::vector<IdleState> states; };

class CpuIdleReader {
  public:
    explicit CpuIdleReader(std::string root) : root_(std::move(root)) {}
    std::vector<CpuResidency> read(std::vector<int32_t> ids) const {
        for (int32_t id : ids) {
            if (id < 0 || id >= 8) throw std::invalid_argument("invalid CPU power entity ID");
        }
        if (ids.empty()) ids = {0, 1, 2, 3, 4, 5, 6, 7};
        std::vector<CpuResidency> result;
        for (int32_t cpu : ids) {
            CpuResidency item{cpu, {}};
            for (int32_t state = 0; state < 2; ++state) {
                const std::string base = root_ + "/cpu" + std::to_string(cpu) +
                    "/cpuidle/state" + std::to_string(state) + "/";
                if (text(base + "name") != "C" + std::to_string(state))
                    throw std::runtime_error("unexpected CPU-idle state name");
                // cpuidle time is microseconds. Never reinterpret as milliseconds.
                item.states.push_back({state, number(base + "time") / 1000,
                                       number(base + "usage")});
            }
            result.push_back(std::move(item));
        }
        return result;  // all-or-error; no successful partial/zero-filled sample
    }
  private:
    static std::string text(const std::string& path) {
        std::ifstream stream(path);
        std::string value, extra;
        if (!stream || !std::getline(stream, value)) throw std::runtime_error("unreadable CPU-idle statistic");
        // PLE's cpuidle names already contain a newline before sysfs adds its
        // own. Accept trailing empty lines, but never a second nonempty value.
        while (std::getline(stream, extra)) {
            if (!extra.empty()) throw std::runtime_error("multiline CPU-idle statistic");
        }
        if (!stream.eof()) throw std::runtime_error("unreadable CPU-idle statistic");
        return value;
    }
    static int64_t number(const std::string& path) {
        const std::string value = text(path);
        uint64_t parsed = 0;
        auto [end, error] = std::from_chars(value.data(), value.data() + value.size(), parsed);
        if (error != std::errc{} || end != value.data() + value.size() ||
            parsed > static_cast<uint64_t>(std::numeric_limits<int64_t>::max()))
            throw std::runtime_error("invalid CPU-idle counter");
        return static_cast<int64_t>(parsed);
    }
    const std::string root_;
};
}
