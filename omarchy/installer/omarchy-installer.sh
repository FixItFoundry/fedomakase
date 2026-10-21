#!/bin/bash
# Fedomakase Interactive TTY Installer (omarchy-installer.sh)
# 1-to-1 port of upstream Omarchy ISO `configurator` + `setup-form.sh` for
# Anaconda `%pre`. Hardware-agnostic and visually/behaviorally indistinguishable
# from the upstream Omarchy installer.
#
# Outputs consumed by omarchy-ks.cfg:
#   /tmp/fedomakase-part.cfg      (%include partitioning, keyboard, timezone, network, user)
#   /tmp/fedomakase-luks-pass     (LUKS passphrase when encrypted, used once in %post)
#   /tmp/fedomakase-input-method  (INPUT_METHOD + XKB_LAYOUT for /etc/omarchy/input-method)
#   /tmp/fedomakase-git-identity  (OMARCHY_USER_NAME + OMARCHY_USER_EMAIL for git config)

set -uo pipefail

export TERM="${TERM:-linux}"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

# In Anaconda %pre, the parent shell runs inside tmux on /dev/pts/0, so
# `exec </dev/tty3 >/dev/tty3 2>&1` leaves `/dev/tty` pointing at `/dev/pts/0`.
# Detach into a new session with `/dev/tty3` as the true controlling terminal
# so gum, ttfx, stty, and `read </dev/tty` all operate on `/dev/tty3`.
if [[ -z "${OMARCHY_CTTY_ATTACHED:-}" && -c /dev/tty3 ]] && command -v python3 &>/dev/null; then
  export OMARCHY_CTTY_ATTACHED=1
  chvt 3 2>/dev/null || true
  exec python3 -c '
import fcntl, os, sys, termios
os.setsid()
fd = os.open("/dev/tty3", os.O_RDWR)
fcntl.ioctl(fd, termios.TIOCSCTTY, 1)
os.dup2(fd, 0); os.dup2(fd, 1); os.dup2(fd, 2)
if fd > 2: os.close(fd)
os.execvp(sys.argv[1], sys.argv[1:])
' bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"
OMARCHY_PATH="${OMARCHY_PATH:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LOGO_PATH="$OMARCHY_PATH/logo.txt"

SETUP_FORM="$OMARCHY_PATH/install/provisioning/setup-form.sh"
if [[ ! -r "$SETUP_FORM" ]]; then
  echo "ERROR: shared setup form not found at $SETUP_FORM" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$SETUP_FORM"

PART_CFG="/tmp/fedomakase-part.cfg"
LUKS_PASS_FILE="/tmp/fedomakase-luks-pass"
INPUT_METHOD_FILE="/tmp/fedomakase-input-method"
GIT_IDENTITY_FILE="/tmp/fedomakase-git-identity"
rm -f "$PART_CFG" "$LUKS_PASS_FILE" "$INPUT_METHOD_FILE" "$GIT_IDENTITY_FILE"

export GUM_CONFIRM_PROMPT_FOREGROUND="6"
export GUM_CONFIRM_SELECTED_FOREGROUND="0"
export GUM_CONFIRM_SELECTED_BACKGROUND="2"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="7"
export GUM_CONFIRM_UNSELECTED_BACKGROUND="0"

LOGO_WIDTH=0
if [[ -r "$LOGO_PATH" ]]; then
  LOGO_WIDTH=$(python3 -c 'import sys; print(max(len(l.rstrip("\r\n")) for l in open(sys.argv[1], encoding="utf-8")))' "$LOGO_PATH" 2>/dev/null || echo 65)
fi
(( LOGO_WIDTH > 0 )) || LOGO_WIDTH=65

clear() {
  printf '\033[H\033[2J'
}

# Read (rows, cols) from /dev/tty even in Fedora 44 Anaconda stage2 where `stty` is absent
tty_size() {
  if command -v stty &>/dev/null; then
    stty size </dev/tty 2>/dev/null && return 0
  fi
  python3 -c 'import os; s=os.get_terminal_size(0); print(f"{s.lines} {s.columns}")' </dev/tty 2>/dev/null || printf '%s %s\n' "${LINES:-24}" "${COLUMNS:-80}"
}

