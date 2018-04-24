#!/bin/bash -xe

# This script install the latest linux-image from the test-infrastructure.

sudo wget -O /etc/apt/sources.list.d/sos_ubuntu.list http://sos-repos/scripts/sos_ubuntu.list
sudo apt update

# Install latest amdsos linux-image.
linuximage=$(apt-cache search linux-image | awk -F' - ' '{print $1}' | fgrep amdsos | sort -V | tail -n1)
[ -n "${linuximage}" ] && sudo apt install ${linuximage}

# Remove any installed *-jenkins package.
sudo apt remove -y *-jenkins

# Set it as the default kernel to boot into.
sudo grubby --set-default /boot/vmlinuz-$(echo ${linuximage} | grep -oP "(?<=linux-image-).+")
