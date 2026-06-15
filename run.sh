#!/usr/bin/env bash
# I/O Systems lab VM — one x86-64 PC with the full bus zoo.
# Same command for EVERY student regardless of host (Apple Silicon, Intel, Windows, Linux).
# Requires: qemu (brew install qemu). Guest arch is fixed to x86-64 for parity.
#
# MODES:
#   ./run.sh                      boot the PERSISTENT system from os.qcow2 (normal use)
#   ./run.sh some-linux.iso       boot from the CD/ISO (live session OR to install)
#   DUMP=1 ./run.sh               freeze CPU, print the virtual hardware tree, quit
#
# TOGGLES:
#   LEGACY=pci ./run.sh [iso]     add a PCI-IDE (piix3) disk  -> lspci class [0101]
#   LEGACY=isa ./run.sh [iso]     add a pre-PCI ISA-IDE disk  -> fixed ports 0x1F0/IRQ14
#
# shellcheck disable=SC2054  # QEMU device strings legitimately contain commas
set -euo pipefail
cd "$(dirname "$0")"

QEMU=qemu-system-x86_64
ISO="${1:-}"           # path to a bootable Linux ISO, or empty to boot the OS disk
LEGACY="${LEGACY:-0}"  # 0/off=none, pci/1=PCI-IDE (piix3), isa=pre-PCI ISA-IDE
DUMP="${DUMP:-0}"      # 1 = freeze + dump hardware tree instead of booting
GUI="${GUI:-0}"        # 1 = open the VGA window (needed before serial console is set up)

# --- backing storage (created once; all sparse) ---------------------------
[ -f os.qcow2 ] || qemu-img create -f qcow2 os.qcow2 8G   # PERSISTENT root (/dev/vda)
[ -f nvme.img ] || qemu-img create -f raw  nvme.img 256M  # experiment NVMe SSD
[ -f sata.img ] || qemu-img create -f raw  sata.img 256M  # experiment SATA/AHCI disk
[ -f usb.img  ] || qemu-img create -f raw  usb.img  64M   # experiment USB stick

ARGS=(
  -M q35                 # modern chipset: gives PCIe + a free SMBus controller
  -m 1G
  -accel tcg             # full x86 emulation (no HW accel for x86 guest on Apple Silicon)

  # --- PERSISTENT OS disk (paravirtual virtio-blk) -> /dev/vda in the guest
  # bootindex=1 makes the firmware boot THIS disk (not the empty experiment disks).
  -drive if=none,id=osdisk,file=os.qcow2,format=qcow2
  -device virtio-blk-pci,drive=osdisk,bootindex=1

  # --- the educational PCI device: MMIO + IRQ + DMA, for driver-writing labs
  -device edu

  # --- NVMe SSD (experiment target) -------------------------------------
  -drive if=none,id=nvm,file=nvme.img,format=raw
  -device nvme,serial=deadbeef,drive=nvm

  # --- USB 3.0 (xHCI) + a USB mass-storage stick ------------------------
  -device qemu-xhci,id=xhci
  -drive if=none,id=usbstick,file=usb.img,format=raw
  -device usb-storage,bus=xhci.0,drive=usbstick

  # --- SATA/AHCI disk (ATA) + ATAPI CD-ROM, both on the AHCI HBA --------
  -device ich9-ahci,id=ahci
  -drive if=none,id=satadisk,file=sata.img,format=raw
  -device ide-hd,bus=ahci.0,drive=satadisk

  -serial mon:stdio      # ttyS0 = console + QEMU monitor on this terminal
  -serial null           # ttyS1 = free UART (0x2F8/IRQ3) for serial-port labs
)
# ATAPI CD-ROM (packet interface) -> /dev/sr0 ; uses labcd.iso if present
if [ -f labcd.iso ]; then
  ARGS+=( -drive if=none,id=cd,file=labcd.iso,format=raw,readonly=on -device ide-cd,bus=ahci.1,drive=cd )
else
  ARGS+=( -device ide-cd,bus=ahci.1 )   # empty ATAPI tray
fi
# VGA window off by default (terminal-only); GUI=1 opens it.
if [ "$GUI" = 0 ]; then ARGS+=( -display none ); fi

# --- optional legacy disk: shows the pre-AHCI storage interface ------------
# Compare in the guest with `lspci -nn`:
#   PCI-IDE (piix3) shows up as class [0101] 8086:7010, beside AHCI's class [0106].
#   ISA-IDE is INVISIBLE to lspci (fixed ports 0x1F0/0x3F6, IRQ 14) -> needs
#   `modprobe pata_legacy` in the guest to attach. That absence is the lesson.
case "$LEGACY" in
  0|off|"") ;;  # legacy disk disabled (default)
  pci|1)
    [ -f legacy.img ] || qemu-img create -f raw legacy.img 64M
    echo ">> LEGACY=pci : adding a PCI-IDE (piix3) disk [class 0101, 8086:7010]"
    ARGS+=(
      -device piix3-ide,id=pciide
      -drive if=none,id=pata0,file=legacy.img,format=raw
      -device ide-hd,bus=pciide.0,drive=pata0
    ) ;;
  isa)
    [ -f legacy.img ] || qemu-img create -f raw legacy.img 64M
    echo ">> LEGACY=isa : adding a pre-PCI ISA-IDE disk [ports 0x1F0/0x3F6, IRQ 14]"
    ARGS+=(
      -device isa-ide,id=oldide
      -drive if=none,id=pata0,file=legacy.img,format=raw
      -device ide-hd,bus=oldide.0,drive=pata0
    ) ;;
  *)
    echo "!! Unknown LEGACY=$LEGACY (use: off | pci | isa)" >&2; exit 1 ;;
esac

# --- mode selection --------------------------------------------------------
if [ "$DUMP" != 0 ]; then
  echo ">> DUMP mode: freezing CPU and printing the virtual hardware tree."
  printf 'info pci\ninfo qtree\nquit\n' | "$QEMU" "${ARGS[@]}" -S
elif [ -n "$ISO" ]; then
  echo ">> Booting from ISO: $ISO   (install with setup-alpine, or just explore)"
  echo ">> Ctrl-a x = quit QEMU   |   Ctrl-a c = QEMU monitor"
  # CD at bootindex=0 -> tried before the OS disk (so the installer/live boots).
  exec "$QEMU" "${ARGS[@]}" \
    -drive if=none,id=cd0,file="$ISO",media=cdrom \
    -device ide-cd,bus=ahci.1,drive=cd0,bootindex=0
else
  echo ">> Booting the PERSISTENT system from os.qcow2 (virtio /dev/vda, bootindex=1)."
  echo ">> (If you see 'No bootable device', the install didn't complete — re-run"
  echo ">>  ./run.sh alpine-virt-*.iso and finish setup-alpine on /dev/vda, mode sys.)"
  echo ">> Ctrl-a x = quit QEMU   |   Ctrl-a c = QEMU monitor"
  exec "$QEMU" "${ARGS[@]}"
fi
