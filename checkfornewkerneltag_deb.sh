#!/bin/bash -x

# This script build and install
# a newly tagged kernel from
# the url given as argument.

set -e

#if using a distro kernel, then used the latest, remove custom perf and exit
if [[ $1 = "DISTRO" ]] ; then
	sudo grubby  --grub2 --set-default `ls /boot/vmlinuz-* | grep -v rescue | grep -v jenkins | sort  | tail -n 1`
	sudo rm -f /usr/local/perf
	exit 1
elif [[ $1 = "CURRENT" ]] ; then
	exit 0
fi

mkdir -p kernel

cd kernel

if [ ! -d linux ]; then
	git clone --progress $1
fi

cd linux

git remote set-url origin $1

git fetch --all --tags

# Retrieve tag to use.
if [ $# -eq 2 -a -n "$2" ]; then
	latestkerneltag=$2
else
	latestkerneltag=$(git describe --tags --abbrev=0 origin/master)
fi

git checkout ${latestkerneltag} || exit 2
#if [ "${latestkerneltag}" != "$(cat latestkerneltag 2>/dev/null)" ]; then
#	git checkout ${latestkerneltag} || exit 1
#else
#	exit 1
#fi

rm -f ../linux-*

make mrproper

# Retrieve kernel config and set the line CONFIG_LOCALVERSION="" .
cp /boot/config-$(uname -r) .config
sed  -ie s/CONFIG_LOCALVERSION.*/CONFIG_LOCALVERSION=\"\"/g .config

# Update current kernel config to kernel to build.
yes "" | make olddefconfig

# SEV specific configs.
#./scripts/config --enable CONFIG_AMD_MEM_ENCRYPT
#./scripts/config --enable CONFIG_CRYPTO_DEV_CCP
#./scripts/config --enable CONFIG_CRYPTO_DEV_SP_PSP
#./scripts/config --enable CONFIG_CRYPTO_DEV_PSP_SEV
#./scripts/config --disable CONFIG_DEBUG_INFO
#./scripts/config --module CRYPTO_DEV_CCP_DD
#./scripts/config --disable CONFIG_LOCALVERSION_AUTO

./scripts/config --disable CONFIG_MODULE_SIG

# Build kernel.
make -j $(getconf _NPROCESSORS_ONLN) deb-pkg LOCALVERSION=-jenkins

sudo dpkg -i ../*.deb

#select the boot parameter with grubby!
kernel_package="$(ls ../linux-image-*.deb | grep -v dbg)"
vmlinuz_name="$(dpkg-deb -c $kernel_package | awk -F' ' '{print $6}' | grep '/boot/vmlinuz' )";
sudo grubby --set-default $vmlinuz_name

#echo ${latestkerneltag} > latestkerneltag

# Build and install perf tool for the kernel we just installed.
cd tools/perf
make
sudo cp perf /usr/local/bin

exit  1
