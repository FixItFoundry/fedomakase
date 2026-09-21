#!/bin/bash
# Fedomakase Offline ISO Build Script
# Builds a self-contained installer by mirroring all manifest packages
# (fedora + updates + nett00n/hyprland + whelanh/omarchy + ghostty COPRs) into a local repo on the ISO.
#
# NOTE: offline install path is PHASE 2 — the file:/// mount layout in
# omarchy-ks-offline.cfg still needs verification on real hardware.
#
# Usage:
#   sudo bash build/build-offline-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OMARCHY_DIR="$REPO_DIR/omarchy"

FEDORA_ISO="${1:-}"
if [[ -z "$FEDORA_ISO" ]]; then
  echo "Usage: sudo bash $0 /path/to/Fedora-Everything-netinst-x86_64-44-*.iso" >&2
  exit 1
fi

for f in "$FEDORA_ISO" \
         "$OMARCHY_DIR/installer/omarchy-ks-offline.cfg" \
         "$OMARCHY_DIR/installer/omarchy-installer.sh" \
         "$OMARCHY_DIR/install/omarchy-fedora-base.packages"; do
  [[ -e "$f" ]] || { echo "Error: required file not found: $f" >&2; exit 1; }
done

BUILD_DIR="/tmp/fedomakase_offline_iso_build"
OUTPUT_ISO="$REPO_DIR/fedomakase-offline-44-x86_64.iso"
ISO_LABEL="Fedora-E-dvd-x86_64-44"
COPR_URL="https://copr-be.cloud.fedoraproject.org/results/nett00n/hyprland/fedora-44-x86_64/"
COPR_GHOSTTY_URL="https://copr-be.cloud.fedoraproject.org/results/scottames/ghostty/fedora-44-x86_64/"
COPR_WHELANH_URL="https://copr-be.cloud.fedoraproject.org/results/whelanh/omarchy/fedora-44-x86_64/"
COPR_STARSHIP_URL="https://copr-be.cloud.fedoraproject.org/results/atim/starship/fedora-44-x86_64/"
COPR_LAZYGIT_URL="https://copr-be.cloud.fedoraproject.org/results/boobaa/lazygit/fedora-44-x86_64/"

echo -e "\e[32m=== Starting Fedomakase Offline ISO Build ===\e[0m"

# 1. Clean & prepare build workspace
echo "[1/7] Preparing offline build workspace..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/extracted"

# 2. Extract base Fedora ISO
echo "[2/7] Extracting base Fedora ISO..."
bsdtar -C "$BUILD_DIR/extracted" -xf "$FEDORA_ISO"

# 3. Extract EFI and MAC boot partitions
echo "[3/7] Restoring UEFI bootloader partition..."
EFI_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+1); break } }')
EFI_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso2$/) { print $(i+3); break } }')
if [[ -n "$EFI_SECTOR" && -n "$EFI_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/efiboot.img" skip="$EFI_SECTOR" count="$EFI_SIZE" bs=512 status=none
else
  echo "Error: Could not find EFI partition in $FEDORA_ISO" >&2
  exit 1
fi

MAC_SECTOR=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+1); break } }')
MAC_SIZE=$(fdisk -l "$FEDORA_ISO" | awk '{ for(i=1;i<=NF;i++) if($i ~ /\.iso3$/) { print $(i+3); break } }')
if [[ -n "$MAC_SECTOR" && -n "$MAC_SIZE" ]]; then
  dd if="$FEDORA_ISO" of="$BUILD_DIR/macboot.img" skip="$MAC_SECTOR" count="$MAC_SIZE" bs=512 status=none
fi

# 4. Download static gum + Nerd Font for the payload (fail loud)
echo "[4/7] Downloading gum binary and Nerd Font..."
rm -rf /tmp/gum_0.14.3_Linux_x86_64 /tmp/gum.tar.gz
wget -qO /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v0.14.3/gum_0.14.3_Linux_x86_64.tar.gz"
tar -xf /tmp/gum.tar.gz -C /tmp
[[ -x /tmp/gum_0.14.3_Linux_x86_64/gum ]] || { echo "Error: gum binary missing after download." >&2; exit 1; }
cp /tmp/gum_0.14.3_Linux_x86_64/gum "$OMARCHY_DIR/installer/gum"
chmod +x "$OMARCHY_DIR/installer/gum"

NF_TMP="/tmp/fedomakase-nf/JetBrainsMono-NF"
mkdir -p "$NF_TMP"
curl -fsSL --max-time 120 \
  "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
  | tar -xJ -C "$NF_TMP"

