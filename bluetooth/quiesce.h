// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <array>
#include <algorithm>
#include <cstring>
#include "packet-write.h"
namespace ple {
// Stop only the volatile Bluetooth controller activity. Do not restart shared
// WCNSS (Wi-Fi), program firmware/NV, or pretend a timed-out reset succeeded.
// Caller must stop/join the packet reader before consuming this acknowledgement.
inline bool Quiesce(int fd, int wait_ms = 300) {
    if (fd < 0 || wait_ms <= 0) return false;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(wait_ms);
    const uint8_t reset[] = {0x03, 0x0c, 0x00};
    if (!WritePacket(fd, reset, sizeof(reset), wait_ms)) return false;
    std::array<uint8_t, 514> buffer{};
    size_t used = 0;
    for (;;) {
        auto remaining = deadline - std::chrono::steady_clock::now();
        if (remaining <= std::chrono::steady_clock::duration::zero()) return false;
        int ms = std::chrono::duration_cast<std::chrono::milliseconds>(remaining).count() + 1;
        pollfd ready{fd, POLLIN, 0};
        int result = poll(&ready, 1, ms);
        if (result < 0 && errno == EINTR) continue;
        if (result <= 0 || (ready.revents & (POLLERR | POLLHUP | POLLNVAL))) return false;
        ssize_t count = read(fd, buffer.data() + used, 257);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count <= 0) return false;
        used += count;
        size_t offset = 0;
        while (used - offset >= 2) {
            size_t length = size_t(buffer[offset + 1]) + 2;
            if (used - offset < length) break;
            if (length >= 6 && buffer[offset] == 0x0e &&
                buffer[offset + 3] == 0x03 && buffer[offset + 4] == 0x0c)
                return buffer[offset + 5] == 0;
            offset += length;
        }
        std::memmove(buffer.data(), buffer.data() + offset, used - offset);
        used -= offset; // At most256 bytes of an incomplete event remain.
    }
}
}
