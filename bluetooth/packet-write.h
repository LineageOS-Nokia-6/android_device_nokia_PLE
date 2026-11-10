// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <poll.h>
#include <thread>
#include <unistd.h>
namespace ple {
inline bool ValidPacket(bool command, const uint8_t* data, size_t size) {
    const size_t header = command ? 3 : 4;
    if (!data || size < header) return false;
    const size_t payload = command ? data[2] : (data[2] | (size_t(data[3]) << 8));
    return size == header + payload;
}
// One SMD write is one packet. Never resend a short write's tail as a second
// packet, nor spin forever when the firmware's TX FIFO stops draining.
inline bool WritePacket(int fd, const uint8_t* data, size_t size, int wait_ms = 500) {
    if (fd < 0 || !data || !size || wait_ms < 0) return false;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(wait_ms);
    for (;;) {
        ssize_t count = write(fd, data, size);
        if (count >= 0) return static_cast<size_t>(count) == size;
        if (errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK) return false;
        auto remaining = deadline - std::chrono::steady_clock::now();
        if (remaining <= std::chrono::steady_clock::duration::zero()) return false;
        if (errno == EINTR) continue;
        int milliseconds = static_cast<int>(std::chrono::duration_cast<std::chrono::milliseconds>(remaining).count()) + 1;
        pollfd ready{fd, POLLOUT, 0};
        int result = poll(&ready, 1, milliseconds);
        if (result < 0 && errno == EINTR) continue;
        if (result <= 0 || (ready.revents & (POLLERR | POLLHUP | POLLNVAL))) return false;
        // SMD POLLOUT means room for a header, not necessarily this whole
        // packet. Bound retries even if poll immediately reports writable.
        std::this_thread::sleep_until(std::min(deadline,
            std::chrono::steady_clock::now() + std::chrono::milliseconds(2)));
    }
}
}
