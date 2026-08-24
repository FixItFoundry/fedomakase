#!/bin/bash
# Fedomakase Apply Script — one-time bootstrap on an existing Fedora system.
# All idempotent Fedora seds live in omarchy-apply-fedora-patches; this script
# installs it plus its support files, then runs it once.
#
# Run with: sudo bash scripts/apply.sh

set -e
OMARCHY="${OMARCHY_PATH:-/usr/share/omarchy}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Fedomakase: applying Fedora port ==="

[[ -d $OMARCHY ]] || { echo "Error: $OMARCHY not found — is Omarchy installed?" >&2; exit 1; }

# --- Runtime patch directory (consumed by omarchy-apply-fedora-patches) ---
echo "[1/5] Installing fedora-patches runtime directory..."
mkdir -p "$OMARCHY/fedora-patches"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/fedora-patches/"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$OMARCHY/fedora-patches/"

# --- Update-surviving stash: upstream overwrites of /usr/share/omarchy can
#     destroy the runner and patch dir; the hook restores them from here. ---
STASH="$HOME/.local/share/fedomakase"
mkdir -p "$STASH/bin" "$STASH/fedora-patches"
cp "$SCRIPT_DIR/omarchy-apply-fedora-patches" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$STASH/bin/"
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$STASH/fedora-patches/"
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$STASH/fedora-patches/"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$STASH/fedora-patches/"

# --- Patch runner ---
echo "[2/5] Installing omarchy-apply-fedora-patches..."
cp "$SCRIPT_DIR/omarchy-apply-fedora-patches" "$OMARCHY/bin/omarchy-apply-fedora-patches"
chmod +x "$OMARCHY/bin/omarchy-apply-fedora-patches"

# --- TPM2 helper on PATH + dracut module config ---
echo "[3/5] Installing TPM2 unlock support..."
cp "$SCRIPT_DIR/omarchy-setup-tpm2-unlock" "$OMARCHY/bin/omarchy-setup-tpm2-unlock"
chmod +x "$OMARCHY/bin/omarchy-setup-tpm2-unlock"
mkdir -p /etc/dracut.conf.d
grep -q "tpm2-tss" /etc/dracut.conf.d/tpm2.conf 2>/dev/null \
  || echo 'add_dracutmodules+=" tpm2-tss "' >> /etc/dracut.conf.d/tpm2.conf

# --- Dev package test (rpmbuild) helper ---
echo "[4/5] Installing omarchy-dev-pkg-test..."
cp "$SCRIPT_DIR/omarchy-dev-pkg-test" "$OMARCHY/bin/omarchy-dev-pkg-test"
chmod +x "$OMARCHY/bin/omarchy-dev-pkg-test"

# --- Run all idempotent patches once now ---
echo "[5/5] Running omarchy-apply-fedora-patches..."
"$OMARCHY/bin/omarchy-apply-fedora-patches"

# --- Post-update hook so upstream refreshes re-apply everything ---
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
mkdir -p "$HOOK_DIR"
cp "$SCRIPT_DIR/apply-fedora-patches.hook" "$HOOK_DIR/apply-fedora-patches.hook"
chmod +x "$HOOK_DIR/apply-fedora-patches.hook"

echo ""
echo "=== Done. Post-update hook installed: future upstream updates will"
echo "    automatically re-apply Fedora patches via omarchy-apply-fedora-patches. ==="
