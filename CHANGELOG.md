# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-06-17

### Fixed

- **Windows launcher line endings:** `package.sh` now emits `run.bat` with CRLF
  (idempotently, regardless of git checkout), so the shipped `.bat` runs reliably
  under `cmd.exe`. The 0.1.0 kit shipped `run.bat` with LF endings.

### Added

- **Windows CI smoke test** (`windows-smoke` job): on a `v*` tag, boots the
  packaged kit via `run.bat` on a `windows-latest` runner (headless, TCG) and
  asserts it reaches the auto-login root shell — continuously verifying the
  Windows launcher, which `build`/`verify.py` (Linux/macOS) cannot exercise.

## [0.1.0] - 2026-06-16

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
  this changelog, and an MIT `LICENSE`.
- **Continuous integration** (`.github/workflows/ci.yml`): a `lint` job
  (shellcheck, ruff check + format, yamllint, actionlint) gating a `build` job
  that builds and verifies the image under TCG on every push to `main`, and on a
  `v*` tag additionally runs `package.sh` and attaches `iolab-student-kit.zip`
  to a GitHub Release.

### Notes

- Verified end-to-end on 2026-06-15: `build-image.sh` builds from scratch and
  `check.sh` reports **all subjects present (0 failures)**. The packaged student
  kit was re-verified on 2026-06-16 (unzipped and booted headless, 0 failures).
- The original hand-built proof-of-concept image (`os.qcow2`) is superseded by the
  reproducible builder and can be retired.
