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

# Boot chain: exact PLE 619F/Phase 7 geometry.
AB_OTA_UPDATER := false
TARGET_NO_BOOTLOADER := true
TARGET_BOOTLOADER_BOARD_NAME := D1C
BOARD_BOOT_HEADER_VERSION := 0
BOARD_KERNEL_BASE := 0x80000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_CMDLINE := console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 androidboot.bootdevice=7824900.sdhci earlycon=msm_hsl_uart,0x78B0000 firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 loglevel=0 buildvariant=user veritykeyid=id:8f56f02c61394639f13af4e8cfe02d087e41b936
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100
BOARD_FLASH_BLOCK_SIZE := 131072

# Kernel: source-built, using the accepted Phase 7 fragment order.
BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_KERNEL_SOURCE := kernel/nokia/msm8937
TARGET_KERNEL_VERSION := 4.19
TARGET_KERNEL_CLANG_VERSION := r563880c
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
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true

# Platform and recovery.
TARGET_BOARD_PLATFORM := msm8937
BOARD_USES_QCOM_HARDWARE := true
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_SCREEN_DENSITY := 400

DEVICE_MANIFEST_FILE := $(DEVICE_PATH)/manifest.xml
DEVICE_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml

include vendor/nokia/PLE/BoardConfigVendor.mk
