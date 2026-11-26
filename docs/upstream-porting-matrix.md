# Xiaomi Civi 1 (`mona`) — Upstream Porting Matrix & Blueprint for crDroid 13 (Android 17 / LineageOS 24.0)

> **Target Device:** Xiaomi Civi 1 (codename `mona`, model `2109119BC`, internal Xiaomi project code `K9B`, Qualcomm SM7325 / Snapdragon 778G / `yupik`, `TARGET_BOARD_PLATFORM := lahaina`).
> **Never confuse with:** Motorola `mona`, Xiaomi 11 Lite 5G NE `lisa` (`K9D`), Xiaomi Civi 1S `zijin` (`K9E`), Xiaomi 12 Lite `taoyao` (`L9`), or POCO X5 Pro `redwood` (`M20`).
> **Research Date:** 2026-11-23 | **Reference Clones:** `<reference-clones>/`

---

## Executive Verdict & Go/No-Go Recommendation

**GO FOR crDroid 13 (`17.0` / Android 17 / SDK 37 / LineageOS 24.0) — NO FALLBACK TO crDroid 12 NEEDED.**

1. **crDroid 13 (`17.0`, v13.1, Android 17, SDK 37, Nov 2026 patch)** is **live, healthy, and actively shipping** (70 official devices in `android_vendor_crDroidOTA/17.0`), including **three SM8350/SM7325 Xiaomi devices** already shipping weekly/monthly official crDroid 13.1 builds:
   - `haydn` (SM8350 — `crdroidandroid/android_device_xiaomi_sm8350-common` `17.0-haydn` + `crdroidandroid/android_kernel_xiaomi_sm8350` `17.0-haydn`)
   - `vili` (SM8350 — `crdroidandroid/android_device_xiaomi_sm8350-common` `17.0` + `crdroidandroid/android_kernel_xiaomi_sm8350` `17.0`)
   - `redwood` (SM7325 — `crdroidandroid/android_device_xiaomi_redwood` `17.0`)
2. **LineageOS 24.0 (Android 17)** is **live** (198 devices in `LineageOS/hudson`), and the entire `xiaomi_sm8350-common` stack (`sm8350-common`, `lisa`, `venus`, `renoir`, `mars`, `haydn`, `android_kernel_xiaomi_sm8350`, `android_hardware_xiaomi`, and `TheMuppets` vendor repos) has actively maintained **`lineage-24.0`** default branches updated through Sep–Nov 2026. Notably, `LineageOS/android_device_xiaomi_sm8350-common` ALREADY uses **SM7325 `redwood` `OS2.0.17.0.UMSMIXM`** as its common proprietary blob base.
3. **Major Discovery — `mona` Kernel Support Already Exists Upstream:** Both `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`, Linux **5.4.302**) and `crdroidandroid/android_kernel_xiaomi_sm8350` (`17.0`, Linux **5.4.302**) **already contain**:
   - `arch/arm64/configs/vendor/mona_QGKI.config`
   - `arch/arm64/boot/dts/vendor/qcom/mona-sm7325-overlay.dts` (`mona-sm7325-overlay.dtbo-base := yupik.dtb`)
   - `arch/arm64/boot/dts/vendor/qcom/mona-sm7325.dtsi`, `mona-pinctrl.dtsi`, `mona-audio-overlay.dtsi`
   - `arch/arm64/boot/dts/vendor/qcom/camera/mona-sm7325-camera-sensor.dtsi` (including front dual soft-light flash `led_flash_front`)
   - `arch/arm64/boot/dts/vendor/qcom/display/dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` (`mi,panel-id = <0x004B3942 0x00420200>` = `K9B`, 120Hz OLED with full Local HBM commands)
   - All required drivers: `goodix_fod.ko`, `synaptics_s3908p` (`synaptics_tcm_*.ko`), `xiaomi_touch.ko`, `aw88263s_m20` (`aw882xx_dlkm.ko`), `aw862xx` haptics, `bq2597x` + `bq_fuel_gauge`, `mius_proximity`, `qca6750`, `ir-spi-led`, `leds-qti-flash.ko`.
4. **Two Real `mona` Kernel UDFPS Bugs Caught in Advance:** Source audit revealed two concrete gaps in `android_kernel_xiaomi_sm8350` for `mona` optical UDFPS (detailed in Section 4.3):
   - Missing 1-line DT property `mi,local-hbm-on-1000nit-51-index = <6>;` in `dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi`.
   - Missing `update_fod_press_status(1/0)` calls & `fod_longpress_gesture_enabled` wiring in `drivers/input/touchscreen/synaptics_s3908p/` (needed for `sensors.xiaomi.v2` screen-off/AOD UDFPS).