tty_sane() {
  if command -v stty &>/dev/null; then
    stty sane </dev/tty 2>/dev/null && return 0
  fi
  python3 -c 'import termios; a=termios.tcgetattr(0); a[3]|=(termios.ECHO|termios.ICANON|termios.ISIG); termios.tcsetattr(0,termios.TCSANOW,a)' </dev/tty 2>/dev/null || true
}

# Scale console font on high-DPI panels to ~48 rows while keeping enough columns for the logo
scale_console_font() {
  [[ $(tty 2>/dev/null) == /dev/tty* ]] || return 0
  local target_rows=48 min_width=$((LOGO_WIDTH + 4))
  (( min_width < 81 )) && min_width=81
  local fonts=("default8x16" "sun12x22" "latarcyrheb-sun32")
  local best="" best_diff=999999 name rows cols diff
  for name in "${fonts[@]}"; do
    setfont "$name" 2>/dev/null || continue
    read -r rows cols < <(tty_size)
    [[ $rows =~ ^[0-9]+$ && $cols =~ ^[0-9]+$ ]] || continue
    (( cols > min_width )) || continue
    diff=$(( rows > target_rows ? rows - target_rows : target_rows - rows ))
    (( diff < best_diff )) && { best_diff=$diff; best="$name"; }
  done
  setfont "${best:-default8x16}" 2>/dev/null || true
}

# Apply upstream Omarchy Tokyo Night VT color palette
set_tokyo_night_colors() {
  [[ $(tty 2>/dev/null) == /dev/tty* ]] || return 0
  printf '\e]P01a1b26\e]P1f7768e\e]P29ece6a\e]P3e0af68\e]P47aa2f7\e]P5bb9af7\e]P67dcfff\e]P7a9b1d6'
  printf '\e]P8414868\e]P9f7768e\e]PA9ece6a\e]PBe0af68\e]PC7aa2f7\e]PDbb9af7\e]PE7dcfff\e]PFc0caf5'
  printf '\033[0m'
}

measure_terminal() {
  TERM_WIDTH=$(tty_size | awk '{print $2}')
  [[ ${TERM_WIDTH:-} =~ ^[0-9]+$ ]] && (( TERM_WIDTH > 0 )) || TERM_WIDTH=${COLUMNS:-80}

  PADDING_LEFT=$(((TERM_WIDTH - LOGO_WIDTH) / 2))
  (( PADDING_LEFT < 0 )) && PADDING_LEFT=0
  PADDING_LEFT_SPACES=$(printf "%*s" "$PADDING_LEFT" "")

  PADDING="0 0 0 $PADDING_LEFT"
  export GUM_CHOOSE_PADDING="$PADDING"
  export GUM_FILTER_PADDING="$PADDING"
  export GUM_INPUT_PADDING="$PADDING"
  export GUM_SPIN_PADDING="$PADDING"
  export GUM_TABLE_PADDING="$PADDING"
  export GUM_CONFIRM_PADDING="$PADDING"
}

wait_for_stable_terminal() {
  local width last="" stable=0 waited=0
  while (( waited < 5000 )); do
    width=$(tty_size | awk '{print $2}')
    [[ $width =~ ^[0-9]+$ ]] || width=0
    if [[ $width == "$last" ]] && (( width >= LOGO_WIDTH )); then
      (( ++stable >= 3 )) && break
    else
      stable=0
    fi
    last=$width
    sleep 0.2
    (( waited += 200 ))
  done
}

clear_logo() {
  measure_terminal
  printf "\033[H\033[2J"
  if [[ -r "$LOGO_PATH" ]]; then
    gum style --foreground 2 --padding "1 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
  fi
}

