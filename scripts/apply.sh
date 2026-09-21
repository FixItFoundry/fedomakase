#!/bin/bash
# Fedomakase Apply Script — one-time bootstrap on an existing Fedora system.
# All idempotent Fedora seds live in omarchy-apply-fedora-patches; this script
# installs it plus its support files, then runs it once.
#
# Run with: sudo bash scripts/apply.sh

set -e
OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD="$SCRIPT_DIR/../omarchy"

# $HOME is /root under sudo; the stash and hook belong to the
# invoking user so post-update hooks fire for their `omarchy update` runs.
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(eval echo "~$TARGET_USER")

echo "=== Fedomakase: applying Fedora port ==="

[[ -d $OMARCHY ]] || { echo "Error: $OMARCHY not found — is Omarchy installed?" >&2; exit 1; }

# --- Runtime patch directory (consumed by omarchy-apply-fedora-patches) ---
echo "[1/6] Installing fedora-patches runtime directory..."
mkdir -p "$OMARCHY/fedora-patches"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$OMARCHY/fedora-patches/"

# --- Update-surviving stash: upstream overwrites of /usr/share/omarchy can
#     destroy the runner and patch dir; the hook restores them from here. ---
STASH="$TARGET_HOME/.local/share/fedomakase"
mkdir -p "$STASH/bin" "$STASH/fedora-patches"
cp "$SCRIPT_DIR/omarchy-apply-fedora-patches" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$STASH/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$STASH/fedora-patches/"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$STASH/fedora-patches/"
chown -R "$TARGET_USER:$TARGET_USER" "$STASH" 2>/dev/null || true

# --- Patch runner ---
echo "[2/6] Installing omarchy-apply-fedora-patches..."
cp "$SCRIPT_DIR/omarchy-apply-fedora-patches" "$OMARCHY/bin/omarchy-apply-fedora-patches"
chmod +x "$OMARCHY/bin/omarchy-apply-fedora-patches"

# --- Fedora-owned helpers + data files: upstream updates overwrite these,
#     so deploy the payload copies (the post-update hook re-patches the rest) ---
echo "[3/6] Syncing Fedora-owned helpers and data files..."
for f in omarchy-pkg-add omarchy-pkg-aur-add omarchy-pkg-drop omarchy-pkg-missing \
         omarchy-pkg-present omarchy-pkg-remove omarchy-pkg-install omarchy-pkg-aur-install \
         omarchy-pkg-aur-accessible omarchy-channel-set omarchy-reinstall-pkgs \
         omarchy-refresh-repos omarchy-refresh-pacman omarchy-update-aur-pkgs \
         omarchy-update-system-pkgs omarchy-voxtype-install omarchy-voxtype-remove \
         omarchy-voxtype-config omarchy-voxtype-model omarchy-voxtype-status; do
  cp "$PAYLOAD/bin/$f" "$OMARCHY/bin/$f"
  chmod +x "$OMARCHY/bin/$f"
done
cp "$PAYLOAD/install/omarchy-fedora-base.packages" "$PAYLOAD/install/omarchy-fedora-copr.repos" "$OMARCHY/install/"
cp "$PAYLOAD/etc/sddm.conf.d/10-wayland.conf" "$OMARCHY/etc/sddm.conf.d/10-wayland.conf"
# Live system config (kickstart does this at install time; repeat for running systems)
cp "$PAYLOAD/etc/sddm.conf.d/10-wayland.conf" /etc/sddm.conf.d/10-wayland.conf

# --- TPM2 helper on PATH + dracut module config ---
echo "[4/6] Installing TPM2 unlock support..."
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/bin/omarchy-setup-tpm2-unlock"
chmod +x "$OMARCHY/bin/omarchy-setup-tpm2-unlock"
mkdir -p /etc/dracut.conf.d
grep -q "tpm2-tss" /etc/dracut.conf.d/tpm2.conf 2>/dev/null \
  || echo 'add_dracutmodules+=" tpm2-tss "' >> /etc/dracut.conf.d/tpm2.conf

# --- Dev package test (rpmbuild) helper ---
echo "[5/6] Installing omarchy-dev-pkg-test..."
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/bin/omarchy-dev-pkg-test"
chmod +x "$OMARCHY/bin/omarchy-dev-pkg-test"

# --- Run all idempotent patches once now ---
echo "[6/6] Running omarchy-apply-fedora-patches..."
"$OMARCHY/bin/omarchy-apply-fedora-patches"

# --- Post-update hook so upstream refreshes re-apply everything ---
HOOK_DIR="$TARGET_HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$HOOK_DIR"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$HOOK_DIR/apply-fedora-patches.hook"
chmod +x "$HOOK_DIR/apply-fedora-patches.hook"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/omarchy/hooks" 2>/dev/null || true

echo ""
echo "=== Done. Post-update hook installed: future upstream updates will"
echo "    automatically re-apply Fedora patches via omarchy-apply-fedora-patches. ==="
