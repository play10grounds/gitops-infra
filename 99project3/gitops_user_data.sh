#!/bin/bash
sudo timedatectl set-timezone "Asia/Seoul"
sudo hwclock
sudo hostnamectl set-hostname gitops

sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

sudo echo "/swapfile       swap    swap    defaults        0       0" >> /etc/fstab
