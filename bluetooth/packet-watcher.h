// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <array>
#include <atomic>
#include <cerrno>
#include <cstdint>
#include <functional>
#include <memory>
#include <poll.h>
#include <sys/eventfd.h>
#include <thread>
#include <unistd.h>

namespace ple {
// Both descriptors/callbacks are immutable before starting the reader. This
// avoids the generic AsyncFdWatcher's live watched-map mutation during startup.
class PacketWatcher {
public:
    using Read = std::function<void(int)>;
    static std::unique_ptr<PacketWatcher> Start(int command, int acl, Read on_command,
                                               Read on_acl, std::function<void()> on_error) {
        if (command < 0 || acl < 0 || !on_command || !on_acl || !on_error) return nullptr;
        int wake = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
        if (wake < 0) return nullptr;
        auto out = std::unique_ptr<PacketWatcher>(new PacketWatcher(
            command, acl, wake, std::move(on_command), std::move(on_acl), std::move(on_error)));
        auto* self = out.get();
        out->reader_ = std::thread([self] { self->Run(); });
        return out;
    }
    ~PacketWatcher() { Stop(); close(wake_); }
    void Stop() {
        if (running_.exchange(false)) {
            uint64_t value = 1;
            // EINTR cannot be allowed to leave the reader asleep forever.
            while (write(wake_, &value, sizeof(value)) < 0 && errno == EINTR) {}
        }
        if (reader_.joinable()) reader_.join();
    }
    PacketWatcher(const PacketWatcher&) = delete;
    PacketWatcher& operator=(const PacketWatcher&) = delete;
private:
    PacketWatcher(int command, int acl, int wake, Read command_cb, Read acl_cb,
                  std::function<void()> error_cb)
        : fds_{{{command, POLLIN, 0}, {acl, POLLIN, 0}, {wake, POLLIN, 0}}},
          wake_(wake), callbacks_{{std::move(command_cb), std::move(acl_cb)}},
          error_(std::move(error_cb)) {}
    void Run() {
        while (running_) {
            int result;
            do { result = poll(fds_.data(), fds_.size(), -1); } while (result < 0 && errno == EINTR);
            if (!running_) return;
            if (result < 0) { error_(); return; }
            for (size_t i = 0; i < 2; ++i) {
                if (fds_[i].revents & (POLLERR | POLLHUP | POLLNVAL)) { error_(); return; }
                if (fds_[i].revents & POLLIN) callbacks_[i](fds_[i].fd);
            }
        }
    }
    std::array<pollfd, 3> fds_;
    int wake_;
    const std::array<Read, 2> callbacks_;
    const std::function<void()> error_;
    std::atomic<bool> running_{true};
    std::thread reader_;
};
}
