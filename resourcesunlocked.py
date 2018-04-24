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
			if resource.find('reservedBy') is None:
				if len(sys.argv) > 1:
					for label in resource.find('labels').text.split():
						for selectlabel in sys.argv:
							if label == selectlabel:
								print(resource.find('name').text)
				else:
					print(resource.find('name').text)
	exit()
