#!/bin/bash -x

# This script provision the ressource
# for which the url is given as argument.
# The provisioning setup the resource
# for use by the test-infrastructure.

set -e

# Exit if the ressource is not reachable.
ping -c 1 $1 &>/dev/null || exit

# Exit if the flag checkfornewkerneltag.sh is present;
# it means that this resource has already been setup
# for use with the test-infrastructure.
ssh -q \
	-o PasswordAuthentication=no \
	-o StrictHostKeyChecking=no \
	jenkins@$1 "test ! -f checkfornewkerneltag.sh" || {

	[ $? -eq 1 ] && {
		# Insure latest version of the script
		# checkfornewkerneltag.sh is installed.
		scp checkfornewkerneltag.sh jenkins@$1:

		scp checkfornewqemutag.sh jenkins@$1:

		exit
	}
}

# Remove all keys matching hostname from known_hosts file.
ssh-keygen -R $1

# Enable passwordless ssh as root
# if not already enabled.
ssh \
	-o PasswordAuthentication=no \
	-o StrictHostKeyChecking=no \
	root@$1 ":" || {
	./ssh-copy-id.expect root@$1
}

ssh root@$1 <<-EOF
	set -e

	# Install necessary applications.
	apt -y install build-essential libssl-dev libelf-dev git bison ifupdown net-tools cpuid flex rpm htop
	apt -y install lib32z1 lib32z1-dev
	apt -y install uuid-dev nasm acpica-tools libncurses5-dev
	apt -y install python-dev python-networkx python-pip golang liblzma-dev libyaml-dev libvirt-dev bridge-utils openvswitch-switch
	apt -y install libpopt-dev libblkid-dev
	pip install snakefood pynacl netifaces libvirt-python

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

	# Install grubby.
	wget http://sos-infrastructure/fileserv/test_infrastructure/grubby/grubby.tar.bz2
	tar -xf grubby.tar.bz2
	cd grubby
	wget http://sos-infrastructure/fileserv/test_infrastructure/grubby/grubby_ubuntu.patch
	patch --dry-run -p1 <grubby_ubuntu.patch
	make
	make install
EOF

# Setup bridge br0.
ssh root@$1 "cat > /etc/network/interfaces" <<'EOF'
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
ssh root@$1 "cat > /etc/skel/.nanorc" <<'EOF'
set smooth
set nowrap
set nonewlines
include /usr/share/nano/*.nanorc
EOF

# Create user "jenkins", add it to the groups "sudo", and set its password to "amd123".
ssh root@$1 "useradd -m -s /bin/bash -G sudo jenkins && echo jenkins:amd123 | chpasswd" || :;

# Enable passwordless ssh as jenkins.
./ssh-copy-id.expect jenkins@$1 || :;

### From here, everything is done as user "jenkins" ###

# Install the script checkfornewkerneltag.sh, which
# is also used as flag that this resource has already
# been setup for use with the test-infrastructure.
scp checkfornewkerneltag.sh jenkins@$1:

scp checkfornewqemutag.sh jenkins@$1:

scp checkfornewkerneldeb.sh jenkins@$1:

scp checkfornewovmftag.sh jenkins@$1:
scp -rp seabios jenkins@$1:

scp -rp guest-payload jenkins@$1:

ssh jenkins@$1 <<-EOF
	set -e

	chmod +x checkfornewkerneltag.sh

	# Set file which will be used by
	# a guest to retrieve its host-hostname.
	echo $1 > guest-payload/host-hostname

	# Install avocado.
	git clone --progress git://github.com/avocado-framework/avocado.git && (
		cd avocado
		git checkout 58.0
		sudo make requirements
		sudo python setup.py install

		cd optional_plugins/varianter_yaml_to_mux
		sudo python setup.py install
	)

	# Install avocado-misc-tests.
	git clone --progress https://github.com/avocado-framework-tests/avocado-misc-tests.git

	# Install avocado-vt.
	git clone --progress https://github.com/avocado-framework/avocado-vt && (
		cd avocado-vt
		git checkout 58.0
		sudo make requirements
		sudo python setup.py install
		yes | sudo avocado vt-bootstrap
	)

	#  Install lkp-tests
	git clone https://github.com/01org/lkp-tests.git
	cd lkp-tests
	sudo make install
	# remove any sos repo; as it conflicts;
	# it will be restored by test neededing it.
	sudo rm -rf /etc/apt/sources.list.d/*sos*
	sudo apt update
	sudo lkp install
EOF

# Install configuration files used with avocado-vt.
scp -r avocado.conf.d jenkins@$1:

./rebootresource.sh jenkins@$1 &>/dev/null
