# Kernel Patches for Xiaomi Civi 1 (`mona` / `K9B`) on `LineageOS/android_kernel_xiaomi_sm8350`

- **Target Repository:** `LineageOS/android_kernel_xiaomi_sm8350`
- **Target Branch / Verified Base Commit:** `lineage-24.0` (`2c0d4b83`, Linux `5.4.302`)
  *(Also compatible with `crdroidandroid/android_kernel_xiaomi_sm8350` branch `17.0`.)*
- **Kernel Defconfig Chain:** `vendor/lahaina-qgki_defconfig vendor/debugfs.config vendor/xiaomi_QGKI.config vendor/mona_QGKI.config`
  *(Note: `arch/arm64/configs/vendor/mona_QGKI.config` and all `mona` DTS/DTSI files are already present upstream in `android_kernel_xiaomi_sm8350`!)*

## Patch Series

1. **`0001-techpack-display-Support-restoring-reg-0x51-on-LHBM-.patch`**
   - Parses optional panel DT property `mi,local-hbm-off-to-normal-51-index` (defaults to `-1`, so panels such as `venus` `k2` that omit it are unaffected).
   - Patches DCS register `0x51` with `panel->bl_config.real_bl_level` before transmitting `DSI_CMD_SET_MI_LOCAL_HBM_OFF_TO_NORMAL` in `dsi_panel_set_fod_hbm(panel, false)`.
   - Widens `dsi_panel_update_cmd_reg51()` high-byte mask from `& 0x07` (11-bit) to `& 0x0f` (12-bit) with a `tx_len < 3` bounds check so 12-bit `k9b` (`0..4095`) does not wrap modulo 2048 at `>= 50%` brightness (regression-safe for 11-bit panels).
   - **Why required on `mona`:** `dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` is a 12-bit panel (`max=4095`) and includes `39 00 00 00 00 00 03 51 00 00` at command index `1` of `mi,mdss-dsi-local-hbm-off-to-normal-command` (and already declares `mi,local-hbm-off-to-normal-51-index = <1>;`). Without this patch, releasing a finger after optical UDFPS sends `0x0000` (black screen) or wraps brightness above 50%.

2. **`0002-arm64-dts-k9b-Specify-mi-local-hbm-on-1000nit-51-ind.patch`**
   - Sets `mi,local-hbm-on-1000nit-51-index = <6>;` in `arch/arm64/boot/dts/vendor/qcom/display/dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` (matching command index `6` = `39 00 00 00 00 00 03 51 07 FF` inside `mi,mdss-dsi-local-hbm-normal-white-1000nit-command`).
   - **Why required on `mona`:** Without it, `dsi_panel_update_cmd_reg51()` fails with `-EINVAL` and leaves register `0x51` at hardcoded `0x07FF`, flashing the entire panel to maximum brightness on finger-down instead of preserving current screen brightness outside the LHBM spot `(540, 2147)`.

3. **`0003-input-touchscreen-synaptics_s3908p-xiaomi_touch-Wire.patch`**
   - Uncomments `xiaomitouch_register_modedata(0, p_xiaomi_touch_interfaces);` in `drivers/input/touchscreen/synaptics_s3908p/synaptics_tcm_core.c`, fixes the upstream missing `return -ENOMEM;` on NULL `touch_pdata` in `xiaomitouch_register_modedata()`, and allows `FOD_STATUS_INVALID` (`-1`) for `Touch_Fod_Enable` in `syna_tcm_set_cur_value()`.
   - Calls `update_fod_press_status(1)` / `update_fod_press_status(0)` in `touch_fod_down_event()` / `touch_fod_up_event()` (`drivers/input/touchscreen/synaptics_s3908p/synaptics_tcm_touch.c`), notifying `/sys/class/touch/touch_dev/fod_press_status` for `hardware/xiaomi/sensors/v2` (`org.lineageos.sensor.udfps`).
   - Exposes `/sys/class/touch/touch_dev/fod_longpress_gesture_enabled` in `drivers/input/touchscreen/xiaomi/xiaomi_touch.c` (with NULL `pdata` guards and state field in `xiaomi_touch.h`) dispatching `Touch_Fod_Enable` (`1` = `FOD_STATUS_UNLOCKING` to enable, `100` = `FOD_STATUS_DELETED` to disable — critical because `synaptics_s3908p` treats `0` as `FOD_STATUS_UNLOCKED` which keeps FOD enabled!).

4. **`0004-arm64-dts-qcom-Build-only-mona-overlay-for-TARGET_PR.patch`**
   - Guards `arch/arm64/boot/dts/vendor/qcom/Makefile` with `ifeq ($(TARGET_PRODUCT),mona)` so only `mona-sm7325-overlay.dtbo` and its base `yupik.dtb` are compiled for `mona` (all other `sm8350` devices unchanged).
   - **Why required on `mona`:** Stock `mona` has a 16 MiB (`16,777,216` B) `dtbo` partition (max AVB payload `16,707,584` B), smaller than `lisa`/`venus` (24 MiB). Packing all 73 Lahaina/Shima/Yupik overlays creates a 19.99 MiB `dtbo.img` that fails `avbtool add_hash_footer`; scoping to `mona-sm7325-overlay.dtbo` shrinks `dtbo.img` to ~252 KiB (and `dtb.img` to `yupik.dtb` 461 KiB).

