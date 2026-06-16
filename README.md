# I/O Systems Lab

A reproducible, emulated PC for teaching the **Input/Output Systems** course.
Students boot a small Linux VM that exposes the full I/O bus zoo — and can inspect
and program it with full privilege, on any laptop, without touching real hardware.

Every student gets **identical** virtual hardware regardless of their machine, so
labs are uniform and nothing can brick a real device.

## What's emulated

| Subject     | Device                                                         | Inspect with              |
| ----------- | -------------------------------------------------------------- | ------------------------- |
| PCIe        | q35 root complex + an **educational PCI device** (`1234:11e8`) | `lspci -nn`               |
| NVMe        | QEMU NVMe controller + namespace                               | `nvme list`               |
| USB         | xHCI (USB 3.0) controller + mass-storage device                | `lsusb`                   |
| ATA         | SATA/AHCI disk (plus optional legacy PCI-IDE / ISA-IDE)        | `hdparm -I /dev/sda`      |
| ATAPI       | CD-ROM (packet interface)                                      | `cat /dev/sr0`            |
| SMBus / I²C | ICH9 SMBus controller + SPD EEPROMs                            | `i2cdetect -y 0`          |
| Serial      | two 16550 UARTs (`ttyS0` console, `ttyS1` free for labs)       | `setserial -g /dev/ttyS1` |

The `edu` device is the flagship driver-writing target (1 MB MMIO BAR, an IRQ, DMA).

## Repository layout

```
.
├── builder/        Reproducible image build (instructor / CI) — see builder/README.md
├── kit/            Student distribution: launchers + README that ship in the zip
├── check.sh        Hardware verification (per-subject PASS report)
├── package.sh      Compress the built image into the student kit zip
├── run.sh          Instructor launcher (boots the locally-built image)
├── CHANGELOG.md
└── README.md       (this file)
```

## Quick start

**Instructor — build the image once** (needs QEMU + python3 + internet):

```sh
./builder/build-image.sh     # -> iolab-base.qcow2  (installs Alpine + tools, verifies)
./package.sh                 # -> iolab-student-kit.zip
```

If your network blocks the default mirror, override it:

```sh
MIRROR=http://mirror.ihost.md/alpine ./builder/build-image.sh
```

**Student — run the lab** (after unzipping the kit):

```sh
./run.sh            # macOS / Linux   (Windows: run.bat)
```

The VM auto-logs in as `root`. Verify everything is present:

```sh
mount /dev/sr0 /media/cdrom 2>/dev/null && sh /media/cdrom/check.sh
```

## Design principles

- **Reproducible, not hand-mutated.** The image is built from version-controlled
  inputs (`builder/`), never by editing a `.qcow2` by hand. Regenerate it for any
  Alpine bump or package change by re-running the builder.
- **`linux-lts` kernel** for the full PC driver set (`i2c-i801`, `pata_legacy`, …)
  that the stripped cloud kernel lacks.
- **x86-64 guest** pinned for cross-student parity — every student sees the same
  hardware. (Functional parity is exact; don't grade on timing, since hosts that
  can't hardware-accelerate x86 run slower.)
- **Base + overlay distribution** so a broken student VM resets in one command and
  the shipped master is never modified.

## Requirements

- **QEMU** (`brew install qemu` / `apt install qemu-system-x86` / Windows installer)
- **python3** (drives the build)
- Building: an internet connection (the guest fetches packages from an Alpine mirror)

## Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` (and is manually
dispatchable). It has two jobs:

- **lint** — `shellcheck` the shell scripts, `ruff check` + `ruff format --check`
  + `py_compile` the Python, and `yamllint` + `actionlint` the workflow itself.
- **build** — `needs: lint`, so it only runs once lint is green. Installs QEMU,
  fetches the checksum-pinned Alpine ISO, and runs `./builder/build-image.sh`
  (build under TCG + `verify.py` acceptance test). On a `v*` tag it additionally
  runs `./package.sh` and attaches `iolab-student-kit.zip` to a GitHub Release.

So a normal `git push` builds and verifies the image; `git push origin v0.1.0`
also publishes the student kit. The build runs exactly once either way.

### Testing it locally

Every CI step is a thin wrapper over a committed script, so running the script
locally *is* testing the step:

- **lint** — run the actual job in Docker: `act -j lint`. Or run the tools
  directly: `shellcheck builder/*.sh ./*.sh kit/run.sh`, `ruff check builder/*.py`,
  `actionlint`, `yamllint -c .yamllint.yml .github/workflows`.
- **build** — `./builder/build-image.sh` is the job body; run it as you already
  do. (`act` can't usefully run this — it would nest QEMU/TCG inside Docker.)
- **release** — `./package.sh` exercises the packaging; only the `gh release`
  upload is CI-only.

## More

- Building & customizing the image: [`builder/README.md`](builder/README.md)
- The student-facing guide: [`kit/README.md`](kit/README.md)

## License

[MIT](LICENSE) © 2026 Mircea Talu — free to use, modify, and redistribute,
including for teaching.
