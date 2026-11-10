# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
LOCAL_PATH := $(call my-dir)

# prebuilt_root has no subdirectory property. Install this mountpoint marker
# through the root staging directory so SAR system.img contains /metadata.
include $(CLEAR_VARS)
LOCAL_MODULE := ple-metadata-mountpoint
LOCAL_SRC_FILES := rootdir/metadata/.keep
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)/metadata
LOCAL_MODULE_STEM := .keep
include $(BUILD_PREBUILT)

# init cannot create this directory on the read-only vendor image. Package
# the mountpoint, then let the existing fstab mount modem firmware read-only.
include $(CLEAR_VARS)
LOCAL_MODULE := ple-wifi-firmware-mountpoint
LOCAL_SRC_FILES := wifi/firmware_mnt/.keep
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/firmware_mnt
LOCAL_MODULE_STEM := .keep
include $(BUILD_PREBUILT)