greeter() {
  measure_terminal

  local rows logo_h content_h top cols logo_row tagline_row hint_row
  local tagline hint tpad hpad anim=""
  cols=$TERM_WIDTH
  rows=$(tty_size | awk '{print $1}')
  [[ $rows =~ ^[0-9]+$ ]] || rows=${LINES:-24}
  logo_h=$(wc -l <"$LOGO_PATH" 2>/dev/null || echo 6)

  content_h=$((logo_h + 4))
  top=$(((rows - content_h) / 2))
  (( top < 0 )) && top=0
  logo_row=$((top + 1))
  tagline_row=$((top + logo_h + 2))
  hint_row=$((top + logo_h + 4))

  printf '\033[?25l\033[H\033[2J'

  printf '\033[%d;1H' "$logo_row"
  if [[ -r "$LOGO_PATH" ]]; then
    gum style --foreground 2 --padding "0 0 0 $PADDING_LEFT" "$(<"$LOGO_PATH")"
  fi

  tagline="Beautiful, Fun & Agentic Linux by DHH"
  tpad=$(((cols - ${#tagline}) / 2)); (( tpad < 0 )) && tpad=0
  printf '\033[%d;%dH%s' "$tagline_row" "$((tpad + 1))" "$tagline"

  hint="Press Return to Start Install"
  hpad=$(((cols - ${#hint}) / 2)); (( hpad < 0 )) && hpad=0
  printf '\033[%d;%dH\033[2m%s\033[0m' "$hint_row" "$((hpad + 1))" "$hint"

  if command -v ttfx &>/dev/null && [[ -r "$LOGO_PATH" ]]; then
    printf '\033[%d;1H\0337' "$((logo_row + logo_h))"
    ttfx -i "$LOGO_PATH" \
      --canvas-width "$((cols > 2 ? cols - 2 : cols))" \
      --anchor-text c \
      --frame-rate 60 \
      --reuse-canvas \
      --xterm-colors \
      colorshift \
      --gradient-stops 2 10 6 10 \
      --gradient-frames 3 \
      --cycles 1000 \
      --final-gradient-stops 2 \
      </dev/null >/dev/tty 2>/dev/null &
    anim=$!
  fi

  IFS= read -r _ </dev/tty || true
  if [[ -n "$anim" ]]; then
    kill "$anim" 2>/dev/null || true
    wait "$anim" 2>/dev/null || true
  fi
  tty_sane
  printf '\033[0m\033[H\033[2J\033[?25h'
}

abort() {
  gum style "${1:-Aborted installation}"
  exit 1
}

step() {
  clear_logo
  echo
  gum style --padding "0 0 0 $PADDING_LEFT" "$1"
  echo
}

say() {
  gum style --padding "0 0 0 $PADDING_LEFT" "$@"
}

notice() {
  clear_logo
  echo
  gum spin --spinner "pulse" --title "$1" -- sleep "${2:-2}"
  echo
}

# Fallback timezone prompt when timedatectl has no D-Bus inside Anaconda %pre
omarchy_prompt_timezone() {
  local guess status tz_list
  guess=$(tzupdate -p 2>/dev/null) || guess=""
  if timedatectl list-timezones &>/dev/null; then
    tz_list=$(timedatectl list-timezones)
  elif [[ -r /usr/share/zoneinfo/zone1970.tab ]]; then
    tz_list=$({ echo "UTC"; awk '!/^#/ && NF>=3 {print $3}' /usr/share/zoneinfo/zone1970.tab | sort -u; })
  else
    tz_list=$'UTC\nAmerica/New_York\nAmerica/Chicago\nAmerica/Denver\nAmerica/Los_Angeles\nAmerica/Toronto\nAmerica/Vancouver\nAmerica/Sao_Paulo\nEurope/London\nEurope/Paris\nEurope/Berlin\nEurope/Amsterdam\nEurope/Madrid\nEurope/Rome\nEurope/Zurich\nEurope/Stockholm\nEurope/Warsaw\nAsia/Tokyo\nAsia/Seoul\nAsia/Shanghai\nAsia/Singapore\nAsia/Kolkata\nAustralia/Sydney\nPacific/Auckland'
  fi

  if [[ -n $guess ]]; then
    timezone=$(printf '%s\n' "$tz_list" | gum choose --height 10 --selected "$guess" --header "Timezone") && status=0 || status=$?
  else
    timezone=$(printf '%s\n' "$tz_list" | gum filter --height 10 --header "Timezone") && status=0 || status=$?
  fi
  ((status == 0)) || return $status

  [[ -n $timezone ]] || timezone="UTC"
}

# STEP 1: KEYBOARD LAYOUT
keyboard_form() {
  local status

  while true; do
    clear_logo
    echo
    say "Let's setup your machine..."
    echo

    omarchy_prompt_keyboard && status=0 || status=$?
    ((status == 0)) && break
    ((status == OMARCHY_FORM_BACK)) && continue
    abort
  done

  if [[ $(tty 2>/dev/null) == "/dev/tty"* ]]; then
    loadkeys "$keyboard" 2>/dev/null || true
  fi
}

# STEP 2: USER ACCOUNT
user_form() {
  step "Let's setup your user account..."

  omarchy_prompt_username || return $?
  omarchy_prompt_password || return $?

  password_hash=$(printf '%s' "$password" | openssl passwd -6 -stdin)

  omarchy_prompt_identity || return $?
  omarchy_prompt_hostname || return $?
  omarchy_prompt_timezone || return $?
}

user_step() {
  local status

  while true; do
    user_form && status=0 || status=$?
    if ((status != 0)); then
      ((status == OMARCHY_FORM_BACK)) || abort
      keyboard_form
      continue
    fi

    echo -e "Field,Value
Username,$username
Password,$(printf "%${#password}s" | tr ' ' '*')
Full name,${full_name:-[Skipped]}
Email address,${email_address:-[Skipped]}
Hostname,$hostname
Timezone,$timezone
Keyboard,$keyboard" |
      gum table -s "," -p | sed "s/^/${PADDING_LEFT_SPACES}/"

    echo
    if gum confirm --negative "No, change it" "Does this look right?"; then
      break
    else
      keyboard_form
    fi
  done
}

# STEP 3: DISK
get_disk_info() {
  local device="$1"
  local size vendor model label

  size=$(lsblk -dno SIZE "$device" 2>/dev/null)
  vendor=$(lsblk -dno VENDOR "$device" 2>/dev/null | sed 's/ *$//')
  model=$(lsblk -dno MODEL "$device" 2>/dev/null | sed 's/ *$//')

  label=""
  if [[ -n $vendor && -n $model ]]; then
    if [[ $model == *$vendor* ]]; then
      label="$model"
    else
      label="$vendor $model"
    fi
  elif [[ -n $model ]]; then
    label="$model"
  elif [[ -n $vendor ]]; then
    label="$vendor"
  fi

  local display="$device"
  [[ -n $size ]] && display="$display ($size)"
  [[ -n $label ]] && display="$display - $label"

  local part_summary
  part_summary=$(lsblk -nro TYPE,NAME,FSTYPE,MOUNTPOINT "$device" 2>/dev/null | \
    awk '$1=="part" { printf "%s%s%s", s, ($3==""?"unknown":$3), ($4==""?"":"("$4")"); s=", " }')
  [[ -n $part_summary ]] && display+=" [$part_summary]"

  echo "$display"
}

get_root_disk() {
  local device="$1"
  local parent

  [[ -n $device ]] || return 1
  device=$(readlink -f "$device" 2>/dev/null || printf "%s\n" "$device")

  while true; do
    parent=$(lsblk -dno PKNAME "$device" 2>/dev/null | tail -n1)
    [[ -n $parent ]] || break
    device="/dev/$parent"
  done

  if [[ $(lsblk -dno TYPE "$device" 2>/dev/null) == "disk" ]]; then
    printf "%s\n" "$device"
  fi
}

to_gb() {
  awk -v bytes="$1" 'BEGIN {printf "%.1fGB", bytes/1024/1024/1024}'
}

disk_form() {
  step "Let's select where to install Omarchy..."

  local boot_source="" exclude_disk="" mp
  for mp in /run/install/repo /run/install/isodir /run/install/source /run/archiso/bootmnt; do
    boot_source=$(findmnt -no SOURCE "$mp" 2>/dev/null || true)
    [[ -n "$boot_source" ]] && break
  done
  exclude_disk=$(get_root_disk "$boot_source" || true)

  local available_disks
  available_disks=$(
    lsblk -dpno NAME,TYPE |
      awk '$2=="disk"{print $1}' |
      grep -E '/dev/(sd|hd|vd|nvme|mmcblk|xv)' |
      { if [[ -n "$exclude_disk" ]]; then grep -Fvx "$exclude_disk"; else cat; fi; }
  )

  local disk_options=""
  while IFS= read -r device; do
    if [[ -n "$device" ]]; then
      disk_info=$(get_disk_info "$device")
      disk_options="$disk_options$disk_info"$'\n'
    fi
  done <<<"$available_disks"

  selected_display=$(printf '%s' "$disk_options" | gum choose --header "Select install disk") || abort
  disk=$(echo "$selected_display" | awk '{print $1}')
}

# STEP 4: INSTALL MODE & ENCRYPTION
open_partition_tool() {
  step "Partition tool for $disk"
  gum style "Create unallocated free space for Omarchy, then write changes and quit."
  gum style --foreground 8 "Do not create an Omarchy partition here — leave the target area as Free space."
  gum style --foreground 8 "Tip: free-space install needs at least 32GB unallocated, plus 2GB more if no ESP already exists."
  echo
  gum confirm --affirmative "Open cfdisk" --negative "Back" "Open partition tool for $disk?" || return 0

  clear
  if command -v cfdisk &>/dev/null; then
    cfdisk "$disk" || true
  elif command -v fdisk &>/dev/null; then
    fdisk "$disk" || true
  else
    parted "$disk" || true
  fi
  partprobe "$disk" 2>/dev/null || true
  sync
  sleep 1
}

free_space_bytes() {
  parted -ms "$disk" unit B print free </dev/null 2>/dev/null | \
    awk -F: '
      $NF ~ /free/ {
        size=$4;
        gsub(/B/, "", size);
        if (size+0 > max+0) max=size;
      }
      END {
        print max+0;
      }'
}

requires_full_disk_install() {
  local pt_type free_b
  pt_type=$(lsblk -dno PTTYPE "$disk" 2>/dev/null)
  [[ -z "$pt_type" ]] && return 0

  free_b=$(free_space_bytes)
  [[ -z "$free_b" || "$free_b" -eq 0 ]]
}

not_enough_space() {
  local available="${1:-0}"
  step "Not enough free space on $disk"
  say --foreground 1 "$disk has $(to_gb "$available") of usable free space; Omarchy needs at least 32GB."
  say "Open the partition tool to free at least 32GB on $disk, then try again."
  echo
  if ! gum confirm --affirmative "Back" --negative "Open partition tool" "Return to installation mode?"; then
    open_partition_tool
  fi
  return 1
}

run_partition_decide() {
  partprobe "$disk" 2>/dev/null || true
  sleep 1

  local free_b min_b=$((32 * 1024 * 1024 * 1024))
  free_b=$(free_space_bytes)
  if [[ -z "$free_b" ]] || (( free_b < min_b )); then
    not_enough_space "${free_b:-0}"
    return $?
  fi

  local mode="encrypted" affirmative confirm_status
  while true; do
    clear_logo
    echo
    say "Install Omarchy in the $(to_gb "$free_b") of free space."

    case $mode in
      encrypted)
        say --foreground 8 "Press Ctrl+C for unencrypted install."
        affirmative="Yes, install"
        ;;
      unencrypted)
        affirmative="Yes, install without encryption"
        ;;
    esac
    echo

    gum confirm --affirmative "$affirmative" --negative "No, change it" \
      "Confirm installing on $disk"
    confirm_status=$?

    case $confirm_status in
      0)
        [[ $mode == "encrypted" ]] && encrypt_installation=true || encrypt_installation=false
        return 0
        ;;
      1)
        return 1
        ;;
      130)
        [[ $mode == "encrypted" ]] && mode="unencrypted" || mode="encrypted"
        ;;
      *)
        abort
        ;;
    esac
  done
}

confirm_disk_overwrite() {
  local mode="encrypted"
  local affirmative confirm_status

  while true; do
    clear_logo
    echo
    say "Everything will be overwritten. There is no recovery possible."

    if [[ $mode == "encrypted" ]]; then
      say --foreground 8 "Press Ctrl+C for unencrypted install."
      affirmative="Yes, install"
    else
      affirmative="Yes, install without encryption"
    fi

    echo
    gum confirm --affirmative "$affirmative" --negative "No, change it" "Confirm overwriting ${disk}"
    confirm_status=$?

    case $confirm_status in
      0)
        [[ $mode == "encrypted" ]] && encrypt_installation=true || encrypt_installation=false
        return 0
        ;;
      1)
        return 1
        ;;
      130)
        [[ $mode == "encrypted" ]] && mode="unencrypted" || mode="encrypted"
        ;;
      *)
        abort
        ;;
    esac
  done
}

