@echo off
rem Orange Pi 4: install Android into the on-board eMMC with fastboot (Windows).
rem Same steps as GloDroid's flash-all.sh. Needs fastboot.exe (Android SDK Platform-Tools)
rem next to this script or in PATH. The board must be booted from deploy-sd-for-emmc.img.
setlocal
cd /d "%~dp0"
set FB=fastboot
if exist "%~dp0fastboot.exe" set FB="%~dp0fastboot.exe"

echo Looking for the board in fastboot mode...
%FB% devices | findstr /r /c:"fastboot" >nul || (
  echo No fastboot device. Boot the board from the deploy SD card with USB-C connected to this PC.
  pause & exit /b 1
)

echo === Step 1/2: partition table and bootloader
%FB% flash gpt deploy-gpt.img || goto :fail
%FB% flash bootloader bootloader-emmc.img || goto :fail
%FB% flash uboot-env env.img || goto :fail
%FB% reboot

echo.
echo Power the board OFF, REMOVE the SD card, power it ON again.
echo (it starts in fastboot mode from the eMMC now)
pause

echo === Step 2/2: Android partitions
%FB% oem format || goto :fail
%FB% flash bootloader      bootloader-emmc.img || goto :fail
%FB% flash uboot-env       env.img || goto :fail
%FB% flash boot            boot.img || goto :fail
%FB% flash init_boot       init_boot.img || goto :fail
%FB% flash vendor_boot     vendor_boot.img || goto :fail
%FB% flash vbmeta_a        vbmeta.img || goto :fail
%FB% flash vbmeta_system_a vbmeta_system.img || goto :fail
%FB% erase misc
%FB% erase frp
%FB% reboot-fastboot || goto :fail
%FB% flash super super.img || goto :fail
%FB% -w
%FB% reboot
echo.
echo Finished. The first start takes 3-5 minutes.
pause
exit /b 0

:fail
echo.
echo FAILED. Check the cable and that "fastboot devices" shows the board, then run again.
pause
exit /b 1
