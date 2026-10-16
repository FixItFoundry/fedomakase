# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
if lspci -nn | grep "106b:180[12]" >/dev/null; then
  echo "Detected MacBook with T2 chip. Installing support items..."

  omarchy-pkg-add \
    linux-t2 \
    linux-t2-headers \
    apple-t2-audio-config \
    apple-bcm-firmware-fetcher \
    t2fanrd

  # Enable T2 fan control
  systemctl enable t2fanrd.service

  mkdir -p /etc/modules-load.d
  {
    echo "t2bce_vhci"
    echo "hci_bcm4377"
  } > /etc/modules-load.d/t2.conf

  mkdir -p /etc/dracut.conf.d
  echo "add_drivers+=\" t2bce_vhci apple-bce usbhid hid_apple hid_generic xhci_pci xhci_hcd \"" > \
    /etc/dracut.conf.d/apple-t2.conf

  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/brcmfmac.conf <<'MODEOF'
# Fix for T2 MacBook WiFi connectivity issues
options brcmfmac feature_disable=0x82000
MODEOF

  if ! grep -q 'intel_iommu=on' /etc/default/grub 2>/dev/null; then
    if grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub 2>/dev/null; then
      sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 intel_iommu=on iommu=pt pm_async=off mem_sleep_default=deep"/' /etc/default/grub
    else
      echo 'GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt pm_async=off mem_sleep_default=deep"' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command -v grubby &>/dev/null; then
      sudo grubby --update-kernel=ALL --args="intel_iommu=on iommu=pt pm_async=off mem_sleep_default=deep"
    fi
  fi

  cat > /etc/t2fand.conf <<'FANEOF'
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
FANEOF
fi
