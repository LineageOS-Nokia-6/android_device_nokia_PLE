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

# Identity captured from this TA-1025 on stock Android 9 00WW_6_19F.
# The generic stock ZIP's TA-1021 template is not this hardware variant.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="TA-1025_00WW-user 9 PKQ1.181105.001 00WW_6_19F release-keys" \
    BuildFingerprint=Nokia/TA-1025_00WW/PLE:9/PKQ1.181105.001/00WW_6_19F:user/release-keys
