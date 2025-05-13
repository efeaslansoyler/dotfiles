#!/usr/bin/env bash
set -euo pipefail

# Load utilities and package categories
source ./utils.sh
source ./packages.conf

PACMAN_CONF="/etc/pacman.conf"
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
ZSHRC="$HOME/.zshrc"

info "Configuring pacman.conf..."

# Backup pacman.conf
sudo cp "$PACMAN_CONF" "$PACMAN_CONF.bak"

# Uncomment 'Color' in pacman.conf
sudo sed -i 's/^#Color/Color/' "$PACMAN_CONF"

# Add ILoveCandy under Color if not already present
if ! grep -q "^ILoveCandy" "$PACMAN_CONF"; then
  sudo sed -i '/^Color$/a ILoveCandy' "$PACMAN_CONF"
fi

# Enable multilib repository
sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/{
  s/#\[multilib\]/[multilib]/;
  s/#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/;
}' "$PACMAN_CONF"

# Refresh pacman database to recognize new repositories
info "Refreshing pacman database..."
sudo pacman -Syy

info "pacman.conf configured successfully."

# Add Chaotic-AUR repository

info "Importing Chaotic-AUR key..."
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

info "Installing Chaotic-AUR keyring and mirrorlist..."
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

# Add Chaotic-AUR repo to pacman.conf if not already present
if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
  info "Adding Chaotic-AUR repository to pacman.conf..."
  echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf
else
  info "Chaotic-AUR repository already present in pacman.conf."
fi

# Sync and update system
info "Syncing and updating system with Chaotic-AUR enabled..."
sudo pacman -Syu --noconfirm

# Ensure reflector is installed
if ! command -v reflector &>/dev/null; then
  info "Installing reflector for mirrorlist optimization..."
  sudo pacman -S --needed --noconfirm reflector
else
  info "reflector is already installed."
fi

# Optimize mirrorlist
info "Optimizing pacman mirrorlist with reflector..."
if ! sudo reflector \
  --country Turkey,Germany,Bulgaria,Greece \
  --age 12 \
  --protocol https \
  --sort rate \
  --save /etc/pacman.d/mirrorlist; then
  error "Reflector failed to update mirrorlist. Continuing with existing mirrorlist."
fi

info "Mirrorlist updated."

# Refresh pacman database to use new mirrors
info "Refreshing pacman database with new mirrors..."
sudo pacman -Syy

# Ensure yay is installed
if ! command -v paru &>/dev/null; then
  info "paru not found, installing paru..."
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/paru-git.git /tmp/paru-git
  cd /tmp/paru-git
  makepkg -si --noconfirm
  cd -
  rm -rf /tmp/paru-git
else
  info "paru is already installed."
fi

# Install NVIDIA drivers
info "Installing NVIDIA drivers..."
install_category nvidia_pkgs

# Backup mkinitcpio.conf
sudo cp "$MKINITCPIO_CONF" "$MKINITCPIO_CONF.bak"

# Configure mkinitcpio.conf
info "Configuring mkinitcpio.conf for NVIDIA..."

# 1. Set MODULES (replace the line with the correct modules)
sudo sed -i 's/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_CONF"

# 2. Remove 'kms' from HOOKS
sudo sed -i 's/\<kms\>//g' "$MKINITCPIO_CONF"

info "mkinitcpio.conf configured."

# Regenerate initramfs
info "Regenerating initramfs..."
sudo mkinitcpio -P

# Install remaining package categories
categories=(
  wm_pkgs
  font_pkgs
  app_pkgs
  audio_pkgs
  util_pkgs
  virt_pkgs
)

info "Installing remaining packages..."
# Gather all package arrays except nvidia_pkgs
for category in "${categories[@]}"; do
  install_category "$category"
done

info "All packages installed!"

# Install Colloid GTK Theme
COLLOID_GTK_DIR="/tmp/Colloid-gtk-theme"
if [ ! -d "$COLLOID_GTK_DIR" ]; then
  info "Cloning Colloid GTK theme..."
  git clone --depth=1 https://github.com/vinceliuice/Colloid-gtk-theme.git "$COLLOID_GTK_DIR"
else
  info "Colloid GTK theme repo already cloned."
fi

