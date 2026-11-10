/* SPDX-License-Identifier: Apache-2.0 */
/* Reuse the maintained entry point, retaining secure init credentials/caps.
 * DT_NEEDED, not LD_PRELOAD: real radio services have AT_SECURE=1.
 */
#define main ple_aosp_rild_main
#include "rild.c"
#undef main
#include <sys/auxv.h>

extern int ple_radio_constructor_maps_ready(void);
int main(int argc, char** argv) {
    if (!ple_radio_constructor_maps_ready()) {
        RLOGE("PLE radio constructor-map ABI check failed");
        return 1;
    }
    RLOGI("PLE_RADIO_ABI_CHECK_READY secure=%lu", getauxval(AT_SECURE));
    if (argc == 2 && strcmp(argv[1], "--check-abi") == 0) {
        return 0;
    }
    return ple_aosp_rild_main(argc, argv);
}
