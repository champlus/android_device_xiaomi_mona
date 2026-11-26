# Xiaomi Civi 1 (`mona` / `K9B`) — Stock Firmware (`OS1.0.2.0.TKVCNXM`) Hardware & ABI Reverse-Engineering Report

> **Target Device**: Xiaomi Civi 1 China (`mona`, model `2109119BC`, internal hardware code `K9B`, SoC Qualcomm SM7325 / Snapdragon 778G / `yupik` — **NOT** Motorola `mona`).  
> **Porting Target**: crDroid 13 (Android 17 / LineageOS 24.0), with crDroid 12 (Android 16 / LineageOS 23.2) comparison.  
> **Source Firmware**: Official Xiaomi HyperOS 1.0 China Stable Final Recovery ROM `OS1.0.2.0.TKVCNXM` (internal incremental `V816.0.2.0.TKVCNXM`).

---

## 1. Firmware Acquisition, Verification & Dump Layout

All large binaries, extracted images, unpacked filesystems, and host extraction tools live strictly under `<workspace>/` (local build workspace), keeping `<device-repo>/` lightweight. The 5.12 GiB stock firmware was downloaded **directly without proxy** across Xiaomi China CDNs (`bn.d.miui.com`, `cdnorg.d.miui.com`, AliCloud OSS) at ~12 MiB/s average and verified against the official XiaomiFirmwareUpdater tracker checksum.

| Artifact | Value / Path |
| :--- | :--- |
| **Filename** | `miui_MONA_OS1.0.2.0.TKVCNXM_697bd03a16_13.0.zip` |
| **File Size** | `5,501,911,434` bytes (`5.12 GiB`) |
| **MD5 (Verified)** | `697bd03a169b37b1c0a3197caf6c7787` (matches official tracker) |
| **SHA256** | `aff7c35b7f633f852e0b4e60b9c3f87418a6ae6c5fec0d6a0527f0894bd10940` |
| **Direct Official URLs** | `https://bn.d.miui.com/OS1.0.2.0.TKVCNXM/miui_MONA_OS1.0.2.0.TKVCNXM_697bd03a16_13.0.zip`<br>`https://cdnorg.d.miui.com/OS1.0.2.0.TKVCNXM/miui_MONA_OS1.0.2.0.TKVCNXM_697bd03a16_13.0.zip` |
| **Stored Archive** | `<firmware-dir>/miui_MONA_OS1.0.2.0.TKVCNXM_697bd03a16_13.0.zip` |
| **Extracted Dump Root** | `<stock-dump>/OS1.0.2.0.TKVCNXM/` |
| **Tools Root** | `<tools-dir>/` (`payload-dumper-go` 2.1.0, `fsck.erofs`/`dump.erofs` 1.7.1, `dtc` 1.7.0, `unpack_bootimg` 34.0.4, `avbtool.py` 1.3.0, `aria2c` 1.37.0, `inspect_dtbo.py`, `audit_blobs.py`) |

### Extracted Dump Directory Structure

```text
<stock-dump>/OS1.0.2.0.TKVCNXM/
├── images/               # All 28 raw .img partitions dumped from payload.bin
├── fs/                   # All 6 EROFS partitions unpacked via fsck.erofs:
│   ├── vendor/           #   5,104 entries (1.6 GB EROFS)
│   ├── odm/              #      45 entries (18 MB EROFS; per-device VINTF + configs)
│   ├── system/           #   3,723 entries (810 MB EROFS)
│   ├── system_ext/       #   1,852 entries (420 MB EROFS)
│   ├── product/          #   1,690 entries (4.0 GB EROFS)
│   └── mi_ext/           #      44 entries (463 kB EROFS)
├── boot_unpacked/        # Uncompressed ARM64 kernel Image, gzip ramdisk, extracted kernel.config (7,013 lines)
├── ramdisk_boot/         # Unpacked boot.img ramdisk (recovery-in-boot + GSI AVB keys)
├── vendor_boot_unpacked/ # vendor_ramdisk (gzip) + 4.22 MB appended DTB blob
├── ramdisk_vboot/        # 44 first-stage 5.4-gki .ko modules + fstab.default + fstab.emmc
├── dtb_unpacked/         # 10 appended DTBs decompiled to .dts (Yupik = 08_dtbdump_*Yupik_SoC.dts)
├── dtbo_unpacked/        # All 37 DTBO overlays decompiled to .dts (mona = dtbo_31_id0x0_rev0x0.dts)
├── meta/                 # OTA metadata, payload_properties.txt, care_map.pb, apex_info.pb
└── audit_blobs.txt       # Full 915-line VINTF, 32/64-bit HAL, and ELF DT_NEEDED audit log
```

---

## 2. Stock Build Properties, Boot Architecture, Partitions & Kernel Audit

### 2.1 Build Fingerprints & Treble / GRF Architecture

Xiaomi Civi 1 launched on **Android 11 (API 30)** and follows Google's **GRF (Generic Reference Freeze)** vendor model: the system/product/system_ext SSI (`missi`) was upgraded to Android 13 (API 33), while `vendor` and `odm` remain frozen on **Android 11 (SDK 30 / VNDK 30 / FCM target-level 5)**.

| Property | Stock Value |
| :--- | :--- |
| OTA `post-build` | `Xiaomi/mona/mona:13/TKQ1.221114.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.system.build.fingerprint` | `qti/missi/missi:13/TKQ1.221114.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.system_ext.build.fingerprint` | `qti/missi/missi:13/TKQ1.221114.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.product.build.fingerprint` | `Xiaomi/mona/missi:13/TKQ1.221114.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.vendor.build.fingerprint` | `Xiaomi/mona/mona:13/RKQ1.211001.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.odm.build.fingerprint` | `Xiaomi/mona/mona:13/RKQ1.211001.001/V816.0.2.0.TKVCNXM:user/release-keys` |
| `ro.mi.os.version.name` / `incremental` | `OS1.0` / `OS1.0.2.0.TKVCNXM` (`ro.miui.ui.version.name=V816`) |
| System Android / API / Security Patch | Android `13` / SDK `33` / `2024-02-01` |
| Vendor SDK / `first_api_level` / `board.api_level` | SDK `30` / `ro.product.first_api_level=30` / `ro.board.api_level=30` |
| Vendor VNDK / Product VNDK / FCM Level | `ro.vndk.version=30` / `ro.product.vndk.version=33` / **FCM `target-level="5"`** |
| Device / Model / Platform / SoC | `mona` / `2109119BC` ("Xiaomi Civi") / `ro.board.platform=lahaina` / QTI SM7325 (`yupik`) |
| ABI / Zygote | `arm64-v8a,armeabi-v7a,armeabi` (`ro.zygote=zygote64_32`) |
| A/B & Dynamic Partitions | `ota-type=AB`, `ro.build.ab_update=true`, `ro.virtual_ab.enabled=true`, `ro.boot.dynamic_partitions=true`, `snapshot_enabled=1` |
| LCD Density / OpenGL ES / Vulkan | `ro.sf.lcd_density=440`, OpenGL ES `3.2` (`196610`), `ro.hardware.vulkan=adreno` |

### 2.2 `boot.img`, `vendor_boot.img`, `dtbo.img` & Kernel Configuration

