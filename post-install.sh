#!/usr/bin/env bash
set -euo pipefail

# Source utils.sh for info()/error()
source /root/arch-setup/utils.sh

# Set the timezone
info "Setting timezone to Europe/Istanbul..."
ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime

# Enable NTP
info "Enabling NTP time synchronization..."
timedatectl set-ntp true

# Enable en_US.UTF-8 locale
info "Generating en_US.UTF-8 locale..."
sed -i 's/^#\s*\(en_US\.UTF-8[[:space:]]\+UTF-8\)/\1/' /etc/locale.gen
locale-gen

# Set system language
info "Setting system language to en_US.UTF-8..."
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# Set console keymap
info "Setting console keymap to trq..."
echo "KEYMAP=trq" >/etc/vconsole.conf

# Set hostname
info "Setting hostname to archlinux..."
echo "archlinux" >/etc/hostname

# Initializing & Populate pacman keyring
info "Initializing pacman keyring..."
pacman-key --init
info "Populating pacman keyring..."
pacman-key --populate archlinux

# Set root password
info "Please set the root password..."
passwd

# Create a new user
info "Creating a new user 'efe'..."
useradd -m -G wheel -s /bin/zsh efe

# Set password for the new user
info "Please set the password for user 'efe'..."
passwd efe

# Enable NetworkManager
info "Enabling NetworkManager..."
systemctl enable --now NetworkManager

# Clone dotfiles to /home/efe/dotfiles
info "Cloning dotfiles into /home/efe/dotfiles..."
runuser -l efe -c "git clone https://github.com/efeaslansoyler/dotfiles.git ~/dotfiles"

# Fix ownership of dotfiles
chown -R efe:efe /home/efe/dotfiles

# Allow wheel group to use sudo
info "Allowing wheel group to use sudo..."
sed -i 's/^#\s*\(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers

# Regenerate initramfs
info "Regenerating initramfs..."
mkinitcpio -P

# Enable fstrim.timer
info "Enabling fstrim.timer for SSDs..."
systemctl enable --now fstrim.timer

# Install and configure systemd-boot
info "Installing systemd-boot..."
bootctl install

# Grab the UUID of the root partition
info "Getting UUID of the root partition..."
root_dev=$(findmnt -n -o SOURCE /)
root_uuid=$(blkid -s UUID -o value "$root_dev")

# Configure loader.conf
info "Configuring /boot/loader/loader.conf..."
cat <<EOF >/boot/loader/loader.conf
default   arch.conf
timeout   3
console-mode   max
editor    no
EOF

# Configure arch.conf
info "Configuring /boot/loader/entries/arch.conf..."
info "Writing /boot/loader/entries/arch.conf..."
cat <<EOF >/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${root_uuid} rw ibt=off intel_iommu=on iommu=pt
EOF

info "Systemd-boot installation and configuration completed."

info "Post-installation tasks completed successfully."
info "You can now reboot the system."
