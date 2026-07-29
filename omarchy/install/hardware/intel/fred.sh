# Enable Flexible Return and Event Delivery on Intel Panther Lake.

if omarchy-hw-intel-ptl; then
  if ! grep -q 'fred=on' /etc/default/grub; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
      sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 fred=on"/' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX="fred=on"' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command -v grubby &>/dev/null; then
      sudo grubby --update-kernel=ALL --args="fred=on"
    fi
  fi
fi
