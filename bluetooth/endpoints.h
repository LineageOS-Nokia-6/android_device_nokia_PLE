// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <cerrno>
#include <fcntl.h>
#include <memory>
#include <unistd.h>

namespace ple {
// Own each physical SMD packet channel once, regardless of CMD/EVT aliases.
class Endpoints {
public:
    static std::unique_ptr<Endpoints> Open(const char* command = "/dev/smd3",
                                         const char* acl = "/dev/smd2") {
        auto pair = std::unique_ptr<Endpoints>(new Endpoints);
        pair->command_ = OpenFd(command);
        if (pair->command_ < 0) return nullptr;
        pair->acl_ = OpenFd(acl);
        if (pair->acl_ < 0) return nullptr;
        return pair;
    }
    ~Endpoints() {
        if (command_ >= 0) close(command_);
        if (acl_ >= 0) close(acl_);
    }
    int command() const { return command_; }
    int acl() const { return acl_; }
    Endpoints(const Endpoints&) = delete;
    Endpoints& operator=(const Endpoints&) = delete;
private:
    Endpoints() = default;
    static int OpenFd(const char* path) {
        int fd;
        do { fd = open(path, O_RDWR | O_CLOEXEC | O_NONBLOCK); } while (fd < 0 && errno == EINTR);
        return fd;
    }
    int command_ = -1;
    int acl_ = -1;
};
}
