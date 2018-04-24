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

RV=0
ssh -q \
	-o PasswordAuthentication=no \
	-o StrictHostKeyChecking=no \
	jenkins@$1 "test ! -f checkfornewkerneltag.sh" || RV=$?
if ((RV == 1)) ; then  
	# Insure latest version of the script
	# checkfornewkerneltag.sh is installed.

	distro=`./what_distro_remote.sh root@$1`
	if [[ $distro = "ubuntu-"* ]] || [[ $distro = "debian"-* ]] ; then
		scp checkfornewkerneltag_deb.sh jenkins@$1:checkfornewkerneltag.sh
		scp checkfornewqemutag.sh jenkins@$1:
		scp efiboot_multitool.pl root@$1:
		scp image_to_scratchdisk.sh root@$1:
	else
		scp checkfornewkerneltag_rpm.sh jenkins@$1:checkfornewkerneltag.sh
		scp checkfornewqemutag.sh jenkins@$1:
		scp efiboot_multitool.pl root@$1:
		scp image_to_scratchdisk.sh root@$1:
	fi
	exit
fi

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

#scp what_distro.sh root@$1:


#check distro here...
#sles and ubuntu have lsb_release by default, RHEL doesn't...

distro=`./what_distro_remote.sh root@$1`

#
# debian based distros
#
if [[ $distro = "ubuntu-"* ]] || [[ $distro = "debian-"* ]] ; then
	ssh -q root@$1 <<-EOF
	set -e

	# Install necessary applications.
	apt -y install build-essential libssl-dev libelf-dev git bison ifupdown net-tools flex rpm htop
	apt -y install lib32z1 lib32z1-dev arping qemu-kvm
	apt -y install uuid-dev nasm acpica-tools libncurses5-dev
	apt -y install python-dev python-networkx python-pip golang liblzma-dev libyaml-dev libvirt-dev bridge-utils openvswitch-switch
	apt -y install libpopt-dev libblkid-dev kpartx
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
	sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0\"' /etc/default/grub
	# Set GRUB_TIMEOUT=1 for faster rebooting.
	sed -i '/GRUB_TIMEOUT=/c\GRUB_TIMEOUT=1' /etc/default/grub
	# Comment out GRUB_HIDDEN_TIMEOUT=0.
	sed -i '/GRUB_HIDDEN_TIMEOUT=/c\#GRUB_HIDDEN_TIMEOUT=0' /etc/default/grub
	# Comment out #GRUB_HIDDEN_TIMEOUT_QUIET=true.
	sed -i '/GRUB_HIDDEN_TIMEOUT_QUIET=/c\#GRUB_HIDDEN_TIMEOUT_QUIET=true' /etc/default/grub
	echo 'GRUB_DISABLE_SUBMENU=y' >> /etc/default/grub
	update-grub

	# Disable un-necessary services.
	systemctl disable unattended-upgrades network-manager || true
	systemctl disable network-manager || true
	# No need to disable services for packages already removed.
	#systemctl disable whoopsie apport apparmor ufw

	# Insure "networking" service is enabled.
	systemctl enable networking || yes

	#install grubby on ubuntu
	rm -rf grubby
	git clone 'https://github.com/rhboot/grubby.git'
	cd grubby
	wget 'http://sos-infrastructure/~brwoods/patches/grubby_grub2.patch'
	git apply grubby_grub2.patch
	make install
	cd ..
EOF

# Setup bridge br0.
	ssh -q root@$1 "cat > /etc/network/interfaces" <<'EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

auto br0
iface br0 inet dhcp
	bridge_ports eth0
	bridge_stp off
	bridge_fd 0
	bridge_maxwait 0 
EOF

