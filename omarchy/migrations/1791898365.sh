echo "Speed up the boot menu and keep it quiet until a key is pressed"

if [[ -f /etc/default/grub ]] && [[ ! -f /etc/default/limine ]] && [[ -z ${OMARCHY_LIMINE_CONF:-} ]]; then
  changed=""
  if grep -Eq '^GRUB_TIMEOUT=5$' /etc/default/grub 2>/dev/null; then
    sudo sed -i 's/^GRUB_TIMEOUT=5$/GRUB_TIMEOUT=1/' /etc/default/grub
    changed=1
  elif ! grep -Eq '^GRUB_TIMEOUT=' /etc/default/grub 2>/dev/null; then
    echo 'GRUB_TIMEOUT=1' | sudo tee -a /etc/default/grub >/dev/null
    changed=1
  fi
  if ! grep -Eq '^GRUB_TIMEOUT_STYLE=' /etc/default/grub 2>/dev/null; then
    echo 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a /etc/default/grub >/dev/null
    changed=1
  fi
  if [[ ! -f /etc/sudoers.d/omarchy-grub-bootmenu ]]; then
    echo '%wheel ALL=(root) NOPASSWD: /usr/bin/grub2-editenv - set menu_show_once=1' | sudo tee /etc/sudoers.d/omarchy-grub-bootmenu >/dev/null
    sudo chmod 0440 /etc/sudoers.d/omarchy-grub-bootmenu
  fi
  if [[ -n $changed ]]; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true
    echo "The GRUB boot menu now waits 1 second and stays hidden until a key is pressed"
  fi
  exit 0
fi

limine_conf="${OMARCHY_LIMINE_CONF:-}"
if [[ -z $limine_conf ]]; then
  esp=""
  if [[ -r /etc/default/limine ]]; then
    esp=$(sed -n 's/^ESP_PATH=["'\'']\?\([^"'\'']*\).*/\1/p' /etc/default/limine | tail -n 1)
  fi
  limine_conf="${esp:-/boot}/limine.conf"
fi

if [[ ! -f $limine_conf ]]; then
  sudo -v
  sudo test -f "$limine_conf" || exit 0
fi

set_timeout=""
added_quiet=""
if ! sudo grep -Eqi '^[[:space:]]*timeout:' "$limine_conf"; then
  if sudo grep -Eqi '^[[:space:]]*#timeout:' "$limine_conf"; then
    sudo sed -i -E 's/^[[:space:]]*#timeout:.*/timeout: 1/I' "$limine_conf"
  else
    sudo sed -i '1i timeout: 1' "$limine_conf"
  fi
  set_timeout=1
fi

if ! sudo grep -Eqi '^[[:space:]]*quiet:' "$limine_conf"; then
  sudo sed -i -E '/^[[:space:]]*timeout:/I a quiet: yes' "$limine_conf"
  added_quiet=1
fi

if [[ -n $set_timeout && -n $added_quiet ]]; then
  echo "The boot menu now waits 1 second and stays quiet until a key is pressed"
elif [[ -n $set_timeout ]]; then
  echo "The boot menu now waits 1 second"
elif [[ -n $added_quiet ]]; then
  echo "The boot now stays quiet until a key is pressed; the boot timeout was left as it was"
fi
