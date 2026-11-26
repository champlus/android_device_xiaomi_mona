#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Optical UDFPS (Goodix FOD + K9B LHBM + Synaptics S3908P)
# Must be set BEFORE inheriting device/xiaomi/sm8350-common/common.mk so
# sm8350-common installs libudfpshandler, sensors.xiaomi.v2,
# FrameworkOverlayUDFPS, hidl/manifest_udfps.xml, and ro.vendor.sensors.xiaomi.udfps=true.
TARGET_HAS_UDFPS := true

# Inherit from sm8350-common
$(call inherit-product, device/xiaomi/sm8350-common/common.mk)

# Mona-specific UDFPS handler installed to /odm/lib{,64}/libudfpshandler.so
# (linkerconfig searches /odm/${LIB} before /vendor/${LIB}, shadowing
# sm8350-common's /vendor/lib64/libudfpshandler.so so onFingerDown emits
# BTN_INFO via synaptics_s3908p fod_finger_down during screen-on auth)
PRODUCT_PACKAGES += \
    libudfpshandler.mona

# Overlays
PRODUCT_PACKAGES += \
    ApertureOverlayMona

PRODUCT_PACKAGES += \
    FrameworkOverlayMona \
    SettingsOverlayMona \
    SettingsProviderOverlayMona \
    SystemUIOverlayMona \
    WifiOverlayMona

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Init & Ueventd (device-specific AW882xx Smart PA, AW8622x/AW8624 haptics,
# PM8350C front dual soft-light flash, K9B mi_display, S3908P FOD, WCN6750 RPS).
# Note: 6 stock sku_yupik *yupikidp*.xml audio configs are extracted via proprietary-files.txt
# (matching venus), while audio_effects.xml/audio_io_policy.conf/audio_policy_configuration.xml
# are supplied by sm8350-common.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init/init.mona.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.mona.rc \
    $(LOCAL_PATH)/init/ueventd.mona.rc:$(TARGET_COPY_OUT_ODM)/etc/ueventd.rc

# WiFi Display (SM7325 / Adreno 642L requires disabling UBWC for WFD, matching lisa)
PRODUCT_SYSTEM_PROPERTIES += \
    vendor.sys.video.disable.ubwc=1

# Call the proprietary setup
$(call inherit-product, vendor/xiaomi/mona/mona-vendor.mk)
