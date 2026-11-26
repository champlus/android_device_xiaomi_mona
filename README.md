# Device Tree for Xiaomi Civi 1 (`mona`) — crDroid 13.1 (Android 17)

> **Important:** This device tree is strictly for **Xiaomi Civi 1 CN** (codename **`mona`**, model **`2109119BC`**, internal board **`K9B`**, Qualcomm **SM7325 / `yupik`**). It is **NOT** compatible with Motorola `mona` or Xiaomi Civi 1S (`zijin`).

[![Android 17](https://img.shields.io/badge/Android-17%20(SDK%2037)-3DDC84?logo=android)](https://source.android.com/)
[![crDroid 13.1](https://img.shields.io/badge/crDroid-13.1%20(17.0)-0099FF)](https://crdroid.net/)
[![Kernel 5.4.302](https://img.shields.io/badge/Kernel-5.4.302--qgki-orange)](https://github.com/champlus/android_kernel_xiaomi_sm8350)
[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-legacy%20(Manual%20Hooks)-blueviolet)](https://github.com/KernelSU-Next/KernelSU-Next)

---

## Multi-Repository Layout

This port follows standard LineageOS / crDroid multi-repo conventions so anyone can sync and compile a bootable ROM using `repo`:

| Repository | Branch | Target Path | Description |
| :--- | :--- | :--- | :--- |
| [champlus/android_device_xiaomi_mona](https://github.com/champlus/android_device_xiaomi_mona) | `17.0` | `device/xiaomi/mona` | Device tree, RRO overlays, SELinux, `mona` UDFPS handler (`/odm/lib64/libudfpshandler.so`), `local_manifests/`, kernel patch reference & docs |
| [champlus/proprietary_vendor_xiaomi_mona](https://github.com/champlus/proprietary_vendor_xiaomi_mona) | `17.0` | `vendor/xiaomi/mona` | Proprietary blobs extracted from HyperOS `OS1.0.2.0.TKVCNXM` (all fixups applied; `radio/` firmware omitted to avoid Git LFS) |
| [champlus/android_kernel_xiaomi_sm8350](https://github.com/champlus/android_kernel_xiaomi_sm8350) | `17.0` | `kernel/xiaomi/sm8350` | `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`, Linux `5.4.302`) with all 10 `mona` patches applied |
| [KernelSU-Next/KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) | `legacy` | `kernel/xiaomi/sm8350/KernelSU-Next` | Built-in non-GKI 5.4 KernelSU-Next (wired via manual hooks, LTO + strict CFI safe) |
| `LineageOS/android_device_xiaomi_sm8350-common` | `lineage-24.0` | `device/xiaomi/sm8350-common` | Shared SM8350/SM7325 common device tree |
| `LineageOS/android_hardware_xiaomi` | `lineage-24.0` | `hardware/xiaomi` | Xiaomi AIDL V4 fingerprint/UDFPS/sensors HALs |
| `TheMuppets/proprietary_vendor_xiaomi_sm8350-common` | `lineage-24.0` | `vendor/xiaomi/sm8350-common` | Shared SM8350/SM7325 common vendor blobs |

---

## Hardware Specifications

| Spec | Detail |
| :--- | :--- |
| **SoC / GPU** | Qualcomm SM7325 Snapdragon 778G 5G (`yupik` / `lahaina`) / Adreno 642L |
| **Memory / Storage** | 8/12 GB LPDDR4X / 128/256 GB UFS 2.2 |
| **Display** | 6.55" Curved 10-bit OLED (CSOT `K9B`, `1080×2400`, 60/120 Hz, 12-bit native LHBM) |
| **Touchscreen** | Synaptics TCM S3908P (SPI) + `xiaomi_touch` |
| **Fingerprint** | Goodix Optical UDFPS (`540\|2147\|103`, AIDL V4 + LHBM `fod_hbm`/`fod_ui` + `fod_finger_down`) |
| **Cameras** | Rear: 64 MP Samsung S5KGW3 + 8 MP Sony IMX355 UW + 2 MP GC02M1 Macro<br>Front: 32 MP Sony IMX616 AF + **Dual Soft-Light Flash** (`PM8350C` `led:switch_1`) |
| **Audio** | Qualcomm WCD938x + Dual Awinic AW882xx Stereo Smart PAs (`lahaina-yupikidp-snd-card`, ForteMedia ACDB + Dolby `capi_v2_dap_cpdp.so`) |
| **Haptics** | Awinic AW8622x / AW8624 Z-axis LRA |
| **Battery / Charging** | 4500 mAh, 55W/67W PD-PPS fast charging (`PM7325B` + `BQ2597X` + `BQ_FG_1S` + `BQ_FUEL_GAUGE` + `BQ_CLOUD_AUTHENTICATION`) |
| **Connectivity** | Qualcomm WCN6750 Wi-Fi 6 / BT 5.2, NXP SN100T/SN110T NFC + eSE, SPI IR Blaster |
| **Stock Firmware Base** | Xiaomi HyperOS 1.0 China Stable **`OS1.0.2.0.TKVCNXM`** (`V816.0.2.0.TKVCNXM`) |

---

## Real-Device Verification Status

Tested end-to-end on real Xiaomi Civi 1 CN (`2109119BC`) hardware:

- **Working**:
  - Boot (0 crashes, 0 tombstones, 0 HAL deaths, SELinux Enforcing)
  - 60/120 Hz OLED display, front punch-hole cutout, ESD polling (`status_offset_cmd` — 0 `PANEL_DEAD` flickers)
  - Optical UDFPS enrollment, screen-on & AOD unlock, 12-bit LHBM reg `0x51` brightness restoration
  - Wi-Fi 6, 5G/LTE cellular data & voice calls, Bluetooth
  - All cameras (wide / ultrawide / macro / front) + rear flash + front dual soft-light flash (`led:torch_{1,2}`)
  - Dual `AW882xx` stereo speakers & media playback (`deep-buffer-playback` / Apple Music via baked ADSP `capi_v2_dap_cpdp.so` + `hrtf5c.bin`)
  - `AW8622x` haptics, gyroscope/accelerometer/magnetometer/light sensors
  - Battery authentication (`authentic=1`, 32-byte digest), 55W/67W Xiaomi & PD-PPS fast charging, powered-off charging (`ro.boot.mode=charger`), stable USB-C DRP (`ufp/sink/device` ADB & data)
  - Built-in **KernelSU-Next (`legacy`, Manual Hooks)** with `preinit` runner and full Clang 22 LTO + strict CFI
- **Known Limitations**:
  - **Elliptic Labs ultrasonic proximity (`us_prox_iio.ko`)**: Untested / suspected hardware defect on the reference unit (already non-functional on stock HyperOS).
  - **Stock radio/bootloader firmware**: Not bundled in the public `vendor` repository to stay below GitHub's 100 MiB file limit without Git LFS (see [Flashing](#flashing) and [Optional: Bundling Firmware](#optional-extracting-blobs-or-bundling-stock-firmware) below).

---

## Build Instructions

### 1. Prerequisites
- Linux x86_64 build host (Ubuntu 22.04/24.04 recommended), **≥32 GiB RAM** (64+ GiB recommended for Android 17 Soong + Clang LTO), **≥400 GiB** free disk space.
- Standard AOSP build packages & `repo` tool installed.

### 2. Initialize crDroid 13 (`17.0`) and Add `mona` Local Manifest
```bash
mkdir -p crdroid13 && cd crdroid13

repo init -u https://github.com/crdroidandroid/android.git -b 17.0 --git-lfs

mkdir -p .repo/local_manifests
curl -fsSL https://raw.githubusercontent.com/champlus/android_device_xiaomi_mona/17.0/local_manifests/mona.xml \
  -o .repo/local_manifests/mona.xml

repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc)
```

> **Note:** `local_manifests/mona.xml` automatically pulls `device/xiaomi/mona`, `vendor/xiaomi/mona`, `kernel/xiaomi/sm8350` (with all 10 `mona` patches pre-applied), `kernel/xiaomi/sm8350/KernelSU-Next` (full `legacy` history for `KSU_VERSION` calculation), and the shared `sm8350-common` / `hardware/xiaomi` trees. No manual kernel patching is required.

### 3. Build ROM
```bash
source build/envsetup.sh
brunch mona
```

*(If your host has limited RAM / no swap, cap parallelism via `lunch lineage_mona-cp2a-userdebug && m bacon -j16`.)*

Outputs are generated under `out/target/product/mona/`:
- `crDroidAndroid-17.0-*-mona-v13.1.zip` (flashable A/B OTA package)
- `boot.img` (192 MiB, recovery-in-boot), `dtbo.img` (16 MiB), `vendor_boot.img` (96 MiB), `vendor_dlkm.img`

> **Tip if you edit kernel DTS/Makefile:** Clear stale intermediate `out/target/product/mona/obj/DTBO_OBJ/arch/arm64/boot/dtbo.img` before rebuilding.

---

## Optional: Extracting Blobs or Bundling Stock Firmware

`champlus/proprietary_vendor_xiaomi_mona` already ships all pre-extracted and patched proprietary blobs (`vendor/xiaomi/mona/proprietary/`), excluding the 17 stock `radio/*.img` partitions.

If you want to re-extract blobs from scratch or bundle stock `OS1.0.2.0.TKVCNXM` firmware images into your OTA zip:
1. Download official HyperOS `OS1.0.2.0.TKVCNXM` (`miui_MONA_OS1.0.2.0.TKVCNXM_697bd03a16_13.0.zip`), extract `payload.bin`, and unpack `system`, `vendor`, `odm`, `product`, `system_ext` plus the 17 firmware `.img` files into a `<stock_dump>` directory (with `RADIO/*.img`).
2. Run from `device/xiaomi/mona/`:
   ```bash
   ./extract-files.py --only-target --allow-prohibited-files <stock_dump>
   ```
   *(The `--allow-prohibited-files` flag is required because `camera.qcom.so` links `libMegviiFacepp-0.5.2.so` & `libmegface.so`.)*

---

## Flashing

1. **Firmware Prerequisite**: Ensure your phone is on Xiaomi HyperOS **`OS1.0.2.0.TKVCNXM`** (`V816.0.2.0.TKVCNXM`) with an unlocked bootloader. **Never relock the bootloader** on a custom ROM.
2. **Flash Recovery & Boot Images** (first install):
   ```bash
   fastboot flash dtbo dtbo.img
   fastboot flash vendor_boot vendor_boot.img
   fastboot flash boot boot.img
   fastboot reboot recovery
   ```
3. **Sideload ROM** (in Lineage/crDroid Recovery):
   - First install: **Factory Reset → Format data/factory reset** (required for FBE), then **Apply Update → Apply from ADB**:
     ```bash
     adb sideload crDroidAndroid-17.0-*-mona-v13.1.zip
     ```
   - Subsequent builds signed with the same keys: dirty `adb sideload` directly without formatting data.
4. **KernelSU-Next Manager (Important UAPI 6 Note)**:
   - The `KernelSU-Next` `legacy` branch (`e5f5ec9+`, `KSU_VERSION >= 33327`) uses **KernelSU UAPI v6**.
   - Use an official **UAPI 6-compatible KernelSU-Next Manager APK** (e.g., official GitHub Actions CI build `v3.4.2-291+` / `33646-6` or newer release supporting UAPI 6; older UAPI 5 APKs such as `33355-5` will report unsupported UAPI).
   - If you prefer a non-rooted build without KernelSU-Next, disable `CONFIG_KSU` / `CONFIG_KSU_MANUAL_HOOK` in `kernel/xiaomi/sm8350/arch/arm64/configs/vendor/mona_QGKI.config`.

---

## Kernel Patch Summary (`patches/kernel/sm8350/`)

All 10 patches are already applied on `champlus/android_kernel_xiaomi_sm8350` (`17.0`) and mirrored under [`patches/kernel/sm8350/`](patches/kernel/sm8350/README.md) for transparency and rebasing:
- `0001`–`0002`: CSOT `K9B` 12-bit reg `0x51` LHBM brightness restoration & 1000-nit index `6`
- `0003` & `0007`: `synaptics_s3908p` + `xiaomi_touch` UDFPS `fod_press_status` / `fod_longpress_gesture_enabled` / `fod_finger_down` (`BTN_INFO`) wiring
- `0004`–`0005`: `mona`-only 16 MiB `dtbo.img` build scope & Clang 22 `-Wstrict-prototypes` fix
- `0006`: `DSI_CMD_SET_PANEL_STATUS_OFFSET` ESD polling fix (eliminates 5.12s `PANEL_DEAD` flicker)
- `0008`: `qti_battery_charger` alignment with real stock QGKI `k8.ko` (99-entry `xm_prop_map` `0x18c`, `CONFIG_BQ_FG_1S=y` 32 B digest, `CONFIG_BQ2597X=y`, `CONFIG_BQ_CLOUD_AUTHENTICATION=y`, async `fb_notifier_work`, quiet `batt_thermal`/`chg_suspend` logs)
- `0009`: `ucsi_glink` Xiaomi `UC_UCSI_SWAP_ROLE_IND` (`0x14` / `MI SMART INTERCHG`) USB-C DRP role swap support
- `0010`: KernelSU-Next (`legacy`) integration with deterministic manual hooks + `path_umount` backport

---

## Credits
- [LineageOS](https://github.com/LineageOS) (`android_device_xiaomi_sm8350-common`, `android_kernel_xiaomi_sm8350`, `android_hardware_xiaomi`)
- [crDroid Android](https://github.com/crdroidandroid)
- [TheMuppets](https://github.com/TheMuppets) (`proprietary_vendor_xiaomi_sm8350-common`)
- [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next)
