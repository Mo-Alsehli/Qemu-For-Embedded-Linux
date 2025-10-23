#!/bin/bash

# This script is created by Eng. Moatasem Elsayed
# Github: https://github.com/Moatasem-Elsayed

set -e

echo "Starting the preparation of partitions..."


echo -e "\e[32mMounting sdimg partitions...\e[0m"

image=$(ls ./2*[0-9]*.img)
qemu-img resize "$image" 4G
raspiosImage=$(sudo losetup --show --partscan -f "$image")
sudo mount "${raspiosImage}"p1 ./raspios/boot

echo "Copying files..."
## Copy the files
sudo cp -r ./raspios/boot/bcm2710-rpi-3-b.dtb .
sudo cp -r ./raspios/boot/kernel8.img .
sync
echo -e "\e[34mCleaning up...\e[0m"
echo -e "\e[34mUnmounting partitions...\e[34m"
## Unmount the partitions
sudo umount ./raspios/boot
sudo losetup -d "$raspiosImage"
echo -e "\e[32mRunning Qemu...\e[0m"
## Run Qemu
qemu-system-arm64 \
    -M raspi3b \
    -cpu cortex-a53 \
    -m 1G \
    -smp 4 \
    -dtb bcm2710-rpi-3-b.dtb \
    -kernel kernel8.img \
    -drive file="$image",format=raw,if=sd \
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw earlyprintk loglevel=7" \
    -usbdevice keyboard -usbdevice mouse \
    -netdev user,id=net0 -device usb-net,netdev=net0 \
    -display gtk

echo "Done."