#
# UBUNTU 18.04
#
#elif [ "$distro" = "ubuntu-18.04" ] ; then
elif false ; then
	#echo "not currently supported due to changes in network config"
	#exit 1
	# see /etc/cloud/cloud.cfg.d/50-curtin-networking.cfg
	# and https://blog.ubuntu.com/2017/12/01/ubuntu-bionic-netplan
	#that should provide enough info
	ssh -q root@$1 <<-EOF
	set -e

	# Install necessary applications.
	apt -y install build-essential libssl-dev libelf-dev git bison net-tools flex rpm htop
	apt -y install lib32z1 lib32z1-dev
	apt -y install uuid-dev nasm acpica-tools libncurses5-dev
	apt -y install python-dev python-networkx python-pip golang liblzma-dev libyaml-dev libvirt-dev bridge-utils openvswitch-switch
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
	sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 selinux=0\"' /etc/default/grub
	# Set GRUB_TIMEOUT=1 for faster rebooting.
	sed -i '/GRUB_TIMEOUT=/c\GRUB_TIMEOUT=1' /etc/default/grub
	sed -i '/GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub
	# Comment out GRUB_HIDDEN_TIMEOUT=0.
	sed -i '/GRUB_HIDDEN_TIMEOUT=/c\#GRUB_HIDDEN_TIMEOUT=0' /etc/default/grub
	# Comment out #GRUB_HIDDEN_TIMEOUT_QUIET=true.
	sed -i '/GRUB_HIDDEN_TIMEOUT_QUIET=/c\#GRUB_HIDDEN_TIMEOUT_QUIET=true' /etc/default/grub

	update-grub

	# Disable un-necessary services.
	systemctl disable unattended-upgrades cups cups-browsed network-manager
	# No need to disable services for packages already removed.
	#systemctl disable whoopsie apport apparmor ufw

	#remove all auto generated netplan
	rm /etc/netplan/50-cloud-init.yaml
EOF

	#disable autogen of network scripts
	ssh -q root@$1 "cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg" <<'EOF'
network: {config: disabled}
EOF

	# Setup bridge br0.
	ssh -q root@$1 "cat > /etc/netplan/60-custom.yaml" <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      addresses: []
      dhcp4: false
  bridges:
    br0:
      dhcp4: true
      interfaces: [eth0]
EOF

#
# SUSE 12.3
#
elif [ "$distro" = "sles-12.3" ] ; then
	ssh -q root@$1 <<-EOF1
set -e

#add local iso repos
if ! ( zypper lr | grep dvd1_repo ) ; then
	zypper ar -c -f -n 'dvd 1 repo'     'http://sos-infrastructure.amd.com/fileserv/iso_repos/sles/12.3/dvd1/'     'dvd1_repo'
	zypper ar -c -f -n 'dvd 2 repo'     'http://sos-infrastructure.amd.com/fileserv/iso_repos/sles/12.3/dvd2/'     'dvd2_repo'
	zypper ar -c -f -n 'sdk dvd 1 repo' 'http://sos-infrastructure.amd.com/fileserv/iso_repos/sles/12.3/sdk_dvd1/' 'sdk_dvd1_repo'
	zypper ar -c -f -n 'sdk dvd 2 repo' 'http://sos-infrastructure.amd.com/fileserv/iso_repos/sles/12.3/sdk_dvd2/' 'sdk_dvd2_repo'
fi

zypper refresh
zypper -n install -t pattern Basis-Devel
zypper -n install gcc xz-devel rpm-build popt-devel libblkid-devel kpartx
zypper -n install libopenssl-devel libelf-devel git bison flex net-tools
zypper -n install rpm uuid-devel nasm acpica ncurses-devel python-devel
zypper -n install libyaml-devel libvirt-devel bridge-utils openvswitch
zypper -n remove python-six

curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py

pip install snakefood pynacl netifaces libvirt-python networkx

curl https://dl.google.com/go/go1.10.2.linux-amd64.tar.gz -o go1.10.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.10.2.linux-amd64.tar.gz
cat << 'EOF2' > /etc/profile.d/go.sh
PATH=$PATH:/usr/local/go/bin
export PATH
EOF2

echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10_jenkins

sed -i '/GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 selinux=0\"' /etc/default/grub
echo 'GRUB_DISABLE_SUBMENU=y' >> /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