install_mode_form() {
  local choices=("Full disk install")
  if ! $full_disk_only; then
    choices+=("Free space install (alongside existing data)")
  fi
  choices+=("Choose a different disk")

  step "Let's select how to install Omarchy..."
  install_mode=$(gum choose --header "Select installation mode on $disk" "${choices[@]}") || abort
}

select_installation() {
  local full_disk_only

  while true; do
    if requires_full_disk_install; then
      full_disk_only=true
    else
      full_disk_only=false
    fi

    if $full_disk_only; then
      install_mode="Full disk install"
    else
      install_mode_form
    fi

    case "$install_mode" in
      "Full disk install")
        if confirm_disk_overwrite; then
          install_target="full_disk"
          return 0
        fi
        $full_disk_only && disk_form
        ;;
      "Free space install"*)
        if run_partition_decide; then
          install_target="free_space"
          return 0
        fi
        ;;
      "Choose a different disk")
        disk_form
        ;;
    esac
  done
}

# --- Main Wizard Execution ---
if ! command -v gum &>/dev/null; then
  echo "Error: 'gum' is required for the Omarchy installer." >&2
  exit 1
fi

install_target="full_disk"
encrypt_installation=true

wait_for_stable_terminal
scale_console_font
set_tokyo_night_colors
measure_terminal

