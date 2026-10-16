echo "Stop the boot from waiting on a black screen for the console to answer"

# systemd asks the console for its size when PID 1 starts and waits for the
# reply. With Plymouth holding the screen the reply sometimes never comes, and
# about 1 boot in 10 sits on a black screen until a key is pressed.
# systemd.tty.term.console=dumb makes systemd skip the query.

defaults_conf="${OMARCHY_LIMINE_DEFAULTS_CONF:-/etc/limine-entry-tool.d/omarchy-defaults.conf}"
running_cmdline="${OMARCHY_RUNNING_CMDLINE:-/proc/cmdline}"
rebuild_marker="${OMARCHY_LIMINE_REBUILD_MARKER:-/var/lib/omarchy/migrations/1791581004}"
param="systemd.tty.term.console=dumb"

[[ -r $running_cmdline ]] || exit 0
[[ ! -e $rebuild_marker ]] || exit 0
[[ " $(<"$running_cmdline") " != *" $param "* ]] || exit 0

if omarchy-cmd-present grubby && [[ -f /etc/default/grub ]]; then
  echo "The booted kernel is missing $param; updating GRUB kernel arguments"
  if ! grep -q "$param" /etc/default/grub 2>/dev/null; then
    sudo sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $param\"/" /etc/default/grub
  fi
  sudo grubby --update-kernel=ALL --args="$param"
  sudo install -Dm644 /dev/null "$rebuild_marker"
  exit 0
fi

omarchy-cmd-present limine-mkinitcpio || exit 0
[[ -f $defaults_conf ]] || exit 0
grep -Eq "^KERNEL_CMDLINE\[default\]\+=\".*${param//./\\.}.*\"" "$defaults_conf" || exit 0

echo "The booted kernel is missing $param; rebuilding the boot image"
sudo limine-mkinitcpio

limine_conf="${OMARCHY_LIMINE_CONF:-}"
if [[ -z $limine_conf ]]; then
  esp=""
  if [[ -r /etc/default/limine ]]; then
    esp=$(sed -n 's/^ESP_PATH=["'\'']\?\([^"'\'']*\).*/\1/p' /etc/default/limine | tail -n 1)
  fi
  limine_conf="${esp:-/boot}/limine.conf"
fi

if sudo grep -Eq '^[[:space:]]*cmdline:' "$limine_conf" 2>/dev/null &&
  ! sudo grep -Eq "^[[:space:]]*cmdline:.*[[:space:]]${param//./\\.}([[:space:]]|\$)" "$limine_conf"; then
  echo "The boot menu still has no entry with $param after the rebuild" >&2
  exit 1
fi

sudo install -Dm644 /dev/null "$rebuild_marker"
