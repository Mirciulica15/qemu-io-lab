#!/bin/sh
# Runs inside a chroot of the freshly installed system (called by bootstrap.sh).
# Turns a stock Alpine install into the I/O Systems lab image, declaratively.
set -e
# shellcheck source=/dev/null
. /root/buildenv
if [ -n "$PROXY" ]; then
	export http_proxy="$PROXY" https_proxy="$PROXY" HTTP_PROXY="$PROXY" HTTPS_PROXY="$PROXY"
fi

echo ">>> pin repositories (main + community) from $MIRROR"
cat >/etc/apk/repositories <<EOF
$MIRROR/$ALPINE_BRANCH/main
$MIRROR/$ALPINE_BRANCH/community
EOF
apk update

echo ">>> install lab packages"
# shellcheck disable=SC2046  # word-splitting is intended: one arg per package
apk add $(grep -vE '^[[:space:]]*#|^[[:space:]]*$' /root/packages.list)

echo ">>> make linux-lts the only kernel (drop the stripped VM kernel)"
apk del linux-virt linux-virt-dev 2>/dev/null || true

echo ">>> kernel cmdline: serial console + let i2c_i801 claim the SMBus region"
# append our opts to whatever the installer set, so update-extlinux keeps them
sed -i 's@^\(default_kernel_opts="[^"]*\)"@\1 console=tty0 console=ttyS0,115200 acpi_enforce_resources=lax"@' /etc/update-extlinux.conf
sed -i 's@^serial_port=.*@serial_port=0@' /etc/update-extlinux.conf
sed -i 's@^serial_baud=.*@serial_baud=115200@' /etc/update-extlinux.conf
sed -i 's@^#\{0,1\}[[:space:]]*vesa_menu=.*@vesa_menu=0@' /etc/update-extlinux.conf
update-extlinux

echo ">>> direct serial boot (strip the graphical menu)"
CONF=/boot/extlinux.conf
LABEL=$(awk 'tolower($1)=="label"{print $2; exit}' "$CONF")
[ -n "$LABEL" ] || LABEL=lts
cp "$CONF" "$CONF.gen"
{
	echo "SERIAL 0 115200"
	echo "PROMPT 0"
	echo "TIMEOUT 10"
	echo "DEFAULT $LABEL"
	grep -viE '^[[:space:]]*(serial|prompt|timeout|default)[[:space:]]' "$CONF.gen" | grep -vi 'menu.c32'
} >"$CONF"
rm -f "$CONF.gen"

echo ">>> serial auto-login as root"
sed -i 's@^#ttyS0::@ttyS0::@; s@^ttyS0::respawn:.*@ttyS0::respawn:/bin/login -f root@' /etc/inittab

echo ">>> auto-load SMBus driver so i2cdetect works out of the box"
grep -q '^i2c-i801$' /etc/modules || echo i2c-i801 >>/etc/modules
grep -q '^i2c-dev$' /etc/modules || echo i2c-dev >>/etc/modules

echo ">>> strip any build-time proxy config (shipped image must be proxy-free)"
rm -f /etc/profile.d/*proxy* 2>/dev/null || true

echo ">>> root password (for su / ssh) + motd + verification script"
echo "root:iolab" | chpasswd
printf 'I/O Systems Lab VM. Auto-login as root.\nRun  sh /root/check.sh  to verify all hardware.\n' >/etc/motd
chmod +x /root/check.sh 2>/dev/null || true

echo "PROVISION_DONE_OK"
