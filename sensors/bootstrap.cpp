// SPDX-License-Identifier: Apache-2.0
// Real sensor daemon bootstrap: factory registry is input, never an output.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <string>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <unistd.h>

namespace {
struct Fd {
    int value;
    ~Fd() { if (value >= 0) close(value); }
};
int validateExisting(const char* path, off_t expectedSize) {
    Fd fd{open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)};
    if (fd.value < 0) return -errno;
    struct stat info{};
    if (fstat(fd.value, &info) != 0) return -errno;
    if (!S_ISREG(info.st_mode) || info.st_size != expectedSize ||
        info.st_uid != geteuid() || (info.st_mode & S_IWOTH)) return -EINVAL;
    return 0;
}
struct Temporary {
    std::string path;
    bool owned = false;
    ~Temporary() { if (owned) unlink(path.c_str()); }
};
}

extern "C" int ple_prepare_sensor_registry(const char* source, const char* destination) {
    Fd input{open(source, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)};
    if (input.value < 0) return -errno;
    struct stat original{};
    if (fstat(input.value, &original) != 0) return -errno;
    if (!S_ISREG(original.st_mode) || original.st_size <= 0 ||
        original.st_size > 1024 * 1024) return -EINVAL;
    int existing = validateExisting(destination, original.st_size);
    if (existing != -ENOENT) return existing;
    Temporary temporary{std::string(destination) + ".tmp.XXXXXX"};
    Fd output{mkstemp(temporary.path.data())};
    if (output.value < 0) return -errno;
    temporary.owned = true;
    char buffer[4096];
    off_t total = 0;
    for (;;) {
        ssize_t count;
        do { count = read(input.value, buffer, sizeof(buffer)); } while (count < 0 && errno == EINTR);
        if (count < 0) return -errno;
        if (count == 0) break;
        total += count;
        if (total > original.st_size) return -EIO;
        ssize_t sent = 0;
        while (sent < count) {
            ssize_t size = write(output.value, buffer + sent, count - sent);
            if (size < 0 && errno == EINTR) continue;
            if (size <= 0) return size < 0 ? -errno : -EIO;
            sent += size;
        }
    }
    if (total != original.st_size) return -EIO;
    if (fchmod(output.value, 0660) != 0 || fsync(output.value) != 0) return -errno;
    // Atomic no-replace publication. Never truncate or replace a working
    // registry, including a destination another process created meanwhile.
    if (renameat2(AT_FDCWD, temporary.path.c_str(), AT_FDCWD, destination,
                  RENAME_NOREPLACE) != 0) {
        return errno == EEXIST ? validateExisting(destination, original.st_size) : -errno;
    }
    temporary.owned = false;
    std::string parent(destination);
    size_t slash = parent.rfind('/');
    parent = slash == std::string::npos ? "." : parent.substr(0, slash);
    Fd directory{open(parent.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)};
    if (directory.value < 0 || fsync(directory.value) != 0) return -errno;
    return 0;
}

#ifndef PLE_SENSOR_REGISTRY_TEST
int main() {
    struct statvfs mount{};
    if (statvfs("/mnt/vendor/persist", &mount) != 0 || !(mount.f_flag & ST_RDONLY)) {
        std::fprintf(stderr, "PLE sensor registry: factory mount is not read-only\n");
        return 1;
    }
    int result = ple_prepare_sensor_registry("/mnt/vendor/persist/sensors/sns.reg",
                                            "/data/vendor/sensors/r");
    if (result != 0) {
        std::fprintf(stderr, "PLE sensor registry: refusing initialization: %s\n", std::strerror(-result));
        return 1;
    }
    execl("/vendor/bin/sensors.qti", "sensors.qti", static_cast<char*>(nullptr));
    std::fprintf(stderr, "PLE sensor registry: daemon exec failed: %s\n", std::strerror(errno));
    return 1;
}
#endif
