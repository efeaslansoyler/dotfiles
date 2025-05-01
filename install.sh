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
if ! command -v yay &>/dev/null; then
  info "yay not found, installing yay..."
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd -
  rm -rf /tmp/yay
else
  info "yay is already installed."
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

info "Enabling SSH daemon..."
sudo systemctl enable --now sshd
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

# Stow dotfiles
if [ "$(basename "$PWD")" == "dotfiles" ]; then
  info "Stowing dotfiles..."
  stow .
else
  error "Please run this script from the 'dotfiles' directory."
  exit 1
fi

info "Setup complete! Please reboot your system to apply all changes."
