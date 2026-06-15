#!/usr/bin/env bash
# I/O Systems lab VM — student launcher (macOS / Linux).
# Boots an x86-64 PC with the edu device + NVMe + USB + SATA/AHCI + SMBus.
# Auto-logs in as root. Your changes are saved in a personal overlay (disk.qcow2);
# the shipped master (iolab-base.qcow2) is never modified.
#
#   ./run.sh            boot the lab
#   GUI=1 ./run.sh      also open a graphical window
#   RESET=1 ./run.sh    throw away your changes and start fresh
#   LEGACY=pci ./run.sh add a legacy PCI-IDE disk   (LEGACY=isa for pre-PCI ISA-IDE)
#
# Quit the VM: press Ctrl-a, then x.
#
# shellcheck disable=SC2054  # QEMU device strings legitimately contain commas
set -euo pipefail
cd "$(dirname "$0")"

QEMU=qemu-system-x86_64
BASE=iolab-base.qcow2
DISK=disk.qcow2
GUI="${GUI:-0}"; LEGACY="${LEGACY:-0}"; RESET="${RESET:-0}"

command -v "$QEMU" >/dev/null 2>&1 || { echo "ERROR: $QEMU not installed — see README.md."; exit 1; }
[ -f "$BASE" ] || { echo "ERROR: $BASE missing — keep run.sh in the same folder as it."; exit 1; }

if [ "$RESET" != 0 ]; then rm -f "$DISK"; echo ">> Reset: your overlay disk was deleted; a fresh one will be created."; fi

# personal overlay backed by the read-only master — all your work lands here
[ -f "$DISK" ] || qemu-img create -f qcow2 -b "$BASE" -F qcow2 "$DISK" >/dev/null
# experiment device backing files (safe to wipe / re-create)
[ -f nvme.img ] || qemu-img create -f raw nvme.img 256M >/dev/null
[ -f sata.img ] || qemu-img create -f raw sata.img 256M >/dev/null
[ -f usb.img  ] || qemu-img create -f raw usb.img  64M  >/dev/null

ARGS=( -M q35 -m 1G -accel tcg
  -drive if=none,id=osdisk,file="$DISK",format=qcow2
  -device virtio-blk-pci,drive=osdisk,bootindex=1
  -device edu
  -drive if=none,id=nvm,file=nvme.img,format=raw
  -device nvme,serial=deadbeef,drive=nvm
  -device qemu-xhci,id=xhci
  -drive if=none,id=usbstick,file=usb.img,format=raw
  -device usb-storage,bus=xhci.0,drive=usbstick
  -device ich9-ahci,id=ahci
  -drive if=none,id=satadisk,file=sata.img,format=raw
  -device ide-hd,bus=ahci.0,drive=satadisk
  -serial mon:stdio
  -serial null )
# ATAPI CD-ROM (packet interface) -> /dev/sr0
if [ -f labcd.iso ]; then
  ARGS+=( -drive if=none,id=cd,file=labcd.iso,format=raw,readonly=on -device ide-cd,bus=ahci.1,drive=cd )
else
  ARGS+=( -device ide-cd,bus=ahci.1 )
fi
[ "$GUI" = 0 ] && ARGS+=( -display none )

case "$LEGACY" in
  0|off|"") ;;
  pci|1) [ -f legacy.img ] || qemu-img create -f raw legacy.img 64M >/dev/null
     ARGS+=( -device piix3-ide,id=pciide -drive if=none,id=pata0,file=legacy.img,format=raw -device ide-hd,bus=pciide.0,drive=pata0 ) ;;
  isa) [ -f legacy.img ] || qemu-img create -f raw legacy.img 64M >/dev/null
     ARGS+=( -device isa-ide,id=oldide -drive if=none,id=pata0,file=legacy.img,format=raw -device ide-hd,bus=oldide.0,drive=pata0 ) ;;
  *) echo "Unknown LEGACY=$LEGACY (use pci or isa)"; exit 1 ;;
esac

echo ">> Booting the I/O Systems lab VM (auto-login as root). Quit: Ctrl-a then x"
exec "$QEMU" "${ARGS[@]}"
