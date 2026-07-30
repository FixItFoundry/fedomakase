#!/bin/bash
# Omarchy Fedora Native Interactive TTY Installer (omarchy-installer.sh)
# Uses Gum terminal UI to generate Anaconda Kickstart configuration.

set -euo pipefail

export TERM=linux
COLUMNS=$(tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}' || echo 80)
# Fallback if stty returns empty
[[ -z "$COLUMNS" ]] && COLUMNS=80

# --- Display Helpers (ANSI-based, reliable on TTY) ---
print_center() {
  local text="$1"
  local pad=$(( (COLUMNS - ${#text}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s%s\n' "$pad" '' "$text"
}

print_color() {
  local color="$1" text="$2"
  local pad=$(( (COLUMNS - ${#text}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s\033[38;5;%sm%s\033[0m\n' "$pad" '' "$color" "$text"
}

print_bold() {
  local color="$1" text="$2"
  local pad=$(( (COLUMNS - ${#text}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s\033[1;38;5;%sm%s\033[0m\n' "$pad" '' "$color" "$text"
}

print_art() {
  local lines=() max_width=0
  while IFS= read -r line; do
    lines+=("$line")
    local width=0
    for ((i=0; i<${#line}; i++)); do
      c="${line:$i:1}"
      if [[ "$c" == $'\xe2' ]] || [[ "$c" == $'\xef' ]]; then
        width=$((width + 2))
      else
        width=$((width + 1))
      fi
    done
    (( width > max_width )) && max_width=$width
  done
  local pad=$(( (COLUMNS - max_width) / 2 ))
  (( pad < 0 )) && pad=0
  local spaces=$(printf '%*s' "$pad" '')
  for line in "${lines[@]}"; do
    printf '%s\033[38;5;74m%s\033[0m\n' "$spaces" "$line"
  done
}

if ! command -v gum &>/dev/null; then
  echo "Error: 'gum' is required for the Omarchy installer." >&2
  exit 1
fi

printf '\033[2J\033[H'
cat << 'BANNER' | print_art
  ██████  ███    ███  █████  ██████   ██████  ██   ██  ██   ██
 ██    ██ ████  ████ ██   ██ ██   ██ ██       ██   ██  ██   ██
 ██    ██ ██ ████ ██ ███████ ██████  ██       ███████   ██████
 ██    ██ ██  ██  ██ ██   ██ ██   ██ ██       ██   ██     ██  
  ██████  ██      ██ ██   ██ ██   ██  ██████  ██   ██     ██  
BANNER

echo ""
print_center "Fedora Edition - Native Installer"
echo ""
print_bold 74 "Welcome to the Omarchy Fedora Interactive Installer!"
echo ""

if ! gum confirm "Ready to configure Omarchy Fedora for installation?"; then
  print_color 204 "Installation aborted."
  exit 1
fi

# 1. Disk Selection
echo ""
print_bold 111 "1. Target Disk Selection"
print_color 204 "WARNING: All data on the selected disk will be completely erased!"

DISKS=$(lsblk -dno NAME,SIZE,MODEL,TYPE | awk '$1 !~ /^(loop|zram)/ && $NF == "disk" { model=""; for(i=3;i<NF;i++) model=model $i " "; gsub(/ $/, "", model); print "/dev/"$1" ("$2" "model")" }')

if [[ -z "$DISKS" ]]; then
  print_color 204 "Error: No suitable installation disks found!"
  exit 1
fi

# Use mapfile + arguments instead of pipe to preserve TTY stdin for gum
mapfile -t DISK_ARRAY <<< "$DISKS"
SELECTED_DISK_STR=$(gum choose --header "Select the drive to install Omarchy Fedora on:" "${DISK_ARRAY[@]}") || true
if [[ -z "$SELECTED_DISK_STR" ]]; then
  print_color 204 "No disk selected, aborting!"
  exit 1
fi

TARGET_DISK=$(echo "$SELECTED_DISK_STR" | awk '{print $1}')
TARGET_DISK_NAME=$(basename "$TARGET_DISK")

if [[ -z "$TARGET_DISK" || ! -b "$TARGET_DISK" ]]; then
  print_color 204 "Invalid disk selected!"
  exit 1
fi

# 2. LUKS Encryption Setup
echo ""
print_bold 111 "2. Drive Encryption (LUKS2)"
ENCRYPT_DRIVE=false
LUKS_PASSPHRASE=""

if gum confirm "Would you like to encrypt your drive with LUKS2?"; then
  ENCRYPT_DRIVE=true
  while true; do
    LUKS_PASSPHRASE=$(gum input --password --header "LUKS encryption passphrase:") || true
    LUKS_CONFIRM=$(gum input --password --header "Confirm LUKS passphrase:") || true
    if [[ -n "$LUKS_PASSPHRASE" && "$LUKS_PASSPHRASE" == "$LUKS_CONFIRM" ]]; then
      print_color 108 "Passphrase confirmed."
      break
    else
      print_color 204 "Passphrases do not match or are empty. Please try again."
    fi
  done
fi

# 3. User Setup
echo ""
print_bold 111 "3. User Account Setup"

REAL_NAME=$(gum input --header "Full Name:" --placeholder "e.g. Omarchy User" --value "Omarchy User") || true

USERNAME=""
while true; do
  USERNAME=$(gum input --header "Username:" --placeholder "e.g. omarchy" --value "omarchy") || true
  if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    break
  else
    print_color 204 "Invalid username format. Use lowercase alphanumeric characters."
  fi
done

USER_PASSWORD=""
while true; do
  USER_PASSWORD=$(gum input --password --header "Enter Password for $USERNAME:") || true
  USER_PASS_CONFIRM=$(gum input --password --header "Confirm Password for $USERNAME:") || true
  if [[ -n "$USER_PASSWORD" && "$USER_PASSWORD" == "$USER_PASS_CONFIRM" ]]; then
    print_color 108 "User password confirmed."
    break
  else
    print_color 204 "Passwords do not match or are empty. Please try again."
  fi
done

# 4. Confirmation Summary
echo ""
gum style --border normal --margin "1 2" --padding "1 2" --border-foreground 74 \
  "Installation Summary:" \
  "  Target Drive:      $TARGET_DISK" \
  "  LUKS Encrypted:    $ENCRYPT_DRIVE" \
  "  User Account:      $USERNAME ($REAL_NAME)" \
  "  Desktop:           Hyprland + SDDM + Omarchy Theme"

if ! gum confirm "Begin installation and overwrite $TARGET_DISK now?"; then
  print_color 204 "Installation cancelled."
  exit 1
fi

echo ""
gum spin --spinner dot --title "Generating Anaconda Kickstart Configuration..." -- sleep 2

# 5. Generate Kickstart Include File
KS_INC="/tmp/omarchy-ks-include.cfg"

if [[ $ENCRYPT_DRIVE == true ]]; then
  AUTOPART_LINE="autopart --type=btrfs --encrypted --passphrase=${LUKS_PASSPHRASE}"
  echo -n "${LUKS_PASSPHRASE}" > /tmp/omarchy-luks-pass
else
  AUTOPART_LINE="autopart --type=btrfs"
fi

cat > "$KS_INC" << KSEOF
ignoredisk --only-use=${TARGET_DISK_NAME}
zerombr
clearpart --all --initlabel --drives=${TARGET_DISK_NAME}
${AUTOPART_LINE}
bootloader --timeout=1 --append="quiet"
rootpw --lock
user --name=${USERNAME} --gecos="${REAL_NAME}" --groups=wheel --plaintext --password="${USER_PASSWORD}"
KSEOF

echo ""
print_bold 108 "Omarchy Fedora frontend setup complete! Handing over to Anaconda..."
sleep 2
