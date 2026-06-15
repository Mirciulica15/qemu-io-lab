# Reproducible image builder

Builds the I/O Systems lab base image **from scratch, declaratively** — no
hand-mutated snapshots. Everything the image contains is version-controlled here,
so the exact image can be regenerated for any future Alpine release or package
change.

## What's here

| File             | Role                                                                                                |
| ---------------- | --------------------------------------------------------------------------------------------------- |
| `build-image.sh` | Orchestrator (run on the host). Boots the pinned ISO, drives the install, runs the acceptance test. |
| `answers.alpine` | Unattended `setup-alpine` answerfile (hostname, network, disk layout).                              |
| `packages.list`  | The exact apk packages installed (kernel, toolchain, lab tools).                                    |
| `bootstrap.sh`   | Runs in the live ISO: unattended install + hands off to provisioning.                               |
| `provision.sh`   | Runs in the new system: kernel swap, serial console, auto-login, boot config.                       |
| `drive.py`       | QEMU serial driver: boots ISO + payload, runs a script, streams output.                             |
| `verify.py`      | Boots the built image and runs `check.sh`; fails if any subject is missing.                         |

## Build it

Run in a **normal shell with internet** (the guest must reach the Alpine mirror —
a restricted sandbox where the VM has no egress will not work):

```sh
./builder/build-image.sh
```

This produces `iolab-base.qcow2` (≈ the master image) and verifies it. Then:

```sh
./package.sh          # compress + zip into the student kit
```

## Design notes

- **Kernel:** `linux-lts` (full PC driver set — has `i2c-i801`, `pata_legacy`, …),
  not `linux-virt` (a stripped cloud kernel that omits hardware drivers).
- **Pinning:** Alpine version is pinned in `build-image.sh` (`ALPINE_VER`) and the
  branch in `provision.sh` (`ALPINE_BRANCH`). Fill `ISO_SHA256` to enforce the ISO
  checksum.
- **Boot:** serial console (`ttyS0`), no graphical menu, auto-login as `root`.
- **To change the image** (add a tool, bump Alpine): edit `packages.list` /
  `provision.sh` / the pinned version, then re-run `build-image.sh`. Never edit a
  `.qcow2` by hand.