greeter
keyboard_form
user_step
disk_form
select_installation

clear

# Write Anaconda Kickstart %include and state files
target_disk_name=$(basename "$disk")
gecos_name="${full_name:-$username}"
gecos_name="${gecos_name//\"/}"
luks_pass_escaped="${password//\"/\\\"}"

{
  echo "keyboard --vckeymap=${keyboard}"
  echo "timezone ${timezone} --utc"
  echo "network --bootproto=dhcp --device=link --activate --hostname=${hostname}"
  echo "ignoredisk --only-use=${target_disk_name}"
  if [[ $install_target == "free_space" ]]; then
    echo "clearpart --none --drives=${target_disk_name}"
  else
    echo "zerombr"
    echo "clearpart --all --initlabel --drives=${target_disk_name}"
  fi
  if [[ $encrypt_installation == true ]]; then
    echo "autopart --type=btrfs --encrypted --luks-version=luks2 --passphrase=\"${luks_pass_escaped}\""
    printf '%s' "$password" > "$LUKS_PASS_FILE"
    chmod 600 "$LUKS_PASS_FILE"
  else
    echo "autopart --type=btrfs"
  fi
  echo "user --name=${username} --gecos=\"${gecos_name}\" --groups=wheel,input --password=${password_hash} --iscrypted"
} > "$PART_CFG"
chmod 600 "$PART_CFG"

printf 'INPUT_METHOD=%s\nXKB_LAYOUT=%s\n' "${keyboard_input_method:-none}" "${keyboard_xkb_layout:-}" > "$INPUT_METHOD_FILE"
chmod 644 "$INPUT_METHOD_FILE"

printf 'OMARCHY_USER_NAME=%q\nOMARCHY_USER_EMAIL=%q\n' "$full_name" "$email_address" > "$GIT_IDENTITY_FILE"
chmod 600 "$GIT_IDENTITY_FILE"

unset password password_confirmation password_hash luks_pass_escaped
