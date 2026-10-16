#!/bin/bash
# Fedomakase Interactive TTY Installer (omarchy-installer.sh)
# Runs inside Anaconda's %pre on TTY3. Uses Gum to gather every install choice
# and writes /tmp/fedomakase-part.cfg — an Anaconda include file consumed by
# omarchy-ks.cfg via %include. Also writes /tmp/fedomakase-luks-pass when
# encryption is selected (used once by systemd-cryptenroll in %post) and
# /tmp/fedomakase-input-method for CJK/XKB layout seeding.

set -euo pipefail

export TERM=linux

# Wait for KMS / framebuffer console geometry to settle before measuring width
wait_for_stable_terminal() {
  local prev="" cur="" stable=0 i
  for ((i = 0; i < 30; i++)); do
    local sz fb_sz="" fb_nm=""
    sz=$(stty size 2>/dev/null || echo "24 80")
    [[ -r /sys/class/graphics/fb0/virtual_size ]] && fb_sz=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || true)
    [[ -r /sys/class/graphics/fb0/name ]] && fb_nm=$(cat /sys/class/graphics/fb0/name 2>/dev/null || true)
    cur="${sz}|${fb_nm}|${fb_sz}"
    if [[ -n "$cur" && "$cur" == "$prev" ]]; then
      stable=$((stable + 1))
      (( stable >= 3 )) && break
    else
      prev="$cur"
      stable=0
    fi
    sleep 0.1
  done
}

wait_for_stable_terminal

COLUMNS=$(tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}' || echo 80)
[[ -z "$COLUMNS" || ! "$COLUMNS" =~ ^[0-9]+$ || "$COLUMNS" -le 0 ]] && COLUMNS=80

PART_CFG="/tmp/fedomakase-part.cfg"
LUKS_PASS_FILE="/tmp/fedomakase-luks-pass"
INPUT_METHOD_FILE="/tmp/fedomakase-input-method"
rm -f "$PART_CFG" "$LUKS_PASS_FILE" "$INPUT_METHOD_FILE"

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
  local spaces
  spaces=$(printf '%*s' "$pad" '')
  for line in "${lines[@]}"; do
    printf '%s\033[38;5;74m%s\033[0m\n' "$spaces" "$line"
  done
}

if ! command -v gum &>/dev/null; then
  echo "Error: 'gum' is required for the Fedomakase installer." >&2
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
print_bold 74 "Welcome to the Fedomakase Interactive Installer!"
echo ""

if ! gum confirm "Ready to configure Fedomakase for installation?"; then
  print_color 204 "Installation aborted."
  exit 1
fi

# 1. Keyboard Layout Selection (synced with install/provisioning/setup-form.sh)
echo ""
print_bold 111 "1. Keyboard Layout"

OMARCHY_KEYBOARD_LAYOUTS=$'English (US)|us
English (UK)|uk
English (US, Dvorak)|dvorak
English (US, Colemak)|colemak
Belarusian|by
Belgian|be-latin1
Bulgarian|bg-cp1251
Chinese (Simplified, Pinyin)|us|pinyin
Croatian|croat
Czech|cz
Danish|dk-latin1
Dutch|nl
Estonian|et
Finnish|fi
French|fr
French (Canada)|cf
French (Switzerland)|fr_CH
Georgian|ge
German|de
German (Switzerland)|de_CH-latin1
Greek|gr
Hebrew|il
Hong Kong (Cangjie)|us|cangjie5
Hungarian|hu
Icelandic|is-latin1
Irish|ie
Italian|it
Japanese|jp106|mozc
Japanese (US keyboard)|us|mozc
Kazakh|kazakh
Korean|us|hangul|kr:kr104
Kyrgyz|kyrgyz
Lao|us||la
Latvian|lv
Lithuanian|lt
Macedonian|mk-utf
Norwegian|no-latin1
Polish|pl
Portuguese|pt-latin1
Portuguese (Brazil)|br-abnt2
Romanian|ro
Russian|ru
Serbian|sr-latin
Slovak|sk-qwertz
Slovenian|slovene
Spanish|es
Spanish (Latin American)|la-latin1
Swedish|sv-latin1
Taiwan (Zhuyin)|us|chewing
Tajik|tj_alt-UTF8
Turkish|trq
Ukrainian|ua'