#networking.... THE JOY OF THE NETWORK
#used yasted and manually edited for sanity

rm -f /etc/sysconfig/network/ifcfg-eth*
rm -f /etc/sysconfig/network/ifcfg-enp*

cat << 'EOF2' > /etc/sysconfig/network/ifcfg-br0
BOOTPROTO='dhcp'
BRIDGE='yes'
BRIDGE_FORWARDDELAY='0'
BRIDGE_PORTS='eth0'
BRIDGE_STP='off'
BROADCAST=''
DHCLIENT_SET_DEFAULT_ROUTE='yes'
ETHTOOL_OPTIONS=''
IPADDR=''
MTU=''
NAME=''
NETMASK=''
NETWORK=''
REMOTE_IPADDR=''
STARTMODE='onboot'
EOF2

cat << 'EOF2' > /etc/sysconfig/network/ifcfg-eth0
BOOTPROTO='none'
BROADCAST=''
ETHTOOL_OPTIONS=''
IPADDR=''
MTU=''
NAME='82574L Gigabit Network Connection'
NETMASK=''
NETWORK=''
REMOTE_IPADDR=''
STARTMODE='hotplug'
EOF2

#SLES one click install via CLI doesn't work, install from source
rm -rf grubby
git clone 'https://github.com/rhboot/grubby.git'
cd grubby
make install
cd ..
EOF1

#
# RED HAT 7.5
#
elif [ "$distro" = "rhel-7.5" ] ; then
	ssh -q root@$1 <<-EOF1
set -e

#add local iso repos
if [ ! -f /etc/yum.repos.d/iso_repo.repo ] ; then
	cat << 'EOF2' > /etc/yum.repos.d/iso_repo.repo
[iso_rhel_repo]
name=ISO RHEL repo
baseurl=http://sos-infrastructure.amd.com/fileserv/iso_repos/rhel/7.5/dvd1/
enabled=1
gpgcheck=0
EOF2
fi

wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
if ! ( rpm -qa | grep 'epel-release' )  ; then
	rpm -ivh epel-release-latest-7.noarch.rpm
fi

yum -y groupinstall 'Development Tools'
yum -y install gcc xz-devel libvirt-devel libvirt-glib-devel
yum -y install openssl-devel elfutils-libelf-devel  git bison flex net-tools
yum -y install rpm libuuid-devel nasm acpica-tools ncurses-devel python-devel
yum -y install yaml-cpp-devel bridge-utils grubby kpartx
yum -y remove python-pyudev


#pip install
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py

pip install snakefood pynacl netifaces libvirt-python networkx

#Install go
curl https://dl.google.com/go/go1.10.2.linux-amd64.tar.gz -o go1.10.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.10.2.linux-amd64.tar.gz
cat << 'EOF2' > /etc/profile.d/go.sh
PATH=$PATH:/usr/local/go/bin
export PATH
EOF2

#easy sudo for jenkins
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10_jenkins

#grub
#so we boot into new kernels
sed -i '/GRUB_DEFAULT=/c\GRUB_DEFAULT=saved' /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"console=tty0 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0 selinux=0\"' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg

#networking v
rm -f /etc/sysconfig/network-scripts/ifcfg-enp*
rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
cat << 'EOF2' > /etc/sysconfig/network-scripts/ifcfg-vbr0
DEVICE=br0
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=dhcp
NM_CONTROLLED=no
DELAY=0
EOF2
cat << 'EOF2' > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
TYPE=Ethernet
BOOTPROTO=none
ONBOOT=yes
NM_CONTROLLED=no
BRIDGE=br0
EOF2

#addes jenkins user
useradd -m -s /bin/bash -G wheel jenkins && echo jenkins:amd123 | chpasswd

EOF1
else
	echo "distro no found, exiting"
	exit 1;
fi
#
# DONE DISTRO DEPENDENT SETUP
#


