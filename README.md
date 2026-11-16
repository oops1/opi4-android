# Android 16 for Orange Pi 4 (RK3399)

**Русский** · [English](#english)

Неофициальная сборка **Android 16** и **Android TV 16** для платы **Orange Pi 4** (RK3399, 4 ГБ).
Основа — чистый AOSP `android-16.0.0_r4`, слой [GloDroid](https://github.com/GloDroid) и
основное (mainline) ядро Linux 6.18 LTS.

**Статус: бета.** Работает: HDMI (видео и звук), Wi‑Fi 5 ГГц, Bluetooth, Ethernet, USB,
аппаратное декодирование видео (HEVC/H.264), GPU Mali‑T860 (OpenGL ES 3.1), GPIO/I2C/SPI/PWM.
Не работает: ИК‑пульт, защищённое видео онлайн‑кинотеатров (нет Widevine).

* **Скачать:** [Releases](https://github.com/oops1/opi4-android/releases)
* **Инструкция по установке:** [docs/INSTALL.ru.md](docs/INSTALL.ru.md) — простыми словами:
  карта памяти, встроенная память, сервисы Google, бэкап и решение проблем.
* **Корпус и крепление вентилятора** для 3D‑печати: [hardware/case](hardware/case)
* **Сообщить об ошибке:** [Issues](https://github.com/oops1/opi4-android/issues)

| Образ | Что это | Root |
|---|---|---|
| `opi4-android16-tv-…` | Android TV: приставка к телевизору, сборка `user`, SELinux enforcing, подписана своими ключами | нет |
| `opi4-android16-tablet-…` | обычный Android для поделок и экспериментов, сборка `userdebug` | `adb root` |

Сервисов Google и Widevine в образах нет: их распространяет только Google. Сервисы Google
(MindTheGapps) ставятся с USB‑флешки без root — см. инструкцию.

---

## English

Unofficial **Android 16** and **Android TV 16** build for the **Orange Pi 4** board (RK3399, 4 GB).
Based on plain AOSP `android-16.0.0_r4`, the [GloDroid](https://github.com/GloDroid) layer and
the mainline Linux 6.18 LTS kernel.

**Status: beta.** Works: HDMI (video and audio), 5 GHz Wi‑Fi, Bluetooth, Ethernet, USB,
hardware video decoding (HEVC/H.264), Mali‑T860 GPU (OpenGL ES 3.1), GPIO/I2C/SPI/PWM.
Does not work: IR remote, protected video in streaming apps (no Widevine).

* **Download:** [Releases](https://github.com/oops1/opi4-android/releases)
* **Installation guide:** [docs/INSTALL.en.md](docs/INSTALL.en.md) — in plain words: memory
  card, built-in memory, Google services, backup and troubleshooting.
* **3D-printable case and fan mount:** [hardware/case](hardware/case)
* **Report a bug:** [Issues](https://github.com/oops1/opi4-android/issues)

| Image | What it is | Root |
|---|---|---|
| `opi4-android16-tv-…` | Android TV box, `user` build, SELinux enforcing, signed with our own keys | no |
| `opi4-android16-tablet-…` | regular Android for DIY and experiments, `userdebug` build | `adb root` |

The images contain no Google services and no Widevine: only Google may distribute them.
Google services (MindTheGapps) install from a USB stick without root — see the guide.

---

## Building from source

Linux (Ubuntu 22.04, WSL2 works too), about 400 GB of free disk space, 32 GB of RAM or more.

```bash
# 1. AOSP 16
mkdir -p ~/aosp && cd ~/aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-16.0.0_r4
# 2. GloDroid a-16 patches and the kernel (setup.sh expects them in ~/opi4)
git clone -b a-16 https://github.com/GloDroidCommunity/raspberry-pi.git ~/opi4/glodroid-a16
git clone --depth 1 -b v6.18.63 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ~/opi4/linux
# 3. This repo
git clone https://github.com/oops1/opi4-android.git ~/opi4/opi4-android
cd ~/opi4/opi4-android
./setup.sh manifest                       # local manifest -> ~/aosp/.repo/local_manifests
cd ~/aosp && repo sync -c -j8 --no-tags
cd ~/opi4/opi4-android && ./setup.sh tree # copy device/opi4, apply GloDroid a-16 + our patches
# 4. Images
bash tools/build-release.sh opi4_tv user  # TV image, needs your own signing keys in ~/opi4/keys
bash tools/build-release.sh opi4 userdebug
```

`tools/build-release.sh` builds without GApps/Widevine at full clocks and packs the SD card
image, the eMMC kit and checksums (`tools/package-release.sh`). `user` builds are signed with
your own keys in `~/opi4/keys` (create them with AOSP `development/tools/make_key`); never sign
them with the public AOSP test keys.

### Layout

| Path | What |
|---|---|
| `manifests/opi4.xml` | local repo manifest: GloDroid a-16 components plus rkbin |
| `device/opi4/` | device config, copied to `vendor/devices-community/opi4` |
| `device/opi4/kernel.config`, `kernel-patches/` | kernel config fragment, Orange Pi 4 DT and driver patches (from Armbian) |
| `device/opi4/firmware/` | AP6256 Wi‑Fi/BT firmware (armbian/firmware) |
| `device/opi4/gapps/` | installer for Google apps from a USB stick |
| `device/opi4/sepolicy/` | SELinux policy |
| `patches-aosp/` | our patches to AOSP/GloDroid, applied after the GloDroid a-16 ones |
| `tools/` | build, packaging and helper scripts |
| `docs/` | installation guides (RU/EN) |
| `hardware/case/` | OpenSCAD case and fan mount, ready-to-print STL files |

## Лицензия / License

Всё, что создано в этом проекте, — скрипты, конфигурация устройства, установщик GApps,
SELinux‑политика, инструкции, загрузочная анимация, модели корпуса — распространяется по
лицензии **[Apache 2.0](LICENSE)**, как AOSP и GloDroid. Исключения — чужой код и прошивки,
у них остаются свои лицензии:

Everything created in this project — scripts, device configuration, the GApps installer, SELinux
policy, guides, boot animation, case models — is licensed under **[Apache 2.0](LICENSE)**, like
AOSP and GloDroid. Exceptions are third-party code and firmware, which keep their own licenses:

| Path | License |
|---|---|
| `device/opi4/kernel-patches*/` | GPL-2.0 — patches to the Linux kernel (partly from [Armbian](https://github.com/armbian/build)) |
| `patches-aosp/glodroid/bootloader/u-boot/` | GPL-2.0+ — patch to U-Boot (from Armbian) |
| other `patches-aosp/` | the license of the patched project (GloDroid: Apache-2.0) |
| `device/opi4/firmware/` | proprietary firmware, redistributable under the vendors' terms: Broadcom/Cypress Wi‑Fi/BT (AP6256), Rockchip `dptx.bin` — from [armbian/firmware](https://github.com/armbian/firmware), see `LICENCE.cypress`, `LICENCE.broadcom_bcm43xx` and `LICENCE.rockchip` in [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git) |

The kernel in the release images is built from Linux `v6.18.63` (kernel.org stable) with
`device/opi4/kernel-patches/` and `device/opi4/kernel.config` (on top of the arm64 defconfig
and the GloDroid a-16 kernel fragments) from the matching commit of this repository; the
release tag marks that commit. Google services and Widevine are not
part of this project or of its images.
