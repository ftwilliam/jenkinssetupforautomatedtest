#!/bin/python

# This script prints the name of unlocked resources.
# When given arguments, only resources with labels
# matching one or more of the given arguments are printed.

import sys
import xml.etree.ElementTree as ET

tree = ET.parse('org.jenkins.plugins.lockableresources.LockableResourcesManager.xml')

root = tree.getroot()

for child in root:
	if (child.tag == 'resources'):
		# Found resources.
		for resource in child:
			lockedby = resource.find('buildExternalizableId')
			if len(sys.argv) > 1 and lockedby != None:
				for jobname in sys.argv:
					if jobname == lockedby.text:
						print(resource.find('name').text)
	exit()
