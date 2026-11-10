# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/nokia/PLE

# Android 9 shipped with fixed physical partitions.  PLE therefore uses the
# retrofit path: the stock physical system partition is the metadata device
# and backing block device for the logical partition group.
PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_RETROFIT_DYNAMIC_PARTITIONS := true

# Use current Lineage framework-facing HALs, but preserve the exact PLE619F
# graphics buffer ABI selected in BoardConfig. Modern Mi8937 uses newer GPU
# blobs; its merged-usage handle is not binary-compatible with Nokia V@331.
$(call inherit-product, hardware/qcom-caf/common/common.mk)

PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH) \
    hardware/qcom-caf/wlan \
    hardware/qcom-caf/wlan/qcwcn

# Keep a gesture-sized bottom system inset without software navigation keys,
# while the Nokia Goodix panel supplies Back/Home/Recents.
PRODUCT_PACKAGES += \
    PLEFrameworkNavigation \
    PLESysUINavigation \
    PLELauncherNavigation \
    PLEHardwareNavigationMode \
    PLELineageHardwareKeys

# Independent ERM defaults: keyboard35ms, physical keys/system feedback45ms.
PRODUCT_PACKAGES += PLEHaptics PLEKeyboardHaptics

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rro_overlays/config.xml:$(TARGET_COPY_OUT_PRODUCT)/overlay/config/config.xml

PRODUCT_PACKAGES += \
    ple-metadata-mountpoint \
    fstab.qcom \
    fstab.qcom.ramdisk \
    init.PLE.rc \
    init.qseecomd.rc \
    init.qti.qseecomd.sh \
    init.recovery.qcom.rc \
    ple-usbdiag.sh \
    ueventd.qcom.rc \
    zz-ple-keymaster.rc

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/ple-metadata.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/ple-metadata.rc \
    $(DEVICE_PATH)/rootdir/etc/fstab.qcom:$(TARGET_COPY_OUT_RECOVERY)/root/fstab.qcom \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml

# LZ4 ZRAM only: current TA-1025 usable RAM plus swap totals8GiB. Keep this
# out of recovery/fstab.qcom and do not allocate an eMMC-backed swapfile.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/storage/fstab.ple-zram:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ple-zram \
    $(DEVICE_PATH)/storage/init.PLE.zram.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.zram.rc

# Display: source-built allocator/mapper/composer and Qualcomm MDSS fbdev HWC,
# paired only with exact 619F Adreno userspace selected in vendor/nokia/PLE.
# Exact619F Vulkan HALs report physical Adreno505 API1.1.66 in both ABIs.
# Keep stock hardware feature level0 (its level-1 filename is misleading).
# Do not switch RenderEngine/Skia to Vulkan merely because apps can use it.
# Legacy fbdev HWC queue depth matches maintained Mi8937/mithorium and angler.
# FramebufferSurface reserves one slot, so three permits two acquired targets.
# Explicit false retains the original two-buffer profile for comparison.
PLE_ENABLE_TRIPLE_FRAMEBUFFER ?= true
ifeq ($(PLE_ENABLE_TRIPLE_FRAMEBUFFER),true)
PRODUCT_SYSTEM_PROPERTIES += ro.surface_flinger.max_frame_buffer_acquired_buffers=3
else
PRODUCT_SYSTEM_PROPERTIES += ro.surface_flinger.max_frame_buffer_acquired_buffers=2
endif

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml

PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.mapper@2.0-impl-2.1 \
    android.hardware.graphics.composer@2.1-service \
    gralloc.msm8937 \
    hwcomposer.qcom \
    android.frameworks.displayservice@1.0.vendor \
    vendor.qti.hardware.memtrack-service \
    libdisplayconfig \
    libqdMetaData \
    libtinyxml \
    vendor.display.config@1.9.vendor

# Exact PLE uses the MDSS lcd-backlight LED (0..255), which drives the
# stock-derived WLED bkl-trigger. Without a real Lights provider the HIDL
# framework fallback only caches brightness and never updates this node.
# The maintained Lineage AIDL service discovers this path without a board
# binary, raw-WLED bypass or optional /sys/class/backlight directory scan.
PRODUCT_PACKAGES += \
    android.hardware.light-service.lineage

