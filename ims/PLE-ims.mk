# Accepted IMS-v4: normal full builds must not depend on an update in DATA.
# Calls + LTE were user-confirmed; keep an explicit native-only opt-out.
PLE_ENABLE_SOURCE_IMS ?= true
ifeq ($(PLE_ENABLE_SOURCE_IMS),true)
PRODUCT_PACKAGES += PhhImsPLE PLEImsDevice PLEImsPhone PLEImsCarrier
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.ims.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/android.hardware.telephony.ims.xml \
    $(DEVICE_PATH)/ims/config/privapp-permissions-me.phh.ims.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/permissions/privapp-permissions-me.phh.ims.xml \
    $(DEVICE_PATH)/ims/config/default-permissions-me.phh.ims.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/default-permissions/default-permissions-me.phh.ims.xml
endif
