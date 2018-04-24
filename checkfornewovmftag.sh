#!/bin/bash -x

# This script build and install
# a newly tagged ovmf from
# the url given as argument.

set -e

if [ ! -d ovmf ]; then
	git clone --progress $1 ovmf
else
	rm -rf ovmf/Build
fi

pushd ovmf

git fetch

# Retrieve tag to use.
if [ $# -eq 2 -a -n "$2" ]; then
	latestovmftag=$2
fi

if [ -n "${latestovmftag}" -a "${latestovmftag}" != "$(cat latestovmftag 2>/dev/null)" ]; then
	git checkout ${latestovmftag} || exit 1
fi

# Insure needed libraries are installed.
sudo apt -y install uuid-dev nasm acpica-tools

make -C BaseTools

source ./edksetup.sh || :;

# Install Compatibility Support Module (CSM).
cp ~/seabios/out/Csm16.bin OvmfPkg/Csm/Csm16/

build --cmd-len=64436 \
	-DDEBUG_ON_SERIAL_PORT=TRUE \
	-DCSM_ENABLE=TRUE \
	-n $(getconf _NPROCESSORS_ONLN) \
	-a X64 \
	-a IA32 \
	-t GCC5 \
	-p OvmfPkg/OvmfPkgX64.dsc

echo ${latestovmftag} > latestovmftag

popd

ln -snf ovmf/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_CODE.fd OVMF_CODE.fd
ln -snf ovmf/Build/OvmfX64/DEBUG_GCC5/FV/OVMF_VARS.fd OVMF_VARS.fd
ln -snf ovmf/Build/OvmfX64/DEBUG_GCC5/FV/OVMF.fd OVMF.fd

exit 0
