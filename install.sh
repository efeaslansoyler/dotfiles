#!/usr/bin/env bash
set -euo pipefail

# Source utils.sh for info()/error()
source ./utils.sh

# Load keymap trq
info "Loading keymap trq..."
loadkeys trq

# Enable NTP
info "Enabling NTP for accurate time…"
timedatectl set-ntp true

# List available disks
info "Listing available disks..."
lsblk -d -o NAME,SIZE,MODEL

# Prompt for disk selection
echo
read -p "Enter the disk to install Arch Linux (e.g., /dev/sda): " DISK

# Validate disk selection
if [[ ! -b "$DISK" ]]; then
  error "Invalid disk selected. Please run the script again and select a valid disk."
  exit 1
fi

info "Selected disk: $DISK"

# Partition Sizes
BOOT_SIZE="2"
SWAP_SIZE="34"

info "Creating partitions on $DISK..."
info " 1) EFI boot partition: $BOOT_SIZE GiB"
info " 2) Swap partition: $SWAP_SIZE GiB"
info " 3) Root partition: Remaining space"

# WİPE DISK
sgdisk --clear "$DISK"

# Create EFI Boot Partition
sgdisk --new=1:0:+${BOOT_SIZE}G \
  --typecode=1:ef00 \
  --change-name=1:"EFI System" \
  "$DISK"

# Create SWAP Partition
sgdisk --new=2:0:+${SWAP_SIZE}G \
  --typecode=2:8200 \
  --change-name=2:"Linux Swap" \
  "$DISK"

# Create Root Partition
sgdisk --new=3:0:0 \
  --typecode=3:8300 \
  --change-name=3:"Linux Root" \
  "$DISK"

# Inform the kernel of partition table changes
partprobe "$DISK"

# Detect whether to use the “p” separator
if [[ "$DISK" =~ ^/dev/nvme ]]; then
  PARTSEP="p"
else
  PARTSEP=""
fi
BOOT_PARTITION="${DISK}${PARTSEP}1"
SWAP_PARTITION="${DISK}${PARTSEP}2"
ROOT_PARTITION="${DISK}${PARTSEP}3"

info "Partitions created:"
lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT

# Format partitions
info "Formatting partitions..."

# Format EFI Boot Partition
info "Formatting EFI Boot Partition ($BOOT_PARTITION)..."
mkfs.fat -F32 "$BOOT_PARTITION"

# Format SWAP Partition
info "Formatting SWAP Partition ($SWAP_PARTITION)..."
mkswap "$SWAP_PARTITION"

# Format Root Partition
info "Formatting Root Partition ($ROOT_PARTITION)..."
mkfs.ext4 "$ROOT_PARTITION"

# Mount partitions
info "Mounting partitions..."

# Mount Root Partition
info "Mounting Root Partition ($ROOT_PARTITION) to /mnt..."
mount "$ROOT_PARTITION" /mnt

# Mount EFI Boot Partition
info "Mounting EFI Boot Partition ($BOOT_PARTITION) to /mnt/boot..."
mount --mkdir "$BOOT_PARTITION" /mnt/boot

# Mount SWAP Partition
info "Mounting SWAP Partition ($SWAP_PARTITION)..."
swapon "$SWAP_PARTITION"

# Ask about additional disk mounting
echo
info "Do you want to mount an additional disk (e.g., for games/VMs)?"
read -p "Mount additional disk? (y/N): " MOUNT_ADDITIONAL

if [[ "$MOUNT_ADDITIONAL" =~ ^[Yy]$ ]]; then
  info "Listing available disks (excluding installation disk)..."
  lsblk -d -o NAME,SIZE,MODEL,FSTYPE | grep -v "$(basename "$DISK")"
  
  echo
  read -p "Enter the additional disk/partition to mount (e.g., /dev/sdb1): " ADDITIONAL_DISK
  
  # Validate additional disk selection
  if [[ ! -b "$ADDITIONAL_DISK" ]]; then
    error "Invalid disk/partition selected: $ADDITIONAL_DISK"
    error "Continuing without mounting additional disk..."
  else
    # Get UUID of the additional disk
    ADDITIONAL_UUID=$(blkid -s UUID -o value "$ADDITIONAL_DISK")
    
    if [[ -z "$ADDITIONAL_UUID" ]]; then
      error "Could not get UUID for $ADDITIONAL_DISK"
      error "Continuing without mounting additional disk..."
    else
      info "UUID of additional disk: $ADDITIONAL_UUID"
      
      # Create mount directory
      ADDITIONAL_MOUNT_POINT="/mnt/run/media/efe/$ADDITIONAL_UUID"
      info "Creating mount directory: $ADDITIONAL_MOUNT_POINT"
      mkdir -p "$ADDITIONAL_MOUNT_POINT"
      
      # Mount the additional disk
      info "Mounting $ADDITIONAL_DISK to $ADDITIONAL_MOUNT_POINT..."
      mount "$ADDITIONAL_DISK" "$ADDITIONAL_MOUNT_POINT"
      
      info "Additional disk mounted successfully!"
      info "It will be available at /run/media/efe/$ADDITIONAL_UUID after installation"
    fi
  fi
fi

# Install base system
info "Installing base system..."
pacstrap -K /mnt \
  base base-devel \
  linux linux-firmware linux-headers \
  sof-firmware intel-ucode \
  networkmanager \
  nano vim git \
  man-db man-pages texinfo \
  zsh

# Generate fstab
info "Generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab

info "fstab generated at /mnt/etc/fstab"

info "Base system installed successfully."

info "Chrooting into the new system..."

# Create a temporary directory for the chroot environment
TEMP_DIR="/mnt/install_temp"
info "Creating temporary directory at $TEMP_DIR..."
mkdir -p "${TEMP_DIR}"

# Copy the script to the temporary directory
info "Copying script to temporary directory..."
cp ./post-install.sh "${TEMP_DIR}/post-install.sh"
cp ./utils.sh "${TEMP_DIR}/utils.sh"
chmod +x "${TEMP_DIR}/post-install.sh"

info "Chrooting into the new system..."
arch-chroot /mnt /bin/bash -c "${TEMP_DIR}/post-install.sh"
info "Chrooted into the new system. Post-installation script executed."

# Clean up
info "Cleaning up temporary directory..."
rm -rf "${TEMP_DIR}"

# Finalize
info "Installation completed. You can now reboot into your new Arch Linux system."
