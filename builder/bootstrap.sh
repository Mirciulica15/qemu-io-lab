#!/bin/sh
# Runs inside the Alpine LIVE environment (launched by drive.py).
# Performs an unattended install to /dev/vda, then provisions the new system.
# Payload (answers/packages/provision/check) is mounted at /payload.
set -e
# shellcheck source=/dev/null
. /payload/buildenv
if [ -n "$PROXY" ]; then
	export http_proxy="$PROXY" https_proxy="$PROXY" HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY"
fi

echo ">>> unattended base install to /dev/vda (mirror: $MIRROR)"
# point the answerfile at the chosen mirror (base URL; setup-apkrepos appends the branch)
cp /payload/answers.alpine /tmp/answers
sed -i "s#^APKREPOSOPTS=.*#APKREPOSOPTS=\"$MIRROR\"#" /tmp/answers
# ERASE_DISKS skips the disk-wipe confirmation; the printf answers the only
# remaining interactive prompt (root password, asked twice). Everything else
# is covered by the answerfile, so NO 'yes' firehose (that corrupts prompts).
export ERASE_DISKS=/dev/vda
printf 'iolab\niolab\n' | setup-alpine -f /tmp/answers

echo ">>> locating the freshly installed root"
ROOT=
for q in /dev/vda3 /dev/vda2 /dev/vda1; do
	if mount "$q" /mnt 2>/dev/null && [ -e /mnt/etc/os-release ]; then
		ROOT="$q"
		break
	fi
	umount /mnt 2>/dev/null || true
done
[ -n "$ROOT" ] || {
	echo "!! could not find installed root on /dev/vda"
	exit 1
}
echo ">>> root is $ROOT"

# /boot is a separate partition on a 'sys' install; mount it inside the root
BOOTDEV=$(awk '$2=="/boot"{print $1}' /mnt/etc/fstab)
case "$BOOTDEV" in
UUID=*) BOOTDEV="/dev/disk/by-uuid/${BOOTDEV#UUID=}" ;;
esac
[ -n "$BOOTDEV" ] && mount "$BOOTDEV" /mnt/boot 2>/dev/null || mount /dev/vda1 /mnt/boot 2>/dev/null || true

mount -o bind /dev /mnt/dev
mount -o bind /proc /mnt/proc
mount -o bind /sys /mnt/sys
cp /etc/resolv.conf /mnt/etc/resolv.conf
cp /payload/packages.list /payload/provision.sh /payload/check.sh /payload/buildenv /mnt/root/

echo ">>> provisioning inside the new system"
chroot /mnt sh /root/provision.sh

echo "BUILD_DONE_OK"