5. **Architecture Recommendation:** Build `device/xiaomi/mona` on top of **`LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`)** (combining `lisa`'s SM7325/`sku_yupik` structure + `venus`'s `TARGET_HAS_UDFPS := true` AIDL V4 optical UDFPS pipeline + `Diva-Room/Miku_device_xiaomi_mona` & `mojin`'s exact `mona` display/camera/blob fixups), paired with source-built **`LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`)** (or `crdroidandroid/android_kernel_xiaomi_sm8350` `17.0` if DeviceAsWebcam UVC backports are desired) plus our two targeted `mona` UDFPS kernel patches.

---

## 1. Upstream Repository & Branch Status Matrix

### 1.1 LineageOS & TheMuppets (`lineage-24.0` = Android 17)

| Repository | Host | Default Branch | `lineage-24.0` HEAD & Date | `lineage-23.2` Status | Maintenance Notes |
|---|---|---|---|---|---|
| `LineageOS/android_device_xiaomi_sm8350-common` | GitHub | `lineage-24.0` | `778db2d3` (2026-09-20; pushed 2026-11-10) | `ea54a321` (behind 24.0) | Actively ported to Android 17 (FCM 7, A17 WFD blobs, `sysfs_typec`, legacy `libion`, `ro.bpf.kver_override`, `redwood OS2.0.17.0` blobs). |
| `LineageOS/android_device_xiaomi_lisa` | GitHub | `lineage-24.0` | `abc2631a` (2026-04-17; pushed 2026-09-28) | Same commit | SM7325 (`yupik`), side FP, flat 90Hz. `hudson` still lists `lineage-23.2` weekly (awaiting 24.0 ship cut). |
| `LineageOS/android_device_xiaomi_venus` | GitHub | `lineage-24.0` | `de881b6a` (2026-04-17; pushed 2026-09-19) | Same commit | SM8350 (`lahaina`), optical UDFPS (`TARGET_HAS_UDFPS := true`), curved 120Hz. `hudson` still lists `lineage-23.2`. |
| `LineageOS/android_device_xiaomi_renoir` | GitHub | `lineage-24.0` | `b3599501` (2026-04-15; pushed 2026-10-12) | Same commit | SM7350 (`shima`), side FP. |
| `LineageOS/android_device_xiaomi_mars` | GitHub | `lineage-24.0` | `0fbf3ca7` (2026-07-20; pushed 2026-10-12) | Same commit | SM8350, optical UDFPS (`libtinyxml2-v34.so` patched). |
| `LineageOS/android_device_xiaomi_haydn` | GitHub | `lineage-24.0` | `fc1ca353` (2026-08-11; pushed 2026-10-27) | Same commit | SM8350, side FP. |
| `LineageOS/android_device_xiaomi_taoyao` | — | — | **Does NOT exist** | — | Unofficial only; see `taoyao-aosp/android_device_xiaomi_taoyao` (`lineage-24.0`, updated 2026-11-16). |
| `LineageOS/android_device_xiaomi_star` | — | — | **Does NOT exist** | — | Maintained unofficially; kernel config `star_QGKI.config` exists in `android_kernel_xiaomi_sm8350`. |
| `LineageOS/android_kernel_xiaomi_sm8350` | GitHub | `lineage-24.0` | `2c0d4b83` (2026-10-04; pushed 2026-10-27) | `7ede20c8` (behind 24.0) | **Linux 5.4.302**. Already includes `mona` DTS + `vendor/mona_QGKI.config`! Recent fixes: CFI fix for `mmhardware_sysfs`, `CONFIG_EXFAT_FS=y`. |
| `LineageOS/android_hardware_xiaomi` | GitHub | `lineage-24.0` | `7ce26877` (2026-11-15; pushed 2026-11-22) | `942fd15e` (behind 24.0) | Provides AIDL V4 `android.hardware.biometrics.fingerprint-service.xiaomi`, `libudfps_extension.xiaomi`, `sensors.xiaomi.v2`, `aidl/touch`, `IFAAService`. |
| `TheMuppets/proprietary_vendor_xiaomi_sm8350-common` | GitHub | `lineage-24.0` | `83b35ce3` | `054f494d` (behind 24.0) | 682 files total (679 blobs). Note: `gitlab.com/the-muppets` counterparts do not exist; hosted on GitHub. |
| `TheMuppets/proprietary_vendor_xiaomi_lisa` | GitHub | `lineage-24.0` | `59569ae3` | Same commit | 604 files total (581 blobs + `radio/` firmware via Git LFS). |
| `TheMuppets/proprietary_vendor_xiaomi_venus` | GitHub | `lineage-24.0` | `25bf24ab` | Same commit | 633 files total (610 blobs + `radio/` firmware via Git LFS). |

*Note on `LineageOS/hudson`:* Overall `lineage-24.0` has **198** official targets (vs 42 on `lineage-23.2`, 116 on `lineage-22.2`). The 5 official `sm8350-common` devices (`haydn`, `lisa`, `mars`, `renoir`, `venus`) are still scheduled on `lineage-23.2` in `hudson/main/lineage-build-targets`, even though their `lineage-24.0` branches are populated and actively developed.

### 1.2 crDroid 13 (`17.0` = Android 17 / v13.1 / SDK 37)

| Repository | Branch | HEAD / Date | Status & Role |
|---|---|---|---|
| `crdroidandroid/android` | `17.0` (also `16.0`, `16.0-qpr0`, `16.0-qpr1`) | `19f27245` | crDroid 13 manifest (`PRODUCT_VERSION_MAJOR=17`, `CR_VERSION=13.1`, SDK 37). Pulls LineageOS base + crDroid overrides in `snippets/crdroid.xml`. |
| `crdroidandroid/android_vendor_crdroid` | `17.0` | `8ff33b22` | Mounted at **`vendor/lineage`** (NOT `vendor/crdroid`!). Contains `config/common.mk`, `config/crdroid.mk`, `config/version.mk`, `config/BoardConfigKernel.mk`, `build/tools/roomservice.py`. |
| `crdroidandroid/android_vendor_crDroidOTA` | `17.0` | Active Nov 2026 | **70 official crDroid 13.1 devices** (vs 121 on `16.0`), including `haydn` (2026-11-12), `vili` (2026-11-18), and SM7325 `redwood` (2026-11-07). |
| `crdroidandroid/android_device_xiaomi_sm8350-common` | `17.0` & `17.0-haydn` | `f3f36597` (pushed 2026-11-14) | Fork of LineageOS `sm8350-common` tailored for `vili` (`17.0`) and `haydn` (`17.0-haydn`). **Caution:** `17.0` drops `vendor_dlkm`, uses older HIDL biometrics (`biometrics/BiometricsFingerprint.cpp`) and omits `FrameworkOverlayUDFPS` — **`LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`) is cleaner and more modern for `mona`!** |
| `crdroidandroid/android_kernel_xiaomi_sm8350` | `17.0` | `87f4070` | Linux **5.4.302**, based on `LineageOS/android_kernel_xiaomi_sm8350`, adding Android 16-6.12 UVC gadget backports (`CONFIG_USB_CONFIGFS_F_UVC`), `vili` Goodix TA FP, and touch polling rate sysfs. Also includes `mona` DTS + `vendor/mona_QGKI.config`. |
| `crdroidandroid/android_device_xiaomi_redwood` | `17.0` | `1e2c4c54` (2026-11-07) | Standalone SM7325 device tree (POCO X5 Pro 5G, side FP). Useful reference for SM7325 on crDroid 13.1 (`os_sdk_level: 37`, `os_patch_level: 2026-11-01`). |
| `crdroidandroid/android_device_xiaomi_lisa` | `14.0` max | Stale | No `15.0`/`16.0`/`17.0` branch. |
| `crdroidandroid/android_device_xiaomi_venus` | `15.0` max | Stale | No `16.0`/`17.0` branch. |
| `crdroidandroid/android_device_xiaomi_mona` / `taoyao` | — | **Does NOT exist** | Never officially supported on crDroid. |

### 1.3 crDroid 13 (`17.0`) Device Tree Requirements

Verified directly from `crdroidandroid/android_vendor_crdroid` (`17.0`) and shipping `17.0` device trees (`haydn`, `vili`, `redwood`):

1. **Product Makefile Naming — Still `lineage_<device>.mk`!**
   - `crdroidandroid/android_vendor_crdroid` mounts at `vendor/lineage`, so crDroid 13 device trees STILL use **`lineage_mona.mk`**, **`PRODUCT_NAME := lineage_mona`**, and **`$(call inherit-product, vendor/lineage/config/common_full_phone.mk)`** (which automatically chains `vendor/lineage/config/common.mk` -> `vendor/lineage/config/crdroid.mk` -> `vendor/lineage/config/version.mk`).
   - `AndroidProducts.mk` exposes `$(LOCAL_DIR)/lineage_mona.mk` (lunch target: `lineage_mona-bp4a-userdebug` / `lineage_mona-userdebug` per Android 17 release config).
2. **Dependency Resolution (`crdroid.dependencies`)**:
   - `vendor/lineage/build/tools/roomservice.py` sets `custom_dependencies = "crdroid.dependencies"`, `custom_default_revision = "17.0"`, `org_manifest = "crdroidandroid"`. For local/manual sync we use `.repo/local_manifests/mona.xml`, and also provide `crdroid.dependencies` (plus `lineage.dependencies` for upstream compatibility).
3. **crDroid 13 Optional Feature Flags (`vendor/lineage/config/crdroid.mk`)**:
   - `TARGET_FACE_UNLOCK_SUPPORTED := true` (enables crDroid `FaceUnlock` package + `ro.face.sense_service=true`)
   - `TARGET_BUILD_DEVICE_AS_WEBCAM := true` (enables UVC webcam if using `crdroidandroid/android_kernel_xiaomi_sm8350` `17.0` with `CONFIG_USB_CONFIGFS_F_UVC=y`)
   - `TARGET_SUPPORTS_QUICK_TAP := true` (enabled by default unless set `false`, ships `ColumbusService`)
   - `TARGET_BOOT_ANIMATION_RES := 1080`
   - `PRODUCT_NO_CAMERA := false`, `TARGET_DISABLE_EPPE := true` (if needed when bypassing EPPE property checks)
   - UDFPS customization (crDroid icons/animations/screen-off UDFPS) works directly with LineageOS's standard AIDL V4 `IFingerprint` + `FrameworkOverlayUDFPS` (`config_screen_off_udfps_enabled`, `config_dozeUdfpsLongPressSensorType`) — **no legacy HIDL `crdroid` UDFPS hacks are required**.

