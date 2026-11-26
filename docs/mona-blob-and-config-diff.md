# Xiaomi Civi 1 (`mona`, `OS1.0.2.0.TKVCNXM`) — Blob Inventory, ELF Fixups, UDFPS ABI & Config Diff for crDroid 13 (Android 17 / LineageOS 24.0)

- **Target Device**: Xiaomi Civi 1 China (`mona`, model `2109119BC`, hardware code `K9B`, SoC Qualcomm SM7325 / Snapdragon 778G / `yupik`, `ro.board.platform=lahaina`)
- **Stock Dump Audited (Read-Only)**: `<stock-dump>/OS1.0.2.0.TKVCNXM/fs/` (`Xiaomi/mona/mona:13/RKQ1.211001.001/V816.0.2.0.TKVCNXM:user/release-keys`, `vendor` API 30 / VNDK 30, `product`/`system` API 33)
- **Reference Baseline Trees Audited (Read-Only)**:
  - `los_device_xiaomi_sm8350-common` (`lineage-24.0` / Android 17 base — 679 proprietary entries)
  - `crdroid_device_xiaomi_sm8350-common` (delta notes where crDroid diverges from LineageOS)
  - `los_device_xiaomi_lisa` (`lineage-24.0`, SM7325 / `yupik` sibling — 581 entries; side FPC FP + TFA98xx PA)
  - `los_device_xiaomi_venus` (`lineage-24.0`, Goodix optical UDFPS sibling — 610 entries; SM8350 + CS35L41 PA)
  - `miku_device_xiaomi_mona` + `miku_device_xiaomi_mojin` (Android 13/14 `mona` reference — 454 device entries)
  - `los_hardware_xiaomi` (`lineage-24.0` AIDL V4 `android.hardware.biometrics.fingerprint-service.xiaomi`)

> **Verification Guarantee**: Every single `mona`-specific file path, ELF SONAME, `DT_NEEDED`, versioned symbol, binary patch offset, and XML fixup below was programmatically verified against `<stock-dump>/OS1.0.2.0.TKVCNXM/fs/` (386 candidate `mona`-specific ELFs audited; 229-library 64-bit camera transitive `DT_NEEDED` closure verified; AArch64 instructions decoded for `fingerprint.goodix_fod.so` and `camera.xiaomi.so`).

---

## Executive Summary of Critical Catches (Do Not Miss!)

1. **Goodix Optical UDFPS (`fingerprint.goodix_fod.so` + `libgf_hal.so`) is 100% V1 ABI-Compatible with `hardware/xiaomi` AIDL V4 (`lineage-24.0`)**:
   - Disassembly of `fingerprint_open` (`0x25d0`) proves `fingerprint_device_t` matches `hardware/xiaomi/fingerprint/include/fingerprint.h` (**V1**, do **NOT** enable `IMPL_V2`), with `extCmd` at offset `0xd0` (`0x2ae8`) handling `COMMAND_NIT=10` and `COMMAND_FOD_PRESS_STATUS=1`.
   - Set `TARGET_HAS_UDFPS := true` in `device/xiaomi/mona/device.mk` before inheriting `sm8350-common/common.mk`.
   - Do **not** extract `vendor/lib64/vendor.xiaomi.hardware.fx.tunnel@1.0.so` — `hardware/xiaomi` builds it from source (`interfaces/xiaomi/hardware/fx/tunnel/1.0/Android.bp`), and `sm8350-common/hidl/manifest_udfps.xml` declares it.
   - Exact UDFPS coordinates derived from stock `vendor/build.prop` (`X_Y=437,2044`, `size=206,206`): `persist.vendor.fingerprint.sensor_location=540|2147|103`.
