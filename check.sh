#!/bin/sh
# I/O Systems lab — hardware verification. Run inside the VM:  sh check.sh
ok(){ printf '   [ OK ]  %s\n' "$1"; }
no(){ printf '   [FAIL]  %s\n' "$1"; }
hr(){ printf '\n--- %s ---\n' "$1"; }

echo "============================================================"
echo "   I/O SYSTEMS LAB  —  DEVICE VERIFICATION"
echo "   $(uname -srm)   |   Alpine $(cat /etc/alpine-release 2>/dev/null)"
echo "============================================================"

hr "PCIe bus"
if lspci >/dev/null 2>&1; then ok "lspci works — $(lspci | wc -l) PCI functions"; else no "lspci missing"; fi
lspci

hr "Educational PCI device (driver target)"
if lspci -d 1234:11e8 2>/dev/null | grep -q .; then ok "edu device present"; lspci -nnv -d 1234:11e8 | sed 's/^/      /'
else no "edu device 1234:11e8 NOT found"; fi

hr "NVMe SSD"
if [ -e /dev/nvme0n1 ]; then ok "namespace /dev/nvme0n1 present"; else no "no NVMe namespace"; fi
nvme list 2>/dev/null

hr "USB (xHCI)"
if lsusb 2>/dev/null | grep -qi xhci; then ok "xHCI USB 3.0 controller present"; else no "no xHCI controller"; fi
lsusb 2>/dev/null | sed 's/^/      /'

hr "ATA / SATA disk"
if [ -e /dev/sda ]; then ok "SATA disk /dev/sda present"; else no "no /dev/sda"; fi
hdparm -I /dev/sda 2>/dev/null | sed -n '1,7p' | sed 's/^/      /'

hr "ATAPI CD-ROM (packet interface)"
if [ -e /dev/sr0 ]; then ok "optical drive /dev/sr0 present  (label: $(blkid -s LABEL -o value /dev/sr0 2>/dev/null))"
else no "no /dev/sr0"; fi

hr "SMBus / I2C"
modprobe i2c-i801 2>/dev/null; modprobe i2c-dev 2>/dev/null
if i2cdetect -l 2>/dev/null | grep -qi smbus; then ok "SMBus adapter registered (i2c-i801)"; else no "SMBus adapter not bound"; fi
i2cdetect -l 2>/dev/null | sed 's/^/      /'
B=$(i2cdetect -l 2>/dev/null | grep -i smbus | head -1 | sed 's/^i2c-\([0-9]*\).*/\1/')
if [ -n "$B" ]; then echo "      EEPROMs visible on bus $B (0x50+ = SPD ROMs):"; i2cdetect -y "$B" 2>/dev/null | sed 's/^/      /'; fi

hr "Serial ports (16550 UART)"
if [ -e /dev/ttyS0 ]; then ok "ttyS0 present (console, COM1 0x3F8)"; else no "no ttyS0"; fi
if [ -e /dev/ttyS1 ]; then ok "ttyS1 present (free for labs, COM2 0x2F8)"; else no "no ttyS1"; fi

hr "Driver-development toolchain"
if command -v gcc >/dev/null; then ok "gcc: $(gcc --version | head -1)"; else no "gcc missing"; fi
if command -v make >/dev/null; then ok "make present"; else no "make missing"; fi
if [ -e "/lib/modules/$(uname -r)/build" ]; then
	ok "kernel headers present for $(uname -r)"
else
	no "kernel headers missing (apk add linux-lts-dev)"
fi

echo
echo "============================================================"
echo "   VERIFICATION COMPLETE"
echo "============================================================"