### 1.4 `TheMuppets` / `sm8350-common` Common vs. Device Blob Split & `extract-files.py`

On `lineage-24.0`, `sm8350-common` migrated completely to the Python **`tools/extract-utils`** framework (`extract-files.py` with `ExtractUtilsModule` and `ExtractUtils.device_with_common(module, 'sm8350-common', module.vendor)`):

- **Common (`vendor/xiaomi/sm8350-common`, 679 blobs):** Extracted primarily from **SM7325 `redwood OS2.0.17.0.UMSMIXM`** (with Display/HDR from `sunstone OS2.0.4.0.UMQMIXM` and Android 17 WFD system blobs from `marvel_g A171WEH.20`). Covers: ADSP/CDSP/DSP services, Audio FX, Bluetooth/A2DP, CAcert, CNE, FastCV, Configstore, Display/HDR/DPPS, DPM, DRM/Widevine, eSE, Gatekeeper, GNSS, Graphics (Adreno userspace), HotwordEnrollment, IMS, IRQ balance, Keymaster, Listen, Media/VPP, Mlipay, NNAPI, NFC stack, NVRAM, Perf, PerMgr, Power-off alarm, QCV/QMI, RIL, Core Sensors + `citsensorservice`, SCVE, Soter, Thermal, Time, QTEE, WiFi, WFD.
- **Device-Specific (`vendor/xiaomi/<device>`, ~580–610 blobs for `lisa`/`venus`):** Covers ONLY hardware-unique files:
  - ACDB calibration & ACDB libs, Audio hardware (`audio.primary.<dev>.so` or mixer/configs) & Audio firmware (e.g., `aw882xx` `.bin` for `mona`)
  - Camera (`camera.qcom.so`, `camera.xiaomi.so`, `com.qti.chi.override.so`, `libcamx*`, sensor drivers, tuning/chromatix `.bin`, ArcSoft/MiAlgo/Bokeh/CameraX libs & models, `mona_motiontuning.xml`)
  - Charger (`mi_thermald` / `batterysecret` / Turbo Charge blobs)
  - Display calibration (`qdcm_calib_data_xiaomi_42_02_0a_cmd_mode_dsc_dsi_panel.xml` etc.)
  - Fingerprint (Goodix FOD optical HAL `fingerprint.goodix_fod.default.so` + `libgf_*` + `vendor.xiaomi.hardware.fx.tunnel@1.0` + TZ/firmware)
  - Graphics firmware (`a660_zap*` / `a650_sqe*` / `a660_gmu*` — **SM7325 uses Adreno 642L firmware from `mona`/`lisa`, NOT SM8350 Adreno 660!**)
  - IPA firmware (`ipa_fws*` — SM7325-specific!)
  - Media VPU firmware (`vpu20_1v.mbn` — SM7325-specific!)
  - NFC configs (`libnfc-nxp.conf` / RF config)
  - Sensors (`sensors.xiaomi` / registry JSONs / calibration)
  - Thermal configs (`thermal-*.conf`)
  - Touchscreen firmware (`synaptics` / `xiaomi_touch` firmware)
  - Vibrator firmware (`aw8622x_haptic.bin`, `aw8624_haptic.bin`)
  - Radio/bootloader firmware (`proprietary-firmware.txt` -> `radio/*.img` if bundling OTA firmware)

---

## 2. Survey of Existing Xiaomi `mona` Community Trees & Reference Siblings

All repositories below were verified to be genuine **Xiaomi Civi 1 (`mona`, SM7325, model `2109119BC`)** or SM7325 optical-UDFPS sibling **`taoyao`** (Motorola `mona` rejected). Cloned under `<reference-clones>/`.

| Repository | Branch | Last Updated | Type / Scope | Value for Our crDroid 13 Port |
|---|---|---|---|---|
| `Diva-Room/Miku_device_xiaomi_mona` | `Blooming` | 2025-07-08 | Full ROM device tree (Miku UI, inherits `mojin`) | **HIGH.** Authentic `mona` (`2109119BC`) tree with 454 device-specific blobs (`MONA_V14.0.6.0.TKVCNXM`), exact camera `blob_fixup` patches (`mona_motiontuning.xml`, `pureShot_parameter.xml`, `camera.qcom.so`, `camera.xiaomi.so` hex patch, `com.qti.chi.override.so`), `TARGET_KERNEL_CONFIG += vendor/mona_QGKI.config`. |
| `Diva-Room/Miku_device_xiaomi_mojin` | `Blooming` | 2025-07 | Full ROM common tree for `mona` (Civi 1) + `zijin` (Civi 1S) | **HIGH.** Provides verified `mona` UI/display/UDFPS geometry: cutout SVG `M 0,0 H -36 V 95 H 36 V 0 H 0 Z`, rounded corners `98px`/`50px`, `pixel_pitch=63.27`, `config_udfps_sensor_props=[540, 2147, 103]`, `config_udfpsEnrollProgressBar=108`, auto-brightness nit curve (`4.5`–`1000` nits), 120Hz Smooth Display, `modules.load`, and `sku_yupik` audio configs. *(Do NOT inherit directly — uses outdated HIDL FP 2.3, Nothing Phone 1 blobs, and `BUILD_BROKEN_*` hacks; cherry-pick hardware configs into a clean `sm8350-common` child tree.)* |
| `chilan666/android_device_xiaomi_mona-twrp` | `android-13` | 2024-10-10 | TWRP tree (updated to HyperOS `OS1.0.2.0` kernel) | **MEDIUM.** Confirms `OS1.0.2.0` partition layout, exact recovery DLKM module list (`synaptics_tcm_*.ko`, `aw882xx_dlkm.ko`, `xiaomi_touch.ko`, `hwid.ko`, `msm_drm.ko`), and Awinic `aw8622x`/`aw8624` + `aw882xx` firmware filenames. |
| `Samuioto/twrp_device_xiaomi_mona` | `master` | 2021-11-12 | Early TWRP tree (Android 11) | **LOW.** Historical reference only; outdated bootctrl/fstab. |
| `shinnshiwang/twrp_device_xiaomi_mona` | `android-12.1` | 2024-02-05 | WIP TWRP tree (adapted from `taoyao`, marked unusable) | **LOW.** Confirms `taoyao` <-> `mona` structural similarity. |
| `iamr0s/android_device_tree_xiaomi_mona` | `android-13` | 2023-06-12 | TWRP/recovery tree (`lisa -> mona`, MIUI `V14.0.23.5.22.DEV`) | **LOW.** Historical `lisa -> mona` diff reference. |
| `Diva-Room/Miku_kernel_xiaomi_mona` | `TDA` | 2023-04-11 | Custom kernel (Linux 5.4.233, ASB 2023-04) | **OBSOLETE.** Outdated vs `LineageOS/android_kernel_xiaomi_sm8350` (5.4.302). |
| `AndroidBlobs/kernel_xiaomi_mona` | `LA.UM.9.14.r1-16700` | 2022-01-19 | CAF-rebased kernel source | **OBSOLETE.** Useful only for bisecting OEM diffs if needed. |
| `MiCode/Xiaomi_Kernel_OpenSource` | `mona-r-oss` | Original R OSS | Official Xiaomi kernel source (Linux **5.4.86**) | **GROUND-TRUTH REFERENCE.** Verified 1:1 against `LineageOS/android_kernel_xiaomi_sm8350`. |
| `taoyao-aosp/android_device_xiaomi_taoyao` | `lineage-24.0` | 2026-11-16 | Community LineageOS 24.0 tree for Xiaomi 12 Lite (`taoyao`, SM7325 + optical UDFPS) | **HIGH (Secondary Reference).** Standalone SM7325 tree actively running Android 17 (`lineage-24.0`). Useful reference for Android 17 SM7325 quirks (e.g., audio HAL bind-mount, sepolicy updates, `TARGET_KERNEL_CLANG_VERSION := r563880c`, `config_supportScreenOffUdfps`). Uses `mi_disp` ioctl UDFPS handler (different from `sm8350-common`'s cleaner `fod_hbm`/`fod_ui` sysfs handler). |

*(No existing `vendor_xiaomi_mona` repo exists publicly on GitHub; `miku.dependencies` pointed to a private `diva-ssh` repo. Blobs must be extracted from our stock HyperOS/MIUI `mona` firmware dump by `@firmware-extract`.)*

---

## 3. Kernel Analysis: `mona-r-oss` vs. `LineageOS/android_kernel_xiaomi_sm8350` & Android 17 Requirements

### 3.1 Exact `mona` DTS/DTBO & Hardware Architecture

Verified directly from `MiCode/Xiaomi_Kernel_OpenSource` (`mona-r-oss`, `afbe78b0`) and `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`, `2c0d4b83`):

