#!/bin/bash

# This script assume that ~/kernel/linux exist.

set -e

touch ~/payload_script_invoked

cd $(dirname $0) || {
	echo "failed to cd to payload script location"
	exit 1
}

yum install -y sshpass

sshpass -pamd123 scp -o StrictHostKeyChecking=no /boot/config-$(uname -r) jenkins@$(cat host-hostname):guest-kernelconfig

S='$'

sshpass -pamd123 ssh -o StrictHostKeyChecking=no -q jenkins@$(cat host-hostname) <<-EOF

	set -xe

	rm -rf rpmbuild

	cd kernel/linux

	make mrproper

	cp ~/guest-kernelconfig .config

	./scripts/config --disable CONFIG_MODULE_SIG

	yes "" | make olddefconfig

	make -j $S(getconf _NPROCESSORS_ONLN) rpm-pkg LOCALVERSION=-jenkins
EOF

sshpass -pamd123 scp -o StrictHostKeyChecking=no jenkins@$(cat host-hostname):rpmbuild/RPMS/x86_64/kernel-[0-9]*.rpm .

touch ~/payload_kernel_built

# Disable selinux.
echo 1 > /sys/fs/selinux/disable

# Install kernel.
rpm -i kernel-*jenkins*.rpm

grubby --set-default /boot/vmlinuz-*-jenkins

touch ~/payload_done_running_script
