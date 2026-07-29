# Display fix for ASUS ExpertBook B9406 (Panther Lake / Xe3 iGPU).
#
# Panel Replay is Xe3-new, default-on in the xe driver, and has a broken
# exit/wake path on this eDP panel: the panel latches the last-presented
# frame in self-refresh and never wakes for subsequent atomic commits, so
# the screen only updates on a full modeset (e.g. a VT switch). The older
# xe.enable_psr=0 knob does not cover Panel Replay.

if omarchy-hw-asus-expertbook-b9406; then
  if ! grep -q 'xe.enable_panel_replay=0' /etc/default/grub; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
      sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 xe.enable_panel_replay=0"/' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX="xe.enable_panel_replay=0"' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command -v grubby &>/dev/null; then
      sudo grubby --update-kernel=ALL --args="xe.enable_panel_replay=0"
    fi
  fi
fi