info "Installing Colloid GTK theme with your options..."
bash "$COLLOID_GTK_DIR/install.sh" -t pink -c dark -l --tweaks black

# Install Colloid Icon Theme
COLLOID_ICON_DIR="/tmp/Colloid-icon-theme"
if [ ! -d "$COLLOID_ICON_DIR" ]; then
  info "Cloning Colloid icon theme..."
  git clone --depth=1 https://github.com/vinceliuice/Colloid-icon-theme.git "$COLLOID_ICON_DIR"
else
  info "Colloid icon theme repo already cloned."
fi

info "Installing Colloid icon theme with your options..."
bash "$COLLOID_ICON_DIR/install.sh" -t pink

# Clean up
rm -rf "$COLLOID_GTK_DIR" "$COLLOID_ICON_DIR"

# Configure Zshrc
touch "$ZSHRC"
HYPRLAND_BLOCK="# Start Hyprland with uwsm
if uwsm check may-start; then
  exec uwsm start hyprland-uwsm.desktop
fi
"
# Add Hyprland autostart block to .zshrc if not already present
if ! grep -q "exec uwsm start hyprland-uwsm.desktop" "$ZSHRC" 2>/dev/null; then
  info "Adding Hyprland autostart block to .zshrc"
  echo -e "\n$HYPRLAND_BLOCK" >>"$ZSHRC"
else
  info "Hyprland autostart block already present in .zshrc"
fi

# Enable and start services
info "Enabling fstrim.timer (SSD TRIM support)..."
sudo systemctl enable --now fstrim.timer

info "Enabling and starting services..."
# System Services
sudo systemctl enable --now sshd
sudo systemctl enable libvirtd.service
sudo systemctl enable --now tuned.service
# User Services
systemctl --user enable waybar
systemctl --user enable hyprpaper
systemctl --user enable hypridle
systemctl --user enable hyprpolkitagent
systemctl --user enable swaync

# Install and enable UFW firewall
info "Installing and enabling UFW firewall..."
sudo pacman -S --needed --noconfirm ufw
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# Download virtio-win ISO for Windows VMs
VIRTIO_DIR="/usr/share/virtio-win"
VIRTIO_ISO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win.iso"
VIRTIO_ISO_PATH="$VIRTIO_DIR/virtio-win.iso"

info "Preparing to download virtio-win ISO for Windows VMs..."

# Create the directory if it doesn't exist
sudo mkdir -p "$VIRTIO_DIR"

# Download the ISO if not already present
if [ ! -f "$VIRTIO_ISO_PATH" ]; then
  info "Downloading virtio-win ISO..."
  sudo wget -O "$VIRTIO_ISO_PATH" "$VIRTIO_ISO_URL"
  info "virtio-win ISO downloaded to $VIRTIO_ISO_PATH"
else
  info "virtio-win ISO already exists at $VIRTIO_ISO_PATH"
fi

# Enable nested virtualization for Intel CPUs (current session)
info "Enabling nested virtualization for Intel CPUs..."
sudo modprobe -r kvm_intel
sudo modprobe kvm_intel nested=1

# Make nested virtualization persistent across reboots
info "Making nested virtualization persistent..."
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf

# Set tuned profile for virtual host
info "Setting tuned profile to 'virtual-host'..."
sudo tuned-adm profile virtual-host

# Add current user to libvirt group
info "Adding $USER to libvirt group..."
sudo usermod -aG libvirt "$USER"

# Autostart the default libvirt network
info "Setting default libvirt network to autostart..."
sudo virsh net-autostart default

# Set ACLs for /var/lib/libvirt/images/ so $USER can access VM images
info "Setting ACLs for /var/lib/libvirt/images/..."

sudo setfacl -R -b /var/lib/libvirt/images/
sudo setfacl -R -m "u:${USER}:rwX" /var/lib/libvirt/images/
sudo setfacl -m "d:u:${USER}:rwx" /var/lib/libvirt/images/

info "ACLs set for /var/lib/libvirt/images/."

# Stow dotfiles
if [ "$(basename "$PWD")" == "dotfiles" ]; then
  info "Stowing dotfiles..."
  stow .
else
  error "Please run this script from the 'dotfiles' directory."
  exit 1
fi

info "Setup complete! Please reboot your system to apply all changes."
