#!/bin/bash
# Omarchy Fedora Port — Unified Apply Script
# Combines all patches: TPM2, scripts, menus, docs, kickstart, update hook
# Run with: sudo bash ~/Projects/Omarchy-Fedora/apply.sh

set -e
OMARCHY=/usr/share/omarchy
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Omarchy Fedora Port: Applying All Patches ==="

# --- BINDINGS ---
echo "[0/8] Fixing keybindings..."
cp "$SCRIPT_DIR/../omarchy/default/hypr/bindings/utilities.lua" "$OMARCHY/default/hypr/bindings/utilities.lua" 2>/dev/null || true
cp "$OMARCHY/default/hypr/bindings/utilities.lua" "$OMARCHY/fedora-patches/utilities.lua" 2>/dev/null || true

# --- FEDORA PATCHES DIRECTORY (for post-update re-application) ---
echo "[1/10] Installing fedora-patches directory..."
mkdir -p "$OMARCHY/fedora-patches"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-ks.cfg" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-ks-offline.cfg" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$OMARCHY/fedora-patches/"

# --- APPLY-FEDORA-PATCHES SCRIPT ---
echo "[2/10] Installing omarchy-apply-fedora-patches..."
cp "$SCRIPT_DIR/omarchy-apply-fedora-patches" "$OMARCHY/bin/omarchy-apply-fedora-patches"
chmod +x "$OMARCHY/bin/omarchy-apply-fedora-patches"

# --- TPM2 SUPPORT ---
echo "[3/10] Installing TPM2 support..."
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/bin/omarchy-setup-tpm2-unlock"
chmod +x "$OMARCHY/bin/omarchy-setup-tpm2-unlock"

# --- DRACUT TPM2 CONFIG ---
echo "[4/10] Configuring dracut TPM2 support..."
mkdir -p /etc/dracut.conf.d
if [[ -f /etc/dracut.conf.d/tpm2.conf ]]; then
  if ! grep -q "tpm2-tss" /etc/dracut.conf.d/tpm2.conf 2>/dev/null; then
    echo 'add_dracutmodules+=" tpm2-tss "' >> /etc/dracut.conf.d/tpm2.conf
  fi
else
  echo 'add_dracutmodules+=" tpm2-tss "' > /etc/dracut.conf.d/tpm2.conf
fi
rm -f /etc/dracut.conf.d/omarchy-keyfile.conf

echo "[5/10] Installing patched kickstart files..."
cp "$SCRIPT_DIR/omarchy-ks.cfg" "$OMARCHY/installer/omarchy-ks.cfg"
cp "$SCRIPT_DIR/omarchy-ks-offline.cfg" "$OMARCHY/installer/omarchy-ks-offline.cfg"
chmod +x "$OMARCHY/installer/omarchy-ks.cfg" "$OMARCHY/installer/omarchy-ks-offline.cfg"

