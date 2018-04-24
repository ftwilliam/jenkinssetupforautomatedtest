deps_config := \
	vgasrc/Kconfig \
	/home/jenkins/seabios/src/Kconfig

include/config/auto.conf: \
	$(deps_config)


$(deps_config): ;