- **`boot.img`** (`201,326,592` bytes = **192 MiB**, original payload `71,315,456` bytes):
  - **Header version**: `3` (`os_version=13.0.0`, `os_patch_level=2024-02`, empty `boot.img` cmdline).
  - **Kernel**: `51,446,272` bytes, **uncompressed** `Linux kernel ARM64 boot executable Image, little-endian, 4K pages`.
  - **Exact Kernel Banner**:
    ```text
    Linux version 5.4.233-qgki-g1e646a5c8cd5 (builder@pangu-build-component-vendor-39163-k8c38-1tv75-5vnwh) (Android (6877366 based on r383902b1) clang version 11.0.2, LLD 11.0.2) #1 SMP PREEMPT Sun Feb 18 03:16:14 UTC 2024 f2fs-hash:1e2949fb28
    ```
  - **Boot Ramdisk**: `19,860,499` bytes gzip (`38,499,328` bytes uncompressed) — **Recovery-in-boot** (no separate `recovery` partition; contains `first_stage_ramdisk/avb/{q,r,s}-gsi.avbpubkey` and recovery binaries).
- **`vendor_boot.img`** (`100,663,296` bytes = **96 MiB**, original payload `6,103,040` bytes):
  - **Header version**: `3`, page size `0x1000` (4096), header size `2112`.
  - **Load addresses**: kernel `0x00008000`, ramdisk `0x01000000`, tags `0x00000100`, dtb `0x01f00000`.
  - **Vendor cmdline**:
    ```text
    console=ttyMSM0,115200n8 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=0 loop.max_part=7 cgroup.memory=nokmem,nosocket pcie_ports=compat loop.max_part=7 iptable_raw.raw_before_defrag=1 ip6table_raw.raw_before_defrag=1 buildvariant=user
    ```
  - **Vendor Ramdisk**: `1,868,600` bytes gzip (`8,077,312` bytes uncompressed) containing:
    - `first_stage_ramdisk/fstab.default` and `first_stage_ramdisk/fstab.emmc`
    - `lib/modules/5.4-gki/` — **44 first-stage boot `.ko` modules** (unified across lahaina/shima/yupik: `gcc-yupik.ko`, `pinctrl-yupik.ko`, `qnoc-yupik.ko`, `phy-qcom-ufs-qmp-v4-yupik.ko`, `ufs-qcom.ko`, `ufshcd-crypto-qti.ko`, `hwkm.ko`, `crypto-qti-hwkm.ko`, `qcom_rpmh.ko`, `rpmh-regulator.ko`, `rpmhpd.ko`, `qcom-pdc.ko`, `qcom-arm-smmu-mod.ko`, `qpnp-power-on.ko`, `_qcom_scm.ko`, `qbt_handler.ko`, etc.).
  - **DTB (`vendor_boot`)**: `4,223,378` bytes containing 9 base SoC DTBs (Lahaina v1/v2/v2.1, LahainaP, Shima, **Yupik** `08_dtbdump_Qualcomm_Technologies,_Inc._Yupik_SoC.dtb` with `qcom,msm-id = <0x1db 0x10000 0x203 0x10000>`, and YupikP).
- **`dtbo.img`** (`16,777,216` bytes = **16 MiB**, DTBO payload `10,883,773` bytes):
  - DTBO Header v0, `37` entries (unified Xiaomi SM8350/SM7350/SM7325 DTBO table).
  - **`mona` overlay is entry `[31]`** (`247,346` bytes, offset `0x8f8df1`):
    - `model = "mona based Qualcomm Technologies, Inc. SM7325";`
    - `compatible = "qcom,yupik-idp", "qcom,yupik", "qcom,idp";`
    - `qcom,msm-id = <0x1db 0x10000>;` (MSM ID `475` = SM7325)
    - `qcom,board-id = <0x1000b 0x00>;`
    - `xiaomi,board-id = <0x0b 0x00>;` *(distinguishes `mona` = `0x0b` from `lisa` = `0x0a` and `taoyao` = `0x0d`!)*
- **Second-stage kernel modules (`vendor/lib/modules/5.4-gki/`)**: ~220 loadable DLKMs (with a legacy non-GKI subset in `vendor/lib/modules/`), including `msm_drm.ko`, `msm_kgsl.ko`, `camera.ko`, `msm-vidc.ko`, `msm-cvp.ko`, `goodix_fod.ko`, `synaptics_tcm_{core_module,spi,device,reflash,testing}.ko`, `xiaomi_touch.ko`, `aw882xx_dlkm.ko`, `wcd938x_dlkm.ko`, `bolero_cdc_dlkm.ko`, `haptic.ko`, `ir-spi.ko`, `nfc_i2c.ko`, `leds-qti-flash.ko`, `qti_battery_charger_main_k8.ko`, `pmic_glink.ko`, `ucsi_glink.ko`, `altmode-glink.ko`, `us_prox_iio.ko`, `qca_cld3_qca6750.ko`, `cnss2.ko`, `icnss2.ko`, `btpower.ko`, `mi_thermal_interface.ko`, `hwid.ko`.

### 2.3 Partition Layout, Super Partition & AVB / VBMeta

Parsed directly from `payload.bin` `DeltaArchiveManifest` (v2) and `avbtool.py info_image`:

| Dynamic Partition Group | Max Group Size | Logical Partitions (ALL EROFS `LZ4_0PADDING`) |
| :--- | :--- | :--- |
| `qti_dynamic_partitions` | `9,073,118,412` bytes (**8.450 GiB**; `super` physical size = **8.5 GiB** / `9,126,805,504` B) | `system`, `system_ext`, `product`, `vendor`, `odm`, `mi_ext` |