# Default configuration for nano.
ssh -q root@$1 "cat > /etc/skel/.nanorc" <<'EOF'
set smooth
set nowrap
set nonewlines
include /usr/share/nano/*.nanorc
EOF

# Create user "jenkins", add it to the groups "sudo", and set its password to "amd123".
SUDOGROUP=""
if [[ $distro = "ubuntu-"* ]] || [[ $distro = "debian-"* ]] ; then
	SUDOGROUP="sudo"
else
	SUDOGROUP="wheel"
fi
RV=0
ssh -q root@$1 "useradd -m -s /bin/bash -G $SUDOGROUP jenkins" || RV=$?
if (( $RV == 9 )) || (( $RV == 0 )) ; then
	ssh -q root@$1 "echo jenkins:amd123 | chpasswd"
else
	echo "failed to create jenkins user, exiting"
	exit 1
fi

# Enable passwordless ssh as jenkins.
ssh -q \
	-o PasswordAuthentication=no \
	-o StrictHostKeyChecking=no \
	jenkins@$1 ":" || {
		./ssh-copy-id.expect jenkins@$1
	}

#put the what distro script in jenkin's home dir too
#scp what_distro.sh jenkins@$1:

### From here, everything is done as user "jenkins" ###

# Install the script checkfornewkerneltag.sh, which
# is also used as flag that this resource has already
# been setup for use with the test-infrastructure.
if [[ $distro = "ubuntu-"* ]] || [[ $distro = "debian-"* ]] ; then
	scp checkfornewkerneltag_deb.sh jenkins@$1:checkfornewkerneltag.sh
else
	scp checkfornewkerneltag_rpm.sh jenkins@$1:checkfornewkerneltag.sh
fi

scp efiboot_multitool.pl root@$1:
scp image_to_scratchdisk.sh root@$1:

scp checkfornewqemutag.sh jenkins@$1:

scp checkfornewovmftag.sh jenkins@$1:
scp -rp seabios jenkins@$1:

scp -rp guest-payload jenkins@$1:

ssh -q jenkins@$1 <<-EOF
chmod +x checkfornewkerneltag.sh

# Set file which will be used by
# a guest to retrieve its host-hostname.
echo $1 > guest-payload/host-hostname

# Install avocado.
git clone --progress git://github.com/avocado-framework/avocado.git && (
	cd avocado
	git checkout 58.0
	cat << 'EOF2' | git apply
diff --git a/avocado/utils/distro.py b/avocado/utils/distro.py
index 4c0d85cf..dfa48500 100644
--- a/avocado/utils/distro.py
+++ b/avocado/utils/distro.py
@@ -367,7 +367,7 @@ class SUSEProbe(Probe):
         version_id_re = re.compile(r'VERSION_ID="([\d\.]*)"')
         version_id = None
 
-        with open(self.check_file) as check_file:
+        with open(self.CHECK_FILE) as check_file:
             for line in check_file:
                 match = version_id_re.match(line)
                 if match:
EOF2
	sudo make requirements
	sudo python setup.py install

	cd optional_plugins/varianter_yaml_to_mux
	sudo python setup.py install
	
	#store basic tests in examples
	sudo mkdir -p /usr/share/avocado/tests/examples
	sudo cp -r ~jenkins/avocado/examples/tests/*  /usr/share/avocado/tests/examples/
)

# Install avocado-misc-tests.
git clone --progress https://github.com/avocado-framework-tests/avocado-misc-tests.git
sudo mkdir -p /usr/share/avocado/tests/avocado-misc-tests
sudo cp -r ~jenkins/avocado-misc-tests/* /usr/share/avocado/tests/avocado-misc-tests/

# Install avocado-vt.
git clone --progress https://github.com/avocado-framework/avocado-vt && (
	cd avocado-vt
	git checkout 58.0
	sudo make requirements
	sudo python setup.py install
	yes | sudo avocado vt-bootstrap
)
EOF

# Install configuration files used with avocado-vt.
scp -r avocado.conf.d jenkins@$1:

./rebootresource.sh jenkins@$1 &>/dev/null
