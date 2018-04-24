#!/bin/bash -x

# This script provision the ressource
# for which the url is given as argument.
# The provisioning setup the resource
# for use by the test-infrastructure.

set -e

# Exit if the ressource is not reachable.
ping -c 1 $1 &>/dev/null || exit

# Remove all keys matching hostname from known_hosts file.
ssh-keygen -R $1

# Enable passwordless ssh as root
# if not already enabled.
ssh -q \
	-o PasswordAuthentication=no \
	-o StrictHostKeyChecking=no \
	root@$1 ":" || {
	./ssh-copy-id.expect root@$1
}

ssh -q root@$1 <<-EOF
	set -e

	# Install necessary applications.
	apt -y install git ifupdown net-tools bridge-utils htop
	#apt -y install build-essential libssl-dev libelf-dev git bison ifupdown net-tools flex rpm htop
	#apt -y install python-dev python-networkx python-pip golang liblzma-dev libyaml-dev libvirt-dev bridge-utils openvswitch-switch
	#pip install snakefood pynacl netifaces libvirt-python

	# Remove unnecessary packages.
	apt -y remove whoopsie apparmor apport ufw

	# Insure /bin/sh symlink to /bin/bash instead of /bin/dash.
	ln -snf /bin/bash /bin/sh

	# Remove password prompting for sudo group.
	sed -i '/%sudo/c\%sudo ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers

	# Set kernel command-line for:
	# - Console output on the vga and first serial tty: console=tty0 console=ttyS0,115200n8
	# - Legacy network interface naming (ei: eth0) : net.ifnames=0 biosdevname=0
	sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8 earlyprintk=serial,keep net.ifnames=0 biosdevname=0\"' /etc/default/grub
	# Set GRUB_TIMEOUT=1 for faster rebooting.
	sed -i '/GRUB_TIMEOUT=/c\GRUB_TIMEOUT=1' /etc/default/grub
	# Comment out GRUB_HIDDEN_TIMEOUT=0.
	sed -i '/GRUB_HIDDEN_TIMEOUT=/c\#GRUB_HIDDEN_TIMEOUT=0' /etc/default/grub
	# Comment out #GRUB_HIDDEN_TIMEOUT_QUIET=true.
	sed -i '/GRUB_HIDDEN_TIMEOUT_QUIET=/c\#GRUB_HIDDEN_TIMEOUT_QUIET=true' /etc/default/grub
	update-grub

	# Disable un-necessary services.
	systemctl disable unattended-upgrades sddm cups cups-browsed network-manager
	# No need to disable services for packages already removed.
	#systemctl disable whoopsie apport apparmor ufw

	# Insure "networking" service is enabled.
	systemctl enable networking
EOF

# Setup bridge br0.
ssh -q root@$1 "cat > /etc/network/interfaces" <<'EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto br0
iface br0 inet manual
	pre-up ip link set eth0 down
	pre-up ip link add ${IFACE} type bridge
	pre-up ip link set eth0 master ${IFACE}
	pre-up ip link set eth0 up
	up ip link set ${IFACE} up
	up dhclient -nw -pf /run/dhclient.${IFACE}.pid -lf /var/lib/dhcp/dhclient.${IFACE}.leases -I -df /var/lib/dhcp/dhclient6.${IFACE}.leases ${IFACE}
	down dhclient -r -pf /run/dhclient.${IFACE}.pid -lf /var/lib/dhcp/dhclient.${IFACE}.leases -I -df /var/lib/dhcp/dhclient6.${IFACE}.leases ${IFACE}
	down ip link set ${IFACE} down
	post-down ip link set eth0 down
	post-down ip link set eth0 nomaster
	post-down ip link del ${IFACE}
EOF

# Default configuration for nano.
ssh -q root@$1 "cat > /etc/skel/.nanorc" <<'EOF'
set smooth
set nowrap
set nonewlines
include /usr/share/nano/*.nanorc
EOF

# Create user "jenkins", add it to the groups "sudo", and set its password to "amd123".
ssh -q root@$1 "useradd -m -s /bin/bash -G sudo jenkins && echo jenkins:amd123 | chpasswd"

# Enable passwordless ssh as jenkins.
./ssh-copy-id.expect jenkins@$1

### From here, everything is done as user "jenkins" ###

./rebootresource.sh jenkins@$1 &>/dev/null
