# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Reproducible image builder** (`builder/`): unattended Alpine install + declarative
  provisioning driven by QEMU, producing `iolab-base.qcow2` from version-controlled
  inputs (`answers.alpine`, `packages.list`, `provision.sh`). Configurable `MIRROR`
  and optional `PROXY`.
- **Emulated I/O hardware**: PCIe + educational `edu` device, NVMe, USB (xHCI),
  SATA/ATA, ATAPI CD-ROM, SMBus/I²C (with SPD EEPROMs), and two serial UARTs.
  Optional legacy PCI-IDE / ISA-IDE disks via `LEGACY=`.
- **Student distribution kit** (`kit/`): `run.sh` / `run.bat` launchers using a
  base + overlay model (one-command reset), and a student `README`.
- **`check.sh`** acceptance/verification script with a per-subject PASS report,
  shipped on the lab CD and used as a build-time gate (`builder/verify.py`).
- **`linux-lts` kernel** for the full PC driver set; serial console + root
  auto-login; clean direct boot (no graphical menu).
- Repository scaffolding: top-level `README`, `.gitignore`, `.gitattributes`,
  this changelog.

### Notes

- First verified end-to-end build is pending; tag `0.1.0` once `build-image.sh`
  completes and `check.sh` reports all subjects present.
- The original hand-built proof-of-concept image (`os.qcow2`) is superseded by the
  reproducible builder and will be retired.