- **Base DTB + Overlay DTBO:**
  - Base DTB: `yupik.dtb` (`CONFIG_ARCH_YUPIK=y`, `CONFIG_PINCTRL_SM7325=y`)
  - Device Overlay: `arch/arm64/boot/dts/vendor/qcom/mona-sm7325-overlay.dts` -> **`mona-sm7325-overlay.dtbo`** (`mona-sm7325-overlay.dtbo-base := yupik.dtb`)
  - Board IDs matched by ABL bootloader:
    ```dts
    model = "mona based Qualcomm Technologies, Inc. SM7325";
    compatible = "qcom,yupik-idp", "qcom,yupik", "qcom,idp";
    qcom,msm-id = <475 0x10000>;
    qcom,board-id = <0x1000B 0>;
    xiaomi,board-id = <0xB 0>;
    ```
- **Included DTSI Hierarchy:**
  1. `mona-pinctrl.dtsi` — GPIO/TLMM pinmux for Smart PA IRQs, touch, fingerprint, haptics.
  2. `xiaomi-sm7325-common.dtsi` — Shared SM7325 base: `yupik-pmic-overlay.dtsi`, `pm7325b.dtsi`, `yupik-thermal-overlay.dtsi`, `display/yupik-sde-display-idp.dtsi`, volume-up key, `xiaomi_touch`, NFC `qcom,sn-nci` (`qupv3_se9_i2c@28`), UFS2.2/3.1 `ufshc_mem` (`1d84000.ufshc`), PMK8350 VADC thermal channels, PM8350C flash driver.
  3. `camera/mona-sm7325-camera-sensor.dtsi` — Rear triple cameras (64MP wide + 8MP UW + 2MP macro), 32MP front AF camera (`actuator_front`), rear flash (`pm8350c_switch0`, `led-mask = <1>`, channel 1), and **front dual soft-light flash (`led_flash_front`, `qcom,camera-flash@3`, `pm8350c_flash1 & pm8350c_flash2`, `pm8350c_torch1 & pm8350c_torch2`, `pm8350c_switch1`, `led-mask = <6>`, channels 2 & 3)**.
  4. `mona-audio-overlay.dtsi` — Enables `wcd938x_codec` (2750mV micbias1–4), disables `wcd937x_codec` and `wsa883x`, routes MI2S to dual Awinic Smart PAs (`aw882xx_smartpa@34` top channel 0 + `aw882xx_smartpa@35` bottom channel 1 on `qupv3_se3_i2c`).
  5. `display/dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` (pulled via `yupik-sde-display.dtsi`) — Panel ID `0x004B3942 0x00420200` (`"K9B"`), 1080x2400 68×152mm 60/120Hz DSC command-mode OLED, `mi,local-hbm-enabled`, LHBM circle register `0x88` = `02 1C 08 63` = `(540, 2147)`.
  6. Peripherals in `mona-sm7325.dtsi`:
     - Touch: `synaptics,tcm-spi` on `qupv3_se13_spi` (IRQ GPIO 81, reset GPIO 105, AVDD `L7C`, IOVDD `L2C`, curved-edge/corner/deadzone filter arrays).
     - Fingerprint: `goodix,fingerprint` (reset GPIO 43, IRQ GPIO 34, `goodix_fod.ko`, `/dev/goodix_fp`).
     - Haptics: `awinic,awinic_haptic` (`0x58`, AW8622x/AW8624, reset GPIO 35, IRQ GPIO 18).
     - IR Blaster: `ir-spi-led` on `qupv3_se15_spi` (`19.2 MHz`).
     - Storage: `sdhc_2` disabled (no microSD slot).

### 3.2 Diff Between `mona-r-oss` (5.4.86) and `LineageOS/android_kernel_xiaomi_sm8350` (5.4.302)

Direct file-by-file diff proved that `LineageOS/android_kernel_xiaomi_sm8350` (commit `634adbf` + subsequent treewide commits) **already imported all 5 `mona` DTS/DTSI files and every required driver**, plus applied clean upstream improvements:

| Component | `mona-r-oss` (5.4.86) | `LineageOS/android_kernel_xiaomi_sm8350` (5.4.302) | Delta / Action Needed |
|---|---|---|---|
| `mona-sm7325-overlay.dts` | Identical | Identical | None. |
| `mona-sm7325.dtsi` | `compatible = "ir-spi"`, placeholder `vib_rtp_time` | Upgraded to upstream `compatible = "ir-spi-led"`, real calibrated `vib_rtp_time`, clean `&sdhc_2` disabled | Already superior upstream. |
| `arch/arm64/configs/vendor/mona_QGKI.config` | Monolithic OEM QGKI config | Clean 421-byte fragment layered on `lahaina-qgki_defconfig` + `xiaomi_QGKI.config` | Ready out of the box! Verify if `BOOT_KERNEL_MODULES` needs `synaptics_tcm_*.ko` + `aw882xx_dlkm.ko`. |
| `goodix_fod` driver | Defines `GOODIX_DRM_INTERFACE_WA`, disables DRM workqueue | Properly integrates DRM notifier + optional `CONFIG_FINGERPRINT_SET_VREG_CONTROL` | Ready out of the box. |
| `aw88263s` Smart PA | `aw882xx` | `CONFIG_SND_SOC_AW88263S_M20=m` enabled in `techpack/audio/config/lahainaauto.conf` | Verify `.ko` module name (`aw88263s_m20_dlkm.ko` or `aw882xx_dlkm.ko`) when compiling! |
| `dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` | Stock LHBM cmds (`mi_disp` daemon) | Missing `mi,local-hbm-on-1000nit-51-index = <6>;` for LOS `dsi_panel_update_cmd_reg51()` | **PATCH REQUIRED (1 line DTS; verify `off-to-normal` reg 0x51 restore too).** |
| `synaptics_s3908p` touch driver | Calls `BTN_INFO`, no `update_fod_press_status()` | Same — does NOT call `update_fod_press_status(1/0)` for `sensors.xiaomi.v2` | **PATCH REQUIRED (~15 lines C) for screen-off / AOD UDFPS.** |

