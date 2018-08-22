#!/bin/bash -x

# This script build and install
# a newly tagged kernel from
# the url given as argument.

set -e

# If there is no argument given,
# install kernel from the package manager.
if [ $# -eq 0 ]; then
	./checkfornewkerneldeb.sh
	exit $?
fi

# Remove any installed *-jenkins package.
sudo apt remove -y *-jenkins

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

if [ "${latestkerneltag}" != "$(cat latestkerneltag 2>/dev/null)" ]; then
	git checkout ${latestkerneltag} || exit 1
else
	exit 1
fi

rm -f ../linux-*

make mrproper

# Retrieve kernel config and set the line CONFIG_LOCALVERSION="" .
cp /boot/config-$(uname -r) .config
sed  -ie s/CONFIG_LOCALVERSION.*/CONFIG_LOCALVERSION=\"\"/g .config

# SEV specific configs.
#./scripts/config --enable CONFIG_AMD_MEM_ENCRYPT
#./scripts/config --enable CONFIG_CRYPTO_DEV_CCP
#./scripts/config --enable CONFIG_CRYPTO_DEV_SP_PSP
#./scripts/config --enable CONFIG_CRYPTO_DEV_PSP_SEV
#./scripts/config --disable CONFIG_DEBUG_INFO
#./scripts/config --module CRYPTO_DEV_CCP_DD
#./scripts/config --disable CONFIG_LOCALVERSION_AUTO

./scripts/config --disable CONFIG_MODULE_SIG

# Update current kernel config to kernel to build.
yes "" | make olddefconfig

# Build kernel.
make -j $(getconf _NPROCESSORS_ONLN) deb-pkg LOCALVERSION=-jenkins

echo ${latestkerneltag} > latestkerneltag

cd ..

sudo dpkg -i *.deb

# Build and install perf tool for the kernel we just installed.
cd linux/tools/perf
make
sudo cp perf /usr/bin

exit 0
