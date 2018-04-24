#!/bin/bash

CODENAME=""

WHICH_OUT=`which lsb_release 2> /dev/null`
RESULT=$?

#rhel doesn't ship with lsb_release, so dunce... er red hat mode it is//
if [ "$RESULT" -ne 0 ] ; then
	INFO=`cat /etc/redhat-release 2> /dev/null`
	RESULT=$?
	if [ "$RESULT" -ne 0 ] ; then
		echo "failed to ID distro"
		exit 1
	fi
	DISTRO=`echo $INFO | awk -F" release " '{print $1}'`
	if [ "$DISTRO" = "Red Hat Enterprise Linux Server" ] ; then
		DISTRO="rhel"
	elif [ "$DISTRO" = "Fedora" ] ; then
		DISTRO="fedora"
	else
		echo "failed to ID distro"
		exit 1
	fi
	VER=`echo $INFO | awk -F" release " '{print $2}'`
	VER=`echo $VER | cut -f1 -d' '`
	CODENAME="$DISTRO-$VER"

else	#sane OSs here
	DISTRO=`lsb_release -si 2> /dev/null | awk '{print tolower($0)}'`
	VER=`lsb_release -rs 2> /dev/null`
	if [ "$DISTRO" = "suse" ] ; then
		DISTRO="sles"
	elif [ "$DISTRO" = "debian" ] ; then
		VER=`echo $VER | awk -F"." '{print $1}'`
	fi
	CODENAME="$DISTRO-$VER"
fi

echo "$CODENAME"
