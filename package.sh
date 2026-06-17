#!/usr/bin/env bash
# INSTRUCTOR tool: compress the built base image into a distributable student kit.
# Run this AFTER builder/build-image.sh has produced iolab-base.qcow2.
set -euo pipefail
cd "$(dirname "$0")"

SRC=iolab-base.qcow2          # produced by builder/build-image.sh
OUT=dist
ZIP=iolab-student-kit.zip

[ -f "$SRC" ] || { echo "ERROR: $SRC not found — run builder/build-image.sh first."; exit 1; }
command -v qemu-img >/dev/null || { echo "ERROR: qemu-img not found (brew install qemu)."; exit 1; }

# Refuse to run if the image is still in use (a VM is booted) — avoids a torn copy.
if ! qemu-img info "$SRC" >/dev/null 2>&1; then echo "ERROR: cannot read $SRC."; exit 1; fi

rm -rf "$OUT" "$ZIP"; mkdir -p "$OUT"
echo ">> Compressing $SRC -> $OUT/iolab-base.qcow2 (a minute or two)..."
qemu-img convert -O qcow2 -c "$SRC" "$OUT/iolab-base.qcow2"

cp kit/run.sh kit/README.md "$OUT"/
# Windows .bat MUST be CRLF for cmd.exe (its ^ line-continuations + if() blocks can
# misbehave on LF-only files). Emit CRLF explicitly, idempotently, regardless of how
# git checked the source out. (awk is portable across macOS/BSD and Linux/GNU.)
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' kit/run.bat > "$OUT/run.bat"
builder/make-labcd.sh >/dev/null            # (re)build the ATAPI lab disc from check.sh
cp labcd.iso "$OUT"/
chmod +x "$OUT/run.sh"

( cd "$OUT" && zip -r -X "../$ZIP" . >/dev/null )

echo ">> Done."
echo "   master : $(du -h "$OUT/iolab-base.qcow2" | cut -f1)  ($OUT/iolab-base.qcow2)"
echo "   bundle : $(du -h "$ZIP" | cut -f1)  ($ZIP)"
echo "   Hand students the zip; they unzip, install QEMU, and run ./run.sh (or run.bat)."
