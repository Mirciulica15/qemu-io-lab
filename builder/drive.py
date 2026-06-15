#!/usr/bin/env python3
# Reusable QEMU serial driver for the I/O-lab image builder.
# Boots an Alpine live ISO with a target disk + a read-only FAT payload disk,
# logs in as root, and runs a named script from the payload, streaming output.
#
#   drive.py <iso> <target.qcow2> <payload-dir> <script-in-payload> <DONE-marker> [extra qemu args...]
#
# Exits 0 iff the DONE-marker appears in the guest output.
import subprocess
import os
import sys
import select
import time
import fcntl

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
    fl = fcntl.fcntl(p.stdout, fcntl.F_GETFL)
    fcntl.fcntl(p.stdout, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    return p


def pump(p, secs):
    end = time.time() + secs
    while time.time() < end:
        r, _, _ = select.select([p.stdout], [], [], 0.2)
        if r:
            try:
                d = os.read(p.stdout.fileno(), 65536)
            except (BlockingIOError, OSError):
                d = b""
            if d:
                buf.extend(d)
                sys.stdout.write(d.decode("latin1"))
                sys.stdout.flush()
        if p.poll() is not None:
            return False
    return True


def send(p, s):
    p.stdin.write(s.encode())
    p.stdin.flush()


def type_slow(p, s, d=0.12):
    for ch in s:
        send(p, ch)
        time.sleep(d)
        pump(p, 0.02)


def wait_for(p, token, secs):
    tb = token.encode()
    end = time.time() + secs
    while time.time() < end:
        if tb in buf:
            return True
        if not pump(p, 0.3):
            return tb in buf
    return tb in buf


def main():
    iso, disk, payload, script, done = sys.argv[1:6]
    extra = sys.argv[6:]
    args = [
        "-M",
        "q35",
        "-m",
        "1024",
        "-accel",
        "tcg",
        "-drive",
        "if=none,id=osdisk,file=%s,format=qcow2" % disk,
        "-device",
        "virtio-blk-pci,drive=osdisk",
        "-drive",
        "if=virtio,file=fat:ro:%s,format=raw,readonly=on" % payload,
        "-cdrom",
        iso,
        "-boot",
        "d",
        "-display",
        "none",
        "-serial",
        "stdio",
        "-monitor",
        "none",
    ] + extra
    p = spawn(args)
    if not wait_for(p, "login:", 240):
        print("\n!! never reached live login")
        p.kill()
        return 1
    time.sleep(1.0)
    type_slow(p, "root\n")
    pump(p, 4)
    # mount the FAT payload (vdb or vdb1) and run the requested script
    send(
        p,
        "mkdir -p /payload; mount -t vfat /dev/vdb1 /payload 2>/dev/null || mount -t vfat /dev/vdb /payload 2>/dev/null; ls /payload\n",
    )
    pump(p, 4)
    send(p, "sh /payload/%s 2>&1\n" % script)
    # stream until DONE marker or timeout (installs/apk can take a long while under TCG)
    ok = wait_for(p, done, 1800)
    pump(p, 2)
    send(p, "poweroff\n")
    pump(p, 30)
    try:
        p.wait(timeout=20)
    except Exception:
        p.kill()
    print(
        "\n=== driver: %s %s ===" % (script, "OK" if ok else "FAILED (no DONE marker)")
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