# Keymaster: use the current source-built HIDL service/adapter while retaining
# only the exact Nokia 619F hardware module and QSEE transport selected in the
# PLE vendor tree. This matches the maintained Mi8937 architecture without
# importing Xiaomi device binaries.
PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-impl.ple \
    android.hardware.keymaster@3.0-service \
    android.hardware.keymaster@3.0.vendor \
    libxml2.vendor

# Real screen-lock enrollment: maintained HIDL adapter around the unchanged
# exact619F Gatekeeper module. Weaver is optional; never substitute software
# authentication or change FRP/data-encryption policy to hide a missing HAL.
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-impl \
    android.hardware.gatekeeper@1.0-service \
    android.hardware.gatekeeper@1.0.vendor

# Exact signed modem transport/storage prerequisite. Radio framework integration
# is separate; do not advertise a working SIM merely because this daemon runs.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/radio/init.PLE.cellular-storage.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.cellular-storage.rc

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/radio/init.PLE.cellular-pm.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.cellular-pm.rc

# Current framework accepts real HIDL1.4. Use the maintained Lineage converter
# around exact619F HIDL1.2; do not advertise a fabricated1.5 or copy stock Binder.
PRODUCT_PACKAGES += \
    android.hardware.radio@1.4-service.legacy \
    android.hardware.radio.config@1.0.vendor \
    android.hardware.radio.deprecated@1.0.vendor \
    android.hardware.secure_element@1.0.vendor \
    libhwbinder.vendor \
    libhidlbase_shim.ple \
    libsqlite.vendor \
    libnetutils.vendor \
    libprotobuf-cpp-full-vendorcompat \
    rild.ple \
    android.system.net.netd@1.1.vendor

# Installed v5 retains SIM/LTE and passes real IPv4/IPv6/DNS/HTTPS + browser
# checks. Normal builds must keep that data path; false selects the v1 fallback.
PLE_CELLULAR_BAM_RTM ?= true
include $(DEVICE_PATH)/ims/PLE-ims.mk
ifeq ($(PLE_CELLULAR_BAM_RTM),true)
PRODUCT_PACKAGES += libple_netmgr_bam
endif
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/radio/init.PLE.cellular-data.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.cellular-data.rc \
    $(DEVICE_PATH)/radio/init.PLE.cellular-radio.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.cellular-radio.rc \
    $(DEVICE_PATH)/radio/init.PLE.radio-mcfg.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.PLE.radio-mcfg.sh \
    $(DEVICE_PATH)/radio/PLE-mcfg619F.sha256:$(TARGET_COPY_OUT_VENDOR)/etc/radio/PLE-mcfg619F.sha256 \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml

# Exact stock DSDS/default RAT. Data stays opt-in; never enable paid traffic as
# a side effect of restoring registration or override the user's roaming choice.
PRODUCT_PRODUCT_PROPERTIES += \
    persist.radio.multisim.config=dsds \
    ro.telephony.default_network=22,22 \
    ro.com.android.mobiledata=false

# BatteryService requires IHealth/default during core-services startup.
# Use the same source-built QTI AIDL service as the primary modern MSM8937
# reference; it discovers PLE's existing battery/bms/usb power supplies.
PRODUCT_PACKAGES += \
    android.hardware.health-service.ple

# Genuine per-core idle residency; energy rails are honestly unsupported.
PRODUCT_PACKAGES += \
    android.hardware.power.stats-service.ple

# Real source-built hints, without an absent proprietary perfd backend.
# PLE config requests finite CPU-QOS floors within existing stock OPPs.
PRODUCT_SOONG_NAMESPACES += \
    hardware/lineage/interfaces/power-libperfmgr \
    hardware/google/pixel \
    hardware/google/interfaces
PRODUCT_PACKAGES += \
    android.hardware.power-service.lineage-libperfmgr \
    android.hardware.thermal@2.0-service.nokia_ple

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/power/powerhint.json:$(TARGET_COPY_OUT_VENDOR)/etc/powerhint.json

