# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/nokia/PLE

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a53
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53

# Build compatibility for exact 619F ELF prebuilts selected by the audited
# vendor generator.
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# Boot chain: stock PLE 619F geometry.
AB_OTA_UPDATER := false
TARGET_NO_BOOTLOADER := true
TARGET_BOOTLOADER_BOARD_NAME := D1C
BOARD_BOOT_HEADER_VERSION := 0
# Keep the non-A/B OTA boot payload byte-identical to the product boot image.
# Rebuilding it from target-files would omit the generic ramdisk device nodes.
BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES := true
BOARD_KERNEL_BASE := 0x80000000
BOARD_KERNEL_PAGESIZE := 2048
# Exact619F starts with LPM disabled and enables it after initialization.
# Keep this early/recovery safeguard; normal init applies the stock GDHS
# restrictions before clearing sleep_disabled at boot completion.
BOARD_KERNEL_CMDLINE := console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 androidboot.bootdevice=7824900.sdhci androidboot.boot_devices=soc/7824900.sdhci earlycon=msm_hsl_uart,0x78B0000 firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 loglevel=0 buildvariant=user veritykeyid=id:8f56f02c61394639f13af4e8cfe02d087e41b936

include device/lineage/sepolicy/libperfmgr/sepolicy.mk
# The 4.19 Image.gz-dtb is larger than the stock 16 MiB kernel-to-ramdisk
# window. Keep the recovery ramdisk clear of both the kernel and the first
# stock-derived reserved-memory region at 0x85b00000.
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x04000000 --tags_offset 0x00000100
BOARD_FLASH_BLOCK_SIZE := 131072

# Kernel: source-built with the ordered MSM8937 and Nokia config fragments.
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/nokia/msm8937
TARGET_KERNEL_VERSION := 4.19
TARGET_KERNEL_CLANG_VERSION := r563880c
# Keep the standalone and Android kernel build settings aligned. The Android kernel
# wrapper otherwise injects an arm-linux-android GCC target and host-dependent
# compile metadata, changing the loadable Image even with an identical config.
TARGET_KERNEL_NO_GCC := true
KERNEL_CC := CC="clang -fdebug-compilation-dir=. -ffile-prefix-map=$(abspath $(OUT_DIR)/target/product/$(TARGET_DEVICE)/obj/KERNEL_OBJ)=." LD=ld.lld
TARGET_KERNEL_ADDITIONAL_FLAGS := \
    PATH=$(abspath prebuilts/clang/host/linux-x86/clang-r563880c/bin):/usr/bin:/bin \
    KBUILD_BUILD_TIMESTAMP="Thu Jan  1 00:00:00 UTC 1970" \
    KBUILD_BUILD_USER=lineage \
    KBUILD_BUILD_HOST=nokia6-bringup \
    KBUILD_BUILD_VERSION=1 \
    SOURCE_DATE_EPOCH=0 \
    TZ=UTC \
    AWK=/usr/bin/mawk \
    PERL5LIB= \
    TAR_OPTIONS="--sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner"
MERGE_ALL_KERNEL_CONFIGS_AT_ONCE := true
TARGET_KERNEL_CONFIG := \
    vendor/msm8937-perf_defconfig \
    vendor/common.config \
    vendor/debugfs.config \
    vendor/feature/android-12.config \
    vendor/feature/compat-vdso.config \
    vendor/feature/erofs.config \
    vendor/feature/lmkd.config \
    vendor/msm8937-legacy.config \
    vendor/feature/lineageos.config \
    vendor/nokia/ple.config

# Physical partitions. The existing stock system partition is the sole super
# block device; 4 MiB is reserved for logical-partition metadata.
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_PERSISTIMAGE_PARTITION_SIZE := 33554432
BOARD_SUPER_PARTITION_BLOCK_DEVICES := system
BOARD_SUPER_PARTITION_METADATA_DEVICE := system
BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE := 5132779520
BOARD_SUPER_PARTITION_SIZE := 5132779520
BOARD_SUPER_PARTITION_GROUPS := ple_dynamic_partitions
BOARD_PLE_DYNAMIC_PARTITIONS_SIZE := 5128585216
BOARD_PLE_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm

TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
# Reserve room for recovery-installed add-ons in the dynamic ext4 images.
# Let mke2fs size the inode tables instead of trimming them to the ROM files.
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 33554432
BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT := -1
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 402653184
BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT := -1
BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 67108864
BOARD_SYSTEM_EXTIMAGE_EXTFS_INODE_COUNT := -1
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
# Fixed ext4 capacities prevent dynamic image auto-sizing from producing a
# completely full ODM and a vendor image with only448KiB spare. These sizes
# fit the existing PLE group without changing GPT/physical super or userdata.
BOARD_VENDORIMAGE_PARTITION_SIZE := 536870912
BOARD_VENDORIMAGE_EXTFS_INODE_COUNT := 4096
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_PARTITION_SIZE := 33554432
BOARD_ODMIMAGE_EXTFS_INODE_COUNT := 1024
TARGET_USERIMAGES_USE_EXT4 := true

# Platform and recovery.
TARGET_BOARD_PLATFORM := msm8937
BOARD_USES_QCOM_HARDWARE := true
# Exact619F supplies the tested data stack, including librmnetctl.so. Do not
# export competing generic dataservices installers into this product's Make.
USE_DEVICE_SPECIFIC_DATASERVICES := true
DEVICE_SPECIFIC_DATASERVICES_PATH := vendor/nokia/PLE
# Exact Android 9 619F declares this platform SPL; its vendor SPL was blank.
# Record the legacy vendor-base date, not new backports or an audited CVE claim.
VENDOR_SECURITY_PATCH := 2020-10-01

# Exact PLE camera userspace is ARM32; keep the maintained provider in that ABI.
BOARD_QTI_CAMERA_32BIT_ONLY := true
# PLE619F V@331 consumes the pre-QSSI split-usage 116-byte gralloc1 handle.
# The QSSI msm8953 stack emits a different 108-byte merged-usage ABI. Use
# Lineage's source-built split-usage display stack; SoC/kernel stay MSM8937/4.19.
QCOM_SOONG_NAMESPACE := hardware/qcom-caf/msm8998
# Keep that exact display ABI, but do not install its old3.18 codec libraries
# over the device-selected modern4.19 media modules with the same SONAMEs.
$(call soong_config_set_bool,nokia_ple,modern_media,true)
# Local implementations retain the stock-facing stems/SONAMEs. Disable only
# their generic counterparts before Soong emits conflicting Make install rules.
$(call soong_config_set_bool,nokia_ple,device_local_hal,true)
BOARD_SHIPPING_API_LEVEL := 25
PRODUCT_FULL_TREBLE_OVERRIDE := true
BOARD_VNDK_VERSION := current
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_SCREEN_DENSITY := 400

TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Lineage's maintained legacy-UM policy covers the msm8937 graphics HAL,
# framebuffer, KGSL, and vendor display properties.
include device/qcom/sepolicy-legacy-um/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += device/nokia/PLE/sepolicy/vendor

# Maintained Mi8937 qcwcn source HAL / Pronto driver contract. Nokia-specific
# firmware, INI and read-only factory calibration are selected separately.
BOARD_HAS_QCOM_WLAN := true
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := //hardware/qcom-caf/wlan/qcwcn:lib_driver_cmd_qcwcn
BOARD_WLAN_DEVICE := qcwcn
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := //hardware/qcom-caf/wlan/qcwcn:lib_driver_cmd_qcwcn
WIFI_HAL_INTERFACE_COMBINATIONS := {{{STA}, 1}}
WIFI_DRIVER_STATE_CTRL_PARAM := "/sys/module/wlan/parameters/fwpath"
WIFI_DRIVER_STATE_ON := ""
WIFI_DRIVER_STATE_OFF := ""
WIFI_AVOID_IFACE_RESET_MAC_CHANGE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WPA_SUPPLICANT_VERSION := VER_0_8_X

DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml
DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/framework_compatibility_matrix.xml

include vendor/nokia/PLE/BoardConfigVendor.mk
