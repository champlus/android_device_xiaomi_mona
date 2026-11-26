#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/mona

# Inherit from sm8350-common
include device/xiaomi/sm8350-common/BoardConfigCommon.mk

# Assert
TARGET_OTA_ASSERT_DEVICE := mona

# Board
TARGET_BOOTLOADER_BOARD_NAME := mona

# Kernel
TARGET_KERNEL_CONFIG += vendor/mona_QGKI.config

# Kernel modules (first-stage vendor_boot & recovery ramdisk)
# Verified against kernel/xiaomi/sm8350 mona_QGKI.config & synaptics_s3908p/Makefile:
# - Synaptics S3908P SPI touchscreen (synaptics_tcm_{core_module,device,reflash,spi}.ko) + xiaomi_touch.ko
# - Display (msm_drm.ko), Charger (qti_battery_charger_main.ko), HWID, Audio DSP
# Second-stage DLKMs (aw882xx_dlkm.ko, goodix_fod.ko, wlan.ko, etc.) load via vendor_modprobe.sh.
BOOT_KERNEL_MODULES := \
    adsp_loader_dlkm.ko \
    apr_dlkm.ko \
    hwid.ko \
    mmhardware_sysfs_dlkm.ko \
    msm_drm.ko \
    q6_notifier_dlkm.ko \
    q6_pdr_dlkm.ko \
    qti_battery_charger_main.ko \
    snd_event_dlkm.ko \
    synaptics_tcm_core_module.ko \
    synaptics_tcm_device.ko \
    synaptics_tcm_reflash.ko \
    synaptics_tcm_spi.ko \
    xiaomi_touch.ko
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(BOOT_KERNEL_MODULES)

# Partitions
# Verified from OS1.0.2.0.TKVCNXM payload.bin DeltaArchiveManifest (docs/stock-hardware-report.md):
# - boot = 201326592 (192 MiB, inherited from sm8350-common)
# - vendor_boot = 100663296 (96 MiB, inherited from sm8350-common)
# - super = 9126805504 (8.5 GiB, inherited from sm8350-common)
# - dtbo = 16777216 (16 MiB — smaller than lisa/venus 24 MiB!)
# - qti_dynamic_partitions max = 9073118412 (8.450 GiB); align down to 1 MiB multiple (8652 MiB)
BOARD_DTBOIMG_PARTITION_SIZE := 16777216
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9072279552

# Properties
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# SELinux
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Include proprietary files
include vendor/xiaomi/mona/BoardConfigVendor.mk