# Pronto is an SMD packet controller; do not select a UART or Xiaomi binary.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0-service.ple \
    android.hardware.bluetooth.audio-impl \
    audio.bluetooth.default
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/av/services/audiopolicy/config/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration_7_0.xml

# Real PMI8950 LED motor, with the device-local legacy AIDL adapter.
# The source module supports this kernel's activate/duration/state ABI.
PRODUCT_PACKAGES += \
    android.hardware.vibrator-service.legacy.ple \
    vibrator.default:64

# Primary Mi8937 architecture: current source HIDL adapter and exact Nokia
# SSC/QMI payload. Factory persist remains read-only; no calibration helper.
PRODUCT_PACKAGES += \
    ple-sensors-bootstrap \
    android.hardware.sensors@1.0-impl:64 \
    android.hardware.sensors@1.0-service.ple \
    libpower.vendor:64 \
    PLEAutomaticBrightness
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/sensors/init.PLE.sensors.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.PLE.sensors.rc \
    frameworks/native/data/etc/android.hardware.sensor.gyroscope.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.sensor.gyroscope.xml

# Camera follows the maintained Mi8937 AIDL wrapper around the exact PLE
# ARM32 camera3 module. Enumeration is not photo/video acceptance.
PRODUCT_PACKAGES += \
    libpleOmxCore \
    libpleOmxVenc \
    libpleOmxVdec \
    libplec2dcolorconvert \
    libstagefrighthw
PRODUCT_PACKAGES += \
    android.hardware.camera.provider-service_32.lineage \
    android.frameworks.sensorservice@1.0.vendor \
    android.hidl.base@1.0.vendor \
    libhidltransport.vendor \
    libcamera_metadata.vendor \
    libstdc++_vendor \
    init.PLE.camera.rc

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(DEVICE_PATH)/media/mediacodec.policy:$(TARGET_COPY_OUT_VENDOR)/etc/seccomp_policy/mediacodec.policy \
    frameworks/native/data/etc/android.hardware.camera.flash-autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.flash-autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.front.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.front.xml

# Modern HIDL7 registration with exact PLE619F ARM32 hardware module.
# Actual speaker/headset/capture acceptance remains separate from registration.
PRODUCT_PACKAGES += \
    init.PLE.audio.rc \
    android.hardware.audio.service \
    android.hardware.audio@7.0-impl \
    android.hardware.audio.effect@7.0-impl

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    frameworks/av/media/libeffects/data/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml \
    $(DEVICE_PATH)/audio/acdbdir:$(TARGET_COPY_OUT_VENDOR)/etc/acdbdir \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml

PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

# Wi-Fi framework is gated by these hardware-feature declarations. Use
# source-built current services, not the Android9 HIDL vendor Wi-Fi binaries.
PRODUCT_PACKAGES += \
    android.hardware.wifi-service \
    libcld80211 \
    libwifi-hal-ctrl \
    libwpa_client \
    hostapd \
    wcnss_service \
    wificond \
    wpa_supplicant \
    wpa_supplicant.conf \
    init.PLE.wifi.rc \
    ple-wifi-firmware-mountpoint \
    ple-wifi-ini-link \
    ple-wifi-nv-link \
    ple-wifi-dictionary-link

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    $(DEVICE_PATH)/wifi/wpa_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant_overlay.conf \
    $(DEVICE_PATH)/wifi/p2p_supplicant_overlay.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/p2p_supplicant_overlay.conf

# Modem remains disabled. Do not pull in QMI merely to fetch a WLAN address;
# Prima consumes this unit's retained factory NV instead of generic addresses.

$(call inherit-product, vendor/nokia/PLE/PLE-vendor.mk)

PRODUCT_PACKAGES += \
    init.PLE.goodix.rc \
    libple_goodix_dumpdeny \
    android.hardware.biometrics.fingerprint@2.1-service.ple \
    PLEBiometrics \
    PLEBiometricsLineage \
    vndservicemanager

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    $(DEVICE_PATH)/goodix/init.PLE.goodix-data.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/init.PLE.goodix-data.rc \
    $(DEVICE_PATH)/goodix/goodix_fp.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/goodix_fp.kl
