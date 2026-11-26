#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from mona device
$(call inherit-product, device/xiaomi/mona/device.mk)

# Inherit some common crDroid / LineageOS stuff (vendor/lineage is android_vendor_crdroid 17.0)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_BRAND := Xiaomi
PRODUCT_DEVICE := mona
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_MODEL := 2109119BC
PRODUCT_NAME := lineage_mona

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# Verified from official HyperOS 1.0 China Stable OS1.0.2.0.TKVCNXM (docs/stock-hardware-report.md)
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="mona-user 13 TKQ1.221114.001 V816.0.2.0.TKVCNXM release-keys" \
    BuildFingerprint=Xiaomi/mona/mona:13/TKQ1.221114.001/V816.0.2.0.TKVCNXM:user/release-keys \
    DeviceProduct=mona \
    SystemName=mona

# crDroid 13 (17.0) product flags
TARGET_BOOT_ANIMATION_RES := 1080
TARGET_FACE_UNLOCK_SUPPORTED := true
TARGET_SUPPORTS_QUICK_TAP := true
