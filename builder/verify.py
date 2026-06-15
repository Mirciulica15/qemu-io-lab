#!/usr/bin/env python3
"""Boot a built lab image headless and run /root/check.sh as an acceptance test.

Usage:
    verify.py <image.qcow2>

Exits 0 only if check.sh reports no [FAIL] lines.
"""

import fcntl
import os
import select
import subprocess
import sys
import time

QEMU = os.environ.get("QEMU", "qemu-system-x86_64")
buf = bytearray()


def spawn(args):
    p = subprocess.Popen(
        [QEMU] + args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0,
    )
    flags = fcntl.fcntl(p.stdout, fcntl.F_GETFL)
    fcntl.fcntl(p.stdout, fcntl.F_SETFL, flags | os.O_NONBLOCK)
    return p


def pump(p, secs):
    end = time.time() + secs
    while time.time() < end:
        ready, _, _ = select.select([p.stdout], [], [], 0.2)
        if ready:
            try:
                data = os.read(p.stdout.fileno(), 65536)
            except (BlockingIOError, OSError):
                data = b""
            if data:
                buf.extend(data)
                sys.stdout.write(data.decode("latin1"))
                sys.stdout.flush()
        if p.poll() is not None:
            return False
    return True


def wait_for(p, token, secs):
    needle = token.encode()
    end = time.time() + secs
    while time.time() < end:
        if needle in buf:
            return True
        if not pump(p, 0.3):
            return needle in buf
    return needle in buf


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    image = sys.argv[1]
    args = [
        "-M",
        "q35",
        "-m",
        "1024",
        "-accel",
        "tcg",
        "-drive",
        f"if=none,id=osdisk,file={image},format=qcow2",
        "-device",
        "virtio-blk-pci,drive=osdisk,bootindex=1",
        "-device",
        "edu",
        "-drive",
        "if=none,id=nvm,file=/dev/null,format=raw",
        "-device",
        "nvme,serial=deadbeef,drive=nvm",
        "-device",
        "qemu-xhci,id=xhci",
        "-device",
        "ich9-ahci,id=ahci",
        "-display",
        "none",
        "-serial",
        "stdio",
        "-monitor",
        "none",
    ]
    # NVMe needs a real backing file; create a scratch one beside the image.
    scratch = image + ".verifynvme"
    with open(scratch, "wb") as fh:
        fh.truncate(64 * 1024 * 1024)
    args[args.index("if=none,id=nvm,file=/dev/null,format=raw")] = (
        f"if=none,id=nvm,file={scratch},format=raw"
    )

    p = spawn(args)
    try:
        if not wait_for(p, ":~#", 240):
            print("\n!! never reached an auto-login root shell")
            p.kill()
            return 1
        p.stdin.write(b"sh /root/check.sh\n")
        p.stdin.flush()
        wait_for(p, "VERIFICATION COMPLETE", 90)
        pump(p, 2)
        fails = buf.count(b"[FAIL]")
        p.stdin.write(b"poweroff\n")
        p.stdin.flush()
        pump(p, 20)
    finally:
        try:
            p.wait(timeout=15)
        except Exception:
            p.kill()
        try:
            os.remove(scratch)
        except OSError:
            pass

    print(f"\n=== verify: {fails} [FAIL] line(s) ===")
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