### 3.3 Android 17 / LineageOS 24.0 Kernel Requirements: Why Source-Built `sm8350` Kernel Wins (and Stock Prebuilt Fails)

| Requirement on Android 17 (API 37 / LineageOS 24.0) | Stock Prebuilt `mona` Kernel (MIUI/HyperOS 5.4.86–5.4.210) | Source-Built `android_kernel_xiaomi_sm8350` (Linux 5.4.302) |
|---|---|---|
| **eBPF / NetBpfLoad / Connectivity APEX** | **FAILS / BOOTLOOPS.** Android 17's `NetBpfLoad` & `Connectivity` mainline module enforce modern BPF verifier features, `CONFIG_BPF_SYSCALL`, `CONFIG_CGROUP_BPF`, `CONFIG_NET_CLS_BPF`, `CONFIG_NET_ACT_BPF`, `CONFIG_FUSE_BPF`, and minimum kernel version checks (`>= 5.10`). Stock MIUI 5.4 lacks 2024–2026 AOSP BPF backports; even with `ro.bpf.kver_override=5.10.239`, old 5.4 BPF verifier rejects Android 17 BPF programs (`netd` / `system_server` crash). | **PASSES.** Linux 5.4.302 with LineageOS/AOSP Android 14–17 BPF backports + `CONFIG_BPF_SYSCALL=y`, `CONFIG_BPF_JIT_ALWAYS_ON=y`, `CONFIG_CGROUP_BPF=y`, `CONFIG_FUSE_BPF=y`, `CONFIG_NET_CLS_BPF=y`, paired with `ro.bpf.kver_override=5.10.239` in `sm8350-common/product.prop`. |
| **Netfilter / Cgroup v2 / PSI / UFFD** | Missing modern `NETFILTER_XT_*`, `CONFIG_USERFAULTFD` backports, or mismatched cgroup/PSI behavior required by Android 17 `lmkd` and ART GC. | All enabled in `lahaina-qgki_defconfig`: `CONFIG_PSI=y`, `CONFIG_MEMCG=y`, `CONFIG_CGROUP_FREEZER=y`, `CONFIG_USERFAULTFD=y`, `CONFIG_NETFILTER_XT_MATCH_BPF/OWNER/QUOTA2/SOCKET=y`, `CONFIG_EROFS_FS=y`, `CONFIG_EXFAT_FS=y`, `CONFIG_CRYPTO_ZSTD=y`. |
| **SELinux Policy Compatibility** | Stock MIUI kernel has OEM-specific SELinux/audit assumptions and lacks newer SELinux policy capability/class backports (`ioctl` extended permissions, `bpf` map classes). | Updated through 5.4.302 with full Android 17 SELinux policy compatibility (`CONFIG_SECURITY_SELINUX=y`). |
| **UDFPS (`fod_hbm` / `fod_ui` sysfs)** | **INCOMPATIBLE** with `sm8350-common` `UdfpsHandler.cpp`. Stock MIUI uses proprietary `/dev/mi_display/disp_feature` + MIUI userspace `mi_disp` daemon; `fod_hbm` / `fod_ui` sysfs nodes do not exist! | **NATIVE SUPPORT.** Implements `fod_hbm` + `fod_ui` sysfs + `sde_connector_fod_{pre,post}_kickoff()` VBLANK-synchronized LHBM directly in `techpack/display`. |
| **`vendor_boot` & `vendor_dlkm` Modules** | Prebuilt `Image` + stock `.ko` modules have mismatched `vermagic`, cannot rebuild/patch `synaptics_s3908p` or `techpack/display`, and lack `ir-spi-led` + CFI fixes (`2c0d4b83`). | Built atomically with AOSP Clang (`r563880c` / `vendor/lineage` default Clang), generating matching `Image`, `dtb`, `mona-sm7325-overlay.dtbo`, `vendor_boot` recovery ramdisk modules, and `vendor_dlkm` modules. |

**Recommendation:** **100% Source-Built Kernel** from `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`, or `crdroidandroid/android_kernel_xiaomi_sm8350` `17.0` if UVC webcam is wanted) with `TARGET_KERNEL_CONFIG += vendor/mona_QGKI.config` + our two small `mona` UDFPS patches. Keep stock `boot.img`/`vendor_boot.img`/`dtbo.img` ONLY as hardware reference for `@firmware-extract`.

---

## 4. Hardware & Optical UDFPS Porting Matrix (`lisa` vs. `mona` vs. `venus` vs. `taoyao`)

### 4.1 Side-by-Side Device Comparison

| Subsystem | `lisa` (Mi 11 Lite 5G NE) | **`mona` (Xiaomi Civi 1 — TARGET)** | `venus` (Mi 11) | `taoyao` (Xiaomi 12 Lite) |
|---|---|---|---|---|
| **SoC / Platform** | SM7325 (`yupik` / `lahaina`) | **SM7325 (`yupik` / `lahaina`)** | SM8350 (`lahaina`) | SM7325 (`yupik` / `lahaina`) |
| **GPU / Firmware** | Adreno 642L (`a660_zap` / SM7325) | **Adreno 642L (SM7325)** | Adreno 660 (SM8350) | Adreno 642L (SM7325) |
| **Upstream Base** | `sm8350-common` (`lineage-24.0`) | **`sm8350-common` (`lineage-24.0`)** | `sm8350-common` (`lineage-24.0`) | Standalone (`taoyao-aosp`, `lineage-24.0`) |
| **Display Panel** | Flat 6.55" 1080×2400 90Hz OLED (`k9d`) | **Curved 6.55" 1080×2400 120Hz OLED (`k9b`, LHBM)** | Curved 6.81" 1440×3200 120Hz OLED (`k2`, HBM) | Flat 6.55" 1080×2400 120Hz OLED (`l9`, LHBM) |
| **Density / Pixel Pitch** | 440 dpi | **440 dpi / `63.27` µm/px** | 560 dpi / `49.29` µm/px | 440 dpi |
| **Cutout & Corners** | Top-left punch-hole | **Top-center punch-hole** (`M 0,0 H -36 V 95 H 36 V 0 H 0 Z`), curved corners `98px` / content padding `50px` | Top-left punch-hole, curved corners `172px` | Top-center punch-hole |
| **Touch Controller** | Goodix BRL (`goodix_core.ko`) | **Synaptics TCM S3908P (`synaptics_tcm_*.ko`)** | FocalTech/ST (`fts_touch_spi.ko`) | Goodix 9916 / FocalTech 3680 |
| **Fingerprint Sensor** | Side capacitive (`fpc_tee`, `side`) | **Optical UDFPS (`goodix_fod.ko`, `udfps_optical`)** | Optical UDFPS (`goodix_fod.ko`, `udfps_optical`) | Optical UDFPS (`goodix_fod.ko`, `udfps_optical`) |
| **UDFPS Coordinates** | `1080\|960\|200` (side) | **`540\|2147\|103`** (`enrollProgressBar=108`) | `720\|2490\|132` (`enrollProgressBar=137`) | Optical (bottom center) |
| **Audio Codec + PA** | `sku_yupik` + WCD938x / TFA/CS | **`sku_yupik` + WCD938x + Dual Awinic AW882xx (`0x34`, `0x35`, `aw88263s_m20`)** | `sku_lahaina` + CS35L41 | `sku_yupik` + Dual Smart PA |
| **Haptics** | Awinic AW8624 (`CONFIG_INPUT_AW8624_HAPTIC=y`) | **Awinic AW8622x / AW8624 (`CONFIG_INPUT_AW862XX_HAPTIC=y`, `aw8622x_haptic.bin`)** | AW8697 | Awinic AW862xx |
| **Charging** | BQ2597X (33W) | **BQ2597X + BQ Fuel Gauge (55W)** | BQ2597X + Wireless PowerShare | BQ2597X + BQ Fuel Gauge (67W) |
| **Cameras + Flash** | 64+8+5MP / 20MP front, rear flash | **64+8+2MP / 32MP AF front + Front Dual Soft-Light Flash (`pm8350c_flash1/2`)** | 108+13+5MP / 20MP front | 108+8+2MP / 32MP AF front + Front Dual Flash |
| **WiFi / NFC / IR / Prox** | QCA6750 / NXP SN-NCI / `ir-spi-led` / MIUS | **QCA6750 / NXP SN-NCI / `ir-spi-led` / MIUS ultrasonic** | QCA6490 / NXP / `ir-spi-led` | QCA6750 / NXP / `ir-spi-led` |
| **Dynamic Partitions** | `odm product system system_ext vendor vendor_dlkm` | **Same (`sm8350-common` layout; verify stock `super` size with `@firmware-extract`)** | Same | No `vendor_dlkm` |