# --- WEBAPP MANIFESTS ---
echo "[6/10] Deploying webapp manifests..."
if [[ -d "$OMARCHY/applications" ]]; then
  for user_dir in /home/*; do
    if [[ -d "$user_dir" ]]; then
      user_name=$(basename "$user_dir")
      if [[ "$user_name" != "lost+found" ]]; then
        mkdir -p "$user_dir/.local/share/applications"
        cp -f "$OMARCHY/applications/"*.desktop "$user_dir/.local/share/applications/" 2>/dev/null || true
        cp -rf "$OMARCHY/applications/icons" "$user_dir/.local/share/icons/" 2>/dev/null || true
        chown -R "$user_name:$user_name" "$user_dir/.local/share/applications" 2>/dev/null || true
      fi
    fi
  done
  mkdir -p /etc/skel/.local/share/applications
  cp -f "$OMARCHY/applications/"*.desktop /etc/skel/.local/share/applications/ 2>/dev/null || true
  cp -rf "$OMARCHY/applications/icons" /etc/skel/.local/share/icons/ 2>/dev/null || true
fi

# --- MENU ---
echo "[7/10] Fixing menu labels..."
sed -i 's|"learn.arch"|"learn.fedora"|' "$OMARCHY/default/omarchy/omarchy-menu.jsonc"
sed -i 's|"label":"Arch"|"label":"Fedora"|' "$OMARCHY/default/omarchy/omarchy-menu.jsonc"
sed -i "s|https://wiki.archlinux.org/title/Main_page|https://docs.fedoraproject.org/en-US/fedora/|" "$OMARCHY/default/omarchy/omarchy-menu.jsonc"
sed -i 's|"label":"AUR"|"label":"COPR"|' "$OMARCHY/default/omarchy/omarchy-menu.jsonc"
sed -i 's|\[AUR\]|[COPR]|' "$OMARCHY/default/omarchy/omarchy-menu.jsonc"

# --- UPDATE SCRIPTS ---
echo "[8/10] Fixing update scripts..."
sed -i 's|/boot/EFI/arch/|/boot/EFI/fedora/|' "$OMARCHY/bin/omarchy-update-firmware"

cat > "$OMARCHY/bin/omarchy-update-analyze-logs" << 'EOF'
#!/bin/bash

# omarchy:summary=Check the update log for known failure conditions

update_log="/tmp/omarchy-update.log"

# Check for dracut initramfs generation failure
if grep -qi "dracut\|initramfs\|initrd" "$update_log"; then
  if grep -qi "error\|fail" "$update_log" | grep -qi "dracut\|initramfs\|initrd"; then
    echo -e '\e[31mError: Initramfs generation may have failed. Review logs before restart.\e[0m'
    echo
  fi
fi
EOF
chmod +x "$OMARCHY/bin/omarchy-update-analyze-logs"

sed -i 's|designed for Arch Linux systems.|already installed as the base system on Fedora.|' "$OMARCHY/bin/omarchy-upgrade-to-quattro"

# --- INSTALL SCRIPTS ---
echo "[9/10] Fixing install scripts..."

# Fedora uses 'uwsm app' instead of the 'uwsm-app' wrapper across all scripts, configs, and QML files
find "$OMARCHY" -type f -exec sed -i 's|uwsm-app|uwsm app|g' {} +

sed -i 's|microsoft-edge-stable-bin|microsoft-edge-stable|' "$OMARCHY/bin/omarchy-install-browser"
sed -i 's|brave-bin|brave-browser|' "$OMARCHY/bin/omarchy-install-browser"
sed -i 's|brave-origin-bin|brave-browser-origin|' "$OMARCHY/bin/omarchy-install-browser"
sed -i 's|zen-browser-bin|zen|' "$OMARCHY/bin/omarchy-install-browser"
sed -i 's|nordvpn-bin|nordvpn|' "$OMARCHY/bin/omarchy-install-service-nordvpn"
sed -i 's|via the omarchy-emacs AUR package|via COPR|' "$OMARCHY/bin/omarchy-install-editor-emacs"
sed -i 's|installed by pacman|installed by dnf|' "$OMARCHY/bin/omarchy-install-gaming-retroarch"

sed -i '/libretro-cap32-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i '/libretro-fbneo-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i '/libretro-uae-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i '/libretro-vice-x.*-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i '/libretro-database-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i '/retroarch-joypad-autoconfig-git/d' "$OMARCHY/bin/omarchy-install-gaming-retroarch"
sed -i 's|libretro-yabause \\$|libretro-yabause|' "$OMARCHY/bin/omarchy-install-gaming-retroarch"

sed -i 's|arch-chroot|chroot|' "$OMARCHY/bin/omarchy-theme-set-gnome"
sed -i 's|pacman writes|dnf writes|' "$OMARCHY/default/systemd/user/omarchy-migrate-notify.service"

# Firewall: ufw → firewalld
sed -i 's|omarchy-cmd-missing ufw|omarchy-cmd-missing firewall-cmd|' "$OMARCHY/bin/omarchy-install-service-sunshine"
sed -i 's|sudo ufw allow in proto "$proto" from "$cidr" to any port "$port".*|sudo firewall-cmd --add-port="$port"/"$proto" --permanent >/dev/null|' "$OMARCHY/bin/omarchy-install-service-sunshine"
sed -i 's|sudo ufw allow in on tailscale0 to any port "$port" proto "$proto".*|sudo firewall-cmd --add-port="$port"/"$proto" --permanent >/dev/null|' "$OMARCHY/bin/omarchy-install-service-sunshine"
sed -i 's|sudo ufw reload|sudo firewall-cmd --reload|' "$OMARCHY/bin/omarchy-install-service-sunshine"

sed -i 's|omarchy-cmd-missing ufw|omarchy-cmd-missing firewall-cmd|' "$OMARCHY/bin/omarchy-remove-service-sunshine"
sed -i 's|delete_ufw_rule allow in proto "$proto" from "$cidr" to any port "$port"|sudo firewall-cmd --remove-port="$port"/"$proto" --permanent >/dev/null 2>\&1 \|\| true|' "$OMARCHY/bin/omarchy-remove-service-sunshine"
sed -i 's|delete_ufw_rule allow in on tailscale0 to any port "$port" proto "$proto"|sudo firewall-cmd --remove-port="$port"/"$proto" --permanent >/dev/null 2>\&1 \|\| true|' "$OMARCHY/bin/omarchy-remove-service-sunshine"
sed -i 's|sudo ufw reload|sudo firewall-cmd --reload|' "$OMARCHY/bin/omarchy-remove-service-sunshine"

sed -i 's|omarchy-cmd-missing ufw|omarchy-cmd-missing firewall-cmd|' "$OMARCHY/bin/omarchy-setup-security-sshd"
sed -i 's|sudo ufw limit 22/tcp.*|sudo firewall-cmd --add-service=ssh --permanent >/dev/null|' "$OMARCHY/bin/omarchy-setup-security-sshd"
sed -i 's|sudo ufw reload.*|sudo firewall-cmd --reload >/dev/null|' "$OMARCHY/bin/omarchy-setup-security-sshd"

sed -i 's|omarchy-cmd-present ufw|omarchy-cmd-present firewall-cmd|' "$OMARCHY/bin/omarchy-remove-security-sshd"
sed -i 's|sudo ufw --force delete limit 22/tcp.*|sudo firewall-cmd --remove-service=ssh --permanent >/dev/null 2>\&1 \|\| true|' "$OMARCHY/bin/omarchy-remove-security-sshd"
sed -i 's|sudo ufw reload.*|sudo firewall-cmd --reload >/dev/null|' "$OMARCHY/bin/omarchy-remove-security-sshd"

# --- SKILL & HOOKS ---
echo "[10/10] Fixing skill docs and hooks..."
sed -i 's|opinionated Arch Linux|opinionated Fedora Linux|' "$OMARCHY/default/omarchy-skill/SKILL.md"
sed -i 's|\*\*Arch Linux\*\*|**Fedora Linux**|' "$OMARCHY/default/omarchy-skill/SKILL.md"
sed -i 's|pre-refresh-pacman.d/|pre-refresh-repos.d/|' "$OMARCHY/default/omarchy-skill/SKILL.md"
sed -i 's|omarchy pkg aur add <pkgs\.\.\.>.*for AUR-only packages|omarchy pkg add <pkgs...> for COPR packages|' "$OMARCHY/default/omarchy-skill/SKILL.md"

cat > "$OMARCHY/config/omarchy/hooks/pre-refresh-pacman.d/add-custom-repo.sample" << 'HOOK'
#!/bin/bash

# This hook is called by `omarchy refresh pacman` AFTER the channel template
# is refreshed and BEFORE the package cache is updated. Use it to add custom
# COPR repositories or extra exclude rules.
#
# The hook runs as the invoking user with a warm sudo cache.
#
# To put it into use, remove .sample from this file name.

# Example: add a custom COPR repo
# sudo dnf copr enable -y user/repo

# Example: exclude a package from updates
# echo "exclude=broken-package" | sudo tee -a /etc/dnf/dnf.conf
HOOK
chmod +x "$OMARCHY/config/omarchy/hooks/pre-refresh-pacman.d/add-custom-repo.sample"

# --- DEV-PKG-TEST ---
cp "$OMARCHY/bin/omarchy-dev-pkg-test" "$OMARCHY/bin/omarchy-dev-pkg-test.arch-bak" 2>/dev/null || true
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/bin/omarchy-dev-pkg-test"
chmod +x "$OMARCHY/bin/omarchy-dev-pkg-test"

# --- DOCUMENTATION ---
bash "$SCRIPT_DIR/apply-docs.sh"

# --- POST-UPDATE HOOK ---
echo ""
echo "Installing post-update hook..."
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$HOOK_DIR"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$HOOK_DIR/apply-fedora-patches.hook"
chmod +x "$HOOK_DIR/apply-fedora-patches.hook"
echo "Installed $HOOK_DIR/apply-fedora-patches.hook"

echo ""
echo "=== All patches applied! ==="
echo ""
echo "Post-update hook installed. Future upstream updates will automatically"
echo "re-apply Fedora patches via omarchy-hook post-update."