5. **`0005-input-touchscreen-synaptics_s3908p-Fix-strict-protot.patch`**
   - Fixes `static int syna_tcm_get_charging_status()` -> `static int syna_tcm_get_charging_status(void)` in `drivers/input/touchscreen/synaptics_s3908p/synaptics_tcm_core.c` for Clang 22 `-Werror,-Wstrict-prototypes` (Android 17 kernel toolchain).

6. **`0006-techpack-display-Support-ESD-panel-status-offset-com.patch`**
   - Adds `DSI_CMD_SET_PANEL_STATUS_OFFSET` (`qcom,mdss-dsi-panel-status-offset-command` and `qcom,mdss-dsi-panel-status-offset-command-state`) to `techpack/display/msm/dsi/{dsi_defs.h,dsi_panel.h,dsi_panel.c,dsi_display.c}`, matching stock `k9b` ESD polling behavior.
   - Transmits the status offset command immediately before `status_cmd` inside `dsi_display_read_status()` whenever present (no-op for panels without `status_offset_cmd`).
   - **Why required on `mona`:** `dsi-panel-k9b-42-02-0a-dsc-cmd.dtsi` declares `qcom,mdss-dsi-panel-status-offset-command = [05 01 00 00 00 00 01 00]` (page/offset select before reading register `0x0A`). Without it, `dsi_panel_read_status` reads `0x00` instead of `0x9C` and triggers `PANEL_DEAD` ESD recovery every ~5.12s.

7. **`0007-input-touchscreen-synaptics_s3908p-xiaomi_touch-Add-.patch`**
   - Exposes `/sys/devices/virtual/touch/touch_dev/fod_finger_down` in `xiaomi_touch.c` / `xiaomi_touch.h` and wires it to `touch_report_fod_btn_info()` in `synaptics_s3908p` (`synaptics_tcm_core.c`, `synaptics_tcm_core.h`, `synaptics_tcm_touch.c`) under `report_mutex` with `fod_display_enabled` dedup.
   - Emits `EV_KEY BTN_INFO (355)` (`1` on finger-down, `0` on finger-up) to trigger Goodix optical UDFPS HAL (`vendor.goodix.hardware.biometrics.fingerprint@2.1`) without modifying `fod_press_status` (preserving AOD `org.lineageos.sensor.udfps`).
   - **Why required on `mona`:** Screen-on UDFPS enrollment/auth on `mona` does not emit firmware `FOD_PRESS` packets, so `libudfpshandler.mona` writes `fod_finger_down` on `onFingerDown()` / `onFingerUp()`.

8. **`0008-power-supply-qti_battery_charger-Align-mona-ADSP-pro.patch`**
   - Adds `CONFIG_MONA_FOR_BUILD` in `drivers/power/supply/Kconfig` and updates `arch/arm64/configs/vendor/mona_QGKI.config` to `CONFIG_BQ2597X=y`, `CONFIG_BQ_FG_1S=y`, `CONFIG_BQ_FUEL_GAUGE=y`, `CONFIG_BQ_CLOUD_AUTHENTICATION=y`, `CONFIG_MONA_FOR_BUILD=y` (matching stock `OS1.0.2.0.TKVCNXM` QGKI `/vendor/lib/modules/qti_battery_charger_main_k8.ko`, NOT the unused `5.4-gki/` copy).
   - Aligns `enum xm_property_id` in `qti_battery_charger.h` (and matching `#if` guards in `qti_battery_charger_xiaomi.c`) to the exact 99-entry (`0..98`, `XM_PROP_MAX == 99`, `xm_prop_map` = `0x18c` = `396` B) `mona` ADSP `BATTERY_CHARGER` GLINK ABI, with 32-byte `BATTERY_DIGEST_LEN` (`0x34` = 52 B glink packet) required for Xiaomi battery/PD/PPS fast-charge authentication.
   - Keeps stock `CONFIG_BQ_FUEL_GAUGE` thermal zone (`power_supply_read_temp` reading `XM_PROP_THERMAL_TEMP = 0x4a = 74`) and `TIME_TO_FULL_AVG` behavior while downgrading `batt_thermal` `pr_err` to `pr_debug`.
   - Makes `fb_notifier_callback()` schedule `fb_notifier_work` asynchronously (`XM_PROP_FB_BLANK_STATE = 0x49 = 73`) and downgrades `chg_suspend`/`chg_resume` `pr_err` to `pr_debug`.

