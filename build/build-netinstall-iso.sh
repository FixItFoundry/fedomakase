#!/bin/bash
# Fedomakase Netinstall ISO Build Script
# Unpacks Fedora Everything Netinstall, embeds the Fedomakase payload,
# generates the %packages block from the single-source-of-truth manifest
# (resolved against live repos), and repacks a bootable ISO.
#
# Prerequisites:
#   - Fedora Everything Netinstall ISO (Fedora-Everything-netinst-x86_64-44-*.iso)
#   - bsdtar, rsync, wget, dnf (with network access for repo metadata)
#
# Usage:
#   sudo bash build/build-netinstall-iso.sh /path/to/Fedora-Everything-netinst-x86_64-44-*.iso

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
         "$OMARCHY_DIR/installer/omarchy-ks.cfg" \
         "$OMARCHY_DIR/installer/omarchy-installer.sh" \
         "$OMARCHY_DIR/install/omarchy-fedora-base.packages"; do
  if [[ ! -e "$f" ]]; then
    echo "Error: required file not found: $f" >&2
    exit 1
  fi
done

BUILD_DIR="/tmp/fedomakase_iso_build"
OUTPUT_ISO="$REPO_DIR/fedomakase-44-x86_64.iso"
ISO_LABEL="Fedora-E-dvd-x86_64-44"
COPR_URL="https://copr-be.cloud.fedoraproject.org/results/lionheartp/Hyprland/fedora-44-x86_64/"
COPR_GHOSTTY_URL="https://copr-be.cloud.fedoraproject.org/results/scottames/ghostty/fedora-44-x86_64/"

echo -e "\e[32m=== Starting Fedomakase Netinstall ISO Build ===\e[0m"

# 1. Clean & prepare build workspace
echo "[1/7] Preparing build workspace..."
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

# 4. Download static gum for the installer UI (fail loud: %pre cannot run without it)
echo "[4/7] Downloading static gum binary..."
rm -rf /tmp/gum_0.14.3_Linux_x86_64 /tmp/gum.tar.gz
wget -qO /tmp/gum.tar.gz "https://github.com/charmbracelet/gum/releases/download/v0.14.3/gum_0.14.3_Linux_x86_64.tar.gz"
tar -xf /tmp/gum.tar.gz -C /tmp
[[ -x /tmp/gum_0.14.3_Linux_x86_64/gum ]] || { echo "Error: gum binary missing after download." >&2; exit 1; }
cp /tmp/gum_0.14.3_Linux_x86_64/gum "$OMARCHY_DIR/installer/gum"
chmod +x "$OMARCHY_DIR/installer/gum"

# 5. Generate %packages block from the manifest, resolved against live repos
echo "[5/7] Resolving manifest packages against fedora/updates/COPR metadata..."
mapfile -t MANIFEST_PKGS < <(sed 's/#.*//' "$OMARCHY_DIR/install/omarchy-fedora-base.packages" | tr -d '[:space:]' | grep -v '^$' || true)
if (( ${#MANIFEST_PKGS[@]} == 0 )); then
  echo "Error: manifest parsed to zero packages." >&2
  exit 1
fi

RESOLVED=()
MISSING=()
for pkg in "${MANIFEST_PKGS[@]}"; do
  if dnf -q repoquery --arch=x86_64,noarch \
      --repoid=fedora --repoid=updates \
      --repofrompath=copr-lionheartp,"$COPR_URL" --repoid=copr-lionheartp \
      --repofrompath=copr-ghostty,"$COPR_GHOSTTY_URL" --repoid=copr-ghostty \
      "$pkg" &>/dev/null; then
    RESOLVED+=("$pkg")
  else
    MISSING+=("$pkg")
  fi
done

if (( ${#RESOLVED[@]} == 0 )); then
  echo "Error: no manifest packages could be resolved — repo metadata unreachable?" >&2
  exit 1
fi

for pkg in "${MISSING[@]:-}"; do
  [[ -z "$pkg" ]] && continue
  echo "  WARNING: not resolvable anywhere, excluding from ISO: $pkg"
done

# Critical set must resolve or the ISO would install a broken desktop
for pkg in hyprland hyprland-uwsm quickshell sddm uwsm xdg-desktop-portal-hyprland; do
  [[ " ${RESOLVED[*]} " == *" $pkg "* ]] || { echo "Error: critical package '$pkg' did not resolve — aborting." >&2; exit 1; }
done

KS="$BUILD_DIR/extracted/omarchy-ks.cfg"
cp -f "$OMARCHY_DIR/installer/omarchy-ks.cfg" "$KS"

# Splice resolved packages between the FEDOMAKASE markers
{
  sed '/^# >>> FEDOMAKASE-PACKAGES-BEGIN$/,$d' "$KS"
  echo "# >>> FEDOMAKASE-PACKAGES-BEGIN"
  printf '@core\n@hardware-support\n'
  printf '%s\n' "${RESOLVED[@]}"
  echo "# >>> FEDOMAKASE-PACKAGES-END"
  sed -n '/^# >>> FEDOMAKASE-PACKAGES-END$/,$p' "$KS" | tail -n +2
} > "$KS.tmp" && mv "$KS.tmp" "$KS"
echo "  Spliced ${#RESOLVED[@]} packages (${#MISSING[@]} excluded) into kickstart."

# Payload: the whole omarchy tree ships as the runtime payload
mkdir -p "$BUILD_DIR/extracted/omarchy-fedora"
rsync -a --exclude="*.iso" --exclude=".git" "$OMARCHY_DIR/" "$BUILD_DIR/extracted/omarchy-fedora/"

# 6. Update GRUB boot configuration
echo "[6/7] Updating bootloader configuration..."
for cfg in "$BUILD_DIR/extracted/boot/grub2/grub.cfg" "$BUILD_DIR/extracted/EFI/BOOT/grub.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/set default=.*/set default="0"/' "$cfg"
    sed -i 's/set timeout=.*/set timeout=1/' "$cfg"
    # Remove any existing inst.ks=/inst.text parameters to prevent duplicates
    sed -i 's/ inst\.ks=[^ ]*//g' "$cfg"
    sed -i 's/ inst\.text//g' "$cfg"
    # Append inst.ks= and force text mode (GUI overrides TTY switches)
    sed -i "s|inst.stage2=hd:LABEL=[^ ]*|& inst.ks=cdrom:/omarchy-ks.cfg inst.text|g" "$cfg"
  fi
done

# Verify the extracted tree before spending time on the repack
for f in "$KS" \
         "$BUILD_DIR/extracted/omarchy-fedora/installer/omarchy-installer.sh" \
         "$BUILD_DIR/extracted/omarchy-fedora/installer/gum"; do
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
