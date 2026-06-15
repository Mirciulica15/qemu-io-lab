@echo off
REM I/O Systems lab VM - student launcher (Windows).
REM Boots an x86-64 PC with the edu device + NVMe + USB + SATA/AHCI + SMBus.
REM Auto-logs in as root. Your changes are saved in disk.qcow2; the shipped
REM master (iolab-base.qcow2) is never modified.
REM
REM   run.bat            boot the lab
REM   run.bat reset      throw away your changes and start fresh
REM
REM Quit the VM: press Ctrl-a, then x.
setlocal
cd /d "%~dp0"
set QEMU=qemu-system-x86_64

where %QEMU% >nul 2>nul || (echo ERROR: %QEMU% not installed - see README.md & exit /b 1)
if not exist iolab-base.qcow2 (echo ERROR: iolab-base.qcow2 missing - keep run.bat next to it & exit /b 1)

if /I "%1"=="reset" (del /q disk.qcow2 nvme.img sata.img usb.img 2>nul & echo Reset: your changes were deleted.)

if not exist disk.qcow2 qemu-img create -f qcow2 -b iolab-base.qcow2 -F qcow2 disk.qcow2 >nul
if not exist nvme.img qemu-img create -f raw nvme.img 256M >nul
if not exist sata.img qemu-img create -f raw sata.img 256M >nul
if not exist usb.img qemu-img create -f raw usb.img 64M >nul

set CD=-device ide-cd,bus=ahci.1
if exist labcd.iso set CD=-drive if=none,id=cd,file=labcd.iso,format=raw,readonly=on -device ide-cd,bus=ahci.1,drive=cd

echo Booting the I/O Systems lab VM (auto-login as root). Quit: Ctrl-a then x
%QEMU% -M q35 -m 1G -accel tcg ^
  -drive if=none,id=osdisk,file=disk.qcow2,format=qcow2 -device virtio-blk-pci,drive=osdisk,bootindex=1 ^
  -device edu ^
  -drive if=none,id=nvm,file=nvme.img,format=raw -device nvme,serial=deadbeef,drive=nvm ^
  -device qemu-xhci,id=xhci -drive if=none,id=usbstick,file=usb.img,format=raw -device usb-storage,bus=xhci.0,drive=usbstick ^
  -device ich9-ahci,id=ahci -drive if=none,id=satadisk,file=sata.img,format=raw -device ide-hd,bus=ahci.0,drive=satadisk ^
  %CD% ^
  -serial mon:stdio -serial null -display none
endlocal
