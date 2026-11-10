// SPDX-License-Identifier: Apache-2.0
// Exact619F libfpservice has one legacy checkCallingPermission call, used
// exclusively by FpService::dump(android.permission.DUMP). Vendor libbinder
// no longer exposes the platform permission controller. Fail CLOSED: do not
// grant a permission, inspect biometric data, or import the allow-all shim.
namespace android {
class String16;
bool checkCallingPermission(const String16&) {
    return false;
}
}