### 4.2 Exact `lineage-24.0` Optical UDFPS Architecture (`sm8350-common` + `venus` Pattern)

On `LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`), setting **`TARGET_HAS_UDFPS := true`** in `device/xiaomi/mona/device.mk` (BEFORE inheriting `sm8350-common/common.mk`) activates the full modern **AIDL V4** optical UDFPS stack:

1. **Fingerprint AIDL V4 Service (`hardware/xiaomi/aidl/fingerprint`):**
   - Binary: `android.hardware.biometrics.fingerprint-service.xiaomi` (implements `android.hardware.biometrics.fingerprint.IFingerprint/default` V4, wrapping Xiaomi's proprietary `fingerprint.goodix_fod.default.so` via `libhardware` `hw_get_module`).
   - Reads `vendor.prop` sysprops via `FingerprintConfig.cpp`:
     ```properties
     persist.vendor.fingerprint.type=udfps_optical
     persist.vendor.fingerprint.sensor_location=540|2147|103
     ```
   - Dynamically `dlopen()`s `libudfpshandler.so` (`UDFPS_HANDLER_FACTORY`) from `device/xiaomi/sm8350-common/udfps/UdfpsHandler.cpp`.
2. **UDFPS Handler (`sm8350-common/udfps/UdfpsHandler.cpp`):**
   - Spawns background `poll(POLLPRI | POLLERR)` thread on `/sys/devices/platform/soc/soc:qcom,dsi-display-primary/fod_ui`.
   - On `onFingerDown()`: writes `1` to `/sys/devices/platform/soc/soc:qcom,dsi-display-primary/fod_hbm` and calls `mDevice->extCmd(mDevice, COMMAND_FOD_PRESS_STATUS(1), PARAM_FOD_PRESSED(1))`.
   - Kernel `sde_connector_fod_pre_kickoff()` triggers `dsi_panel_set_fod_hbm(panel, true)` -> sends `mona`'s `k9b` Local HBM 1000-nit command (`DSI_CMD_SET_MI_LOCAL_HBM_NORMAL_WHITE_1000NIT` or `HLPM_WHITE_1000NIT` from Doze).
   - Kernel `sde_connector_fod_post_kickoff()` waits for `MSM_ENC_TX_COMPLETE` + `MSM_ENC_VBLANK`, then sets `fod_ui=1`.
   - Poll thread wakes and calls `mDevice->extCmd(mDevice, COMMAND_NIT(10), PARAM_NIT_UDFPS(1))` -> Goodix optical sensor captures fingerprint at peak illumination!
   - On `onFingerUp()` / `onAcquired()` / `onAuthenticationSucceeded()` (500ms debounce) / `onAuthenticationFailed()`: writes `0` to `fod_hbm`, clears `COMMAND_FOD_PRESS_STATUS`, kernel drops LHBM and sets `fod_ui=0` -> `COMMAND_NIT(0)`.
3. **SurfaceFlinger Dim Layer / Z-Order (`hardware/xiaomi/fingerprint/UdfpsExtension.cpp`):**
   - `libudfps_extension.xiaomi` sets `FOD_PRESSED_LAYER_ZORDER` (already configured in `sm8350-common` via `TARGET_SURFACEFLINGER_UDFPS_LIB := //hardware/xiaomi:libudfps_extension.xiaomi`). Note: because `mona` uses **Local HBM** (illuminating only the sensor circle via panel register `0x88`), it does NOT require full-screen software dimming (unlike non-LHBM global-HBM OLEDs).
4. **Screen-Off / AOD UDFPS (`hardware/xiaomi/sensors/v2` + `FrameworkOverlayUDFPS`):**
   - `sm8350-common` ships `sensors.xiaomi.v2`, sets `ro.vendor.sensors.xiaomi.udfps=true`, and includes `FrameworkOverlayUDFPS`:
     - `config_dozeUdfpsLongPressSensorType = "org.lineageos.sensor.udfps"`
     - `config_screen_off_udfps_enabled = true` (`default_on = false`)
   - `UdfpsSensor` in `sensors.xiaomi.v2` polls `/sys/class/touch/touch_dev/fod_press_status` and toggles `/sys/class/touch/touch_dev/fod_longpress_gesture_enabled`.
   - `device/xiaomi/mona/extract-files.py` MUST add `'vendor/etc/sensors/hals.conf': blob_fixup().add_line_if_missing('sensors.xiaomi.v2.so')` (matching `venus`).
5. **VINTF, Init RC & SELinux (All Already Built Into `sm8350-common`!):**
   - VINTF: `hidl/manifest_udfps.xml` declares `vendor.xiaomi.hardware.fx.tunnel@1.0::IMiFxTunnel/default` (added automatically when `TARGET_HAS_UDFPS := true`), while `android.hardware.biometrics.fingerprint-service.xiaomi.xml` declares AIDL `IFingerprint/default` V4.
   - Init RC (`init.target.rc`): creates `/data/vendor/goodix`, `/mnt/vendor/persist/goodix`, and `chown system system` on `fod_hbm`, `fod_ui`, `/sys/devices/virtual/touch/tp_dev/fod_status`, and `/dev/xiaomi-touch`. `ueventd.rc` sets `/dev/goodix_fp 0660 system system`.
   - SELinux (`sepolicy/vendor/hal_fingerprint_default.te`, `file_contexts`, `genfs_contexts`): already labels `/dev/goodix_fp` (`vendor_fingerprint_device`), `fod_hbm`/`fod_ui`/`fod_press_status`/`fod_status` (`vendor_sysfs_udfps`), `/dev/xiaomi-touch` (`vendor_touchfeature_device`), and grants `hal_fingerprint_default` full access.
6. **Device-Specific RRO Overlays Needed for `mona`:**
   - `FrameworkOverlayMona`: `config_defaultRefreshRate=0`, `config_defaultPeakRefreshRate=120`, cutout path `M 0,0 H -36 V 95 H 36 V 0 H 0 Z`, `rounded_corner_radius=98px`, `status_bar_height_portrait=108px`, auto-brightness nit curve (`4.5`–`1000` nits from `mojin`), `power_profile.xml` (4500mAh).
   - `SystemUIOverlayMona`: `physical_fingerprint_sensor_center_screen_location_y=2147px`, `physical_power_button_center_screen_location_y=1100px`, `pixel_pitch=63.27`, `rounded_corner_content_padding=50px`.
   - `SettingsOverlayMona`: `config_show_smooth_display=true`, `config_udfpsEnrollProgressBar=108`.

### 4.3 Two Critical `mona` Kernel UDFPS Patches Required Before Bring-Up

1. **Patch 1 — `arch/arm64/boot/dts/vendor/qcom/display/dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi`:**
   - Add `mi,local-hbm-on-1000nit-51-index = <6>;` (matching byte `0x51` at command index 6 of `mi,mdss-dsi-local-hbm-normal-white-1000nit-command`). Without this, `dsi_panel_update_cmd_reg51()` returns `-EINVAL` and leaves screen backlight at max `0x07FF` during LHBM.
   - *Bring-up check:* Verify `DSI_CMD_SET_MI_LOCAL_HBM_OFF_TO_NORMAL` (`51 00 00` at index 1) restores backlight properly on finger-up; if the screen flashes dark briefly on finger-up, update `dsi_panel_update_cmd_reg51()` to also patch `DSI_CMD_SET_MI_LOCAL_HBM_OFF_TO_NORMAL` using `mi,local-hbm-off-to-normal-51-index = <1>;` (or trigger `dsi_panel_update_backlight` right after LHBM off).
2. **Patch 2 — `drivers/input/touchscreen/synaptics_s3908p/` (`synaptics_tcm_touch.c` & `synaptics_tcm_core.c`):**
   - Call `update_fod_press_status(1)` inside `touch_fod_down_event()` and `update_fod_press_status(0)` inside `touch_fod_up_event()` (mirroring `drivers/input/touchscreen/fts_spi/fts.c` on `venus`).
   - Wire `xiaomi_touch`'s `fod_longpress_gesture_enabled` sysfs toggle to `syna_tcm_set_cur_value(Touch_Fod_Enable, ...)` so screen-off/AOD UDFPS wakes the sensor cleanly via `sensors.xiaomi.v2`.

### 4.4 Front Dual Soft-Light Flash & Curved Display Specifics

- **Front Dual Soft-Light Flash (`led_flash_front`):** Already wired in `mona-sm7325-camera-sensor.dtsi` (`pm8350c_flash1/2` + `pm8350c_torch1/2` on `pm8350c_switch1`, `led-mask = <6>`, driven by `leds-qti-flash.ko`). Standard Camera2 API (`FLASH_MODE_TORCH` / `FLASH_MODE_SINGLE` on front camera ID `1`) works through `mona`'s proprietary CamX blobs (`camera.qcom.so` + `com.qti.chi.override.so`) once `mona` camera blobs and `extract-files.py` patches are installed. Verify sysfs LED paths (`/sys/class/leds/led:torch_1`, `led:torch_2`, `led:switch_1`) against `@firmware-extract`'s stock dump if adding a quick-settings/parts front-torch toggle.
- **Curved 120Hz OLED Display:** `synaptics_tcm@0` in `mona-sm7325.dtsi` already includes Xiaomi's full curved-edge palm/mistouch rejection arrays (`cornerzone-filter-*`, `deadzone-filter-*`, `edgezone-filter-*`, `Touch_Edge_Filter`). Set `rounded_corner_content_padding=50px` in `SystemUIOverlayMona` to prevent status-bar clock/battery clipping on the curved bezels.

---

## 5. Android 17 / LineageOS 24.0 Breaking Changes Affecting SM8350/SM7325

Extracted directly from `LineageOS/android_device_xiaomi_sm8350-common` (`lineage-23.2` -> `lineage-24.0`) and `android_kernel_xiaomi_sm8350` commit histories:

1. **FCM Target Level Bumped to 7 (`778db2d`):** `hidl/manifest_lahaina.xml` MUST declare `target-level="7"` (Android 17 rejects legacy FCM 5/6 vendor manifests). Inherited automatically from `sm8350-common`.
2. **eBPF Kernel Version Override (`c72b337`):** `product.prop` MUST set `ro.bpf.kver_override=5.10.239` so Android 17 `NetBpfLoad` accepts our patched Linux 5.4.302 kernel.
3. **VNDK Removal & Shim/Versioned Libraries (`ddaa960`, `4b7b682`, `0fbf3ca`):**
   - Android 15–17 completely removed VNDK-SP; older proprietary blobs linking dropped/ABI-broken shared libs MUST be patched in `extract-files.py`:
     - `libtinyxml2.so` -> `libtinyxml2-v34.so` (on `libdpps.so`, `libsnapdragoncolor-manager.so`, and any `mona` camera/vendor blobs crashing with `tinyxml2 10.1.0` ABI break)
     - `libaudioroute.so` -> `libaudioroute-v34.so` (if using prebuilt `audio.primary.mona.so` / `libaudioroute_ext.so`, as `venus` does; OR build `audio.primary.lahaina` from source with `sku_yupik` mixer paths as `lisa` does!)
     - `libprocessgroup_shim.so` added to `camera.qcom.so` and `com.qti.chi.override.so`
     - `libjsoncpp_shim.so` added to `libmisight.so` and `libsensor_cal_v2.so`
     - `libcrypto_shim.so` added to Widevine (`libwvdrmengine.so`, `libwvhidl.so`)
     - `libinput_shim.so` added to `libwfdnative.so` + Android 17 `marvel_g A171WEH.20` WFD system blobs + `WfdCommon.patch` (`79d5488`)
     - `clear_symbol_version(...)` for `AHardwareBuffer_*` (`libalAILDC.so`, `libalLDC.so`, `libalhLDC.so`) and `remote_handle*` (`libarcsoft_*`, `libmialgo_*`)
4. **Legacy `libion` Implementation (`ed9cb79`):** Android 17 requires explicit `$(call soong_config_set_bool,libion,legacy_impl,true)` + `include device/lineage/sepolicy/libion/sepolicy.mk` for QCOM 5.4 ION camera/display blobs.
5. **SELinux `sysfs_typec` Collision (`c5b03d3`):** Android 17 (CP2A) labels `/sys/class/typec` in core `system/sepolicy`; custom `vendor_sysfs_usb_c` causes a sepolicy compile conflict and must be replaced with `sysfs_typec` (already fixed in `sm8350-common`).
6. **Build Flag Deprecations (`e6f8abe`, `2ea7150`, `387c90f`, `eb07fc9`):**
   - Drop `TARGET_KERNEL_NO_GCC := true` (no longer used in `lineage-24.0`).
   - Drop `PRODUCT_ENABLE_UFFD_GC := true` (dropped in Android 17).
   - Drop explicit `fastbootd` enablement (now default).
   - Convert Soong config flags to `soong_config_set_bool` (e.g., `android_hardware_audio,skip_speaker_layout_channel_mask_field,true`).
   - RRO XML strictness (`b3f6838`): use `<integer-array>` instead of untyped `<array>` for integer arrays.
7. **HIDL -> AIDL & 32-bit/HAL Migrations:**
   - Fingerprint: **AIDL V4** (`android.hardware.biometrics.fingerprint-service.xiaomi`) replaces legacy HIDL 2.3 (`android.hardware.biometrics.fingerprint@2.3-service.xiaomi_mona`).
   - Audio & SoundTrigger: Built from source in `sm8350-common` (`390b885`, `abc1e72`); verify whether `mona`'s `aw882xx` dual Smart PAs work cleanly with source-built `audio.primary.lahaina` + `sku_yupik` mixer XMLs (preferred, like `lisa`) or require a device-specific `audio.primary.mona.so` bind/override (like `venus`/`taoyao`).
   - Camera: Still uses `android.hardware.camera.provider@2.4-service_64` (64-bit only), `camera_cnf.txt` binary patch in `camera.qcom.so`, and `camera.xiaomi.so` signature patch (verify exact ARM64 `BL` offset on our target HyperOS/MIUI `mona` dump — `miku_device_xiaomi_mona` patched `2100805229070094 -> 210080521F2003D5` on MIUI 14 `V14.0.6.0.TKVCNXM`).
   - Kernel CFI (`2c0d4b83`): Android 17 Clang enforces stricter CFI on `module_init`/`module_exit` signatures — already fixed in `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`).

