# Ubuntu Touch 24.04 for the Samsung Galaxy Tab S9 Ultra Wi-Fi

Ubuntu Touch 24.04 port for the **Samsung Galaxy Tab S9 Ultra Wi-Fi**
(**SM-X910**, codename `gts9uwifi`, Snapdragon 8 Gen 2 / SM8550 "kalama").

This is a fork of [Azkali's `samsung-gts9`](https://gitlab.com/azkali-samsung/gts9/ubports/samsung-gts9),
the Ubuntu Touch port for the Tab S9 11" (SM-X710, `gts9wifi`). The Halium 13
adaptation, the kernel tree, the vendor module set and the whole build pipeline
are his work; this branch only carries the delta needed to make the Ultra boot
and to bring its hardware up. **If you own the Tab S9 11", use his repository,
not this one.**

The kernel is shared with the reference port —
[`kernel-samsung-gts9wifi`](https://gitlab.com/azkali-samsung/gts9/ubports/kernel-samsung-gts9wifi),
branch `android13-5.15-halium`. The SM-X910 differences (Goodix Berlin touch
controller, Ultra panel cmdline, `kiwi_v2` WLAN, a `dataipa` probe header) are
applied on top at build time by `scripts/prepare-kernel-gts9uwifi.sh`, so no
kernel fork is needed.

## Status

Ubuntu Touch boots and is usable as a tablet. The last build validated after a
clean flash is **v7**; **v8** adds writable package management, was verified in
the running system and passed static validation, but has not yet been
re-validated from a clean flash.

| Component | Status | Notes |
|---|---|---|
| **Display** | ✅ | Native panel selected by the stock `msm_drm.dsi_display0` cmdline |
| **Shell** | ✅ | Lomiri on Mir, tablet form factor |
| **GPU** | ✅ | Adreno 740 through the Android graphics stack (libhybris) |
| **Touchscreen** | ✅ | Goodix Berlin / GT9916, driver imported for the Ultra |
| **Wi-Fi** | ✅ | `kiwi_v2` / qcacld-3.0; needs the `cnss/fs_ready` write |
| **Speakers / microphones** | ✅ | Four speakers and microphone capture through PulseAudio; validated with real playback and recording |
| **Motion sensors** | ✅ | Accelerometer, gyroscope and autorotation, via the ADSP `sensor_pd` |
| **Battery and charging** | ✅ | Telemetry and charging work; the reported percentage is occasionally wrong on some boots |
| **Storage** | ✅ | Installs to the device's own UFS dynamic partitions (`super`) |
| **Package management** | ✅ | `apt` works after the writable-rootfs fix; PPAs installable |
| **Core applications** | ✅ | Morph browser, File manager and Terminal launch and survive reboots |
| **Waydroid** | ✅ | Android applications run without issues |
| **Audio/sensor DSPs** | ✅ | Prerequisite for audio and sensors; both reach `running` |
| **SSH over Wi-Fi** | ✅ | Development access, opt-in and shipped without any key — see below |
| **USB gadget** | 🟡 | Enumerates as `18d1:6860` but the host does not mount the MTP volume |
| **Bluetooth** | ❌ | `bluebinder` starts, the chip does not respond |
| **USB host** | ❌ | `dwc3` is deliberately forced to `peripheral`; host mode would need the charger fix the reference port carries |
| **S Pen** | ❌ | Not integrated |
| **Fingerprint / haptics** | ❌ | Not brought up |
| **Flash / cameras** | ❌ | Not started |
| **Backlight / blanking** | ❔ | Not validated |
| **Buttons** | ❔ | Power and volume not explicitly validated |
| **Suspend / resume** | ❔ | Not validated |
| **USB-C DisplayPort** | ❔ | Not validated |
| **Ethernet / UAS** | ❔ | RTL8153 not tested |
| **Book cover** | ❔ | Hall switch not tested |
| **Ambient light** | ❔ | STK31610 not tested |
| **Keyboard cover** | ❔ | Samsung EF-DX920 pogo keyboard not tested |
| **Hardware video decode** | ❔ | `msm_video.ko` kept stock, as the reference port does; not tested here |
| **Speaker protection** | ❔ | Cirrus protection DSP not tested |
| **Modem** | — | Not applicable to the Wi-Fi-only model |

✅ tested on the physical tablet · 🟡 partially working · ❌ known not to work
or not integrated · ❔ not tested yet · — not applicable

Every ✅ entry was tested on the physical tablet. A driver merely binding is
not considered proof that a subsystem works, and nothing is marked ✅ because
it works on another operating system on the same hardware.

## What this branch adds on top of the reference port

The Ultra needs more than a different device tree; without the Android
framework several bring-up steps that stock `init` performs never happen. The
commits in this branch are, in order of how much they mattered:

- **Wi-Fi.** `/sys/kernel/cnss/fs_ready` must be written before the `/dev/wlan`
  trigger, mirroring `init.target.rc`.
- **Audio and sensors.** Both live in ADSP *protection domains* and only come
  up once `/vendor/bin/pd-mapper` publishes them to the service registry. That
  daemon has to be alive **before the first ADSP boot** but after the container
  mounts `firmware_mnt`; SSR is kept only as a fallback. PulseAudio then
  crashed in `audio.hidl_compat` because `audio.primary.kalama` refused to
  open: `/sys/kernel/snd_card/card_state` and `/sys/kernel/aud_dev/state`
  appear late as `0660 root:root` while AGM runs as gid 1005, so it exhausted
  its retries and forced the primary-default fallback. Fixing the ownership
  and letting the HAL start makes speakers and microphone work.
- **DSPs.** `/sys/kernel/boot_{a,c}dsp/boot` is written by `ut-hw-bringup`
  after the container is up, because doing it earlier breaks PIL.
- **Click applications.** Lomiri rejected every Click app as `Invalid app ID`
  because `~/.cache/lomiri-app-launch/desktop` was missing entirely;
  `click hook run-user` rebuilds it.
- **Writable rootfs for APT.** `apt update` failed on a read-only root before
  reaching any mirror. The root is remounted `rw` and APT's volatile
  directories are recreated each boot.
- **USB.** The stock DTB ships `dr_mode="otg"`; the port needs `peripheral`,
  patched with `fdtput` as the reference port does.
- **Partitions.** `mount-android-partitions` could not create mount points on a
  read-only root, which left `vendor_dlkm` and `sec_efs` unmounted.

## Building

Requires a Linux host (WSL2 works) and the stock **SM-X910 X910XXS5CYG1**
firmware. The dynamic partition images come from your own firmware download —
they are proprietary and are not distributed here. The X710 firmware used by
the reference port **must not** be used.

```bash
git clone <this-repo> samsung-gts9u
cd samsung-gts9u
scripts/import-stock-partitions.sh /path/to/lpunpack-output-of-stock-super
./build.sh
```

`build.sh` clones the build tools, the kernel and the ten Qualcomm vendor
module trees on first run, applies the SM-X910 kernel preparation, builds the
Ubuntu Touch rootfs and produces `out/`. `scripts/make-flashable.sh` packages
the TWRP-installable ZIP.

## Installing

Unlocked bootloader and TWRP, same as the reference port. Flash the ZIP you
built yourself or downloaded from
[releases](https://github.com/agcarbajo/ubuntu-touch-galaxy-tab-s9-ultra/releases).
Coming from Android you have to format data first in TWRP, which **erases
everything on the tablet**; updating an existing Ubuntu Touch install does not.

The ZIP itself writes **only** `boot`, `init_boot`, `vendor_boot`, `vbmeta` and
`super`. It never touches `recovery`, `dtbo`, `efs`, `persist`, the bootloader
or the PIT. After the writes it removes a known list of development units and
injected scripts from userdata; it does not format userdata or delete user
content on its own.

Restoring stock is a normal Odin flash of the official firmware.

## Development SSH

`ut-ssh-enable.service` ships **disabled**, and **no key is bundled**. Enable
it on the device only when you need it:

```bash
sudo systemctl enable --now ut-ssh-enable
```

To have your own key installed automatically, drop its public half at
`overlay/system/usr/share/gts9uwifi/authorized_keys` before building — the path
is gitignored so it cannot be committed by accident. Without a key sshd falls
back to password authentication, which on Ubuntu Touch means the screen unlock
passphrase, so do not leave the service enabled on a network you do not trust.

## Credits

- **[Azkali](https://gitlab.com/Azkali)** — the Tab S9 port this one is derived
  from, and the Halium 13 work that makes it possible.
- **[Halium](https://halium.org)** and **[UBports](https://ubports.com)** —
  the platform.

## Licensing

This repository is a fork of an upstream that carries no license file;
inherited files keep whatever terms upstream applies to them, and the changes
in this branch are offered on the same basis. The overlay also redistributes
Samsung and Qualcomm binaries — panel calibration data, Goodix touch firmware
and a gralloc shim — solely for device enablement; they are proprietary and
are not covered by any license granted here. Stock dynamic partition images
are never committed and must be extracted from your own firmware download.
