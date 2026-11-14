# opi4-android — Android 16 (+ Android TV) для Orange Pi 4 (RK3399)

Порт на чистом AOSP `android-16.0.0_r4` со слоем [GloDroid](https://github.com/GloDroid) (ветка a-16):
mainline-ядро 6.18 LTS, Mesa Panfrost (GLES 3.1), drm_hwcomposer, minigbm, ffmpeg_codec2 (V4L2 request API).

| Продукт | lunch |
|---------|-------|
| Планшетный Android | `opi4-trunk_staging-userdebug` |
| Android TV (Leanback) | `opi4_tv-trunk_staging-userdebug` |

## Структура
- `manifests/opi4.xml` — локальный манифест: компоненты GloDroid a-16 без Raspberry Pi, плюс rkbin.
- `device/opi4/` — конфигурация устройства (линкуется в `vendor/devices-community/opi4`).
  - `kernel.config` — фрагмент ядра поверх arm64 defconfig.
  - `kernel-patches/` — DT Orange Pi 4 и два драйверных патча из Armbian (rockchip64-6.18).
  - `firmware/` — прошивки AP6256 (armbian/firmware).
- `patches-aosp/` — наши патчи к AOSP/GloDroid (накладываются после патчей a-16).
- `tools/import-files.sh` — заново импортирует DT, прошивки и заголовки из `~/opi4`.

## Порядок
```bash
./setup.sh manifest                 # локальный манифест в ~/aosp/.repo/local_manifests
cd ~/aosp && repo sync -c -j8 --no-tags
cd ~/opi4/opi4-android && ./setup.sh tree   # симлинки + патчи GloDroid a-16 + наши
cd ~/aosp && . build/envsetup.sh && lunch opi4-trunk_staging-userdebug && make images
```

## Статус / TODO
- [x] DT Orange Pi 4 + патчи Armbian накладываются на 6.18.63, DT собирается.
- [ ] U-Boot: добавить orangepi-4 defconfig/dts в ревизию GloDroid и собирать `u-boot-rockchip.bin`
      (binman, TF-A BL31, TPL = DDR-блоб rkbin) вместо старой схемы rkbin miniloader/trust в
      `glodroid/configuration/platform/uboot/uboot.mk` (флаг `RK_MAINLINE_UBOOT`).
- [ ] Уточнить имя DDR-блоба в rkbin (`RK_TPL_BLOB`) после синхронизации.
- [ ] nvram Wi-Fi: взять родной `nvram_ap6256.txt` со стоковой прошивки.
- [ ] HDMI-звук: DT Armbian использует свою карту `rockchip,rk3399-hdmi-dp`, в mainline её нет.
- [ ] ИК-пульт, HDMI-CEC HAL для TV.
