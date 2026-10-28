# Copyright (C) 2026 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_n_mr1.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
$(call inherit-product, device/nokia/PLE/device.mk)

PRODUCT_DEVICE := PLE
PRODUCT_NAME := lineage_PLE
PRODUCT_BRAND := Nokia
PRODUCT_MODEL := Nokia 6
PRODUCT_MANUFACTURER := HMD Global

PRODUCT_GMS_CLIENTID_BASE := android-nokia
