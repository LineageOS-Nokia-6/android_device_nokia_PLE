/*
 * Copyright (C) 2023 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <hidl/Static.h>
#include <new>

namespace android {
namespace hardware {
namespace details {

// Preserve the legacy exported storage ABI, but do not dynamically initialize
// it again after an early libhidlbase constructor has already registered HALs.
// The bridge's dependencies initialize before the bridge itself.
static_assert(sizeof(DoNotDestruct<BnConstructorMap>) == sizeof(BnConstructorMap));
static_assert(sizeof(DoNotDestruct<BsConstructorMap>) == sizeof(BsConstructorMap));
alignas(BnConstructorMap) unsigned char gBnConstructorMap[sizeof(BnConstructorMap)]{};
alignas(BsConstructorMap) unsigned char gBsConstructorMap[sizeof(BsConstructorMap)]{};

namespace {
BnConstructorMap& legacyBnMap() {
    static auto& map = *new (gBnConstructorMap) BnConstructorMap();
    return map;
}
BsConstructorMap& legacyBsMap() {
    static auto& map = *new (gBsConstructorMap) BsConstructorMap();
    return map;
}
__attribute__((constructor)) void initializeLegacyMaps() {
    (void)legacyBnMap();
    (void)legacyBsMap();
}
}  // namespace

// When this library is linked first by an isolated legacy service,
// old generated HALs register through the globals while current libhidlbase
// looks up constructors through these accessors. They must share one map;
// merely exporting empty legacy globals resolves ELF imports but loses HALs.
BnConstructorMap& getBnConstructorMap() {
    return legacyBnMap();
}

BsConstructorMap& getBsConstructorMap() {
    return legacyBsMap();
}

}  // namespace details
}  // namespace hardware
}  // namespace android

extern "C" int ple_radio_constructor_maps_ready() {
    using namespace android::hardware::details;
    return &getBnConstructorMap() == &legacyBnMap() &&
           &getBsConstructorMap() == &legacyBsMap() &&
           getBnConstructorMap().get("android.hidl.manager@1.0::IServiceManager", nullptr);
}
