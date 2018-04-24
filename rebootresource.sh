#!/bin/bash -x

# This script reboot the resource
# for which the url is given as first argument,
# and wait until it can accept commands.
# If a second argument is given, it is used
# to select the custom kernel installed to boot into.

set -e

# Check if the resource is to be rebooted
# into a custom kernel installed.
if [ $# -eq 2 ]; then
	# Escape ERE regexp meta-characters.
	kernver=$(echo -n "$2" | sed 's/[.[\*^$()+?{|]/\\&/g')
	# Extract grub menuentry from /boot/grub/grub.cfg .
	grubkernentry0=$(ssh -q $1 sudo cat /boot/grub/grub.cfg | grep -P "(?<=menuentry ').+${kernver}(|.+)(?=-jenkins')")
	grubkernentry1=$(echo -n ${grubkernentry0} | grep -oP "(?<=menuentry_id_option ').+${kernver}(|.+)(?=' {)")
	grubkernentry2=$(echo -n ${grubkernentry1} | grep -oP "(?<=advanced-).+")
	# Escape BRE regexp meta-characters.
	grubkernentry1=$(echo -n "${grubkernentry1}" | sed 's/[.[\*^$]/\\&/g')
	grubkernentry2=$(echo -n "${grubkernentry2}" | sed 's/[.[\*^$]/\\&/g')
	# Set kernel to reboot into.
	ssh -q $1 sudo sed -i "/GRUB_DEFAULT=/c\GRUB_DEFAULT=\'gnulinux-advanced-${grubkernentry2}\\>${grubkernentry1}\'" /etc/default/grub
	ssh -q $1 sudo update-grub
fi

# Send reboot commands until the system actually
# stop accepting commands due to being in a reboot.
#until ! ssh -q $1 'sudo reboot || sudo reboot -f || :;'; do :; done
#until ! ssh -q $1 'sync; sudo reboot -f || :;'; do :; done
timeout -sKILL 60 ssh -q $1 'sync; sudo reboot -f' || :;

# Wait until resource can accept commands.
until timeout -sKILL 60 ssh -q $1 ':'; do :; done
