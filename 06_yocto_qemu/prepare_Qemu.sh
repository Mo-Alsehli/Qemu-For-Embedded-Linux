#!/bin/bash

# This script is created by Eng. Moatasem Elsayed
# Github: https://github.com/Moatasem-Elsayed

set -e

echo "Starting the preparation of partitions..."

## Prepare the partitions
sudo rm -rf ./mnt/ || true
mkdir -p ./mnt/{boot,rootfs}
if [ -f rootfs.img ]; then
    echo -e "\e[32mrootfs.img already exists\e[0m"
else
    echo "Creating rootfs.img..."
    qemu-img create rootfs.img 2G
    echo "Please use cfdisk to create the following partitions:"
    echo "1. A primary partition of type FAT32 for boot."
    echo "2. A primary partition of type Linux for rootfs."
    echo "Press Enter to continue..."
    read
    sudo cfdisk ./rootfs.img
fi

echo -e "e[32Setting up loop device...\e[0m"
loopdevice=$(sudo losetup --show --partscan -f ./rootfs.img)
echo "Formatting partitions..."
sudo mkfs.fat "${loopdevice}"p1
sudo mkfs.ext4 "${loopdevice}"p2
echo -e "\e[32mMounting partitions...\e[0m"
sudo mount "${loopdevice}"p1 ./mnt/boot
sudo mount "${loopdevice}"p2 ./mnt/rootfs

echo -e "\e[32mMounting wic partitions...\e[0m"
## mount wic partitions
sudo rm -rf ./yoctomnt/ || true
mkdir -p ./yoctomnt/{boot,rootfs}
rm -rf ./*[0-9]*.wic || true
cp ../*[0-9]*.wic*bz2 .
bunzip2 ./*bz2
image=$(ls ./*[0-9]*.wic)
yoctoImage=$(sudo losetup --show --partscan -f "$image")
sudo mount "${yoctoImage}"p1 ./yoctomnt/boot
sudo mount "${yoctoImage}"p2 ./yoctomnt/rootfs

echo "Copying files..."
## Copy the files
sudo cp -r ./yoctomnt/boot/* ./mnt/boot/
sudo cp -r ./yoctomnt/rootfs/* ./mnt/rootfs/
sync

echo -e "\e[34mUnmounting partitions...\e[34m"
## Unmount the partitions
sudo umount ./mnt/boot
sudo umount ./mnt/rootfs

echo -e "\e[32mRunning Qemu...\e[0m"
## Run Qemu
sudo qemu-system-aarch64 \
    -M raspi3b \
    -cpu cortex-a7 \
    -m 1G \
    -smp 4 \
    -dtb ./yoctomnt/boot/bcm2710-rpi-3-b-plus.dtb \
    -kernel ./yoctomnt/boot/kernel8.img \
    -drive file=rootfs.img,format=raw,if=sd \
    -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootwait rw" \
    -nographic

echo -e "\e[34mCleaning up...\e[0m"
#unmount the wic partitions
sudo umount ./yoctomnt/boot
sudo umount ./yoctomnt/rootfs
sudo losetup -d "$loopdevice"
sudo losetup -d "$yoctoImage"

echo "Done."
