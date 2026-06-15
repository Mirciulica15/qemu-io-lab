#!/usr/bin/env bash
# Generate labcd.iso (the tiny ATAPI lab disc) from check.sh — portably.
# Used by build-image.sh and package.sh so the CD is never a committed binary.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=labcd.iso
SRC="$(mktemp -d "${TMPDIR:-/tmp}/labcd.XXXXXX")"
trap 'rm -rf "$SRC"' EXIT
cp check.sh "$SRC/check.sh"
printf 'I/O Systems Lab disc.\nRun the device check:  sh /media/cdrom/check.sh\n' >"$SRC/README.txt"

rm -f "$OUT"
if command -v hdiutil >/dev/null; then
	hdiutil makehybrid -iso -joliet -default-volume-name IOLAB -o "$OUT" "$SRC" >/dev/null
elif command -v xorriso >/dev/null; then
	xorriso -as mkisofs -J -V IOLAB -o "$OUT" "$SRC" >/dev/null 2>&1
elif command -v genisoimage >/dev/null; then
	genisoimage -J -V IOLAB -o "$OUT" "$SRC" >/dev/null 2>&1
elif command -v mkisofs >/dev/null; then
	mkisofs -J -V IOLAB -o "$OUT" "$SRC" >/dev/null 2>&1
else
	echo "ERROR: need hdiutil / xorriso / genisoimage / mkisofs to build $OUT" >&2
	exit 1
fi
echo "built $OUT"
