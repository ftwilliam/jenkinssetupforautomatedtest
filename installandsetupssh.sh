#!/bin/bash

set -xe

sudo apt -y install openssh-server
yes "" | sudo ssh-keygen -t rsa
sudo sed -i '/#PasswordAuthentication/c\PasswordAuthentication yes' /etc/ssh/sshd_config
sudo sed -i '/#PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
sudo /etc/init.d/ssh restart