KB_CHOICE=$(printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" | cut -d'|' -f1 | \
  gum choose --height 10 --selected "English (US)" --header "Select your keyboard layout:") || true
[[ -z "$KB_CHOICE" ]] && KB_CHOICE="English (US)"

KB_ROW=$(printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" | awk -F'|' -v c="$KB_CHOICE" '$1==c{print; exit}')
IFS='|' read -r KEYBOARD_LABEL KEYMAP INPUT_METHOD XKB_LAYOUT <<< "${KB_ROW:-English (US)|us}"
KEYMAP="${KEYMAP:-us}"
INPUT_METHOD="${INPUT_METHOD:-none}"
XKB_LAYOUT="${XKB_LAYOUT:-}"

# Load selected keymap on live TTY immediately so passphrases/passwords match
loadkeys "$KEYMAP" 2>/dev/null || true

# 2. Disk Selection
echo ""
print_bold 111 "2. Target Disk Selection"
print_color 204 "WARNING: All data on the selected disk will be completely erased!"

DISKS=$(lsblk -dno NAME,SIZE,MODEL,TYPE | awk '$1 !~ /^(loop|zram|sr|fd)/ && $NF == "disk" { model=""; for(i=3;i<NF;i++) model=model $i " "; gsub(/ $/, "", model); print "/dev/"$1" ("$2" "model")" }')

if [[ -z "$DISKS" ]]; then
  print_color 204 "Error: No suitable installation disks found!"
  exit 1
fi

mapfile -t DISK_ARRAY <<< "$DISKS"
SELECTED_DISK_STR=$(gum choose --header "Select the drive to install Fedomakase on:" "${DISK_ARRAY[@]}") || true
if [[ -z "$SELECTED_DISK_STR" ]]; then
  print_color 204 "No disk selected, aborting!"
  exit 1
fi

TARGET_DISK=$(echo "$SELECTED_DISK_STR" | awk '{print $1}')
TARGET_DISK_NAME=$(basename "$TARGET_DISK")

if [[ ! -b "$TARGET_DISK" ]]; then
  print_color 204 "Invalid disk selected!"
  exit 1
fi

# 3. LUKS Encryption Setup
echo ""
print_bold 111 "3. Drive Encryption (LUKS2)"
ENCRYPT_DRIVE=false
LUKS_PASSPHRASE=""

if gum confirm "Would you like to encrypt your drive with LUKS2?"; then
  while true; do
    LUKS_PASSPHRASE=$(gum input --password --header "LUKS encryption passphrase:") || true
    LUKS_CONFIRM=$(gum input --password --header "Confirm LUKS passphrase:") || true
    if [[ -z "$LUKS_PASSPHRASE" ]]; then
      print_color 204 "Passphrase cannot be empty. Please try again."
    elif [[ "$LUKS_PASSPHRASE" != "$LUKS_CONFIRM" ]]; then
      print_color 204 "Passphrases do not match. Please try again."
    elif [[ "$LUKS_PASSPHRASE" == *'"'* ]]; then
      print_color 204 "Passphrase cannot contain double-quote characters. Please try again."
    else
      print_color 108 "Passphrase confirmed."
      ENCRYPT_DRIVE=true
      break
    fi
  done
fi

# 4. User Account, Hostname & Timezone Setup
echo ""
print_bold 111 "4. User Account & System Identity"

REAL_NAME=$(gum input --header "Full Name:" --placeholder "e.g. Omarchy User" --value "Omarchy User") || true
REAL_NAME=${REAL_NAME//\"/}

RESERVED_USERNAMES='^(root|bin|daemon|mail|ftp|http|nobody|dbus|systemd-coredump|systemd-network|systemd-oom|systemd-journal-remote|systemd-resolve|systemd-timesync|tss|uuidd|alpm|git|avahi|cups|cups-browsed|lp|_talkd|polkitd|rtkit|qemu|brltty|gluster|rpc|libvirt-qemu|pcscd|nvidia-persistenced|sddm)$'
USERNAME=""
while true; do
  USERNAME=$(gum input --header "Username:" --placeholder "e.g. omarchy" --value "omarchy") || true
  if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && (( ${#USERNAME} <= 32 )) && ! [[ "$USERNAME" =~ $RESERVED_USERNAMES ]]; then
    break
  else
    print_color 204 "Invalid or reserved username. Use lowercase alphanumeric characters."
  fi
done

USER_PASSWORD=""
while true; do
  USER_PASSWORD=$(gum input --password --header "Enter Password for $USERNAME:") || true
  USER_PASS_CONFIRM=$(gum input --password --header "Confirm Password for $USERNAME:") || true
  if [[ -z "$USER_PASSWORD" ]]; then
    print_color 204 "Password cannot be empty. Please try again."
  elif [[ "$USER_PASSWORD" != "$USER_PASS_CONFIRM" ]]; then
    print_color 204 "Passwords do not match. Please try again."
  else
    print_color 108 "User password confirmed."
    break
  fi
done

# Hash password so nothing sensitive or quote-sensitive lands in the kickstart
USER_HASH=$(openssl passwd -6 "$USER_PASSWORD")
unset USER_PASSWORD USER_PASS_CONFIRM

HOSTNAME=""
while true; do
  HOSTNAME=$(gum input --header "Hostname:" --placeholder "Letters, digits, and dashes (default: omarchy)" --value "omarchy") || true
  [[ -z "$HOSTNAME" ]] && HOSTNAME="omarchy"
  if [[ "$HOSTNAME" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
    break
  else
    print_color 204 "Hostname must be 1-63 letters, digits, or dashes, and cannot start or end with a dash."
  fi
done

TIMEZONE_LIST="UTC
America/New_York
America/Chicago
America/Denver
America/Los_Angeles
America/Phoenix
America/Anchorage
Pacific/Honolulu
America/Toronto
America/Vancouver
America/Sao_Paulo
Europe/London
Europe/Dublin
Europe/Paris
Europe/Berlin
Europe/Amsterdam
Europe/Madrid
Europe/Rome
Europe/Zurich
Europe/Stockholm
Europe/Warsaw
Europe/Athens
Europe/Helsinki
Europe/Kyiv
Asia/Tokyo
Asia/Seoul
Asia/Shanghai
Asia/Hong_Kong
Asia/Taipei
Asia/Singapore
Asia/Kolkata
Asia/Dubai
Australia/Sydney
Australia/Melbourne
Pacific/Auckland"

if [[ -r /usr/share/zoneinfo/zone1970.tab ]]; then
  TIMEZONE_LIST=$( { echo "UTC"; awk '!/^#/ && NF>=3 {print $3}' /usr/share/zoneinfo/zone1970.tab | sort -u; } )
fi

TIMEZONE=$(printf '%s\n' "$TIMEZONE_LIST" | gum filter --height 10 --header "Select Timezone (type to filter):" --value "UTC") || true
[[ -z "$TIMEZONE" ]] && TIMEZONE="UTC"

# 5. Confirmation Summary
echo ""
gum style --border normal --margin "1 2" --padding "1 2" --border-foreground 74 \
  "Installation Summary:" \
  "  Keyboard Layout:   $KEYBOARD_LABEL ($KEYMAP)" \
  "  Target Drive:      $TARGET_DISK" \
  "  LUKS Encrypted:    $ENCRYPT_DRIVE" \
  "  User Account:      $USERNAME ($REAL_NAME)" \
  "  Hostname:          $HOSTNAME" \
  "  Timezone:          $TIMEZONE" \
  "  Desktop:           Hyprland + SDDM + Omarchy Theme"

if ! gum confirm "Begin installation and overwrite $TARGET_DISK now?"; then
  print_color 204 "Installation cancelled."
  exit 1
fi

# 6. Generate Anaconda partitioning & identity include consumed by omarchy-ks.cfg
{
  echo "keyboard --vckeymap=${KEYMAP}"
  echo "timezone ${TIMEZONE} --utc"
  echo "network --bootproto=dhcp --device=link --activate --hostname=${HOSTNAME}"
  echo "ignoredisk --only-use=${TARGET_DISK_NAME}"
  echo "clearpart --all --initlabel --drives=${TARGET_DISK_NAME}"
  if [[ $ENCRYPT_DRIVE == true ]]; then
    echo "autopart --type=btrfs --encrypted --luks-version=luks2 --passphrase=\"${LUKS_PASSPHRASE}\""
    printf '%s' "$LUKS_PASSPHRASE" > "$LUKS_PASS_FILE"
    chmod 600 "$LUKS_PASS_FILE"
  else
    echo "autopart --type=btrfs"
  fi
  echo "user --name=${USERNAME} --gecos=\"${REAL_NAME}\" --groups=wheel --password=${USER_HASH}"
} > "$PART_CFG"
chmod 600 "$PART_CFG"

printf 'INPUT_METHOD=%s\nXKB_LAYOUT=%s\n' "$INPUT_METHOD" "$XKB_LAYOUT" > "$INPUT_METHOD_FILE"
chmod 644 "$INPUT_METHOD_FILE"

unset LUKS_PASSPHRASE USER_HASH

echo ""
print_bold 108 "Fedomakase setup complete! Handing over to Anaconda..."
sleep 2