---

## 6. Actionable Phase 2 Blueprint for `device/xiaomi/mona`

1. **Manifest / Local Manifest (`.repo/local_manifests/mona.xml`):**
   - `device/xiaomi/sm8350-common` <- `LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`)
   - `vendor/xiaomi/sm8350-common` <- `TheMuppets/proprietary_vendor_xiaomi_sm8350-common` (`lineage-24.0`)
   - `hardware/xiaomi` <- `LineageOS/android_hardware_xiaomi` (`lineage-24.0`)
   - `kernel/xiaomi/sm8350` <- `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`) + our 2 `mona` UDFPS patches (`dsi-panel-k9b` LHBM reg51 index + `synaptics_s3908p` `update_fod_press_status`) *(optionally cherry-pick crDroid's UVC gadget backports if webcam is desired)*
   - `device/xiaomi/mona` <- Our new tree (templated from `lisa` + `venus` + `mona`/`mojin` hardware details)
   - `vendor/xiaomi/mona` <- Extracted via our `device/xiaomi/mona/extract-files.py` from `@firmware-extract`'s stock `mona` HyperOS/MIUI dump.
2. **Key Files in `device/xiaomi/mona`:**
   - `BoardConfig.mk`: inherits `device/xiaomi/sm8350-common/BoardConfigCommon.mk`, sets `TARGET_BOOTLOADER_BOARD_NAME := mona`, `TARGET_KERNEL_CONFIG += vendor/mona_QGKI.config`, `BOARD_DTBOIMG_PARTITION_SIZE := 25165824` (verify against stock GPT from `@firmware-extract`), and `BOOT_KERNEL_MODULES` (`adsp_loader_dlkm.ko`, `apr_dlkm.ko`, `aw882xx_dlkm.ko`/`aw88263s_m20_dlkm.ko`, `hwid.ko`, `mmhardware_sysfs_dlkm.ko`, `msm_drm.ko`, `q6_notifier_dlkm.ko`, `q6_pdr_dlkm.ko`, `qti_battery_charger_main.ko`, `snd_event_dlkm.ko`, `synaptics_tcm_core_module.ko`, `synaptics_tcm_device.ko`, `synaptics_tcm_diagnostics.ko`, `synaptics_tcm_reflash.ko`, `synaptics_tcm_spi.ko`, `synaptics_tcm_testing.ko`, `xiaomi_touch.ko`).
   - `device.mk`: sets **`TARGET_HAS_UDFPS := true`** BEFORE inheriting `sm8350-common/common.mk`; copies `mona` `sku_yupik` audio XMLs (`mixer_paths_yupikqrd.xml`, `audio_platform_info_yupikqrd.xml`, `sound_trigger_*`); installs `FrameworkOverlayMona`, `SystemUIOverlayMona`, `SettingsOverlayMona`, `SettingsProviderOverlayMona`, `WifiOverlayMona`, `ApertureOverlayMona`; sets `vendor.sys.video.disable.ubwc=1` (as on `lisa` SM7325 for WFD).
   - `lineage_mona.mk`: inherits `device/xiaomi/mona/device.mk` + `vendor/lineage/config/common_full_phone.mk`; sets `PRODUCT_NAME := lineage_mona`, `PRODUCT_DEVICE := mona`, `PRODUCT_MODEL := 2109119BC`, stock `BuildFingerprint`/`BuildDesc` from `@firmware-extract`'s target firmware, and crDroid flags (`TARGET_FACE_UNLOCK_SUPPORTED := true`, `TARGET_BOOT_ANIMATION_RES := 1080`).
   - `vendor.prop`: `persist.vendor.fingerprint.type=udfps_optical`, `persist.vendor.fingerprint.sensor_location=540|2147|103`, `bluetooth.device.default_name=Xiaomi Civi`, `vendor.usb.product_string=Xiaomi Civi`, plus `ro.hardware.audio.primary` (verified against `@firmware-extract`'s stock `/vendor/lib/hw/audio.primary.*.so`).
   - `extract-files.py` + `proprietary-files.txt`: `ExtractUtils.device_with_common(module, 'sm8350-common', module.vendor)` combining `lisa`/`venus` Android 17 fixups (`libtinyxml2-v34`, `libjsoncpp_shim`, `libprocessgroup_shim`, `AHardwareBuffer_*`/`remote_handle*` symbol version clearing, `sensors.xiaomi.v2.so` in `hals.conf`) with `mona`-specific camera XML/binary patches (`mona_motiontuning.xml`, `pureShot_parameter.xml`, `pureView_parameter.xml`, `camera.qcom.so`, `camera.xiaomi.so`).

---

## 7. Local Reference Clones Inventory (`<reference-clones>/`)

All clones were fetched direct (zero proxy traffic), shallow (`--depth 1`), with `--filter=blob:none --no-checkout` for large kernel/vendor/TWRP repos:

- **LineageOS (`lineage-24.0`):** `los_device_xiaomi_sm8350-common`, `los_device_xiaomi_lisa`, `los_device_xiaomi_venus`, `los_device_xiaomi_haydn`, `los_device_xiaomi_renoir`, `los_hardware_xiaomi`, `kernel_los_sm8350` (blobless)
- **crDroid (`17.0`):** `crdroid_device_xiaomi_sm8350-common`, `crdroid_device_xiaomi_sm8350-common-haydn`, `crdroid_device_xiaomi_haydn`, `crdroid_device_xiaomi_vili`, `crdroid_device_xiaomi_redwood`, `crdroid_vendor_crdroid` (blobless), `kernel_crdroid_sm8350` (blobless)
- **TheMuppets (`lineage-24.0`, blobless):** `muppets_vendor_sm8350-common`, `muppets_vendor_lisa`, `muppets_vendor_venus`
- **Xiaomi `mona` Community & Official Kernel:** `miku_device_xiaomi_mona`, `miku_device_xiaomi_mojin`, `kernel_micode_mona` (`mona-r-oss`, blobless), `kernel_micode_lisa` (`lisa-r-oss`, blobless), `kernel_miku_mona` (blobless), `twrp_chilan666_mona`, `twrp_samuioto_mona`, `twrp_iamr0s_mona`, `twrp_shinnshiwang_mona` (blobless)
- **SM7325 UDFPS Sibling (`lineage-24.0`):** `taoyao_device_xiaomi_taoyao`
