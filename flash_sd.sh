#!/bin/bash

set -e

IMAGE_DIR="/home/dave/workspace/android-riscv"
DEVICE="/dev/sda"
BOOT_MOUNT="/home/dave/workspace/android-riscv/tmp"

echo "This will destroy all data on ${DEVICE}. Are you sure? (yes/[no])"
read confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Ensure all partitions on the device are unmounted
echo "[1/9] Unmounting all partitions on ${DEVICE}..."
sudo umount ${DEVICE}?* || true

# Disable swap if it is active
echo "[2/9] Disabling swap..."
sudo swapoff -a || true

# Partition the SD card
echo "[3/9] Partitioning SD card..."
sudo parted -s /dev/sda mklabel msdos
sudo parted /dev/sda mkpart primary ext4 1MiB 129MiB
sudo parted /dev/sda mkpart primary ext4 129MiB 1153MiB
sudo parted /dev/sda mkpart primary fat32 1153MiB 1281MiB
sudo parted /dev/sda set 3 esp on
sudo parted /dev/sda mkpart primary ext4 1281MiB 100%

# Format the partitions
echo "[4/9] Formatting partitions..."
sleep 2
sudo mkfs.ext4 -F ${DEVICE}1 -L vendor
sudo mkfs.ext4 -F ${DEVICE}2 -L system
sudo mkfs.vfat -F 32 ${DEVICE}3
sudo mkfs.ext4 -F ${DEVICE}4 -L userdata

# Flash the vendor and system images
echo "[5/9] Flashing vendor and system images..."
sudo dd if=${IMAGE_DIR}/vendor.img of=${DEVICE}1 bs=1M status=progress
sudo dd if=${IMAGE_DIR}/system.img of=${DEVICE}2 bs=1M status=progress

# Mount the boot partition
echo "[6/9] Mounting boot partition..."
sudo mkdir -p ${BOOT_MOUNT}
sudo mount ${DEVICE}3 ${BOOT_MOUNT}

# Set up correct /boot structure expected by U-Boot
echo "[7/9] Setting up /boot structure..."
sudo mkdir -p ${BOOT_MOUNT}/boot/extlinux
sudo cp -v ${IMAGE_DIR}/extlinux.conf ${BOOT_MOUNT}/boot/extlinux/
#sudo cp -v ${IMAGE_DIR}/uEnv.txt ${BOOT_MOUNT}/boot/
sudo cp -v ${IMAGE_DIR}/uEnv.txt ${BOOT_MOUNT}/vf2_uEnv.txt
sudo cp -v ${IMAGE_DIR}/ramdisk.img ${BOOT_MOUNT}/

# Copy kernel binaries to boot partition
sudo mkdir -p ${BOOT_MOUNT}/dtbs/starfive
sudo cp -v ${IMAGE_DIR}/jh7110-starfive-visionfive-2-v1.2a.dtb ${BOOT_MOUNT}/dtbs/starfive/
sudo cp -v ${IMAGE_DIR}/Image.gz ${BOOT_MOUNT}/

# Sync and unmount
echo "[9/9] Syncing and unmounting..."
sync
sudo umount ${BOOT_MOUNT}
sudo rm -rf ${BOOT_MOUNT}

echo "✅ Done! SD card is ready for autoboot."