| Partition | Exact Size (Bytes) | Size (MiB) | Format / Notes |
| :--- | ---: | ---: | :--- |
| `system` | `810,471,424` | `772.93` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta_system`) |
| `system_ext` | `420,450,304` | `400.97` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta_system`) |
| `product` | `3,985,973,248` | `3,801.32` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta_system`) |
| `vendor` | `1,617,018,880` | `1,542.11` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta`) |
| `odm` | `17,838,080` | `17.01` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta`) |
| `mi_ext` | `462,848` | `0.44` | EROFS (`LZ4_0PADDING`), dm-verity + FEC (`vbmeta`), MIUI overlayfs |
| **Total Stock Dynamic Used** | **`6,852,214,784`** | **`6,534.78`** | Leaves ~2.12 GiB headroom inside `qti_dynamic_partitions` (8,652.8 MiB) |
| `boot` | `201,326,592` | `192.00` | Android boot v3 (kernel + recovery ramdisk) |
| `vendor_boot` | `100,663,296` | `96.00` | Android vendor_boot v3 (vendor ramdisk + DTB) |
| `dtbo` | `16,777,216` | `16.00` | DTBO v0 (37 overlays) |
| `vbmeta` / `vbmeta_system` | `8,192` / `4,096` | `0.01` / `0.004` | AVB 1.2 (`SHA256_RSA2048`, `Flags: 0`; `vbmeta` chains `vbmeta_system`) |
| `modem` | `218,263,552` | `208.15` | FAT16 (`/vendor/firmware_mnt`, includes `image/qca6750/bdwlan.*`) |
| `dsp` | `67,108,864` | `64.00` | ext4 (`/vendor/dsp`) |
| `bluetooth` | `503,808` | `0.48` | FAT16 (`/vendor/bt_firmware`) |
| Firmware partitions (14) | `abl` (209k), `aop` (209k), `cpucp` (188k), `devcfg` (53k), `featenabler` (90k), `hyp` (3.7M), `imagefv` (2.1M), `keymaster` (270k), `qupfw` (57k), `shrm` (49k), `tz` (3.7M), `uefisecapp` (127k), `xbl` (3.7M), `xbl_config` (229k) | — | A/B slot-selected QTI bootloader/TEE/firmware images |

- **AVB Details**: `vbmeta.img` uses `SHA256_RSA2048` (pubkey SHA1 `b2a02f1e56e366d727a1a8e089762fe0b91bbc84`), `Flags: 0`, `Rollback Index: 0`, and chains `vbmeta_system` (`Rollback Index Location: 2`, `Rollback Index: 1706745600`). Individual images (`boot`, `vendor_boot`, `dtbo`, dynamic images) carry `Algorithm: NONE` AVB footers verified by descriptors in `vbmeta`/`vbmeta_system`.
- **Fstab Highlights (`fstab.default`)**:
  - Supports **both `ext4` and `erofs`** entries for `system`, `system_ext`, `product`, `vendor`, `odm`, `mi_ext` (first-stage mount, `slotselect,avb,logical`).
  - `/metadata`: `ext4`, `first_stage_mount`, holds `/metadata/vold/metadata_encryption`.
  - `/data` (`userdata`, UFS host `/sys/devices/platform/soc/1d84000.ufshc`): **F2FS**, `inlinecrypt`, `fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0`, `metadata_encryption=aes-256-xts:wrappedkey_v0`, `quota,reservedsize=128M,checkpoint=fs`.
  - `/mnt/vendor/persist` (`ext4`), `/vendor/firmware_mnt` (`modem`, vfat, `slotselect`), `/vendor/dsp` (`dsp`, ext4, `slotselect`), `/vendor/vm-system` (`vm-bootsys`, ext4, `slotselect`), `/vendor/bt_firmware` (`bluetooth`, vfat, `slotselect`), `/mnt/vendor/qmcs` (`vfat`).
  - MIUI `mi_ext` bind-mount + 17 `overlay` mounts over `/product/*` and `/system/*` are all marked `nofail` (not needed for crDroid/LineageOS).

### 2.4 Stock Kernel 5.4.233 `IKCFG` Compatibility Audit for Android 16/17

Inspecting the 7,013-line `kernel.config` extracted from stock `boot.img` reveals **hard blockers** against reusing the stock prebuilt 5.4.233 kernel on Android 16 or Android 17:

| Feature / Config | Stock 5.4.233 Value | Impact on Android 16 / 17 (crDroid 12 / 13) |
| :--- | :--- | :--- |
| `CONFIG_USERFAULTFD` | **NOT SET** | **Critical**: Android 14+ ART Concurrent Mark-Compact (CMC) GC relies on `userfaultfd`; missing it forces fallback/degradation or crashes if expected. |
| `CONFIG_NF_TABLES` | **NOT SET** | **High**: Modern Android `netd`/tethering/connectivity increasingly expects `nftables` / BPF-based packet filtering alongside `iptables`. |
| `CONFIG_DM_USER` | **ABSENT** | **Medium**: Required for Virtual A/B Compression (`vabc`) userspace snapshots; stock only has `CONFIG_DM_SNAPSHOT=y`. |
| `CONFIG_BPF*` | `CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`, `CONFIG_CGROUP_BPF=y`, `CONFIG_NET_CLS_BPF=y`, `# CONFIG_BPF_UNPRIV_DEFAULT_OFF is not set`, `# CONFIG_NET_ACT_BPF is not set` | **Critical Blocker**: Stock 5.4.233 lacks AOSP 5.4.302+ `NetBpfLoad` / BPF verifier / `BPF_MAP_TYPE_RINGBUF` / cgroup socket / FUSE-BPF backports required by Android 16/17 mainline `Connectivity`/`Tethering` APEXes. Boot will fail or lose networking (`netd`/BPF load failure). |
| `CONFIG_EROFS_FS` / `ZIP` | `=y` / `=y` | Present (`CONFIG_EROFS_FS_XATTR=y`, `SECURITY=y`, `POSIX_ACL=y`). |
| `CONFIG_DM_VERITY` / `DEFAULT_KEY` / `INLINE_ENCRYPTION` | All `=y` | Present; FBE v2 wrapped-key inline encryption supported. |
| `CONFIG_PSI` / `MEMCG` / `CGROUP_FREEZER` / `UCLAMP_TASK` | All `=y` | Present (`CONFIG_IO_URING=y`, `CONFIG_INCREMENTAL_FS=y`, `CONFIG_LTO_CLANG=y`, `CONFIG_CFI_CLANG=y`, `CONFIG_SHADOW_CALL_STACK=y`). |

**Verdict**: Stock prebuilt kernel 5.4.233 **must NOT be reused** for crDroid 13 (Android 17). A source-built 5.4.302+ kernel (`LineageOS/android_kernel_xiaomi_sm8350` with AOSP BPF/userfaultfd/netfilter backports and `mona` DTS/drivers) is mandatory.

---

## 3. Complete Hardware Reverse-Engineering Inventory

Verified directly from `dtbo_31_id0x0_rev0x0.dts`, `08_dtbdump_Qualcomm_Technologies,_Inc._Yupik_SoC.dts`, `vendor/lib/modules/`, `vendor/firmware/`, `vendor/lib64/`, and `vendor/etc/`.

| Subsystem | Hardware Component | Exact DTBO / Driver / Firmware Details |
| :--- | :--- | :--- |
| **SoC / GPU** | Qualcomm SM7325 (Snapdragon 778G), `yupik`, Adreno 642L (`Adreno642Lv1`) | `qcom,msm-id = <0x1db 0x10000>`, `qcom,board-id = <0x1000b 0x00>`, `xiaomi,board-id = <0x0b 0x00>` |
| **PMIC Topology** | `PMK8350` (@0), `PM7325` (@1), `PM8350C` (@2), `PM7325B` (@3), `PMR735A` (@4), dual camera `PM8008I` (I2C `0x08/0x09`) & `PM8008J` (I2C `0x0c/0x0d`) | SPMI bus + `qupv3_se1_i2c`; `pm7325b` handles battery/USB/WLED/LCDB; `pm8350c` handles flash LEDs + PWM/LPG |
| **Display Panel** | 6.55" Curved 10-bit OLED (**CSOT/TCL Huaxing `K9B`**) | Node `qcom,mdss_dsi_k9b_42_02_0a_dsc_cmd`, panel name `"xiaomi 42 02 0a cmd mode dsc dsi panel"`, `mi,panel-id = <0x4b3942 0x420200>` (`0x4b3942` = ASCII `K9B`). Command-mode DSC 1.1 (`10 bpc`, `8 bpp`, `bpp=30`), `1080×2400` (`0x438×0x960`), physical `68.3×151.7 mm`, **60 Hz (`timing@0`) & 120 Hz (`timing@1`)**, HDR enabled, backlight range `0x03..0xfff` (`4095`), HBM threshold `0x7ff` (`2047`), **hardware Local HBM (`mi,local-hbm-enabled`)** with 1000 nit / 110 nit white + 500 nit green + HLPM/LLPM AOD + flatmode/GIR + ESD IRQ GPIO 3. QDCM calib: `vendor/etc/qdcm_calib_data_xiaomi_42_02_0a_cmd_mode_dsc_dsi_panel.xml`. |
| **Touch Controller** | **Synaptics S3908P** (SPI) + Xiaomi TouchFeature | Node `synaptics_tcm@0` (`compatible = "synaptics,tcm-spi"`), IRQ GPIO 81 (`0x51`), Reset GPIO 105 (`0x69`), resolution `1080×2400` (`0x437×0x95f`), curved-edge deadzone/edgezone/cornerzone rejection tables in DTBO. Modules: `synaptics_tcm_{core_module,spi,device,reflash,testing}.ko` + `xiaomi_touch.ko` (`compatible = "xiaomi-touch"`, `/dev/xiaomi-touch`). Firmware: `vendor/firmware/s3908p_xiaomi_k9b_spi.img`. |
| **UDFPS (Optical Fingerprint)** | **Goodix Optical FOD** | Node `fingerprint_goodix` (`compatible = "goodix,fingerprint"`, `l11c_vdd-supply`, Reset GPIO 43 / `0x2b`, IRQ GPIO 34 / `0x22`). Module: `goodix_fod.ko` (`/dev/goodix_fp`). Full deep dive in Section 4. |
| **Front Dual Soft-Light Flash & Rear Flash / LEDs** | **PM8350C 4-Channel Flash LED Controller** (`qcom,pm8350c-flash-led` @ `0xee00`, `leds-qti-flash.ko`) | **Rear Single Flash**: `led:flash_0` (max 1500 mA) / `led:torch_0` (max 500 mA) controlled by `led:switch_0` (`qcom,led-mask = <0x01>`) -> `qcom,camera-flash@0/1/2` (rear cameras).<br>**Front Dual Soft-Light Flash**: **`led:flash_1` + `led:flash_2`** (1500 mA each) and **`led:torch_1` + `led:torch_2`** (500 mA each) ganged on **`led:switch_1` (`qcom,led-mask = <0x06>` = channels 1 & 2 simultaneously, `qcom,symmetry-en`)** -> wired to **`qcom,camera-flash@3`** -> `led-flash-src` on **`qcom,cam-sensor1`** (Front IMX616)! Verified in `cit_param_config.json` (`cit_soft_torch_first` -> `/sys/class/leds/led:switch_1` + `led:torch_1`) and `init.target.rc` (`chmod 0664` on `led:{torch,flash}_{0..3}/brightness`).<br>**Notification RGB LED**: None (`pm8350c` `qcom,tri-led` @ `0xef00` is `status = "disabled"`). |
| **Camera Sensors (4 Sensors, No OIS)** | 1. **Rear Wide**: 64 MP Samsung **S5KGW3** + **DW9800** AF (`sensor0`, CSIPHY 1)<br>2. **Front Selfie**: 32 MP Sony **IMX616** + **DW9714V** AF + Dual Soft-Light Flash (`sensor1`, CSIPHY 0)<br>3. **Rear Ultra-Wide**: 8 MP Sony **IMX355** FF (`sensor2`, CSIPHY 2)<br>4. **Rear Macro**: 2 MP GalaxyCore **GC02M1** FF (`sensor3`, CSIPHY 3) | Verified sensor/actuator/EEPROM libs in `vendor/lib64/camera/`: `com.qti.sensor.mona_semco_s5kgw3_wide.so`, `com.qti.actuator.mona_semco_s5kgw3_dw9800_wide.so`, `com.qti.eeprom.mona_semco_s5kgw3_gt24p128e_wide_eeprom.so`, `com.qti.sensor.mona_sunny_imx616_front.so`, `com.qti.actuator.mona_sunny_imx616_dw9714v_front.so`, `com.qti.eeprom.mona_sunny_imx616_p24c64f_front_eeprom.so`, `com.qti.sensor.mona_ofilm_imx355_ultra.so`, `com.qti.sensor.mona_sunny_gc02m1_macro.so`. No `com.qti.ois.*` libs (EIS only; `mona_motiontuning.xml`). Camera HAL uses `ro.hardware.camera=xiaomi` (`camera.xiaomi.so` + `camera.qcom.so` CamX/CHI). |
| **Audio Codec & Stereo Smart PAs** | **Qualcomm WCD938x** + **Dual Awinic AW882xx** Stereo Smart PAs + Dolby Atmos | Sound card: `lahaina-yupikidp-snd-card` (`wcd938x-codec` `status = "okay"`, `wcd937x` disabled, `wsa-max-devs = 0`, Bolero LPASS SoundWire, USB-C audio supported). Dual I2C Smart PAs: `aw882xx_smartpa@34` (ch 0 top speaker/earpiece, reset GPIO 2, IRQ GPIO 102, `spk-sw-gpio` GPIO 101) and `aw882xx_smartpa@35` (ch 1 bottom speaker, reset GPIO 6, IRQ GPIO 24). Module: `aw882xx_dlkm.ko`; firmware: `aw882xx_pid_1852_acf.bin`, `aw882xx_pid_2032_acf.bin`, `aw882xx_{spk,rcv}_reg_{l,r}.bin`. Dolby DMS (`vendor.dolby.hardware.dms@2.0`) + OZO Audio C2 (`vendor.ozoaudio.media.c2@1.0`). |
| **NFC & eSE** | **NXP SN100T/SN110T** (I2C + embedded Secure Element) | Node `nq@28` (`compatible = "qcom,sn-nci"`, bus `qupv3_se9_i2c` @ `0x28`, IRQ GPIO 41, VEN GPIO 38, FIRM GPIO 40, CLKREQ GPIO 39). Module: `nfc_i2c.ko`. Configs: `vendor/etc/libnfc-mtp-SN100.conf`, `libnfc-nxp.conf`. VINTF (`odm/etc/vintf/manifest_mona.xml`): `android.hardware.nfc@1.2`, `vendor.nxp.hardware.nfc@2.0`, `android.hardware.secure_element@1.2` (`SIM1`, `eSE1`). |
| **IR Blaster** | **SPI IR LED** | Node `ir-spi@0` (`compatible = "ir-spi"`, max freq 19.2 MHz / `0x124f800`). Module: `ir-spi.ko`. HAL: `android.hardware.ir@1.0-service` + `consumerir.lahaina.so`. |
| **Vibrator / Haptics** | **Awinic AW8622x / AW8624** Z-Axis LRA | Node `awinic_haptic@58` (`compatible = "awinic,awinic_haptic"`, `reg = 0x5a`, `aw8622x_i2c_addr = 0x58`, Reset GPIO 35, IRQ GPIO 18, `f0_pre = 0x802` ~205 Hz). Module: `haptic.ko`; firmware: `aw8622x_haptic.bin`, `aw8624_haptic.bin` + 390+ `*_RTP.bin` waveforms. Note: QTI `pm8350b-swr-haptics` is `status = "disabled"`. Stock HAL is `vendor.xiaomi.hardware.vibratorfeature.service` exposing custom AIDL instance `IVibrator/vibratorfeature` (not `default`). |
| **Charging, Battery & Thermal** | **55W Fast Charging** via ADSP PMIC-GLINK + Charge Pump + Fuel Gauge | Kernel config: `CONFIG_QTI_BATTERY_CHARGER_K8=m` (`qti_battery_charger_main_k8.ko`), `CONFIG_BQ2597X=y`, `CONFIG_BQ_FUEL_GAUGE=y`, `CONFIG_QTI_PMIC_GLINK=y`, `CONFIG_UCSI_QTI_GLINK=y`, `CONFIG_QTI_ALTMODE_GLINK=y`. Exposes `/sys/class/qcom-battery/*` and `/sys/class/power_supply/{battery,bms,usb,main}/*` (`pd_verifed`, `quick_charge_type`, `fastchg_mode`, `night_charging`, `smart_batt`, `input_suspend`). Thermal: `mi_thermald` + `thermal-engine` + `mi_thermal_interface.ko` + 18 `vendor/etc/thermal-*.conf` profiles + 20-step `qcom,thermal-mitigation` current table (`10A` down to `0.5A`). |
| **Sensors** | **Qualcomm SLPI/SEE** + **Elliptic Ultrasonic Proximity** | Confirmed from `vendor/etc/sensors/config/sm7350_*.json` (explicitly listing `"hw_platform": [..., "MONA"]`, `"soc_id": ["475"]`): **TDK InvenSense ICM4x6xA** & **ST LSM6DSO** (accel+gyro IMU), **AKM AK0991x** (magnetometer, I2C/I3C), **ams TMD3719** & **TCS3408** (ambient light / flicker), and **Elliptic Labs ultrasonic virtual proximity** (`us_prox_iio.ko`, `/dev/elliptic0`, `vendor/lib64/sensors.elliptic@2.0.so`, `vendor/etc/elliptic_sensor.xml`). No dedicated hardware IR proximity sensor. |
| **Wi-Fi / BT / Modem** | **Qualcomm WCN6750** (Wi-Fi 6 / BT 5.2) + Snapdragon X53 5G | Modules: `qca_cld3_qca6750.ko`, `icnss2.ko`, `btpower.ko`, `bt_fm_slim.ko`. Board data in `modem.img`: `image/qca6750/bdwlan.{bin,elf,b01..b07,e01..e07}`. BT A2DP offload codecs: `sbc, aptx, aptxtws, aptxhd, aptxadaptiver2, aac, ldac, lhdc`. Dual-SIM 5G/4G (`slot1`/`slot2`). |

---

## 4. UDFPS (Optical In-Display Fingerprint) Deep Dive

Xiaomi Civi 1 uses a **Goodix optical under-display fingerprint sensor** paired with **hardware Local High-Brightness Mode (LHBM)** on the CSOT `K9B` OLED panel and **Synaptics S3908P** FOD touch reporting.

### 4.1 Exact Sensor Geometry & Properties (`vendor/build.prop`)

| Property | Stock Value | Derived AOSP / crDroid UDFPS Parameter |
| :--- | :--- | :--- |
| `ro.hardware.fp.fod` | `true` | Optical UDFPS enabled |
| `ro.hardware.fp.fod.location` | `low` | Low-position optical sensor |
| `persist.vendor.sys.fp.fod.location.X_Y` | `437,2044` | Top-left corner `(437, 2044)` on `1080×2400` |
| `persist.vendor.sys.fp.fod.size.width_height` | `206,206` | Diameter `206 px` -> **Radius = `103 px`** |
| **Computed Center `(X, Y, R)`** | **`(540, 2147, 103)`** | Exact match for `persist.vendor.fingerprint.sensor_location=540\|2147\|103` (`437+103=540`, `2044+103=2147`) |

### 4.2 Stock UDFPS Software & Kernel Stack

1. **Kernel Driver (`goodix_fod.ko` + DTBO `fingerprint_goodix`)**:
   - Compatible `"goodix,fingerprint"`, regulator `l11c_vdd`, Reset GPIO 43 (`0x2b`), IRQ GPIO 34 (`0x22`).
   - Exposes char device `/dev/goodix_fp` (`chmod 0666`, `chown system system`) with ioctls `GF_IOC_INIT`, `GF_IOC_RESET`, `GF_IOC_ENABLE_POWER`, `GF_IOC_ENABLE_IRQ`, `GF_IOC_NAV_EVENT`, etc.
2. **HAL Daemon (`/vendor/bin/hw/mfp-daemon`, 64-bit ELF)**:
   - Started by `vendor/etc/init/init.mfp-daemon.rc` (`user system`, `group system drmrpc diag input uhid`, `seclabel u:r:vendor_mfp-daemon:s0`, `capabilities SYS_NICE`).
   - Registers **five HIDL services** across `AHBF@2.1-service.xml` and `fod.xml`:
     - `android.hardware.biometrics.fingerprint@2.1::IBiometricsFingerprint/default`
     - `vendor.xiaomi.hardware.fingerprintextension@1.0::IXiaomiFingerprint/default`
     - `com.fingerprints.extension@3.0::{IFingerprintSensorTest,IFingerprintNavigation}/default`
     - `vendor.xiaomi.hardware.fx.tunnel@1.0::IMiFxTunnel/default`
     - `vendor.xiaomi.hardware.dtool@1.0::IDtool/default`
   - Dynamically loads vendor sensor module `/vendor/lib64/hw/fingerprint.goodix_fod.so` -> `/vendor/lib64/libgf_hal.so` -> `libQSEEComAPI.so` (TrustZone Goodix TA).
   - Data/calibration dirs: `/data/vendor/goodix`, `/data/vendor/fpdump`, `/data/vendor/fingerprint`, `/data/vendor/misc/mi_fp`, `/mnt/vendor/persist/goodix`, `/mnt/vendor/persist/mi_fp`.
   - Feature XML: `vendor/etc/permissions/android.hardware.fingerprint.xml`; stock system UI companion: `product/app/MiuiBiometric3389/MiuiBiometric3389.apk` + `system_ext/lib64/vendor.xiaomi.hardware.fingerprintextension@1.0.so`.
3. **Display LHBM / HBM & Touch Handoff (Verified from ELF Strings & Init RCs)**:
   - `mfp-daemon` directly accesses:
     - `/dev/mi_display/disp_feature` (`set local hbm`, `"fod high brightness capture start"`, `"fod low brightness capture start"`, `"skip enable lhbm as fingerprint is idle"`)
     - `/sys/class/touch/touch_dev/fod_press_status` (touch press state)
     - `vendor.xiaomi.hw.touchfeature@1.0` (`ITouchFeature`, backed by `/dev/xiaomi-touch` & `/sys/class/touch/tp_dev/fod_status`)
     - `android.frameworks.sensorservice@1.0` (ambient lux check against `ro.hardware.fp.fod.lowlight.lux.threshold` for 110-nit vs 1000-nit LHBM!)
   - `fingerprint.goodix_fod.so` directly accesses:
     - `/sys/class/drm/card0-DSI-1/disp_param` (`gf_hal_set_hbm_cyan_status`, `hbm_fd`)
     - `/dev/input` (`gf_finger_pressure_detecting_thread`)
   - `init.mfp-daemon.rc` also sets permissions on `/sys/bus/platform/devices/soc:xiaomi_fingerprint/{fingerdown,actpower}`.
   - Panel DTBO `qcom,mdss_dsi_k9b_42_02_0a_dsc_cmd` provides full hardware LHBM DCS commands (`mi,mdss-dsi-local-hbm-normal-white-1000nit-command`, `...-110nit-command`, `...-hlpm-white-1000nit-command`, `...-normal-green-500nit-command`, `...-off-to-normal-command`, `...-off-to-hbm-command`) as well as global HBM FOD fallback (`mi,mdss-dsi-hbm-fod-{on,off}-command`).

### 4.3 Critical UDFPS Porting Notes for crDroid 13 (Android 17)

1. **HIDL 2.1 -> AIDL V4 Bridge Required**: Stock `mfp-daemon` only exposes HIDL `IBiometricsFingerprint@2.1` + `IXiaomiFingerprint@1.0`. Android 15/16/17 requires an **AIDL Fingerprint HAL** (with `onPointerDown`/`onPointerUp`/`onUiReady` UDFPS callbacks). Using `sm8350-common`'s open-source AIDL V4 wrapper (`android.hardware.biometrics.fingerprint-service.xiaomi` + `libudfpshandler`) sitting on top of stock `libgf_hal.so`/`fingerprint.goodix_fod.so` (or bridging `IXiaomiFingerprint@1.0`) is the proven path.
2. **Legacy Shared-Lib Dependencies on Goodix Blobs**:
   - `vendor/lib64/hw/fingerprint.goodix_fod.so` and `vendor/lib64/libgf_hal.so` BOTH link **`libhidltransport.so`**, **`libhwbinder.so`**, and **`libion.so`** (plus `libutils.so`, `libcutils.so`, `libhidlbase.so`, `libhardware.so`, `vendor.xiaomi.hardware.fx.tunnel@1.0.so`).
   - `vendor/bin/hw/mfp-daemon` additionally links **`libstagefright_foundation.so`**, **`android.frameworks.sensorservice@1.0.so`**, and **`libbinder.so`**.
   - On Android 16/17 (no VNDK 30 APEX), `libhidltransport.so` and `libhwbinder.so` MUST be replaced via `patchelf --replace-needed ... libhidlbase.so` (or empty shims), and `libion.so` / `libstagefright_foundation` / `libutils` compatibility shims must be supplied in `vendor`.

---

## 5. VINTF Manifest Inventory & 32-bit vs 64-bit HAL Audit

### 5.1 Active Stock HAL Inventory for `mona`

Merged from `vendor/etc/vintf/manifest_yupik.xml` (`target-level="5"`), `vendor/etc/vintf/manifest/*.xml`, and `odm/etc/vintf/manifest_mona.xml` (`target-level="5"`):

| Subsystem | Stock VINTF Interface(s) | Format | Version | Stock Service Binary & Arch | Porting Strategy (crDroid 13 / A17) |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **Audio** | `android.hardware.audio` / `.effect`<br>`android.hardware.bluetooth.audio`<br>`android.hardware.soundtrigger`<br>`vendor.dolby.hardware.dms` | HIDL | `6.0`<br>`2.0`<br>`2.3`<br>`2.0` | `android.hardware.audio.service` (**32-bit!**)<br>`vendor.dolby.hardware.dms@2.0-service` (64-bit) | **Rebuild from source** (`hardware/qcom-caf/sm8350/audio`, 64-bit HIDL 7.x / AIDL BT audio); drop 32-bit `audio.service` & `audio.primary.lahaina.so` (which links deprecated `android.hardware.power@1.2.so`). |
| **Camera** | `android.hardware.camera.provider`<br>`vendor.qti.hardware.camera.postproc`<br>`vendor.xiaomi.hardware.campostproc` | HIDL | `2.4`<br>`1.0`<br>`1.0` | `android.hardware.camera.provider@2.4-service_64` (64-bit) + `camera.xiaomi.so` + `camera.qcom.so` | **Keep proprietary CamX/CHI + Xiaomi blobs** with `patchelf` / shims (`libprotobuf-cpp-full-3.9.1.so`, `libhidltransport.so`, `libtinyxml2-v34.so`, `android.frameworks.sensorservice@1.0.so`). Rebuild open-source `camera.provider@2.4` wrapper or verify A17 cameraserver HIDL 2.4 compat. |
| **Display / Composer / Gralloc** | `android.hardware.graphics.composer`<br>`android.hardware.graphics.allocator` / `.mapper`<br>`vendor.qti.hardware.display.*`<br>`vendor.xiaomi.hardware.displayfeature` | HIDL | `2.4`<br>`3.0,4.0`<br>`3.0/4.0`<br>`1.0` | `vendor.qti.hardware.display.composer-service` (64-bit)<br>`vendor.qti.hardware.display.allocator-service` (64-bit)<br>`vendor.xiaomi.hardware.displayfeature@1.0-service` (64-bit) | **Rebuild Composer & Gralloc from source** (`hardware/qcom-caf/sm8350/display`, AIDL Composer3 / Mapper4) to eliminate `libui.so`/`libhidltransport.so` ABI breaks. |
| **Fingerprint / UDFPS** | `android.hardware.biometrics.fingerprint`<br>`vendor.xiaomi.hardware.fingerprintextension`<br>`vendor.xiaomi.hardware.fx.tunnel` | HIDL | `2.1`<br>`1.0`<br>`1.0` | `mfp-daemon` (64-bit) + `fingerprint.goodix_fod.so` + `libgf_hal.so` | **Replace top layer with AIDL V4** (`android.hardware.biometrics.fingerprint-service.xiaomi` from `sm8350-common` + `libudfpshandler`), shimming `libgf_hal.so`/`fingerprint.goodix_fod.so`. |
| **RIL / Modem / IMS / Data** | `android.hardware.radio` / `.config`<br>`android.hardware.tetheroffload.*`<br>`vendor.qti.hardware.radio.*` (`ims@1.7`, `qtiradio@2.6`, `am`, `uim`, `lpa`, `qcrilhook`)<br>`vendor.qti.hardware.data.*` (`connection@1.1`, `iwlan@1.0`) | HIDL | `1.5` / `1.1`<br>`1.0`<br>`1.0–2.6` | `qcrilNrd` (64-bit) + `libqcrilNr.so` + `imsdaemon` + `ims_rtp_daemon` + `cnd` + `dpmQmiMgr` | **HIGHEST A17 RISK**: Stock RIL is **HIDL `IRadio@1.5`** (FCM 5) and links `android.hardware.radio.deprecated@1.0.so` & `libprotobuf-cpp-full-3.9.1.so`. Check `sm8350-common` `lineage-24.0` — prefer upgrading QCRIL/IMS blobs to AIDL-capable SM8350/SM7325 vendor blobs (`TheMuppets/sm8350-common` `lineage-24.0`) if Android 17 Telephony drops HIDL 1.5! |
| **Sensors** | `android.hardware.sensors` (multihal)<br>`vendor.qti.hardware.sensorscalibrate`<br>`vendor.xiaomi.sensor.communicate` | HIDL | `2.0` (`2.1` lib)<br>`1.0`<br>`1.0` | `android.hardware.sensors@2.0-service.multihal` (64-bit) + `sensors.qti` + `sensors.elliptic@2.0.so` | **Upgrade to AIDL Sensors MultiHAL** (`sm8350-common` `lineage-24.0`) loading QTI SSC + `sensors.xiaomi.v2` (for UDFPS/AOD/pickup) + Elliptic proximity sub-HAL. |
| **Keymaster & Gatekeeper** | `android.hardware.keymaster`<br>`android.hardware.gatekeeper` | HIDL | `4.1`<br>`1.0` | `android.hardware.keymaster@4.1-service-qti` (64-bit)<br>`android.hardware.gatekeeper@1.0-service-qti` (64-bit) | Keep `keymaster@4.1` (or `sm8350-common` `keymint` wrapper if compatible with stock `keymaster.img` TA) + `gatekeeper@1.0`; note `libcrypto.so` -> `libcrypto-v33.so` shim needed! |
| **DRM (Widevine & Clearkey)** | `android.hardware.drm` (`widevine`, `clearkey`, `wfdhdcp`) | HIDL | `1.3` | `android.hardware.drm@1.3-service.widevine` (64-bit)<br>`android.hardware.drm@1.3-service.clearkey` (64-bit) | **HIGH A17 RISK**: Android 16/17 requires **AIDL DRM** (`android.hardware.drm-service.clearkey` built from source + newer **AIDL Widevine L1** blobs from `TheMuppets/sm8350-common`). Stock HIDL 1.3 Widevine will not work on A17. |
| **Media Codecs (C2 / OMX / CAS)** | `android.hardware.media.c2` (`default`, `ozoaudio`, `dolby`)<br>`android.hardware.media.omx`<br>`android.hardware.cas` | HIDL | `1.0`<br>`1.0`<br>`1.2` | `vendor.qti.media.c2@1.0-service` (**32-bit!**)<br>`android.hardware.media.omx@1.0-service` (**32-bit!**)<br>`dolbycodec2` (**32-bit!**)<br>`android.hardware.cas@1.2-service` (**32-bit!**) | **Drop `media.omx@1.0` completely** (removed in Android 15+). Rebuild `media.c2` (64-bit `hardware/qcom-caf/sm8350/media`) and AIDL CAS from source. |
| **Wi-Fi & Bluetooth** | `android.hardware.wifi` (`1.4`), `hostapd` (`1.2`), `supplicant` (`1.3`)<br>`android.hardware.bluetooth` (`1.0`) | HIDL | `1.0–1.4` | `android.hardware.wifi@1.0-service`, `hostapd`, `wpa_supplicant`, `android.hardware.bluetooth@1.0-service-qti` (all 64-bit) | **Rebuild ALL from source as AIDL** (`android.hardware.wifi-service`, AIDL `wpa_supplicant`/`hostapd`, `android.hardware.bluetooth-service.qti` / LineageOS BT HAL). |
| **NFC & Secure Element** | `android.hardware.nfc` (`1.2`), `vendor.nxp.hardware.nfc` (`2.0`)<br>`android.hardware.secure_element` (`1.2`: `SIM1`, `eSE1`) | HIDL | `1.2` / `2.0` | `vendor.nxp.hardware.nfc@2.0-service` (64-bit)<br>`vendor.qti.secure_element@1.2-service` (64-bit) | **Upgrade NFC to AIDL** (`android.hardware.nfc-service.nxp` / SN100 open-source NXP AIDL HAL in LineageOS) + keep `libnfc-mtp-SN100.conf` / `libnfc-nxp.conf`. |
| **Power / Thermal / Health / Light / Vibrator / IR / USB / Boot / GNSS / Memtrack** | `android.hardware.power` (AIDL)<br>`android.hardware.light` (AIDL)<br>`android.hardware.vibrator` (AIDL `vibratorfeature`)<br>`android.hardware.thermal` (`2.0`), `health` (`2.1`), `ir` (`1.0`), `usb` (`1.2`), `boot` (`1.1`), `gnss` (`2.1`), `memtrack` (`1.0`) | Mixed (3 AIDL, 7 HIDL) | — | All 64-bit (`vendor/bin/hw/*`) | **Rebuild ALL from source as modern AIDL HALs** via `sm8350-common` (`lineage-24.0`): Power, Thermal, Health, Lights, Vibrator (`IVibrator/default` for AW8622x/AW8624), ConsumerIR (`ir-spi-led`), USB, BootControl, Memtrack; GNSS from `hardware/qcom-caf/sm8350/gps` + QTI location blobs. |

### 5.2 32-bit vs 64-bit Vendor Binary Breakdown

- **Vendor/ODM HAL & Service Executables Audited**: **105 total** -> **99 are 64-bit (`ELF64`)**, only **6 are 32-bit (`ELF32`)**:
  1. `vendor/bin/hw/android.hardware.audio.service` (32-bit -> **replace with 64-bit source-built audio HAL**)
  2. `vendor/bin/hw/vendor.qti.media.c2@1.0-service` (32-bit -> **replace with 64-bit source-built QTI C2 HAL**)
  3. `vendor/bin/hw/android.hardware.media.omx@1.0-service` (32-bit -> **drop**, OMX obsolete in A15+)
  4. `vendor/bin/hw/dolbycodec2` (32-bit -> optional/drop or replace)
  5. `vendor/bin/hw/android.hardware.cas@1.2-service` (32-bit -> **replace with 64-bit AIDL CAS**)
  6. `vendor/bin/wifidisplayhalservice` (32-bit -> optional Miracast/WFD, can upgrade/drop)
- **Vendor Shared Library Counts**: `vendor/lib` has **809** `.so`s (+ 72 in `lib/hw`), `vendor/lib64` has **891** `.so`s (+ 71 in `lib64/hw`). Note that all critical proprietary blobs we MUST retain from `mona` (`camera.qcom.so`, `camera.xiaomi.so`, `com.qti.sensor.mona_*.so`, `libgf_hal.so`, `fingerprint.goodix_fod.so`, `qcrilNrd`/`libqcrilNr.so`, `sensors.elliptic@2.0.so`) already ship **64-bit (`ELF64`)** variants!

---

## 6. Critical ELF `DT_NEEDED` & ABI / HAL Risk Audit (crDroid 13 / Android 17 vs crDroid 12 / Android 16)

Scanning **154 critical vendor/odm ELF targets** via `readelf -d` identified the exact non-vendor external dependencies that pose ABI breakage risks once VNDK 30 is absent:

### 6.1 High-Impact Missing / Changed Libraries (`readelf -d` Ground Truth)

| External `DT_NEEDED` Library | Affected Critical `mona` Blobs (Count & Examples) | Why It Breaks on Android 16/17 & Exact Fix |
| :--- | :--- | :--- |
| **`libutils.so`** (VNDK 30 ABI) | 85 64-bit / 23 32-bit (`camera.qcom.so`, `camera.xiaomi.so`, `libgf_hal.so`, `fingerprint.goodix_fod.so`, `mfp-daemon`, `libqcrilNr.so`, `audio.primary.lahaina.so`, `keymaster@4.1`, `widevine`) | Android 14+ changed `android::RefBase` / `String8` / `Vector` ABI and Android 15+ removed VNDK APEXes (`com.android.vndk.v30.apex`). **Fix**: `patchelf --replace-needed libutils.so libutils-v32.so` (or `libutils-v33.so` from LineageOS `android_vendor_lineage` / `sm8350-common` compat prebuilts) on kept stock blobs! |
| **`libhidltransport.so`** & **`libhwbinder.so`** | `fingerprint.goodix_fod.so`, `libgf_hal.so`, `camera.qcom.so`, `camera.xiaomi.so`, `vendor.qti.hardware.display.composer-service`, `vendor.qti.media.c2@1.0-service` | Merged into `libhidlbase.so` and removed as separate VNDK libs in Android 15+. **Fix**: `patchelf --remove-needed` or `--replace-needed libhidltransport.so libhidlbase.so` (and same for `libhwbinder.so`), since `libhidlbase.so` is already in `DT_NEEDED`! |
| **`libion.so`** | `fingerprint.goodix_fod.so`, `libgf_hal.so` (both 64-bit and 32-bit) | Legacy ION allocator lib removed from AOSP (replaced by `libdmabufheap`). **Fix**: Ship `libion.so` (vendor prebuilt or source-built compat lib in `vendor/lib64`) — `sm8350-common` handles this cleanly. |
| **`libprotobuf-cpp-full-3.9.1.so`** | `camera.qcom.so`, `libqcrilNr.so`, `com.qti.chi.override.so` | Version-pinned VNDK 30 protobuf. **Fix**: Extract and keep `vendor/lib64/libprotobuf-cpp-full-3.9.1.so` (or `libprotobuf-cpp-full-3.9.1-vendorcompat.so`) in `vendor_xiaomi_mona` / `sm8350-common`. |
| **`libtinyxml2.so`** / **`libxml2.so`** / **`libsqlite.so`** | `camera.qcom.so` (`libtinyxml2.so`), `libqcrilNr.so` (`libxml2.so`, `libsqlite.so`) | `libtinyxml2.so` changed soname/ABI in Android 15+ (`libtinyxml2-v34.so`). **Fix**: `patchelf --replace-needed libtinyxml2.so libtinyxml2-v34.so` (standard `sm8350-common` `extract-files.py` fixup). |
| **`libcrypto.so`** / **`libssl.so`** | `android.hardware.keymaster@4.1-service-qti`, `libwvhidl.so`, `hostapd`, `wpa_supplicant` | BoringSSL ABI evolves every Android release (no VNDK 30). **Fix**: Rebuild `hostapd`/`wpa_supplicant` from source; patch `keymaster`/`libqtikeymaster4.so` to `libcrypto-v33.so` (or use `sm8350-common` updated keymint/keymaster blobs). |
| **`libstagefright_foundation.so`** & **`android.frameworks.sensorservice@1.0.so`** | `mfp-daemon`, `camera.qcom.so`, `vendor.xiaomi.sensor.communicate@1.0-service` | `libstagefright_foundation` ABI shifted; `android.frameworks.sensorservice@1.0` HIDL framework interface is deprecated in favor of AIDL `ISensorManager`. **Fix**: Replace `mfp-daemon` with AIDL V4 `fingerprint-service.xiaomi` (eliminates `libstagefright_foundation` dep completely!); verify `android.frameworks.sensorservice@1.0` compat shim (`libframeworks_sensorservice_shim` / `sm8350-common` `camera.qcom.so` fixup). |
| **`libui.so`** & **`android.hardware.graphics.{mapper,allocator}@2.0/2.1/3.0/4.0.so`** | `composer-service` (`libui.so`), `camera.qcom.so`, `camera.xiaomi.so`, `camx*` | `libui.so` breaks across major Android versions -> **solved by rebuilding Display/Composer/Gralloc from source**. Camera blobs still link HIDL `mapper@2.0/3.0/4.0` & `allocator@3.0/4.0` -> ensure `vendor` provides HIDL mapper/allocator compat libs alongside AIDL display HALs. |
| **`android.hardware.power@1.2.so`** | `audio.primary.lahaina.so` | Removed in modern Android -> **solved automatically** by rebuilding Audio HAL from `hardware/qcom-caf/sm8350/audio`. |
| **`android.hardware.radio@1.0–1.5.so`** & **`radio.deprecated@1.0.so`** | `libqcrilNr.so` (stock Android 11 GRF RIL) | **Major A17 risk** if `libqcrilNr.so` from `mona` stock is kept verbatim. **Fix**: Prefer `TheMuppets/proprietary_vendor_xiaomi_sm8350-common` (`lineage-24.0`) common QCRIL/IMS blobs (from newer HyperOS/Android 13–14 SM8350/SM7325 vendor) paired with `mona` stock `modem.img` / MBNs, falling back to `mona` stock RIL only if modem QMI version mismatches. |

### 6.2 Risk Matrix: crDroid 13 (Android 17 / LOS 24.0) vs crDroid 12 (Android 16 / LOS 23.2)

| Risk Area | Severity on crDroid 13 (Android 17) | Severity on crDroid 12 (Android 16) | Concrete Engineering Mitigation |
| :--- | :---: | :---: | :--- |
| **1. Kernel 5.4 BPF / NetBpfLoad / Userfaultfd / DLKM** | **CRITICAL** (if stock 5.4.233 used)<br>**LOW** (with source-built LOS 5.4.302) | **HIGH** (stock 5.4.233)<br>**LOW** (LOS 5.4.302) | Build `LineageOS/android_kernel_xiaomi_sm8350` (`lineage-24.0`, Linux `5.4.302` with AOSP BPF/userfaultfd backports + `ro.bpf.kver_override=5.10.239` + `mona` DTS/configs already present upstream!). |
| **2. VNDK 30 Removal & Shared-Lib ABI Drift (`libutils`, `libhidltransport`, `libtinyxml2`, `libion`, `libcrypto`)** | **HIGH** (for `mona`-specific camera + Goodix blobs) | **HIGH** (same — VNDK dropped in Android 15) | Apply standard `sm8350-common` `extract-files.py` `blob_fixup` (`patchelf --replace-needed` to `libutils-v32`/`libtinyxml2-v34`/`libhidlbase`/`libcrypto-v33`) and bundle `libprotobuf-cpp-full-3.9.1.so` + `libion.so` in vendor. |
| **3. Legacy HIDL HAL Removal (`DRM@1.3`, `OMX@1.0`, `Radio@1.5`, `Fingerprint@2.1`, `Audio@6.0`, `Composer@2.4`)** | **HIGH** (Android 17 tightens FCM/HIDL deprecation; DRM 1.3 & OMX dead; FP must be AIDL V4) | **MEDIUM-HIGH** (same core HIDL->AIDL transitions already completed in LOS 23.2 `sm8350-common`) | Inherit `LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`) + `TheMuppets/proprietary_vendor_xiaomi_sm8350-common` (`lineage-24.0`), which ALREADY replaces Audio, Composer/Gralloc, Wi-Fi, BT, NFC, IR, Vibrator, Lights, Power, Thermal, Health, Sensors, DRM Widevine, and Fingerprint with AIDL/updated HALs! Only `mona`-specific camera (`S5KGW3`/`IMX616`/`IMX355`/`GC02M1`), `mona` audio ACDB/AW882xx firmware/mixer, `mona` S3908P touch fw, `mona` sensor configs/Elliptic, `mona` QDCM/panel XML, and Goodix FOD blobs come from this `OS1.0.2.0.TKVCNXM` dump! |
| **4. Optical UDFPS (Goodix FOD + K9B LHBM + S3908P Touch)** | **MEDIUM** (device-specific integration) | **MEDIUM** (identical kernel/HAL path) | Use `sm8350-common` AIDL V4 `fingerprint-service.xiaomi` + `libudfpshandler` + `sensors.xiaomi.v2` with exact stock coordinates `540\|2147\|103`, plus `K9B` LHBM & `synaptics_s3908p` `update_fod_press_status` kernel fixes. |
| **5. Front Dual Soft-Light Flash (`led:torch_1/2` + `led:switch_1`)** | **LOW-MEDIUM** (camera HAL + sysfs exposure) | **LOW-MEDIUM** | Preserve `pm8350c_flash{1,2}`/`torch{1,2}`/`switch1` (`led-mask=0x06`) -> `qcom,camera-flash@3` -> `cam-sensor1` in `mona-sm7325-camera-sensor.dtsi` and SELinux labels for `/sys/class/leds/led:{torch,flash,switch}_*` so Camera2 front flash and optional QS/XiaomiParts soft-light toggle work cleanly. |
| **6. 32-bit Vendor HALs (6 stock binaries)** | **LOW** (once rebuilt/dropped) | **LOW** | Dropping `media.omx@1.0` and building 64-bit Audio/C2/CAS removes all 6 32-bit HAL services while keeping 32-bit app compatibility (`zygote64_32`) if desired. |

### 6.3 Bottom-Line Readiness Assessment

- **Stock Dump Status**: **100% acquired, checksum-verified, extracted, and audited** under `<stock-dump>/OS1.0.2.0.TKVCNXM/` — ready for immediate Phase 2 `extract-files.py` blob extraction!
- **crDroid 13 (Android 17 / LineageOS 24.0) Feasibility**: **HIGH / GO**. Because `LineageOS/android_device_xiaomi_sm8350-common` (`lineage-24.0`) + `LineageOS/android_kernel_xiaomi_sm8350` (5.4.302) already solve the hardest platform-wide Android 17 blockers (VNDK 30 shims, BPF 5.4 backports, AIDL Fingerprint V4/Audio/Display/DRM/RIL/Sensors/Wi-Fi/BT/NFC/Vibrator), the `OS1.0.2.0.TKVCNXM` dump only needs to supply **device-specific `mona` blobs & configs** (camera sensors/tuning/Actuators/EEPROMs, AW882xx PA firmware & mixer paths, Synaptics S3908P firmware, AW8622x/AW8624 haptic waveforms, SLPI `sm7350_*` sensor JSONs & Elliptic proximity, K9B QDCM calibration, Goodix FOD vendor libs if not shared with `sm8350-common`, and `qca6750` Wi-Fi/NFC configs).