# 5. Mirror every manifest package into the local ISO repository
echo "[5/7] Mirroring manifest packages (fedora + updates + COPR)..."
mapfile -t MANIFEST_PKGS < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$OMARCHY_DIR/install/omarchy-fedora-base.packages" | grep -v '^$' || true)
(( ${#MANIFEST_PKGS[@]} > 0 )) || { echo "Error: manifest parsed to zero packages." >&2; exit 1; }

REPO_DIR_TARGET="$BUILD_DIR/extracted/omarchy-repo"
mkdir -p "$REPO_DIR_TARGET"

MISSING=()
for pkg in "${MANIFEST_PKGS[@]}"; do
  # ponytail: per-pkg download keeps a single bad name from killing the mirror
  dnf download --resolve --alldeps --destdir="$REPO_DIR_TARGET" \
    --repoid=fedora --repoid=updates \
    --repofrompath=copr-nett00n,"$COPR_URL" --repoid=copr-nett00n \
    --repofrompath=copr-ghostty,"$COPR_GHOSTTY_URL" --repoid=copr-ghostty \
    --repofrompath=copr-whelanh,"$COPR_WHELANH_URL" --repoid=copr-whelanh \
    --repofrompath=copr-starship,"$COPR_STARSHIP_URL" --repoid=copr-starship \
    --repofrompath=copr-lazygit,"$COPR_LAZYGIT_URL" --repoid=copr-lazygit \
    "$pkg" 2>/dev/null || MISSING+=("$pkg")
done

RPM_COUNT=$(find "$REPO_DIR_TARGET" -name '*.rpm' | wc -l)
echo "  Mirrored $RPM_COUNT RPMs total."
for pkg in "${MISSING[@]:-}"; do
  [[ -z "$pkg" ]] && continue
  echo "  WARNING: could not fully resolve: $pkg"
done

for pkg in hyprland quickshell sddm uwsm hyprland-preview-share-picker omacut omawrite tensaku; do
  find "$REPO_DIR_TARGET" -name "${pkg}-*.rpm" | grep -q . \
    || { echo "Error: critical package '$pkg' missing from local repo — aborting." >&2; exit 1; }
done

if ! command -v createrepo_c &>/dev/null; then
  dnf install -y createrepo_c
fi
createrepo_c "$REPO_DIR_TARGET"

# Payload
mkdir -p "$BUILD_DIR/extracted/omarchy-fedora"
rsync -a --exclude="*.iso" --exclude=".git" "$OMARCHY_DIR/" "$BUILD_DIR/extracted/omarchy-fedora/"
mkdir -p "$BUILD_DIR/extracted/omarchy-fedora/installer/fonts/JetBrainsMono-NF"
cp -rf "$NF_TMP"/. "$BUILD_DIR/extracted/omarchy-fedora/installer/fonts/JetBrainsMono-NF/"

# Splice resolved package list into the offline kickstart
KS="$BUILD_DIR/extracted/omarchy-ks-offline.cfg"
cp -f "$OMARCHY_DIR/installer/omarchy-ks-offline.cfg" "$KS"
{
  sed '/^# >>> FEDOMAKASE-PACKAGES-BEGIN$/,$d' "$KS"
  echo "# >>> FEDOMAKASE-PACKAGES-BEGIN"
  printf '@core\n@hardware-support\n'
  printf '%s\n' "${MANIFEST_PKGS[@]}"
  echo "# >>> FEDOMAKASE-PACKAGES-END"
  sed -n '/^# >>> FEDOMAKASE-PACKAGES-END$/,$p' "$KS" | tail -n +2
} > "$KS.tmp" && mv "$KS.tmp" "$KS"

# 6. Update GRUB boot configuration
echo "[6/7] Updating bootloader configuration..."
for cfg in "$BUILD_DIR/extracted/boot/grub2/grub.cfg" "$BUILD_DIR/extracted/EFI/BOOT/grub.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/set default=.*/set default="0"/' "$cfg"
    sed -i 's/set timeout=.*/set timeout=1/' "$cfg"
    sed -i 's/ inst\.ks=[^ ]*//g' "$cfg"
    sed -i 's/ inst\.text//g' "$cfg"
    sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=cdrom:/omarchy-ks-offline.cfg|g" "$cfg"
  fi
done

# Verify before repack
for f in "$KS" \
         "$BUILD_DIR/extracted/omarchy-fedora/installer/omarchy-installer.sh" \
         "$BUILD_DIR/extracted/omarchy-fedora/installer/gum" \
         "$REPO_DIR_TARGET/repodata/repomd.xml"; do
  [[ -s "$f" ]] || { echo "Error: verification failed, missing: $f" >&2; exit 1; }
done

# 7. Repack bootable ISO
echo "[7/7] Building final ISO ($OUTPUT_ISO)..."

if ! command -v xorriso &>/dev/null; then
  echo "Installing xorriso locally..."
  mkdir -p /tmp/xorriso_local
  pushd /tmp/xorriso_local >/dev/null
  dnf download xorriso libisoburn libisofs libburn -yq
  for pkg in *.rpm; do
    rpm2cpio "$pkg" | cpio -idmv &>/dev/null
    chmod -R u+w . 2>/dev/null || true
  done
  export PATH="/tmp/xorriso_local/usr/bin:$PATH"
  export LD_LIBRARY_PATH="/tmp/xorriso_local/usr/lib64:/tmp/xorriso_local/usr/lib:${LD_LIBRARY_PATH:-}"
  popd >/dev/null
fi
command -v xorriso &>/dev/null || { echo "Error: xorriso unavailable after local install." >&2; exit 1; }

xorriso -as mkisofs \
  -V "$ISO_LABEL" \
  -J -R -l \
  -b images/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:all::' \
  -no-emul-boot \
  --grub2-mbr "$BUILD_DIR/extracted/boot/grub2/i386-pc/boot_hybrid.img" \
  -partition_offset 16 \
  --protective-msdos-label \
  -append_partition 2 0xef "$BUILD_DIR/efiboot.img" \
  $([[ -f "$BUILD_DIR/macboot.img" ]] && echo "-append_partition 3 0x00 $BUILD_DIR/macboot.img") \
  -appended_part_as_gpt \
  -o "$OUTPUT_ISO" \
  "$BUILD_DIR/extracted"

rm -rf "$BUILD_DIR"
echo -e "\e[32m=== Build Complete: $OUTPUT_ISO ===\e[0m"
