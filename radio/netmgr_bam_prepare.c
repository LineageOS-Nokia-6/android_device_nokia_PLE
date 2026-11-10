// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
// FEERO uses BAM-DMUX, not IPA. RTM VND control must not omit the physical
// transport open performed by the old netmgr powerup path. Never close/reset it.
#include <errno.h>
#include <dlfcn.h>
#include <net/if.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

extern int __android_log_print(int priority, const char *tag, const char *format, ...);

static int ple_netmgr_prepare_bam(void) {
    int fd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -errno;
    int result = -ENODEV;
    for (unsigned attempt = 0; attempt < 300; ++attempt) {
        struct ifreq request = {0};
        memcpy(request.ifr_name, "rmnet0", sizeof("rmnet0"));
        if (ioctl(fd, SIOCGIFFLAGS, &request) < 0) {
            result = -errno;
            if (result != -ENODEV || attempt == 299) break;
            usleep(100000);
            continue;
        }
        if (!(request.ifr_flags & IFF_UP)) {
            request.ifr_flags |= IFF_UP;
            if (ioctl(fd, SIOCSIFFLAGS, &request) < 0) {
                result = -errno;
                break;
            }
        }
        result = 0;
        break;
    }
    close(fd);
    return result;
}

// Signature from maintained librmnetctl.h; opaque handle stays native-owned.
typedef struct rmnetctl_hndl_s rmnetctl_hndl_t;
int rtrmnet_ctl_init(rmnetctl_hndl_t **handle, uint16_t *error_code) {
    typedef int (*native_init_t)(rmnetctl_hndl_t **, uint16_t *);
    native_init_t native_init = (native_init_t)dlsym(RTLD_NEXT, "rtrmnet_ctl_init");
    if (!native_init) {
        __android_log_print(6, "PLE-Netmgr-BAM", "native RTM initializer unavailable");
        _exit(78);
    }
    const char *program = getprogname();
    if (program && !strcmp(program, "netmgrd") && handle && error_code) {
        // Exact619F calls this after blocking DPM initialization and its own
        // physical-transport attempt. A constructor here deadlocks startup:
        // DPM must first run to make the real BAM netdev appear.
        int result = ple_netmgr_prepare_bam();
        __android_log_print(result ? 6 : 4, "PLE-Netmgr-BAM",
                            "post-DPM physical rmnet0 prepare result=%d", result);
        if (result) _exit(78);
    }
    // Preserve actual library validation, handle, error and return unchanged.
    return native_init(handle, error_code);
}
