# I/O Systems Lab VM

A ready-to-run virtual PC for the Input/Output Systems course. It boots a small
Linux (Alpine) and presents a full set of I/O hardware to explore and program:

- **PCIe** bus (`lspci`)
- an **educational PCI device** (`edu`, `1234:11e8`) — for writing a driver
- an **NVMe** SSD (`nvme`, `/dev/nvme0`)
- a **USB 3.0** controller + stick (`lsusb`)
- a **SATA/AHCI** disk (ATA/ATAPI, `/dev/sda`)
- an **SMBus** controller (`i2cdetect`)

Everything is virtual — your real computer is never touched, and every student
sees identical hardware regardless of laptop.

______________________________________________________________________

## 1. Install QEMU (one time)

**macOS** (with [Homebrew](https://brew.sh)):

```
brew install qemu
```

**Linux (Debian/Ubuntu):**

```
sudo apt update && sudo apt install qemu-system-x86
```

**Linux (Fedora):** `sudo dnf install qemu-system-x86` — **Arch:** `sudo pacman -S qemu-base`

**Windows:** download the installer from <https://qemu.weilnetz.de/w64/> and run it.
During/after install, make sure QEMU is on your `PATH` (the installer offers this,
or add `C:\Program Files\qemu`). Open a new **Command Prompt** afterwards.

Verify it works:

```
qemu-system-x86_64 --version
```

## 2. Run the lab

Keep `run.sh` / `run.bat` in the **same folder** as `iolab-base.qcow2`.

- **macOS / Linux:** `./run.sh` (first time: `chmod +x run.sh`)
- **Windows:** double-click `run.bat`, or run it from a Command Prompt

The VM boots straight to a `root` shell — **no login or password needed**.

To shut it down: press **Ctrl-a**, release, then **x**. (Or type `poweroff`.)

## 3. Using it

```sh
# PCIe
lspci -nn                       # all PCI devices; 1234:11e8 = the edu device
# NVMe
nvme list ; nvme id-ctrl /dev/nvme0
# ATA (SATA disk) + ATAPI (CD-ROM)
lsblk ; hdparm -I /dev/sda      # ATA IDENTIFY
cat /dev/sr0 | head             # ATAPI packet read of the lab CD
# USB
lsusb ; lsusb -v 2>/dev/null | less
# SMBus / I2C  (load the controller driver first, then scan + read an EEPROM)
modprobe i2c-i801 i2c-dev ; i2cdetect -l ; i2cdetect -y 0 ; i2cdump -y 0 0x50
# Serial port (ttyS1 is free; ttyS0 is your console)
setserial -g /dev/ttyS1 ; stty -F /dev/ttyS1 -a
# How the kernel found and bound every device:
dmesg | less
```

Your work is saved automatically in a personal disk file (`disk.qcow2`) — it
persists across reboots. The experiment disks (`nvme.img`, `sata.img`, `usb.img`)
are scratch space you can format and destroy freely.

## Verify all hardware is present

Inside the VM, run the bundled check (it reads off the lab CD — which also proves ATAPI works):

```sh
mount /dev/sr0 /media/cdrom 2>/dev/null
sh /media/cdrom/check.sh
```

It prints a per-subject `[ OK ]` report: PCIe, the edu device, NVMe, USB, ATA/ATAPI, SMBus/I2C, serial ports, and the build toolchain.

## 4. Reset to a clean VM

If you break something, throw away your changes and start fresh:

- **macOS / Linux:** `RESET=1 ./run.sh`
- **Windows:** `run.bat reset`

This deletes only your overlay; the original lab image is untouched.

## Optional flags (macOS / Linux)

- `GUI=1 ./run.sh` — also open a graphical window (normally the terminal is enough)
- `LEGACY=pci ./run.sh` — add an old PCI-IDE disk to compare with modern AHCI
- `LEGACY=isa ./run.sh` — add a pre-PCI ISA-IDE disk (fixed ports 0x1F0, IRQ 14)

## Troubleshooting

- **"qemu-system-x86_64 not installed"** — finish step 1; on Windows open a *new*
  terminal so `PATH` updates.
- **Slow boot** — normal on Apple Silicon / when your CPU can't accelerate x86;
  it still works fine, just give it a few extra seconds.
- **Stuck?** quit with Ctrl-a then x, then `RESET=1 ./run.sh` (or `run.bat reset`).