9. **`0009-usb-typec-ucsi-glink-Support-Xiaomi-swap-role-notifi.patch`**
   - Adds Xiaomi `UC_UCSI_SWAP_ROLE_IND` (`0x14`, `MI SMART INTERCHG`) handler and `swap_role_work_func()` to `drivers/usb/typec/ucsi/ucsi_glink.c`, matching stock `OS1.0.2.0` `ucsi_glink.ko` (`UCSI_SET_PDR`, `msleep(100)`, `UCSI_SET_UOR`).
   - **Why required on `mona`:** Without handling opcode `0x14`, ADSP-initiated USB-C DRP role swaps (`MI SMART INTERCHG`) are dropped by `ucsi_glink`.

10. **`0010-ksu-Integrate-KernelSU-Next-legacy-with-manual-hooks.patch`**
    - Wires `KernelSU-Next` `legacy` branch (`drivers/kernelsu -> ../KernelSU-Next/kernel`, cloned at `kernel/xiaomi/sm8350/KernelSU-Next`) with `CONFIG_KSU=y` + `CONFIG_KSU_MANUAL_HOOK=y` in `mona_QGKI.config`.
    - Backports `can_umount()` / `path_umount()` into `fs/namespace.c` & `fs/internal.h` (prevents `Kbuild` `sed -i` against read-only Soong `srctree`).
    - Adds deterministic manual hooks in `kernel/reboot.c`, `fs/exec.c`, `fs/open.c`, `fs/read_write.c`, `fs/stat.c`, `drivers/input/input.c`, and `security/selinux/avc.c` (100% safe under Clang 22 `CONFIG_LTO_CLANG=y` + strict `CONFIG_CFI_CLANG=y`, handles `sys_reboot` supercalls and Android 17 Bionic `execveat` without kprobes or RO `sys_call_table` patching).

## `mona_QGKI.config` & Android 17 Config Audit

Audited `vendor/lahaina-qgki_defconfig` + `vendor/xiaomi_QGKI.config` + `vendor/mona_QGKI.config` against `lisa_QGKI.config`, `venus_QGKI.config`, stock `OS1.0.2.0.TKVCNXM` `kernel.config`, and Android 17 requirements:

- **Already enabled in `lahaina-qgki_defconfig`:** `CONFIG_BPF_SYSCALL=y`, `CONFIG_BPF_JIT_ALWAYS_ON=y`, `CONFIG_CGROUP_BPF=y`, `CONFIG_FUSE_BPF=y`, `CONFIG_USERFAULTFD=y`, `CONFIG_PSI=y`, `CONFIG_MEMCG=y`, `CONFIG_CGROUP_FREEZER=y`, `CONFIG_EROFS_FS=y`, `CONFIG_DM_SNAPSHOT=y`, `CONFIG_USB_CONFIGFS_F_UVC=y`, `CONFIG_SECURITY_SELINUX=y`, `CONFIG_CRYPTO_ZSTD=y`, `CONFIG_UCSI_QTI_GLINK=y`.
- **Already enabled in `xiaomi_QGKI.config`:** `CONFIG_BUILD_ARM64_DT_OVERLAY=y`, `CONFIG_EXFAT_FS=y`, `CONFIG_INPUT_FINGERPRINT=y`, `CONFIG_MI_HARDWARE_ID=m`, `CONFIG_IR_SPI=m`, `CONFIG_LEDS_QTI_FLASH=m`, `CONFIG_QTI_BATTERY_CHARGER=m`, `CONFIG_MI_THERMAL_INTERFACE=m`, `CONFIG_ICNSS2=m`, `CONFIG_CNSS2=m`, `CONFIG_QCA_CLD_WLAN=m`.
- **Enabled in `mona_QGKI.config` (with Patch `0008`):** `CONFIG_FINGERPRINT_GOODIX_FOD=m`, `CONFIG_INPUT_AW862XX_HAPTIC=y`, `CONFIG_PINCTRL_SM7325=y`, `CONFIG_BQ2597X=y`, `CONFIG_BQ_FG_1S=y`, `CONFIG_BQ_FUEL_GAUGE=y`, `CONFIG_BQ_CLOUD_AUTHENTICATION=y`, `CONFIG_MONA_FOR_BUILD=y`, `CONFIG_MIUS_PROXIMITY=y`, `CONFIG_TOUCHSCREEN_SYNAPTICS_TCM_S3908P*=m`, `CONFIG_TOUCHSCREEN_XIAOMI_TOUCHFEATURE=m`, `CONFIG_CNSS_QCA6750=y`.
- **Audio codec build rule:** `techpack/audio/asoc/codecs/Kbuild` already selects `aw88263s/` -> `aw882xx_dlkm.ko` when `TARGET_PRODUCT=mona` (`TARGET_KERNEL_ADDITIONAL_FLAGS := TARGET_PRODUCT=$(PRODUCT_DEVICE)` in `sm8350-common/BoardConfigCommon.mk`).
- **Android 17 boot verification:** Boot #1 confirmed `lahaina-qgki_defconfig` + `mona_QGKI.config` boots Android 17 (SDK 37) cleanly with 0 crashes/tombstones/HAL deaths.

## Applying Patches

```bash
cd <rom-root>/kernel/xiaomi/sm8350
git am device/xiaomi/mona/patches/kernel/sm8350/*.patch
```
