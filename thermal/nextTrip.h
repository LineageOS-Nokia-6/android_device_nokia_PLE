// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <cmath>
#include <limits>
#include <optional>
#include <charconv>
#include <string_view>

namespace ple {
inline std::optional<int> parseSysfsInt(std::string_view text) {
    int value;
    const auto result = std::from_chars(text.data(), text.data() + text.size(), value);
    if (result.ec != std::errc() || result.ptr != text.data() + text.size()) return std::nullopt;
    return value;
}

template <typename Thresholds>
std::optional<int> nextHotTrip(const Thresholds& limits, int current, int scale) {
    if (scale <= 0) return std::nullopt;
    for (int i = current + 1; i < static_cast<int>(limits.size()); ++i) {
        const double value = static_cast<double>(limits[i]) * scale;
        if (!std::isfinite(value) || value < std::numeric_limits<int>::min() ||
            value > std::numeric_limits<int>::max()) continue;
        return static_cast<int>(value);
    }
    return std::nullopt;
}

// When starting already hot, still arm the current trip/hysteresis so the
// cooler transition is observed, rather than retaining an old125C trip.
template <typename Thresholds>
std::optional<int> rearmHotTrip(const Thresholds& limits, int current, int scale) {
    auto next = nextHotTrip(limits, current, scale);
    return next ? next : nextHotTrip(limits, current - 1, scale);
}
}
