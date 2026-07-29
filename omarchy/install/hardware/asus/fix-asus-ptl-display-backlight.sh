# Display backlight fix for ASUS Panther Lake / Xe3 iGPU laptops.
# Enabled only for ExpertBook B9406 and Zenbook UX5406AA for now.
# Other models need confirmation whether the issue exists there too.
#
# The panel's EDID on eDP-1 reads as empty, so xe takes backlight type from
# VBT (which says PWM) but the panel actually wants DPCD AUX backlight.
# Without xe.enable_dpcd_backlight=1, intel_backlight sysfs writes succeed
# but produce no visible change; brightness is effectively binary.

if omarchy-hw-asus-expertbook-b9406 || omarchy-hw-asus-zenbook-ux5406aa; then
  if ! grep -q 'xe.enable_dpcd_backlight=1' /etc/default/grub; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
      sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 xe.enable_dpcd_backlight=1"/' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX="xe.enable_dpcd_backlight=1"' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command -v grubby &>/dev/null; then
      sudo grubby --update-kernel=ALL --args="xe.enable_dpcd_backlight=1"
    fi
  fi
fi
