#!/bin/bash -xe

set -e

# This script takes a image or http link to an image and then puts it
# on a scratch disk and sets it up.   For new OSs under test, you'll
# need to modify this script.

# settings start
FILE="/etc/test_scratchdisk"
BOOT_TOOL="./efiboot_multitool.pl"
MNT_POINT="./mnt"
# settings end

if (( $# < 1 )) ; then
	echo "run as: ./$0 <image_for_testing>"
	echo "Set scratch disk in $FILE as SCRATCHDISK=/dev/..."
	echo "The device can either be a /dev/sdX or /dev/nvme or it can"
	echo "be /dev/disk/by-id/X.  Either way, it's the base device"
	echo "and NOT a partition."
	exit 1
fi

IMAGE=$1

# used for adding a ssh key when configuring the image's ssh
# this gets added to the image's root's .ssh/authorized_keys
KEY=""
if (( $# >= 2 )) ; then
	KEY=$2
else
	if [ -f "$HOME/.ssh/id_rsa.pub" ] ; then
		KEY=$(cat "$HOME/.ssh/id_rsa.pub")
	else
		KEY="#no key added"
	fi
fi

if [ -f "$FILE" ] ; then
	source "$FILE"
	if [ -z "$SCRATCHDISK" ] ; then
		echo "no SCRATCHDISK=</dev/..> in scratch disk settings file"
		echo "set scratch disk in $FILE as SCRATCHDISK=/dev/..."
		exit 1
	fi
else
	echo "no scratch disk settings file"
	echo "set scratch disk in $FILE as SCRATCHDISK=/dev/..."
	exit 1
fi

DEV="$SCRATCHDISK"


BZIP=""
RV=0
which pbzip2 || RV=$?
if [ $RV -eq 0 ] ; then
	BZIP="pbzip2"
else
	BZIP="bzip2"
fi
# first dd image over
if [[ $IMAGE = "http"* ]] ; then
	curl -f -O -s -L "$IMAGE"
	IMAGE=$(ls -c ./*.img.bz2  | head -n 1)
	$BZIP -cd "$IMAGE" | dd oflag=sync bs=128k of="$DEV"
	rm -f "$IMAGE"
elif [[ $IMAGE = *".bz2" ]] ; then
	$BZIP -cd "$IMAGE" | dd oflag=sync bs=128k of="$DEV"
else
	dd oflag=sync bs=128k if="$IMAGE" of="$DEV"
fi
sync
partprobe
sleep 3

# create a new partition and format it
ROOTDEV=$(ls "$DEV"* | tail -n1)	# we assume the root is the last partition
				# before we add home, save it
sgdisk -e "$DEV"
sgdisk -n 0:0:+40G -t 8300 -c 0:"home" "$DEV"
sync
partprobe
sleep 3

HOMEDEV=$(ls "$DEV"* | tail -n1)
UUID=$(mkfs.ext4 -F "$HOMEDEV" | grep UUID | awk -F ' ' '{print $3}')

# mount and add a home for jenkins
mkdir -p "$MNT_POINT"
mount -t auto "$ROOTDEV" "$MNT_POINT"
echo "UUID=$UUID /home ext4 defaults 0 2" >> "$MNT_POINT/etc/fstab"
mv "$MNT_POINT/home" "$MNT_POINT/home.old"
mkdir "$MNT_POINT/home/"
mount -t ext4 "$HOMEDEV" "$MNT_POINT/home"
cp -a "$MNT_POINT/home.old/"* "$MNT_POINT/home"

# OS dependent
# set hostname,
if [[ $IMAGE = *"ubuntu-18.04"* ]] ; then
	if [ -f "$MNT_POINT/etc/cloud/cloud.cfg" ] ; then
		sed -i '/preserve_hostname:/c\preserve_hostname: true' "$MNT_POINT/etc/cloud/cloud.cfg"
	fi
	echo "$HOSTNAME" > "$MNT_POINT/etc/hostname"
elif [[ $IMAGE = *"ubuntu-16.04"* ]] ; then
	sed -i "127.0.1.1:/c\127.0.1.1        $HOSTNAME.amd.com $HOSTNAME" "$MNT_POINT/etc/hosts"
	echo "$HOSTNAME" > "$MNT_POINT/etc/hostname"
elif [[ $IMAGE = *"sles-12."* ]] ; then
	sed -i "/DHCLIENT_SET_HOSTNAME=/c\DHCLIENT_SET_HOSTNAME=\"no\"" "$MNT_POINT/etc/sysconfig/network/dhcp"
	echo "$HOSTNAME" > "$MNT_POINT/etc/HOSTNAME"
elif [[ $IMAGE = *"rhel-7."* ]] ; then
	echo "$HOSTNAME" > "$MNT_POINT/etc/hostname"
else
	echo "can't find OS, exiting"
	sync
	umount "$MNT_POINT/home"
	umount "$MNT_POINT"
	exit 1
fi

# OS independent stuff here
# copy over ssh host keys, make sure passwords are set,
rm -f "$MNT_POINT/etc/ssh/ssh_host"*
cp -a /etc/ssh/ssh_host* "$MNT_POINT/etc/ssh/"
echo 'root:amd123' | chroot "$MNT_POINT" /usr/sbin/chpasswd
echo 'amd:amd123' | chroot "$MNT_POINT" /usr/sbin/chpasswd
sed -i "/PermitRootLogin/c\PermitRootLogin Yes" "$MNT_POINT/etc/ssh/sshd_config"
if [ ! -f "$MNT_POINT/root/.ssh/authorized_keys" ] ; then
	mkdir -p "$MNT_POINT/root/.ssh/"
	chmod 700 "$MNT_POINT/root/.ssh/"
	touch "$MNT_POINT/root/.ssh/authorized_keys"
	chmod 600 "$MNT_POINT/root/.ssh/authorized_keys"
fi
echo -n "$KEY" >>  "$MNT_POINT/root/.ssh/authorized_keys"
cp /root/efiboot_multitool.pl "$MNT_POINT/root/efiboot_multitool.pl" #even if we fail to provision, we can still switch back to the host OS

sync
umount "$MNT_POINT/home"
umount "$MNT_POINT"

# remove any old testing EFI entries first
for ENTRY in $($BOOT_TOOL list | grep '\-testing' | awk -F '=' '{print $2}') ; do
	$BOOT_TOOL delete "$ENTRY"
done

EFINAME=""
EFIDEV="$ROOTDEV"
EFIDEV="${EFIDEV::-1}1"
# add efi entry efi boot order
if [[ $IMAGE = *"ubuntu"* ]] ; then
	EFINAME="ubuntu-testing"
	$BOOT_TOOL add "$EFINAME","$EFIDEV","\EFI\UBUNTU\SHIMX64.EFI"
elif [[ $IMAGE = *"sles"* ]] ; then
	EFINAME="sles-testing"
	$BOOT_TOOL add "$EFINAME","$EFIDEV","\EFI\SLES\SHIM.EFI"
elif [[ $IMAGE = *"rhel"* ]] ; then
	EFINAME="rhel-testing"
	$BOOT_TOOL add "$EFINAME","$EFIDEV","\EFI\REDHAT\SHIMX64.EFI"
else
	echo "can't find OS, exiting"
	exit 1
fi

# sets default boot to the new entry
$BOOT_TOOL push "$EFINAME"
