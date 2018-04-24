#!/bin/bash -x

# This script build and install
# a newly tagged qemu from
# the url given as argument.

set -e

if [ ! -d qemu ]; then
	git clone --progress $1
fi

cd qemu

git remote set-url origin $1

git fetch --all --tags

# Retrieve tag to use.
if [ $# -eq 2 -a -n "$2" ]; then
	latestqemutag=$2
else
	latestqemutag=$(git describe --tags --abbrev=0 origin/master)
fi

if [ "${latestqemutag}" != "$(cat latestqemutag 2>/dev/null)" ]; then
	git checkout ${latestqemutag} || exit 1
else
	exit 1
fi

# Insure needed libraries are installed.
sudo apt -y install libglib2.0-dev libpixman-1-dev

./configure \
	--target-list=x86_64-softmmu \
	--enable-trace-backend=log \
	--prefix=/usr
make -j$(getconf _NPROCESSORS_ONLN)
sudo make -j$(getconf _NPROCESSORS_ONLN) install

echo ${latestqemutag} > latestqemutag

exit 0
