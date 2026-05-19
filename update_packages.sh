#!/bin/bash

# ==================================================
# Auto Install Basic Packages for Ubuntu
# Python3, Node.js, npm, build tools, dll
# ==================================================

echo "======================================"
echo " UPDATE & UPGRADE SYSTEM"
echo "======================================"

sudo apt update && sudo apt upgrade -y

echo "======================================"
echo " INSTALL BASIC TOOLS"
echo "======================================"

sudo apt install -y \
curl \
wget \
git \
nano \
vim \
unzip \
zip \
build-essential \
software-properties-common \
ca-certificates \
apt-transport-https \
gnupg \
lsb-release \
screen \
htop

echo "======================================"
echo " INSTALL PYTHON3"
echo "======================================"

sudo apt install -y \
python3 \
python3-pip \
python3-venv

echo "======================================"
echo " INSTALL NODE.JS & NPM"
echo "======================================"

# Install NodeSource Repository (Node.js 22)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -

sudo apt install -y nodejs

echo "======================================"
echo " CHECK VERSION"
echo "======================================"

echo "Python Version:"
python3 --version

echo "Pip Version:"
pip3 --version

echo "Node.js Version:"
node -v

echo "NPM Version:"
npm -v

echo "======================================"
echo " INSTALL PM2"
echo "======================================"

sudo npm install -g pm2

echo "PM2 Version:"
pm2 -v

echo "======================================"
echo " CLEAN UNUSED PACKAGES"
echo "======================================"

sudo apt autoremove -y
sudo apt autoclean

echo "======================================"
echo " INSTALLATION COMPLETED"
echo "======================================"