2. **New Camera Blob & Symbol-Version Catches Missed by `miku_mona` / `lisa` / `venus`**:
   - **`vendor/lib64/libmialgo_det_seg.so`** is a hard `DT_NEEDED` of `vendor/lib64/camera/plugins/com.xiaomi.plugin.capbokeh.so`, yet is missing from `miku_mona`, `lisa`, and `sm8350-common`. Must be extracted!
   - **`vendor/lib64/libTrueSight.so`** (used by `mona` BeautyLens / front portrait, absent from `lisa`/`venus`) imports **7** versioned `AHardwareBuffer_*@LIBNATIVEWINDOW` symbols — must have `.clear_symbol_version(...)` in `extract-files.py` or Android 17 linker will reject it.
   - **`vendor/lib64/libarcsoft_hdrplus_hvx_stub.so`** imports **5** `@SDSPRPC` versioned symbols (`remote_handle_{open,invoke,close}`, `remote_register_buf`, `remote_register_buf_attr` — `lisa` only cleared 3 of the 5).
   - **`vendor/lib64/hw/camera.xiaomi.so`** `sig_replace` target verified at `0x64718` (`21 00 80 52 29 07 00 94` -> `21 00 80 52 1F 20 03 D5`): NOPs the duplicate `bl android::hardware::configureRpcThreadpool(size_t, bool)` call inside `RegisterIMiPostProcService()`. (`venus`'s `AA 06 00 94` does **not** exist in `mona`.)
   - **`vendor/lib64/vendor.xiaomi.hardware.cameraperf@1.0-impl.so`** does **not** exist in `mona` (same as `lisa`; do **not** copy `venus/hidl/manifest.xml` or `cameraperf` fixups).
   - Drop all 33 unused 32-bit camera `.so` blobs from `miku_mona` (only keep `vendor/lib/libcamxexternalformatutils.so`, matching `lisa`/`venus`) — this also eliminates `vendor/lib/libmmcamera_faceproc.so;DISABLE_CHECKELF`.
3. **Audio & Smart PA (`AW882xx` on `lahaina-yupikidp-snd-card`, NOT `lisa`'s `TFA98xx` on `yupikqrd`)**:
   - `mona` uses dual Awinic `aw882xx` smart PAs (`aw882xx_smartpa@34`/`@35`, `aw882xx_dlkm.ko`, `vendor/firmware/aw882xx_*.bin` × 8) and `vendor/etc/audio/sku_yupik/*yupikidp*.xml` + `mixer_paths_overlay_{static,dynamic}.xml` + `sound_trigger_platform_info.xml`.
   - ACDB uses `vendor/etc/acdbdata/Forte/*` (verified via `libacdbloader.so` string `Loaded ForteMedia ACDB!`) + `adsp_avs_config.acdb` + `nn_ns_models/*` + `nn_vad_models/*`.
4. **Sensors (`sensors.mius.proximity.so` + `sensors.xiaomi.v2.so`)**:
   - Stock `vendor/etc/sensors/hals.conf` contains `sensors.ssc.so`, `sensors.touch.detect.so`, `sensors.mius.proximity.so`. Must patch `hals.conf` with `.add_line_if_missing('sensors.xiaomi.v2.so')` for UDFPS!
   - `vendor/lib64/libsensor_cal_v2.so` requires `.add_needed('libjsoncpp_shim.so')`, and `vendor/lib64/libnotifyaudiohal.so` requires `;FIX_SONAME` (SONAME is `libnotifyaudiohal@6.0.so`).
5. **Hardware & Partition Traps vs `lisa`/`venus`/`sm8350-common`**:
   - **`BOARD_DTBOIMG_PARTITION_SIZE := 16777216`** (16 MiB — **NOT** `25165824` as in `lisa`/`venus`!).
   - **Wi-Fi (`WCN6750` / `qca6750`)**: integrated WPSS via `icnss2.ko` + `qca_cld3_qca6750.ko`, requiring `vendor/etc/init/init.vendor.wlan.rc` (`write /sys/kernel/icnss/wpss_boot 1`) and `qca6750` symlink to `WCNSS_qcom_cfg.ini` & `wlan_mac.bin`.
   - **Touchscreen (`Synaptics S3908P`)**: `vendor/firmware/s3908p_xiaomi_k9b_spi.img` (also copy to `vendor_ramdisk/lib/firmware/` for recovery/early boot) + `synaptics_tcm_*.ko` modules.
   - **Vibrator (`AW8622x`/`AW8624`)**: `aw8622x_haptic.bin`, `aw8622x_osc_rtp_24K_5s.bin`, `aw8624_haptic.bin`, `aw8624_rtp.bin`, `osc_rtp_24K_5s.bin`.
   - **Front Dual Soft-Light Flash (`PM8350C`)**: `led:switch_1`, `led:torch_1`, `led:torch_2` sysfs permissions + SELinux needed for front selfie flash/torch.

---

## 1. Complete `mona`-Specific Blob Inventory (Delta Over `sm8350-common`)

All paths below are verified to exist in `<stock-dump>/OS1.0.2.0.TKVCNXM/fs/` and have **zero overlap** with `los_device_xiaomi_sm8350-common/proprietary-files.txt`.

### 1.1 High-Level Comparison Summary

| Category | `sm8350-common` | `lisa` (`yupik`) | `venus` (`lahaina`) | `miku_mona` (`mona` A13) | **`mona` (`OS1.0.2.0.TKVCNXM` for crDroid 13)** |
|---|---|---|---|---|---|
| ACDB | None | `Forte/` (15) | `Tutu/` (15) | In `mojin` | `Forte/` + `Forte_Codec_cal.acdb` + `nn_*` + `adsp_avs_config.acdb` (**16 files**) |
| ACDB libs (32-bit) | None | 5 libs | 5 libs | In `mojin` | Same 5 libs (`libacdb-fts`, `libacdbloader`, `libacdbrtac`, `libadiertac`, `libaudcal`) |
| ADSP/CDSP modules | None | 40 files | 42 files | 51 files | **40 core** (`lisa` set, all 40 OK) + **11 optional `mona` extras** (`mc_bokeh`, `hrtf5c`, `bm2n*`, `dap_cpdp`, `VppFrc`/`mobilenet_frc`) |
| Audio HAL + libs (32-bit) | Builds AOSP `audio.primary.lahaina` | 12 blobs (`audio.primary.lisa.so`) | 14 blobs (`audio.primary.venus.so`) | In `mojin` | **12 blobs** (`audio.primary.mona.so;FIX_SONAME`, same set as `lisa`; all 12 OK) |
| Audio Smart PA fw | None | `tfa98xx.cnt` | `cs35l41-*` (18) | In `mojin` | **`aw882xx_*.bin` (8 files)** |
| Audio XML configs | `audio_effects`, `audio_io_policy`, `audio_policy_configuration` | 6 `yupikqrd` XMLs in `device/xiaomi/lisa/audio/` | 7 `sku_lahaina` XMLs | In `mojin` | **6 `yupikidp` XMLs** copied to `vendor/etc/audio/sku_yupik/` (recommended in `device/xiaomi/mona/audio/` like `lisa`, or extracted) |
| Camera HAL / CHI / Postproc / 64-bit libs | None (only `camera_cnf.txt` + QTI display/gralloc) | 64-bit + `lib/libcamxexternalformatutils.so` | 64-bit + `lib/libcamxexternalformatutils.so` | 64-bit + 33 unused 32-bit libs | **Full 64-bit transitive closure** (4 `mona` sensors, 2 actuators, 4 EEPROMs, 4+1 tuned bins, 69 components, 16 plugins, **+ `libmialgo_det_seg.so`**) + `lib/libcamxexternalformatutils.so` |
| Camera configs & models | `camera_cnf.txt` | 72 files | 55 files | 91 files | **`mona` union** (`mona_motiontuning.xml`, `pureShot`/`pureView`, `xiaomi/*.json`, `CFR_para_*`, `LDC_*`, `mibokeh/*`, `model/*`, `*.dlc`, `ai_enhance.dlc`, plus optional `beautyLens/*` & `resources/*` for stock-parity front beauty) |
| Camera firmware | None | `CAMERA_ICP_170.elf` | `CAMERA_ICP.elf` + OIS | `CAMERA_ICP.elf` + `_170` | `vendor/firmware/CAMERA_ICP_170.elf` (SM7325/Yupik; optionally also `CAMERA_ICP.elf`) |
| Charger | `init.batterysecret.rc` | `vendor/bin/batterysecret` | `vendor/bin/batterysecret` | In `mojin` | `vendor/bin/batterysecret` |
| Display QDCM | `libdpps`, `libsnapdragoncolor-manager` | 2 `lisa` XMLs | 1 `venus` XML | In `mojin` | `vendor/etc/qdcm_calib_data_xiaomi_42_02_0a_cmd_mode_dsc_dsi_panel.xml` |
| Fingerprint | AIDL V4 service + `libudfpshandler` | `fingerprint.fpc.so` (side) | `fingerprint.goodix_fod.so` + `libgf_hal.so` | Both + `fx.tunnel@1.0.so` | `fingerprint.goodix_fod.so:.../fingerprint.goodix_fod.default.so;FIX_SONAME` + `libgf_hal.so` (**no** `fx.tunnel@1.0.so` blob) |
| Graphics / IPA / VPU fw | None | `a660_*` (7), `yupik_ipa_fws.*` (8), `vpu20_1v.*` (23) | `a660_*` (7), `ipa_fws.*` (8), `vpu20_4v.*` (25), `evass.*` (22) | In `mojin` | **Exact `lisa` SM7325 set**: `a660_*` (7), `yupik_ipa_fws.*` + `ipa_fws.rc` (8), `vpu20_1v.*` (23); optionally `evass-lt.*` (22) if CVP needed |
| NFC configs | `android.hardware.nfc-service.nxp` + `libsn100u_fw.so` | 3 configs | 3 configs | In `mojin` | `libnfc-nci.conf`, `libnfc-nxp.conf`, `libnfc-nxp_RF.conf:vendor/libnfc-nxp_RF.conf` |
| Sensors + configs | `android.hardware.sensors-service.xiaomi-multihal` + `sensors.xiaomi.v2` | 18 blobs + 60 configs (`sensors.mius.proximity.so`) | 17 blobs + 65 configs (`sensors.elliptic@2.0.so`) | In `mojin` | **18 blobs** (`sensors.mius.proximity.so` + `libsensor_cal_v2.so` + `libnotifyaudiohal.so;FIX_SONAME` + `libultrasound.so` + `libsns_*`) + **48 `mona` JSON/reg configs** + patched `hals.conf` |
| Thermal configs | `mi_thermald` + `init.mi_thermald.rc` | 28 (CN + IN) | 20 | In `mojin` | **18 stock CN configs** (`thermal-*.conf` incl. `thermal-huanji.conf` + `thermald-devices.conf`) |
| Touchscreen fw | None | 4 `goodix_gt9897t_*` | 2 `st_fts_k2*` (+ ramdisk) | 1 `s3908p` | `vendor/firmware/s3908p_xiaomi_k9b_spi.img` (+ `:vendor_ramdisk/lib/firmware/s3908p_xiaomi_k9b_spi.img`) |
| Vibrator fw | `vendor.qti.hardware.vibrator.service` | 3 `aw8624` + `osc_rtp` | `aw8697_haptic.bin` | In `mojin` | **5 files**: `aw8622x_haptic.bin`, `aw8622x_osc_rtp_24K_5s.bin`, `aw8624_haptic.bin`, `aw8624_rtp.bin`, `osc_rtp_24K_5s.bin` |
| Wi-Fi (`WCN6750`) | `WCNSS_qcom_cfg.ini` (`lahaina`) | Uses common | Uses common | `qca6750/WCNSS_qcom_cfg.ini` | `vendor/etc/wifi/qca6750/WCNSS_qcom_cfg.ini` + `vendor/etc/init/init.vendor.wlan.rc` + `qca6750` symlinks (see §4.4) |
| A/B Firmware imgs | None | 17 `.img;AB` | 17 `.img;AB` | None | **Exact same 17 `.img;AB` partitions** (all 17 verified in `dump/images/`) |

---

### 1.2 Verified `device/xiaomi/mona/proprietary-files.txt` Complete Listing

Every path below is verified `[OK]` in `OS1.0.2.0.TKVCNXM/fs/`:

#### ACDB (16 files)
```text
# ACDB
vendor/etc/acdbdata/Forte/Forte_Bluetooth_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Codec_cal.acdb
vendor/etc/acdbdata/Forte/Forte_General_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Global_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Handset_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Hdmi_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Headset_cal.acdb
vendor/etc/acdbdata/Forte/Forte_Speaker_cal.acdb
vendor/etc/acdbdata/Forte/Forte_workspaceFile.qwsp
vendor/etc/acdbdata/adsp_avs_config.acdb
vendor/etc/acdbdata/nn_ns_models/fai__2.0.0_0.1__3.0.0_0.0__eai_1.00.pmd
vendor/etc/acdbdata/nn_ns_models/fai__2.0.0_0.1__3.0.0_0.0__eai_1.10.pmd
vendor/etc/acdbdata/nn_ns_models/fai__2.3.0_0.1__3.0.0_0.0__eai_1.00.pmd
vendor/etc/acdbdata/nn_ns_models/fai__2.3.0_0.1__3.0.0_0.0__eai_1.10.pmd
vendor/etc/acdbdata/nn_vad_models/fai_3.0.0_0.0_eai_1.00.pmd
vendor/etc/acdbdata/nn_vad_models/fai__3.0.0_0.0__eai_1.10.pmd
```
*Note*: `vendor/etc/acdbdata/IDP/lahaina-yupikidp-snd-card/` also exists in the dump, but `libacdbloader.so` binary strings confirm `mona` loads `ForteMedia ACDB` (`Forte/`), matching `lisa` and `miku_mojin`.

#### ACDB Libraries (5 files, 32-bit)
```text
# ACDB libraries
vendor/lib/libacdb-fts.so
vendor/lib/libacdbloader.so
vendor/lib/libacdbrtac.so
vendor/lib/libadiertac.so
vendor/lib/libaudcal.so
```

#### ADSP / CDSP Modules (40 required + 11 `mona` extras = 51 files)
```text
# ADSP Modules (all 40 in lisa + 11 mona-specific extras verified in dump)
vendor/lib/rfsa/adsp/capi_v2_aptX_CLHDADV_Encoder.so
vendor/lib/rfsa/adsp/capi_v2_aptX_CLHDAD_Speech_Decoder.so
vendor/lib/rfsa/adsp/libMIAIHDR_skel.so
vendor/lib/rfsa/adsp/libQ6MSFR_manager_skel.so
vendor/lib/rfsa/adsp/libQnnHtpAltPrepSkel.so
vendor/lib/rfsa/adsp/libQnnHtpSkel.so
vendor/lib/rfsa/adsp/libVppAisQnnHtp.so
vendor/lib/rfsa/adsp/libVppQnnHtp.so
vendor/lib/rfsa/adsp/libadsp_jpege_skel.so
vendor/lib/rfsa/adsp/libapps_mem_heap.so
vendor/lib/rfsa/adsp/libarcsoft_hdrplus_hvx_skel.so
vendor/lib/rfsa/adsp/libbitml_nsp_skel.so
vendor/lib/rfsa/adsp/libbitml_nsp_v2_skel.so
vendor/lib/rfsa/adsp/libcamera_nn_skel.so
vendor/lib/rfsa/adsp/libcvpdsp_2_1.so
vendor/lib/rfsa/adsp/libdspCV_skel.so
vendor/lib/rfsa/adsp/libdsp_streamer_binning.so
vendor/lib/rfsa/adsp/libfastcvadsp.so
vendor/lib/rfsa/adsp/libfastcvdsp_skel.so
vendor/lib/rfsa/adsp/libhdr_skel.so
vendor/lib/rfsa/adsp/libmctfengine_skel.so
vendor/lib/rfsa/adsp/libmialgo_basic_cdsp_skel.so
vendor/lib/rfsa/adsp/libmialgo_mc_bokeh_cdsp_skel.so
vendor/lib/rfsa/adsp/libmialgo_mfnr_cdsp_skel.so
vendor/lib/rfsa/adsp/libmialgo_pureview_cdsp_skel.so
vendor/lib/rfsa/adsp/libmialgo_rfs_cdsp_skel.so
vendor/lib/rfsa/adsp/libmialgo_sfnr_cdsp_skel.so
vendor/lib/rfsa/adsp/libscveObjectSegmentation_skel.so
vendor/lib/rfsa/adsp/libscveT2T_skel.so
vendor/lib/rfsa/adsp/libsnpe_dsp_v65_domains_v2_skel.so
vendor/lib/rfsa/adsp/libsnpe_dsp_v66_domains_v2_skel.so
vendor/lib/rfsa/adsp/libsnpe_dsp_v68_domains_v3_skel.so
vendor/lib/rfsa/adsp/libsns_device_mode_skel.so
vendor/lib/rfsa/adsp/libsns_low_lat_stream_skel.so
vendor/lib/rfsa/adsp/libsuper_res_networks.so
vendor/lib/rfsa/adsp/libvpp_ais_networks.so
vendor/lib/rfsa/adsp/libvpt_action_recognition.so
vendor/lib/rfsa/adsp/misound_karaoke_res.bin
vendor/lib/rfsa/adsp/misound_karaokemix_res.bin
vendor/lib/rfsa/adsp/misound_res_headphone.bin
vendor/lib/rfsa/adsp/misound_res_spk.bin
# Optional mona audio/VPP DSP extras (also in stock & miku_mona):
# vendor/lib/rfsa/adsp/bm2n06.bin
# vendor/lib/rfsa/adsp/bm2n08.bin
# vendor/lib/rfsa/adsp/bm2n13.bin
# vendor/lib/rfsa/adsp/bm2n14.bin
# vendor/lib/rfsa/adsp/bm2n15.bin
# vendor/lib/rfsa/adsp/capi_v2_dap_cpdp.so
# vendor/lib/rfsa/adsp/hrtf5c.bin
# vendor/lib/rfsa/adsp/libVppFrcQnnHtp.so
# vendor/lib/rfsa/adsp/libmobilenet_dsp_frc.so
# vendor/lib/rfsa/adsp/libmobilenet_dsp_frc_networks.so
```

#### Audio Hardware & Awinic AW882xx Firmware (20 blobs + 6 `sku_yupik` XMLs)
```text
# Audio Hardware
vendor/lib/hw/audio.primary.lahaina.so:vendor/lib/hw/audio.primary.mona.so;FIX_SONAME
vendor/lib/liba2dpoffload.so:odm/lib/liba2dpoffload.so;MODULE_SUFFIX=_odm
vendor/lib/libadm.so
vendor/lib/libaudio_log_utils.so
vendor/lib/libaudiocloudctrl.so
vendor/lib/libaudioparsers.so
vendor/lib/libaudioroute_ext.so
vendor/lib/libhdmipassthru.so
vendor/lib/libqtigef.so
vendor/lib/libresampler.so
vendor/lib/libssrec.so:odm/lib/libssrec.so;MODULE_SUFFIX=_odm
vendor/lib/libvideoNS.so;DISABLE_CHECKELF

# Audio firmware (Awinic AW882xx stereo Smart PA)
vendor/firmware/aw882xx_pid_1852_acf.bin
vendor/firmware/aw882xx_pid_1852_monitor.bin
vendor/firmware/aw882xx_pid_2032_acf.bin
vendor/firmware/aw882xx_pid_2032_monitor.bin
vendor/firmware/aw882xx_rcv_reg_l.bin
vendor/firmware/aw882xx_rcv_reg_r.bin
vendor/firmware/aw882xx_spk_reg_l.bin
vendor/firmware/aw882xx_spk_reg_r.bin
```
**Audio XML configs** (copy into `device/xiaomi/mona/audio/` via `PRODUCT_COPY_FILES` to `$(TARGET_COPY_OUT_VENDOR)/etc/audio/sku_yupik/` matching `lisa/device.mk`, OR list directly in `proprietary-files.txt` — do **not** extract `audio_effects.xml`/`audio_io_policy.conf`/`audio_policy_configuration.xml` as `sm8350-common` already installs them into `sku_yupik/`):
- `vendor/etc/audio/sku_yupik/audio_platform_info_yupikidp.xml` (49,989 B)
- `vendor/etc/audio/sku_yupik/mixer_paths_yupikidp.xml` (156,020 B)
- `vendor/etc/audio/sku_yupik/mixer_paths_overlay_static.xml` (40,968 B — defines `aw882xx_*`, `aw_dev_{0,1}_*`, and `Mi_Ultrasound*` mixer controls!)
- `vendor/etc/audio/sku_yupik/mixer_paths_overlay_dynamic.xml` (2,835 B)
- `vendor/etc/audio/sku_yupik/sound_trigger_mixer_paths_yupikidp.xml` (18,303 B)
- `vendor/etc/audio/sku_yupik/sound_trigger_platform_info.xml` (44,261 B)

#### Camera (Verified 64-bit Transitive Closure + Configs + Firmware)
1. **`mona`-Specific Sensor / Actuator / EEPROM / Tuned Binaries (19 files)**:
```text
vendor/lib64/camera/com.qti.actuator.mona_semco_s5kgw3_dw9800_wide.so
vendor/lib64/camera/com.qti.actuator.mona_sunny_imx616_dw9714v_front.so
vendor/lib64/camera/com.qti.eeprom.mona_ofilm_imx355_gt24p64e_ultra_eeprom.so
vendor/lib64/camera/com.qti.eeprom.mona_semco_s5kgw3_gt24p128e_wide_eeprom.so
vendor/lib64/camera/com.qti.eeprom.mona_sunny_gc02m1_gt24p64e_macro_eeprom.so
vendor/lib64/camera/com.qti.eeprom.mona_sunny_imx616_p24c64f_front_eeprom.so
vendor/lib64/camera/com.qti.sensor.mona_ofilm_imx355_ultra.so
vendor/lib64/camera/com.qti.sensor.mona_semco_s5kgw3_wide.so
vendor/lib64/camera/com.qti.sensor.mona_sunny_gc02m1_macro.so
vendor/lib64/camera/com.qti.sensor.mona_sunny_imx616_front.so
vendor/lib64/camera/com.qti.sensormodule.mona_ofilm_imx355_ultra.bin
vendor/lib64/camera/com.qti.sensormodule.mona_semco_s5kgw3_wide.bin
vendor/lib64/camera/com.qti.sensormodule.mona_sunny_gc02m1_macro.bin
vendor/lib64/camera/com.qti.sensormodule.mona_sunny_imx616_front.bin
vendor/lib64/camera/com.qti.tuned.default.bin
vendor/lib64/camera/com.qti.tuned.mona_ofilm_imx355_ultra.bin
vendor/lib64/camera/com.qti.tuned.mona_semco_s5kgw3_wide.bin
vendor/lib64/camera/com.qti.tuned.mona_sunny_gc02m1_macro.bin
vendor/lib64/camera/com.qti.tuned.mona_sunny_imx616_front.bin
vendor/lib64/camera/fdconfigpreview.bin
vendor/lib64/camera/fdconfigpreviewlite.bin
vendor/lib64/camera/fdconfigvideo.bin
vendor/lib64/camera/fdconfigvideolite.bin
```
2. **Camera HAL, CHI, Postproc, Components (69 `.so`), Plugins (16 `.so`), CamX, Arcsoft, MiAlgo, Settings (all verified in `mona` dump)**:
   - Start from the 64-bit Camera sections of `miku_device_xiaomi_mona/proprietary-files.txt` (lines covering `vendor/lib64/hw/{camera.qcom,camera.xiaomi,com.qti.chi.override}.so`, `vendor/lib64/com.qti.*`, `vendor/lib64/camera/components/*`, `vendor/lib64/camera/plugins/*`, `vendor/lib64/lib*`, `vendor/lib64/vendor.{qti,xiaomi}.hardware.cam*`, plus `vendor/lib/libcamxexternalformatutils.so`), **DROP** the 33 unused 32-bit `vendor/lib/` camera `.so` blobs, and **ADD** these **7 missing 64-bit libs** verified in `mona` dump:
     - `vendor/lib64/libmialgo_det_seg.so` (**CRITICAL NEW CATCH**: `DT_NEEDED` by `com.xiaomi.plugin.capbokeh.so`!)
     - `vendor/lib64/camera/components/com.mi.node.AIIE.so` (matches `lisa`, present in `mona`)
     - `vendor/lib64/libQnnHtpStub.so` (matches `lisa`, needed by `libarcsoft_qnnhtp.so` / `AIIE`)
     - `vendor/lib64/libmialgo_ie_preview.so` (matches `lisa`, needed by `AIIE` / `miaiie`)
     - `vendor/lib64/libmialgo_video_enhance.so` (matches `lisa`, needed by `com.mi.node.rearvideo.so`)
     - `vendor/lib64/libmiXmlParser.so` (present in `mona`, in `lisa`)
     - `vendor/lib64/libnanopb.so` (present in `mona`, in `lisa`)
   - **Mark SONAME fixup**: `vendor/lib64/libmiStereoFactoryRemapLib_v2.so;FIX_SONAME` (SONAME is `libmiStereoFactoryRemapLib.so`).
   - **Do NOT add** (missing in `mona` dump): `libarcsoft_beautyshot.so`, `libwa_rtdof.so`, `vendor.xiaomi.hardware.cameraperf@1.0-impl.so`, `venus_bu63169_ois.*`, `beauty_style_*.cng`.
3. **Camera Configs & Models**:
   - All 91 `vendor/etc/camera/*` files in `miku_device_xiaomi_mona/proprietary-files.txt` (all 91 exist verbatim in `OS1.0.2.0.TKVCNXM`, including `mona_motiontuning.xml`, `pureShot_parameter.xml`, `pureView_parameter.xml`, `xiaomi/*.json`, `CFR_para_*`, `LDC_*`, `mibokeh/*`, `model/{dof_model,rt_model}/*`, `*.dlc`, `com.xiaomi.dcal.wu.{fake,golden}`, `com.xiaomi.eeprom.{m2x,u}.golden`, `com.xiaomi_k9_mecp*.bin`, `megviifacepp_0_5_2_model`).
   - **Add**: `vendor/etc/camera/ai_enhance.dlc` (matches `com.mi.node.AIIE.so` / `lisa`).
   - **Optional (only if shipping Leica/MIUI Camera / full BeautyLens & TrueSight front portrait shaders)**:
     - `vendor/etc/camera/beautyLens/*` (18 files: `dualcam_beauty_effect*_config.json` + 16 filter PNGs)
     - `vendor/etc/camera/102_SummerDay.png` .. `128_Sepia.png` (20 filter PNGs)
     - `vendor/etc/camera/resources/*` (230 files: TrueSight `default_param.json`, `FaceRetouch64.bin`, `render/Configure/*`, `render/Shaders/binShaders64/*`, `render/Overlay/*`, `render/InnerMaterial/*`)
     - *Note*: Stock AOSP/Aperture camera does not need `beautyLens/` or `resources/`, so omit them for lean AOSP vendor unless MIUI Camera is added later.
   - **Front Dual Soft-Light Flash (`PM8350C`)**: Controlled via kernel DTBO (`qcom,camera-flash@3` -> `flash-source = <0x00 0x04>`, `torch-source = <0x00 0x04>`, i.e., `led:flash_1` + `led:flash_2`, `led:torch_1` + `led:torch_2`, `led:switch_1`) and `com.qti.sensormodule.mona_sunny_imx616_front.bin` — no separate flash-only blob file exists; permissions/SELinux are covered in §4.3.
4. **Camera Firmware**:
```text
# Camera firmware
vendor/firmware/CAMERA_ICP_170.elf
# Optionally also include vendor/firmware/CAMERA_ICP.elf (present in dump & miku_mona)
```

#### Charger, Display QDCM, Fingerprint, Graphics/IPA/VPU Firmware, NFC, Thermal, Touch, Vibrator
```text
# Charger (Mi Turbo Charge)
vendor/bin/batterysecret

# Display calibration (Xiaomi Civi 1 120Hz curved OLED panel 42_02_0a)
vendor/etc/qdcm_calib_data_xiaomi_42_02_0a_cmd_mode_dsc_dsi_panel.xml

# Fingerprint (Goodix optical UDFPS — see §3)
vendor/lib64/hw/fingerprint.goodix_fod.so:vendor/lib64/hw/fingerprint.goodix_fod.default.so;FIX_SONAME
vendor/lib64/libgf_hal.so

# Graphics firmware (Adreno 642L uses a660_* on SM7325)
vendor/firmware/a660_gmu.bin
vendor/firmware/a660_sqe.fw
vendor/firmware/a660_zap.b00
vendor/firmware/a660_zap.b01
vendor/firmware/a660_zap.b02
vendor/firmware/a660_zap.elf
vendor/firmware/a660_zap.mdt

# IPA firmware (Yupik SM7325)
vendor/etc/init/ipa_fws.rc
vendor/firmware/yupik_ipa_fws.b00
vendor/firmware/yupik_ipa_fws.b01
vendor/firmware/yupik_ipa_fws.b02
vendor/firmware/yupik_ipa_fws.b03
vendor/firmware/yupik_ipa_fws.b04
vendor/firmware/yupik_ipa_fws.elf
vendor/firmware/yupik_ipa_fws.mdt

# Media (VPU firmware — SM7325 uses vpu20_1v, identical to lisa)
vendor/firmware/vpu20_1v.b00
vendor/firmware/vpu20_1v.b01
vendor/firmware/vpu20_1v.b02
vendor/firmware/vpu20_1v.b03
vendor/firmware/vpu20_1v.b04
vendor/firmware/vpu20_1v.b05
vendor/firmware/vpu20_1v.b06
vendor/firmware/vpu20_1v.b07
vendor/firmware/vpu20_1v.b08
vendor/firmware/vpu20_1v.b09
vendor/firmware/vpu20_1v.b10
vendor/firmware/vpu20_1v.b11
vendor/firmware/vpu20_1v.b12
vendor/firmware/vpu20_1v.b13
vendor/firmware/vpu20_1v.b14
vendor/firmware/vpu20_1v.b15
vendor/firmware/vpu20_1v.b16
vendor/firmware/vpu20_1v.b17
vendor/firmware/vpu20_1v.b18
vendor/firmware/vpu20_1v.b19
vendor/firmware/vpu20_1v.mbn
vendor/firmware/vpu20_1v.mdt
vendor/firmware/vpu20_1v_unsigned.mbn

# NFC configs (NXP SN100U — HAL & libsn100u_fw.so come from sm8350-common)
vendor/etc/libnfc-nci.conf
vendor/etc/libnfc-nxp.conf
vendor/etc/libnfc-nxp_RF.conf:vendor/libnfc-nxp_RF.conf

# Thermal configs (18 CN stock profiles; no India profiles on mona)
vendor/etc/thermal-4k.conf
vendor/etc/thermal-8k.conf
vendor/etc/thermal-camera.conf
vendor/etc/thermal-chg-only.conf
vendor/etc/thermal-class0.conf
vendor/etc/thermal-engine.conf
vendor/etc/thermal-huanji.conf
vendor/etc/thermal-map.conf
vendor/etc/thermal-mgame.conf
vendor/etc/thermal-navigation.conf
vendor/etc/thermal-nolimits.conf
vendor/etc/thermal-normal.conf
vendor/etc/thermal-phone.conf
vendor/etc/thermal-tgame.conf
vendor/etc/thermal-video.conf
vendor/etc/thermal-videochat.conf
vendor/etc/thermal-youtube.conf
vendor/etc/thermald-devices.conf

# Touchscreen firmware (Synaptics S3908P SPI)
vendor/firmware/s3908p_xiaomi_k9b_spi.img
vendor/firmware/s3908p_xiaomi_k9b_spi.img:vendor_ramdisk/lib/firmware/s3908p_xiaomi_k9b_spi.img

# Vibrator firmware (Awinic AW8622x / AW8624 linear LRA)
vendor/firmware/aw8622x_haptic.bin
vendor/firmware/aw8622x_osc_rtp_24K_5s.bin
vendor/firmware/aw8624_haptic.bin
vendor/firmware/aw8624_rtp.bin
vendor/firmware/osc_rtp_24K_5s.bin

# Wi-Fi (WCN6750 / qca6750 WPSS early-boot trigger; see §4.4 for WCNSS_qcom_cfg.ini)
vendor/etc/init/init.vendor.wlan.rc
```

#### Sensors & SLPI Registry Configs (23 binaries/libs/rc + 48 configs)
```text
# Sensors
vendor/bin/init.qcom.sensors.sh
vendor/bin/sensors.qti
vendor/bin/sscrpcd
vendor/etc/init/init.vendor.sensors.rc
vendor/etc/init/vendor.sensors.qti.rc
vendor/etc/init/vendor.sensors.sscrpcd.rc
vendor/lib64/libnotifyaudiohal.so;FIX_SONAME
vendor/lib64/libsensor_cal_v2.so
vendor/lib64/libsensorcal.so
vendor/lib64/libsensorslog.so
vendor/lib64/libsns_api.so
vendor/lib64/libsns_device_mode_stub.so
vendor/lib64/libsns_fastRPC_util.so
vendor/lib64/libsns_low_lat_stream_stub.so
vendor/lib64/libsns_registry_skel.so
vendor/lib64/libsnsapi.so
vendor/lib64/libsnsdiaglog.so
vendor/lib64/libssc.so
vendor/lib64/libssc_default_listener.so
vendor/lib64/libssccalapi.so
vendor/lib64/libultrasound.so
vendor/lib64/sensors.mius.proximity.so
vendor/lib64/sensors.ssc.so
vendor/lib64/sensors.touch.detect.so

# Sensors Configs (48 mona-exact SLPI registry JSONs — NO sx932x/sx933x/bmp285/vl53l1)
vendor/etc/sensors/calibratedCheck.json
vendor/etc/sensors/config/ak991x_dri_0.json
vendor/etc/sensors/config/lsm6dso_0.json
vendor/etc/sensors/config/sm7350_ak991x_0.json
vendor/etc/sensors/config/sm7350_default_sensors.json
vendor/etc/sensors/config/sm7350_dynamic_sensors.json
vendor/etc/sensors/config/sm7350_icm4x6xa_0.json
vendor/etc/sensors/config/sm7350_irq.json
vendor/etc/sensors/config/sm7350_lsm6dso_0.json
vendor/etc/sensors/config/sm7350_power_0.json
vendor/etc/sensors/config/sm7350_tcs3408.json
vendor/etc/sensors/config/sm7350_tmd3719.json
vendor/etc/sensors/config/sns_amd.json
vendor/etc/sensors/config/sns_amd_sw_disabled.json
vendor/etc/sensors/config/sns_amd_sw_enabled.json
vendor/etc/sensors/config/sns_aod.json
vendor/etc/sensors/config/sns_aont.json
vendor/etc/sensors/config/sns_basic_gestures.json
vendor/etc/sensors/config/sns_bring_to_ear.json
vendor/etc/sensors/config/sns_cm.json
vendor/etc/sensors/config/sns_device_orient.json
vendor/etc/sensors/config/sns_diag_filter.json
vendor/etc/sensors/config/sns_distance_bound.json
vendor/etc/sensors/config/sns_dpc.json
vendor/etc/sensors/config/sns_facing.json
vendor/etc/sensors/config/sns_fmv.json
vendor/etc/sensors/config/sns_geomag_rv.json
vendor/etc/sensors/config/sns_gyro_cal.json
vendor/etc/sensors/config/sns_heart_rate.json
vendor/etc/sensors/config/sns_mag_cal.json
vendor/etc/sensors/config/sns_mag_cal_legacy.json
vendor/etc/sensors/config/sns_multishake.json
vendor/etc/sensors/config/sns_nonui.json
vendor/etc/sensors/config/sns_oem13.json
vendor/etc/sensors/config/sns_pedometer.json
vendor/etc/sensors/config/sns_rmd.json
vendor/etc/sensors/config/sns_rotv.json
vendor/etc/sensors/config/sns_screen_down.json
vendor/etc/sensors/config/sns_smd.json
vendor/etc/sensors/config/sns_tilt.json
vendor/etc/sensors/config/sns_tilt_sw_disabled.json
vendor/etc/sensors/config/sns_tilt_sw_enabled.json
vendor/etc/sensors/config/sns_tilt_to_wake.json
vendor/etc/sensors/config/sns_wrist_pedo.json
vendor/etc/sensors/config/tcs3408.json
vendor/etc/sensors/config/tmd3719.json
vendor/etc/sensors/hals.conf
vendor/etc/sensors/judge_calibrated.json
vendor/etc/sensors/sns_reg_config
```
*Note on ultrasonic proximity*: Stock `mona` `vendor/etc/sensors/hals.conf` loads `sensors.mius.proximity.so` (not `sensors.elliptic@2.0.so`), though `vendor/etc/elliptic_sensor.xml` and `vendor/lib64/sensors.elliptic@2.0.so` also exist in the dump as unused fallbacks. Note `libsns_device_mode_stub.so`, `libsns_fastRPC_util.so`, `libsns_low_lat_stream_stub.so`, `libsns_registry_skel.so`, `libsnsapi.so`, `libsnsdiaglog.so` are in `lisa`'s Camera/Sensors sections — keep them deduplicated cleanly.

#### A/B Firmware Partitions (`device/xiaomi/mona/proprietary-firmware.txt`)
All **17** A/B firmware images are verified present in `<stock-dump>/OS1.0.2.0.TKVCNXM/images/` (exact match to `lisa/proprietary-firmware.txt`):
```text
# All unpinned blobs below are extracted from mona OS1.0.2.0.TKVCNXM
abl.img;AB
aop.img;AB
bluetooth.img;AB
cpucp.img;AB
devcfg.img;AB
dsp.img;AB
featenabler.img;AB
hyp.img;AB
imagefv.img;AB
keymaster.img;AB
modem.img;AB
qupfw.img;AB
shrm.img;AB
tz.img;AB
uefisecapp.img;AB
xbl_config.img;AB
xbl.img;AB
```
*(Set `add_firmware_proprietary_file=True` in `extract-files.py`.)*

---

## 2. Complete ELF Dependency, SONAME, Symbol-Version & `blob_fixup` Audit (Android 17)

### 2.1 Exact Verified `blob_fixups` Table for `device/xiaomi/mona/extract-files.py`

| Target Blob | Fixup Type & Exact Arguments | Binary / File Verification Proof in `OS1.0.2.0.TKVCNXM` |
|---|---|---|
| `vendor/etc/camera/pureShot_parameter.xml` | `.regex_replace(r'=(\d+)>', r'="\1">')` | **23** unquoted numeric XML attrs (e.g. `=100>`, `=200>`) |
| `vendor/etc/camera/pureView_parameter.xml` | `.regex_replace(r'=(\d+)>', r'="\1">')` | **24** unquoted numeric XML attrs (e.g. `=100>`, `=0>`, `=1>`) |
| `vendor/etc/camera/mona_motiontuning.xml` | `.regex_replace('xml=version', 'xml version')` | Line 1 is `<?xml=version="1.0" encoding="UTF-8"?>` |
| `vendor/etc/sensors/hals.conf` | `.add_line_if_missing('sensors.xiaomi.v2.so')` | Stock has `sensors.ssc.so`, `sensors.touch.detect.so`, `sensors.mius.proximity.so`; `sensors.xiaomi.v2.so` required for UDFPS |
| `vendor/lib/hw/audio.primary.mona.so` | `.replace_needed('/vendor/lib/liba2dpoffload.so', '/odm/lib/liba2dpoffload.so')`<br>`.replace_needed('/vendor/lib/libssrec.so', '/odm/lib/libssrec.so')`<br>`.replace_needed('libaudioroute.so', 'libaudioroute-v34.so')` | Verified in `audio.primary.lahaina.so`: 1× `/vendor/lib/liba2dpoffload.so`, 1× `/vendor/lib/libssrec.so`, `DT_NEEDED: libaudioroute.so`; `;FIX_SONAME` updates SONAME from `audio.primary.lahaina.so` |
| `vendor/lib/libaudioroute_ext.so` | `.replace_needed('libaudioroute.so', 'libaudioroute-v34.so')` | `DT_NEEDED: libaudioroute.so` (matches `lisa`/`venus` on `lineage-24.0`) |
| `vendor/lib64/hw/camera.qcom.so` | `.binary_regex_replace(b'\x73\x74\x5F\x6C\x69\x63\x65\x6E\x73\x65\x2E\x6C\x69\x63', b'\x63\x61\x6D\x65\x72\x61\x5F\x63\x6E\x66\x2E\x74\x78\x74')`<br>`.add_needed('libprocessgroup_shim.so')` | Exact 1 match of `st_license.lic` @ file offset **`0xc2fac`** -> `camera_cnf.txt` (from `sm8350-common/configs/camera_cnf.txt`); `UND SetTaskProfiles` |
| `vendor/lib64/hw/camera.xiaomi.so` | `.sig_replace('21 00 80 52 29 07 00 94', '21 00 80 52 1F 20 03 D5')` | Exact 1 match @ **`0x64718`** inside `_Z26RegisterIMiPostProcServicev`: `0x6471c` (`29 07 00 94`) is `bl 0x663c0` -> PLT `_ZN7android8hardware22configureRpcThreadpoolEmb`; replaced with AArch64 `nop` (`1F 20 03 D5`) |
| `vendor/lib64/hw/com.qti.chi.override.so` | `.add_needed('libprocessgroup_shim.so')` | `UND SetTaskProfiles` |
| `vendor/lib64/libTrueSight.so` | `.clear_symbol_version('AHardwareBuffer_allocate')`<br>`.clear_symbol_version('AHardwareBuffer_describe')`<br>`.clear_symbol_version('AHardwareBuffer_isSupported')`<br>`.clear_symbol_version('AHardwareBuffer_lock')`<br>`.clear_symbol_version('AHardwareBuffer_lockPlanes')`<br>`.clear_symbol_version('AHardwareBuffer_release')`<br>`.clear_symbol_version('AHardwareBuffer_unlock')` | **NEW CATCH**: All 7 `AHardwareBuffer_*@LIBNATIVEWINDOW (5)` verified via `readelf --dyn-syms` |
| `vendor/lib64/libalAILDC.so`<br>`vendor/lib64/libalLDC.so`<br>`vendor/lib64/libalhLDC.so` | `.clear_symbol_version('AHardwareBuffer_allocate')`<br>`.clear_symbol_version('AHardwareBuffer_describe')`<br>`.clear_symbol_version('AHardwareBuffer_lock')`<br>`.clear_symbol_version('AHardwareBuffer_release')`<br>`.clear_symbol_version('AHardwareBuffer_unlock')` | All 5 `AHardwareBuffer_*@LIBNATIVEWINDOW (4)` verified on each of the 3 libs |
| `vendor/lib64/libarcsoft_hdrplus_hvx_stub.so` | `.clear_symbol_version('remote_handle_close')`<br>`.clear_symbol_version('remote_handle_invoke')`<br>`.clear_symbol_version('remote_handle_open')`<br>`.clear_symbol_version('remote_register_buf')`<br>`.clear_symbol_version('remote_register_buf_attr')` | All **5** `@SDSPRPC (3)` symbols verified via `readelf --dyn-syms` (`lisa` missed `remote_register_buf` & `remote_register_buf_attr`) |
| `vendor/lib64/libmialgo_pureShot.so` | `.clear_symbol_version('remote_handle64_close')`<br>`.clear_symbol_version('remote_handle64_invoke')`<br>`.clear_symbol_version('remote_handle64_open')`<br>`.clear_symbol_version('remote_register_buf_attr')` | All 4 `@SDSPRPC (3)` symbols verified (`@MIBOCKEH_1.0` stays intact — exported by companion `libmibokeh_mask_dsp.so`) |
| `vendor/lib64/libsensor_cal_v2.so` | `.add_needed('libjsoncpp_shim.so')` | `DT_NEEDED: libjsoncpp.so`, 10 `UND _ZN4Json5Value*` symbols (exact match to `lisa`) |

### 2.2 Required `proprietary-files.txt` Inline Flags (`;FIX_SONAME`, `;MODULE_SUFFIX`, `;DISABLE_CHECKELF`)

| Blob Entry | Flag | Reason (Verified via `readelf -d`) |
|---|---|---|
| `vendor/lib/hw/audio.primary.lahaina.so:vendor/lib/hw/audio.primary.mona.so` | `;FIX_SONAME` | Stock SONAME `audio.primary.lahaina.so` != installed `audio.primary.mona.so` |
| `vendor/lib64/hw/fingerprint.goodix_fod.so:vendor/lib64/hw/fingerprint.goodix_fod.default.so` | `;FIX_SONAME` | Stock SONAME `fingerprint.goodix_fod.so` != `fingerprint.goodix_fod.default.so` required by `hw_get_module_by_class("fingerprint", "goodix_fod")` |
| `vendor/lib64/libmiStereoFactoryRemapLib_v2.so` | `;FIX_SONAME` | Stock SONAME is `libmiStereoFactoryRemapLib.so` (mismatches filename `_v2`) |
| `vendor/lib64/libnotifyaudiohal.so` | `;FIX_SONAME` | Stock SONAME is `libnotifyaudiohal@6.0.so` (matches `lisa`/`venus`) |
| `vendor/lib/liba2dpoffload.so:odm/lib/liba2dpoffload.so` | `;MODULE_SUFFIX=_odm` | Avoids Soong module name collision with AOSP `liba2dpoffload` |
| `vendor/lib/libssrec.so:odm/lib/libssrec.so` | `;MODULE_SUFFIX=_odm` | Avoids Soong module name collision with AOSP `libssrec` |
| `vendor/lib/libvideoNS.so` | `;DISABLE_CHECKELF` | Missing SONAME + ARM32 EABI intrinsics (`__aeabi_dcmpeq`, `__aeabi_dcmpge`) moved across LLVM/compiler-rt namespaces (identical to `lisa`) |

*Watchlist (Check during first Android 17 `extract-files.py` / `checkelf` build)*:
- **`vendor/lib64/libqllengine.so`**: On `venus` (`OS2.0.3.0`), `libqllengine.so` required `;DISABLE_CHECKELF` due to `__fixunstfdi`; on `mona` (`OS1.0.2.0`), `libqllengine.so` had no `__fixunstfdi` flagged in our scan, but keep on watchlist if Soong `check_elf_files` flags a compiler-rt intrinsic.
- **`libtinyxml2.so` (`camera.qcom.so`, `libaudiocloudctrl.so`)**: `sm8350-common` already patches `libdpps.so` & `libsnapdragoncolor-manager.so` to `libtinyxml2-v34.so` on `lineage-24.0`, while `lisa`/`venus` did **not** need `libtinyxml2-v34.so` on `camera.qcom.so` or `libaudiocloudctrl.so` (only calling ABI-stable symbols). If Android 17 `libtinyxml2.so` breaks any symbol in `camera.qcom.so` or `libaudiocloudctrl.so` during build-time `checkelf`, add `.replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so')`.
- **`libaudioroute.so` on `odm/lib/liba2dpoffload.so`, `odm/lib/libssrec.so`, `vendor/lib/libhdmipassthru.so`**: All three have `DT_NEEDED: libaudioroute.so`, though `lisa`/`venus` only replace it on `audio.primary.*.so` and `libaudioroute_ext.so`. If Android 17 `checkelf` flags missing `mixer_ctl_*` / `audio_route_*` symbols on those three, extend the `libaudioroute-v34.so` fixup to them as well.

### 2.3 External `DT_NEEDED` Disposition Table Across All 386 Audited `mona` ELFs

| External `DT_NEEDED` Library | `mona` Consumer Count / Examples | Android 17 (`lineage-24.0`) Resolution |
|---|---|---|
| `libhidltransport.so` | 85 64-bit, 13 32-bit (`camera.qcom.so`, `fingerprint.goodix_fod.so`, `libgf_hal.so`, `sensors.mius.proximity.so`, etc.) | Provided by `hardware/qcom-caf/sm8350` / AOSP `libhidltransport` compatibility stub / `extract-utils` default `lib_fixups` (handled identically to `lisa`/`venus` on `lineage-24.0`) |
| `libhwbinder.so` | 2 64-bit (`fingerprint.goodix_fod.so`, `libgf_hal.so`) | Same as above (built by `libhwbinder` compat module / `lib_fixups`) |
| `libion.so` (`ion_open`, `ion_alloc_fd`) | 11 64-bit (`libgf_hal.so`, `libmialgoengine.so`, `libmialgo_pureShot.so`, `libpreview_beautyeffect.so`, etc.) | Provided by `sm8350-common`: `$(call soong_config_set_bool,libion,legacy_impl,true)` + `device/lineage/sepolicy/libion/sepolicy.mk` |
| `vendor.xiaomi.hardware.fx.tunnel@1.0.so` | 1 64-bit (`libgf_hal.so`) | Built from source by `hardware/xiaomi/interfaces/xiaomi/hardware/fx/tunnel/1.0/Android.bp` (`namespace_imports` includes `'hardware/xiaomi'`) |
| `libprocessgroup.so` (`SetTaskProfiles`) | 2 64-bit (`camera.qcom.so`, `com.qti.chi.override.so`) | Shimmed via `.add_needed('libprocessgroup_shim.so')` (from `hardware/xiaomi` / `sm8350-common`) |
| `libjsoncpp.so` (`Json::Value::*`) | 1 64-bit (`libsensor_cal_v2.so`) | Shimmed via `.add_needed('libjsoncpp_shim.so')` |
| `libprotobuf-cpp-full-3.9.1.so` / `libprotobuf-cpp-lite-3.9.1.so` | `camera.qcom.so` (full); 6 sensor libs (`libssc.so`, `sensors.ssc.so`, `sensors.qti`, etc. — lite) | Provided by `vendor/lineage` / `sm8350-common` `libprotobuf-cpp-*-3.9.1-vendorcompat` via `extract-utils` default `lib_fixups` |
| `vendor.display.config@1.0..2.0.so`, `vendor.qti.hardware.display.*`, `libgralloc.qti.so`, `libqdMetaData.so` | `camera.qcom.so`, `camera.xiaomi.so`, `com.qti.chi.override.so`, `libcom.xiaomi.grallocutils.so` | Built from source by `hardware/qcom-caf/sm8350` & `vendor/qcom/opensource/display` (`namespace_imports`) |
| `android.frameworks.sensorservice@1.0.so`, `android.hardware.power@1.2.so`, `android.hardware.audio@6.0.so` | `camera.qcom.so`, `libsensor_cal_v2.so`, `audio.primary.mona.so`, `libnotifyaudiohal.so` | Built from source by AOSP / LineageOS HIDL vendor libraries (`sm8350-common` uses `android.hardware.audio@6.0-impl` on `lineage-24.0` — note `crdroid_device_xiaomi_sm8350-common` used `@7.0-impl`; see §4.6!) |
| `libui.so` | 7 64-bit camera libs | Provided by AOSP VNDK / vendor `libui` |
| `libcdsprpc.so`, `libadsprpc.so`, `libQSEEComAPI.so`, `libqmi_*`, `libSNPE.so`, `libOpenCL.so` | Camera, Goodix FP, Sensors | Extracted in `vendor/xiaomi/sm8350-common` (`namespace_imports` includes `'vendor/xiaomi/sm8350-common'`) |
| Companion Xiaomi versioned symbols (`@MIBOCKEH_1.0`, `@MIHDR_1.0`, `@MISN_1.0`, `@VERS_1.0`, `@VERSION`, `@LIBSYNC`) | Camera algo libs + `libomp.so` + `libsync.so` | Satisfied internally by extracted companion `.so` files & LLNDK `libsync.so` — **do NOT clear** |

### 2.4 Ready-to-Use `device/xiaomi/mona/extract-files.py` Template

```python
#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.fixups_lib import (
    lib_fixups,
    lib_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'hardware/qcom-caf/sm8350',
    'hardware/xiaomi',
    'vendor/qcom/opensource/display',
    'vendor/xiaomi/sm8350-common',
]

lib_fixups: lib_fixups_user_type = {
    **lib_fixups,
}

blob_fixups: blob_fixups_user_type = {
    ('vendor/etc/camera/pureShot_parameter.xml', 'vendor/etc/camera/pureView_parameter.xml'): blob_fixup()
        .regex_replace(r'=(\d+)>', r'="\1">'),
    'vendor/etc/camera/mona_motiontuning.xml': blob_fixup()
        .regex_replace('xml=version', 'xml version'),
    'vendor/etc/sensors/hals.conf': blob_fixup()
        .add_line_if_missing('sensors.xiaomi.v2.so'),
    'vendor/lib/hw/audio.primary.mona.so': blob_fixup()
        .replace_needed('/vendor/lib/liba2dpoffload.so', '/odm/lib/liba2dpoffload.so')
        .replace_needed('/vendor/lib/libssrec.so', '/odm/lib/libssrec.so')
        .replace_needed('libaudioroute.so', 'libaudioroute-v34.so'),
    'vendor/lib/libaudioroute_ext.so': blob_fixup()
        .replace_needed('libaudioroute.so', 'libaudioroute-v34.so'),
    'vendor/lib64/hw/camera.qcom.so': blob_fixup()
        .binary_regex_replace(b'\x73\x74\x5F\x6C\x69\x63\x65\x6E\x73\x65\x2E\x6C\x69\x63', b'\x63\x61\x6D\x65\x72\x61\x5F\x63\x6E\x66\x2E\x74\x78\x74')
        .add_needed('libprocessgroup_shim.so'),
    'vendor/lib64/hw/camera.xiaomi.so': blob_fixup()
        .sig_replace('21 00 80 52 29 07 00 94', '21 00 80 52 1F 20 03 D5'),
    'vendor/lib64/hw/com.qti.chi.override.so': blob_fixup()
        .add_needed('libprocessgroup_shim.so'),
    'vendor/lib64/libTrueSight.so': blob_fixup()
        .clear_symbol_version('AHardwareBuffer_allocate')
        .clear_symbol_version('AHardwareBuffer_describe')
        .clear_symbol_version('AHardwareBuffer_isSupported')
        .clear_symbol_version('AHardwareBuffer_lock')
        .clear_symbol_version('AHardwareBuffer_lockPlanes')
        .clear_symbol_version('AHardwareBuffer_release')
        .clear_symbol_version('AHardwareBuffer_unlock'),
    ('vendor/lib64/libalAILDC.so', 'vendor/lib64/libalLDC.so', 'vendor/lib64/libalhLDC.so'): blob_fixup()
        .clear_symbol_version('AHardwareBuffer_allocate')
        .clear_symbol_version('AHardwareBuffer_describe')
        .clear_symbol_version('AHardwareBuffer_lock')
        .clear_symbol_version('AHardwareBuffer_release')
        .clear_symbol_version('AHardwareBuffer_unlock'),
    'vendor/lib64/libarcsoft_hdrplus_hvx_stub.so': blob_fixup()
        .clear_symbol_version('remote_handle_close')
        .clear_symbol_version('remote_handle_invoke')
        .clear_symbol_version('remote_handle_open')
        .clear_symbol_version('remote_register_buf')
        .clear_symbol_version('remote_register_buf_attr'),
    'vendor/lib64/libmialgo_pureShot.so': blob_fixup()
        .clear_symbol_version('remote_handle64_close')
        .clear_symbol_version('remote_handle64_invoke')
        .clear_symbol_version('remote_handle64_open')
        .clear_symbol_version('remote_register_buf_attr'),
    'vendor/lib64/libsensor_cal_v2.so': blob_fixup()
        .add_needed('libjsoncpp_shim.so'),
}  # fmt: skip

module = ExtractUtilsModule(
    'mona',
    'xiaomi',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    add_firmware_proprietary_file=True,
)

if __name__ == '__main__':
    utils = ExtractUtils.device_with_common(
        module, 'sm8350-common', module.vendor
    )
    utils.run()
```

---

## 3. Goodix Optical UDFPS Binary ABI Compatibility Verdict

**VERDICT: PASS (100% Binary-Compatible with `LineageOS/android_hardware_xiaomi` AIDL V4 `android.hardware.biometrics.fingerprint-service.xiaomi` on `lineage-24.0` + `sm8350-common/udfps/UdfpsHandler.cpp`)**

### 3.1 `HMI` (`hw_module_t`) & Module Discovery Proof
- `hardware/xiaomi/aidl/fingerprint/Fingerprint.cpp` scans `kModules[]` (including `"goodix_fod"`) via `hw_get_module_by_class("fingerprint", "goodix_fod", &hw_mdl)`, which searches for **`/vendor/lib64/hw/fingerprint.goodix_fod.default.so`**.
- Direct inspection of `mona`'s `vendor/lib64/hw/fingerprint.goodix_fod.so` at `HMI` (`vaddr 0x5440`, 248 B, RELR-relocated):
  - `tag = 0x48574d54` (`HARDWARE_MODULE_TAG` = `"HWMT"`)
  - `module_api_version = 0x0201` (`FINGERPRINT_MODULE_API_VERSION_2_1` — exact match to `kVersion = HARDWARE_MODULE_API_VERSION(2, 1)`)
  - `hal_api_version = 0x0100`
  - `id = "fingerprint"`, `name = "Goodix Fingerprint HAL"`, `author = "Goodix"`
  - `methods = 0x5438` -> `methods->open = 0x25d0`

### 3.2 `fingerprint_device_t` Vtable Layout Proof (AArch64 Disassembly of `0x25d0`)
`fingerprint_open` (`0x25d0`) allocates `0xf0` (240) bytes via `malloc(0xf0)` and initializes every function pointer at the **exact** offsets defined in `hardware/xiaomi/fingerprint/include/fingerprint.h` (**V1 ABI**, *not* `fingerprint-v2.h`):

| Struct Offset | `fingerprint.h` (V1) Field | `mona` Function Addr | Verified Goodix Core Call / Behavior |
|---|---|---|---|
| `0x00..0x6f` | `hw_device_t common` header | — | `tag`, `version`, `module` (`[x0, #0x8]`), `reserved[12]` |
| `0x70` | `common.close` | `0x27dc` | `free()`, `__android_log_print` |
| `0x78` | `notify` | `NULL` (`xzr`) | Initialized NULL until `set_notify` |
| `0x80` | `set_notify` | `0x2ac0` | `goodix::FingerprintCore::setNotify(...)` |
| `0x88` | `pre_enroll` | `0x2884` | `goodix::FingerprintCore::preEnroll()` |
| `0x90` | `enroll` | `0x2894` | `HalContextExt::getHeartRateFlag()` + `FingerprintCore::enroll(...)` |
| `0x98` | `post_enroll` | `0x2948` | `goodix::FingerprintCore::postEnroll()` |
| `0xa0` | `get_authenticator_id` | `0x2958` | `goodix::FingerprintCore::getAuthenticatorId()` |
| `0xa8` | `cancel` | `0x2968` | `goodix::FingerprintCore::cancel(bool)` |
| `0xb0` | `enumerate` | `0x2c74` | `goodix::FingerprintCore::enumerate()` |
| `0xb8` | `remove` | `0x297c` | `goodix::FingerprintCore::remove(uint32_t, uint32_t)` + `usleep` + `sync` |
| `0xc0` | `set_active_group` | `0x29b8` | `goodix::FingerprintCore::setActiveGroup(...)` + `usleep` + `sync` |
| `0xc8` | `authenticate` | `0x2a1c` | `HalContextExt::getHeartRateFlag()` + `FingerprintCore::authenticate(...)` |
| **`0xd0`** | **`extCmd`** | **`0x2ae8`** | **Exact match to `UdfpsHandler.cpp`!** Disassembly shows `cmp` against command IDs **`10` (`COMMAND_NIT`)**, **`1` (`COMMAND_FOD_PRESS_STATUS`)**, and `6` (heart-rate/aux). |
| `0xd8..0xef` | `reserved[3]` | — | `fingerprint.h` declares `reserved[4]` (`0xf8`), never read by `hardware/xiaomi` — safe. |

### 3.3 Runtime Dependencies & Kernel Interface Checklist for Goodix UDFPS
1. **`libgf_hal.so` `DT_NEEDED`**: `libhidlbase.so`, `libhwbinder.so`, `libhidltransport.so`, `libutils.so`, `libcutils.so`, `liblog.so`, `libhardware.so`, **`libion.so`**, `libQSEEComAPI.so`, **`vendor.xiaomi.hardware.fx.tunnel@1.0.so`**.
   - `libgf_hal.so` internally implements and registers `vendor.xiaomi.hardware.fx.tunnel@1.0::IMiFxTunnel` (`MiFxTunnel::getInstance`) when `goodix::registerService(HalContext*)` runs!
   - `TARGET_HAS_UDFPS := true` in `device/xiaomi/mona/device.mk` activates `sm8350-common`'s `manifest_udfps.xml` (declares `IMiFxTunnel/default`), `libudfpshandler`, `sensors.xiaomi.v2`, `ro.vendor.sensors.xiaomi.udfps=true`, and `FrameworkOverlayUDFPS`.
2. **Device / Sysfs Nodes Used at Runtime**:
   - `/dev/goodix_fp` (`0660 system system` — already in `sm8350-common/rootdir/etc/ueventd.rc`)
   - `/dev/ion` (via legacy `libion` — already enabled in `sm8350-common/common.mk` + `sepolicy.mk`)
   - `/data/vendor/goodix`, `/mnt/vendor/persist/goodix`, `/data/vendor/fpdump` (already created in `sm8350-common/rootdir/etc/init.target.rc`)
   - `UdfpsHandler.cpp` drives `/sys/devices/platform/soc/soc:qcom,dsi-display-primary/{fod_hbm,fod_ui}` and `/sys/devices/virtual/touch/tp_dev/fod_status` (already `chown system system` in `sm8350-common/rootdir/etc/init.target.rc`), plus `goodix_fod.so`/`libgf_hal.so` optionally write `/sys/class/drm/card0-DSI-1/disp_param` and `/sys/class/mi_display/disp-DSI-0/disp_param` (kernel `msm_drm` + `synaptics_tcm`/`xiaomi_touch` must preserve `fod_hbm`, `fod_ui`, `fod_status`, and `disp_param`).
3. **Important crDroid vs LineageOS `UdfpsHandler.cpp` Note**:
   - `los_device_xiaomi_sm8350-common/udfps/UdfpsHandler.cpp` sends **both** `COMMAND_NIT (10)` and `COMMAND_FOD_PRESS_STATUS (1)` (verified supported by `mona`'s `0x2ae8` `extCmd`). `crdroid_device_xiaomi_sm8350-common` had an older `UdfpsHandler.cpp` diff removing `COMMAND_FOD_PRESS_STATUS` — prefer the `los_device_xiaomi_sm8350-common` (`lineage-24.0`) `UdfpsHandler.cpp`!

---

## 4. Stock `fstab`, `init.*.rc`, `ueventd.rc`, Props, Wi-Fi & VINTF Deltas Over `sm8350-common`

### 4.1 `BoardConfig.mk` & Partition Layout Deltas (Critical!)

| Variable | `lisa` / `venus` (`sm8350-common`) | **`mona` Verified Stock Value** | Notes |
|---|---|---|---|
| `TARGET_BOOTLOADER_BOARD_NAME` | `lisa` / `venus` | `mona` | Matches DTBO & bootloader |
| `BOARD_DTBOIMG_PARTITION_SIZE` | `25165824` (24 MiB) | **`16777216` (16 MiB)** | **CRITICAL**: Stock `dtbo.img` is exactly 16,777,216 B! Using 24 MiB will fail to flash/overflow `dtbo_a/b`! |
| `BOARD_BOOTIMAGE_PARTITION_SIZE` | `201326592` (192 MiB, in common) | `201326592` (192 MiB) | Matches `sm8350-common` |
| `BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE` | `100663296` (96 MiB, in common) | `100663296` (96 MiB) | Matches `sm8350-common` |
| `TARGET_SCREEN_DENSITY` | `440` (common default) / `560` (`venus`) | `440` | 1080×2400 @ 6.55" OLED (`ro.sf.lcd_density=440` in stock) |
| `BOOT_KERNEL_MODULES` (`vendor_boot` / recovery) | `goodix_core.ko` (`lisa`) / `fts_touch_spi.ko` (`venus`) | Replace touch module with **`synaptics_tcm_core_module.ko`**, **`synaptics_tcm_spi.ko`**, **`synaptics_tcm_device.ko`**, **`synaptics_tcm_reflash.ko`** + `xiaomi_touch.ko`, `msm_drm.ko`, `hwid.ko`, `mmhardware_sysfs_dlkm.ko`, `adsp_loader_dlkm.ko`, `apr_dlkm.ko`, `q6_notifier_dlkm.ko`, `q6_pdr_dlkm.ko`, `snd_event_dlkm.ko`, `qti_battery_charger_main.ko` (note stock `vendor` calls it `qti_battery_charger_main_k8.ko`; match compiled kernel module name) | Required for touchscreen in Lineage/crDroid recovery |
| `vendor/lib/modules` (`mona`-specific loadables) | `tfa98xx_dlkm.ko` (`lisa`) | **`aw882xx_dlkm.ko`**, **`goodix_fod.ko`**, **`synaptics_tcm_*.ko`**, **`qca_cld3_qca6750.ko`**, **`icnss2.ko`**, **`ir-spi.ko`**, **`nfc_i2c.ko`**, **`leds-qti-flash.ko`**, **`us_prox_iio.ko`** | Ensure kernel config builds these (built-in or DLKM matching `vendor_modprobe.sh`) |

### 4.2 `fstab` Delta (`ramdisk_vboot/first_stage_ramdisk/fstab.default` vs `sm8350-common/rootdir/etc/fstab.qcom`)
- Stock `mona` has **no** `/vendor/etc/fstab.qcom` — it uses `vendor_boot` `first_stage_ramdisk/fstab.default` (which `sm8350-common` installs from `rootdir/etc/fstab.qcom` to `vendor/etc/fstab.default`, `vendor_ramdisk/first_stage_ramdisk/fstab.default`, and recovery).
- **Verified parity**: `metadata` (`ext4`), `persist` (`ext4`), `userdata` (`f2fs`, `inlinecrypt`, `aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`, `sysfs_path=/sys/devices/platform/soc/1d84000.ufshc`), `modem` (`/vendor/firmware_mnt`), `dsp` (`/vendor/dsp`), `bluetooth` (`/vendor/bt_firmware`), `misc`, `usbotg`, `sdcard1` all match `sm8350-common/rootdir/etc/fstab.qcom`.
- **Two minor deltas**:
  1. Stock mounts `mi_ext` + 16 overlayfs entries (MIUI-only — omit for crDroid).
  2. `los_device_xiaomi_sm8350-common/rootdir/etc/fstab.qcom` has a `vendor_dlkm` logical entry (matching `BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST` in `BoardConfigCommon.mk`) whereas stock `mona` does not have a `vendor_dlkm` partition (`crdroid_device_xiaomi_sm8350-common` dropped `vendor_dlkm`). Because `sm8350-common` formats super dynamic partitions on clean flash, `sm8350-common`'s `fstab.qcom` works as-is without a `mona` fstab override (note: if keeping `erofs` vs `ext4`, `sm8350-common` builds `ext4` images by default).

### 4.3 `init.mona.rc` & `ueventd.mona.rc` Deltas Over `sm8350-common`

Most nodes (`/dev/goodix_fp`, `/dev/nq-nci`, `/dev/elliptic0`, `/dev/elliptic1`, `/dev/ir_spi`, `/dev/xiaomi-touch`, `/mnt/vendor/persist/{haptics,audio,goodix}`, `/data/vendor/{goodix,fpdump,nfc,thermal}`, `fod_hbm`, `fod_ui`, `fod_status`, `init.batterysecret.rc`, `init.mi_thermald.rc`, `flash_state`) are **already handled** by `sm8350-common/rootdir/etc/{init.target.rc,ueventd.rc}`.

**Add `device/xiaomi/mona/rootdir/etc/init.mona.rc`** (installed to `$(TARGET_COPY_OUT_VENDOR)/etc/init/init.mona.rc`) for the verified `mona`-specific gaps:

```rc
# Awinic AW882xx Smart PA calibration & SPI/audio nodes
on fs
    chown system system /sys/class/smartpa/re25_calib
    chmod 0666 /sys/class/smartpa/re25_calib

# Awinic AW8622x / AW8624 linear haptics calibration (DTBO: awinic_haptic@58)
    chown system system /sys/bus/i2c/drivers/awinic_haptic/3-005a/f0_save
    chown system system /sys/bus/i2c/drivers/awinic_haptic/3-005a/osc_save
    chown system system /sys/bus/i2c/drivers/awinic_haptic/3-005a/custom_wave
    chmod 0666 /sys/bus/i2c/drivers/awinic_haptic/3-005a/custom_wave
    chown system system /sys/bus/i2c/drivers/awinic_haptic/3-005a/f0_value
    chmod 0666 /sys/bus/i2c/drivers/awinic_haptic/3-005a/f0_value
    chown system system /sys/bus/i2c/drivers/awinic_haptic/3-005a/nv_flag
    chmod 0666 /sys/bus/i2c/drivers/awinic_haptic/3-005a/nv_flag

# Camera memcg hierarchy (from stock / miku_mojin init.xiaomi.camera.rc — optional if kernel enables MEMCG)
# WCN6750 WPSS boot (already covered if extracting vendor/etc/init/init.vendor.wlan.rc:
#   on early-boot -> write /sys/kernel/icnss/wpss_boot 1)

# Front dual soft-light flash (led:torch_1, led:torch_2, led:switch_1) & rear flash (led:torch_0, led:switch_0)
on post-fs-data
    chown system system /sys/class/leds/led:torch_0/brightness
    chown system system /sys/class/leds/led:torch_1/brightness
    chown system system /sys/class/leds/led:torch_2/brightness
    chown system system /sys/class/leds/led:flash_0/brightness
    chown system system /sys/class/leds/led:flash_1/brightness
    chown system system /sys/class/leds/led:flash_2/brightness
    chown system system /sys/class/leds/led:switch_0/brightness
    chown system system /sys/class/leds/led:switch_1/brightness
    chown system system /sys/class/leds/led:switch_0/trigger
    chown system system /sys/class/leds/led:switch_1/trigger
    chown system system /sys/class/leds/flashlight/brightness
    chmod 0664 /sys/class/leds/led:torch_0/brightness
    chmod 0664 /sys/class/leds/led:torch_1/brightness
    chmod 0664 /sys/class/leds/led:torch_2/brightness
    chmod 0664 /sys/class/leds/led:flash_0/brightness
    chmod 0664 /sys/class/leds/led:flash_1/brightness
    chmod 0664 /sys/class/leds/led:flash_2/brightness
    chmod 0664 /sys/class/leds/led:switch_0/brightness
    chmod 0664 /sys/class/leds/led:switch_1/brightness
    chmod 0664 /sys/class/leds/led:switch_0/trigger
    chmod 0664 /sys/class/leds/led:switch_1/trigger
    chmod 0664 /sys/class/leds/flashlight/brightness

# Xiaomi display feature nodes (used by libgf_hal.so & panel calibration)
on boot
    chown system system /sys/class/mi_display/disp-DSI-0/disp_param
    chmod 0664 /sys/class/mi_display/disp-DSI-0/disp_param
    chown system system /sys/class/mi_display/disp-DSI-0/panel_info
    chmod 0444 /sys/class/mi_display/disp-DSI-0/panel_info
    chown system system /sys/class/mi_display/disp-DSI-0/wp_info
    chmod 0444 /sys/class/mi_display/disp-DSI-0/wp_info
    chown system system /sys/class/mi_display/disp-DSI-0/dynamic_fps
    chmod 0444 /sys/class/mi_display/disp-DSI-0/dynamic_fps
    chown system system /sys/class/mi_display/disp-DSI-0/doze_brightness
    chmod 0664 /sys/class/mi_display/disp-DSI-0/doze_brightness
    chown system system /sys/class/mi_display/disp-DSI-0/brightness_clone
    chmod 0664 /sys/class/mi_display/disp-DSI-0/brightness_clone
```

**`ueventd` delta** (stock `vendor/ueventd.rc` nodes missing from `los_device_xiaomi_sm8350-common/rootdir/etc/ueventd.rc` — note `crdroid_device_xiaomi_sm8350-common` already adds `led:torch_1` & `led:switch_1`, but `mona` has **dual** front soft-light LEDs `torch_1` + `torch_2` + `switch_1`!):
- `/dev/mi_display/* 0666 root graphics` (with `subsystem mi_display` / `dirname /dev/mi_display`)
- `/sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/spmi0-02/c440000.qcom,spmi:qcom,pm8350c@2:qcom,flash_led@ee00/leds/led:torch_1 brightness 0660 cameraserver camera`
- `/sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/spmi0-02/c440000.qcom,spmi:qcom,pm8350c@2:qcom,flash_led@ee00/leds/led:torch_2 brightness 0660 cameraserver camera`
- `/sys/devices/platform/soc/c440000.qcom,spmi/spmi-0/spmi0-02/c440000.qcom,spmi:qcom,pm8350c@2:qcom,flash_led@ee00/leds/led:switch_1 brightness 0660 cameraserver camera`
- **SELinux**: Ensure `hal_camera_default` / `cameraserver` has `sysfs_leds` write access for `led:torch_{1,2}` & `led:switch_1`, and `hal_audio_default` has access to `/sys/class/smartpa/re25_calib` (`sysfs_smartpa` / `aw882xx` calibration).

### 4.4 Wi-Fi (`WCN6750` / `qca6750`) & Media Config Deltas

1. **Wi-Fi (`qca6750`)**:
   - `sm8350-common` only installs `vendor/etc/wifi/WCNSS_qcom_cfg.ini` and symlink `vendor/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini -> /vendor/etc/wifi/WCNSS_qcom_cfg.ini` (for `qca_cld3_wlan.ko`).
   - Stock `mona` loads **`qca_cld3_qca6750.ko`** (on `icnss2.ko`), which looks up:
     - `vendor/firmware/wlan/qca_cld/qca6750/WCNSS_qcom_cfg.ini -> /vendor/etc/wifi/qca6750/WCNSS_qcom_cfg.ini` (15,913 B stock file has `gEnableImps=1`, `gEnableBmps=1`, `hostArpOffload=1`, `hostNSOffload=1`, `gEnableApProt=1`, `gEnableApUapsd=1` vs `sm8350-common`'s minimal `WCNSS_qcom_cfg.ini`)
     - `vendor/firmware/wlan/qca_cld/qca6750/wlan_mac.bin -> /mnt/vendor/persist/wlan/wlan_mac.bin`
   - **Action**: If `kernel_los_sm8350` compiles Wi-Fi as `qca_cld3_qca6750.ko` (matching stock/`mojin`), install `qca6750/WCNSS_qcom_cfg.ini`, `init.vendor.wlan.rc` (`write /sys/kernel/icnss/wpss_boot 1`), and `install_symlink` targets for `firmware/wlan/qca_cld/qca6750/{WCNSS_qcom_cfg.ini,wlan_mac.bin}` in `device/xiaomi/mona/Android.bp`! (If `kernel_los_sm8350` uses unified `wlan.ko` like `lisa` with `icnss` auto-boot, still keep `init.vendor.wlan.rc` — writing `/sys/kernel/icnss/wpss_boot` is idempotent — and verify which path `qca_cld3` reads in kernel defconfig.)
2. **Media (`media_yupik_v1`)**:
   - `sm8350-common` **already** includes `media/yupik/media_{codecs,codecs_performance,profiles}_yupik_v1.xml`, `media/init.qti.media.sh` (handles Yupik SoC IDs `475|515` -> `_yupik_v1` & `vendor.netflix.bsp_rev=Q7325-SPY-33758-1`), and `vendor/etc/media_yupik_v1/video_system_specs.json` (with `max_retry_alloc_output_timeout: 0` fixup). **No `mona` media override required!**
   - Keep `PRODUCT_SYSTEM_PROPERTIES += vendor.sys.video.disable.ubwc=1` in `device.mk` (same as `lisa/device.mk` line 43 for SM7325 WFD stability).

### 4.5 Device `vendor.prop`, `odm.prop` & `sku/CN_build.prop` Deltas

#### `device/xiaomi/mona/vendor.prop`
```properties
# Audio hardware (triggers loading vendor/lib/hw/audio.primary.mona.so)
ro.hardware.audio.primary=mona
ro.vendor.audio.spk.stereo=true
vendor.audio.spkcal.copy.inhal=true
vendor.audio.spkr_prot.tx.sampling_rate=48000

# Bluetooth
bluetooth.device.default_name=Xiaomi Civi

# Display
ro.vendor.display.type=oled
ro.vendor.display.default_fps=60

# Fingerprint (Goodix optical UDFPS — verified from stock X_Y=437,2044 size=206,206)
persist.vendor.fingerprint.type=udfps_optical
persist.vendor.fingerprint.sensor_location=540|2147|103

# USB
vendor.usb.product_string=Xiaomi Civi

# Wi-Fi (WCN6750)
ro.hardware.wlan.chip=6750
ro.hardware.wlan.dbs=0
ro.hardware.wlan.mimo=1
ro.hardware.wlan.vendor=qcom
```
*(Optional audio soundtrigger tuning from stock `vendor/build.prop` vs `sm8350-common`: `ro.vendor.audio.soundtrigger.xanzn.gmm.level=50`, `xatx.cnn.level=42`, `xatx.gmm.level=54`, `xatx.gmm.user.level=54`.)*

#### `device/xiaomi/mona/odm.prop` & `device/xiaomi/mona/sku/CN_build.prop`
`mona` is a **China-only** SKU (`ro.boot.hwc=CN`, `2109119BC`), so `odm.prop` can either directly declare the model/device or use the `lisa`/`venus` SKU pattern:
```properties
# odm.prop
ro.product.property_source_order=odm,product,vendor,system_ext,system
import /odm/etc/${ro.boot.hwc}_build.prop
```
```properties
# sku/CN_build.prop
bluetooth.device.default_name=Xiaomi Civi
ro.product.odm.brand=Xiaomi
ro.product.odm.cert=2109119BC
ro.product.odm.device=mona
ro.product.odm.manufacturer=Xiaomi
ro.product.odm.marketname=Xiaomi Civi
ro.product.odm.model=2109119BC
ro.product.odm.name=mona
vendor.usb.product_string=Xiaomi Civi
```

### 4.6 VINTF Manifest Delta (`stock mona` vs `sm8350-common`)

- **`device/xiaomi/mona` requires ZERO custom device VINTF manifest XML files** on top of `los_device_xiaomi_sm8350-common` (`lineage-24.0`), because:
  1. `manifest_lahaina.xml` (in `sm8350-common`, `target-level="7"`) already covers RIL (`IRadio@1.5` slot1/slot2), IMS, Data, `ICameraProvider@2.4`, `IPostProcService@1.0`, `IKeymasterDevice@4.1`, `IGatekeeper@1.0`, `ISecureElement@1.2` (`eSE1`/`SIM1`/`SIM2`), Bluetooth, Audio `@6.0`, SoundTrigger `@2.3`, Perf `@2.2`, Soter, Alarm, etc.
  2. `manifest_xiaomi.xml` (in `sm8350-common`) already declares `vendor.xiaomi.hardware.campostproc@1.0::IMiPostProcService/default`.
  3. `manifest_udfps.xml` (enabled automatically by `TARGET_HAS_UDFPS := true`) already declares `vendor.xiaomi.hardware.fx.tunnel@1.0::IMiFxTunnel/default`.
  4. All open-source AIDL/HIDL services built by `sm8350-common` (`android.hardware.biometrics.fingerprint-service.xiaomi` AIDL V4, `android.hardware.nfc-service.nxp` AIDL, `android.hardware.sensors-service.xiaomi-multihal` AIDL, `android.hardware.ir-service.lineage` AIDL, `vendor.qti.hardware.vibrator.service` AIDL, `android.hardware.lights-service.qti` AIDL, `android.hardware.power-service.lineage-libperfmgr` AIDL, `android.hardware.thermal`, `android.hardware.health`, `android.hardware.boot`, `android.hardware.usb`, `android.hardware.wifi`) register their own VINTF fragments automatically.
  5. Unlike `venus`, `mona` does **NOT** ship `vendor.xiaomi.hardware.cameraperf@1.0-impl.so`, so do **NOT** copy `venus/hidl/manifest.xml`.
- **Important Audio HAL Version Warning (`los_sm8350-common` vs `crdroid_sm8350-common`)**:
  - `los_device_xiaomi_sm8350-common` (`lineage-24.0`) uses **`android.hardware.audio@6.0-impl`** (which matches `mona`'s `libnotifyaudiohal.so` `DT_NEEDED: android.hardware.audio@6.0.so`!).
  - `crdroid_device_xiaomi_sm8350-common` switched to **`android.hardware.audio@7.0-impl`** — if building on a `@7.0` common tree, ensure `android.hardware.audio@6.0.vendor` and `android.hardware.audio.common@6.0.vendor` remain installed for `libnotifyaudiohal.so` (used by `sensors.mius.proximity.so` / ultrasonic proximity)!
- **MIUI-Only VINTF HALs Intentionally Dropped**: `vendor.dolby.hardware.dms`, `vendor.xiaomi.hardware.{cld,displayfeature,dtool,fingerprintextension,mfidoca,micharge,mimd,misecurity,misys,mlipay,mrm,mtdservice,otrpagent,tidaservice,vsimapp}`, `vendor.xiaomi.hw.touchfeature`, `vendor.xiaomi.sensor.communicate`, `vendor.xiaomi.cit.*`, `vendor.nxp.hardware.nfc@2.0` (replaced by AOSP/NXP AIDL NFC HAL), `android.hardware.biometrics.fingerprint@2.1` (replaced by `hardware/xiaomi` AIDL V4).
