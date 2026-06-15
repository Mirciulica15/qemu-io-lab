#!/usr/bin/env bash
# Reproducibly build the I/O Systems lab base image from scratch.
#
#   builder/build-image.sh
#
# Boots a pinned Alpine ISO in QEMU, performs an unattended install + provisioning
# (declarative: answers.alpine + packages.list + provision.sh), then boots the
# result and runs check.sh as an acceptance test. Output: iolab-base.qcow2.
#
# Requires QEMU + python3 + an internet connection (the GUEST must reach the
# Alpine mirror — run this in a normal shell, not a restricted sandbox).
set -euo pipefail
cd "$(dirname "$0")/.."

ALPINE_VER=3.21.0
ALPINE_BRANCH=v3.21
ISO="alpine-virt-${ALPINE_VER}-x86_64.iso"
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_BRANCH}/releases/x86_64/${ISO}"
ISO_SHA256="__FILL_ME__"
OUT="iolab-base.qcow2"
SIZE="8G"
# Mirror the guest installs from. Override if dl-cdn is slow/blocked for you, e.g.
#   MIRROR=http://mirror.ihost.md/alpine ./builder/build-image.sh
MIRROR="${MIRROR:-https://dl-cdn.alpinelinux.org/alpine}"
# Optional HTTP proxy for the guest's apk (only needed in restricted networks /
# sandboxes where the VM has no direct egress). Empty = direct internet.
PROXY="${PROXY:-}"
export QEMU="${QEMU:-qemu-system-x86_64}"
QEMU_IMG="${QEMU_IMG:-qemu-img}"

command -v "$QEMU"     >/dev/null || { echo "ERROR: $QEMU not found (brew install qemu)."; exit 1; }
command -v "$QEMU_IMG" >/dev/null || { echo "ERROR: $QEMU_IMG not found."; exit 1; }
command -v python3     >/dev/null || { echo "ERROR: python3 not found."; exit 1; }

if [ ! -f "$ISO" ]; then
	echo ">> $ISO not present — fetch it from: $ISO_URL"
	exit 1
fi
if [ "$ISO_SHA256" != "__FILL_ME__" ]; then
	echo "$ISO_SHA256  $ISO" | shasum -a 256 -c - || { echo "ERROR: ISO checksum mismatch."; exit 1; }
fi

echo ">> creating fresh target disk $OUT ($SIZE)"
rm -f "$OUT"
"$QEMU_IMG" create -f qcow2 "$OUT" "$SIZE" >/dev/null

echo ">> staging payload"
PAY="$(mktemp -d "${TMPDIR:-/tmp}/iopay.XXXXXX")"
trap 'rm -rf "$PAY"' EXIT
cp builder/answers.alpine builder/packages.list builder/bootstrap.sh builder/provision.sh check.sh "$PAY/"
cat >"$PAY/buildenv" <<EOF
MIRROR='$MIRROR'
PROXY='$PROXY'
ALPINE_BRANCH='$ALPINE_BRANCH'
EOF

echo ">> install + provision (this takes a while; the guest downloads packages)"
python3 builder/drive.py "$ISO" "$OUT" "$PAY" bootstrap.sh BUILD_DONE_OK

echo ">> acceptance test: boot the built image and run check.sh"
python3 builder/verify.py "$OUT"

echo ">> SUCCESS: $OUT built and verified."
echo "   Next: ./package.sh  to compress it into the student kit."
